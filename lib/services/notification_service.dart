import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/call_model.dart';
import '../screens/incoming_call_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Audio player for ringtone
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRingtonePlaying = false;
  String? _activeCallId;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Global navigator key to access context from anywhere
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Set the navigator key (useful for sharing the same key across the app)
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
    debugPrint('NotificationService: Using shared navigator key');
  }

  Future<void> initialize() async {
    // Request notification permissions
    await _requestNotificationPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Setup Firebase Messaging
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
            'Message also contained a notification: ${message.notification}');

        if (message.data['type'] == 'call') {
          // Handle incoming call
          final String callId = message.data['callId'] ?? '';
          final String callerId = message.data['callerId'] ?? '';
          final String callerName = message.data['callerName'] ?? 'Unknown';
          final String callType = message.data['callType'] ?? 'audio';

          // Create a CallModel from the message data
          final CallModel call = CallModel(
            id: callId,
            callerId: callerId,
            callerName: callerName,
            callerPhotoUrl: message.data['callerPhotoUrl'] ?? '',
            receiverId: _auth.currentUser?.uid ?? '',
            receiverName: message.data['receiverName'] ?? '',
            receiverPhotoUrl: message.data['receiverPhotoUrl'] ?? '',
            channelId: message.data['channelId'] ?? '',
            token: message.data['token'] ?? '',
            type: callType == 'video' ? CallType.video : CallType.audio,
            status: CallStatus.ringing,
            createdAt: DateTime.now(),
            numericUid: int.tryParse(message.data['numericUid'] ?? '0') ?? 0,
            participants: [callerId, _auth.currentUser?.uid ?? ''],
          );

          showIncomingCallNotification(call);
        }
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notifications opened app from terminated state
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null && message.data['type'] == 'call') {
        _handleCallNotification(message);
      }
    });

    // Handle notification when app is in background but opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'call') {
        _handleCallNotification(message);
      }
    });

    // Listen for incoming calls from Firestore even when app is in background
    _setupBackgroundCallListener();
  }

  Future<void> _initializeLocalNotifications() async {
    debugPrint('Initializing local notifications');

    // Initialize settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize settings for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialize settings for all platforms
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('Local notifications initialized successfully');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');

    // Parse the payload to get call information
    if (response.payload != null) {
      try {
        final callId = response.payload!;

        // Fetch call details from Firestore
        _firestore.collection('calls').doc(callId).get().then((doc) {
          if (doc.exists) {
            final CallModel call = CallModel.fromFirestore(doc);

            // Only show incoming call if it's still ringing
            if (call.status == CallStatus.ringing ||
                call.status == CallStatus.dialing) {
              showIncomingCallScreen(call);
            }
          }
        });
      } catch (e) {
        debugPrint('Error handling notification tap: $e');
      }
    }
  }

  // Setup background call listener
  void _setupBackgroundCallListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    debugPrint(
        'Setting up background call listener for user: ${currentUser.uid}');

    // Listen to the user's calls subcollection for incoming calls
    _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('calls')
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      debugPrint(
          'Background listener received call snapshot: ${snapshot.docs.length} documents');

      if (snapshot.docs.isNotEmpty) {
        final callDoc = snapshot.docs.first;
        final call = CallModel.fromFirestore(callDoc);

        // Show notification for incoming call
        _showIncomingCallLocalNotification(call);

        // Also try to show the call screen directly if possible
        showIncomingCallNotification(call);
      }
    }, onError: (error) {
      debugPrint('Error in background call listener: $error');
    });
  }

  // Handle call notification
  void _handleCallNotification(RemoteMessage message) {
    final String callId = message.data['callId'] ?? '';
    debugPrint('Handling call notification for call ID: $callId');

    // Fetch call details from Firestore
    _firestore.collection('calls').doc(callId).get().then((doc) {
      if (doc.exists) {
        final CallModel call = CallModel.fromFirestore(doc);
        debugPrint('Found call document with status: ${call.status}');

        // Only show incoming call if it's still ringing
        if (call.status == CallStatus.ringing ||
            call.status == CallStatus.dialing) {
          showIncomingCallScreen(call);
        } else {
          debugPrint(
              'Call is no longer ringing (status: ${call.status}), not showing UI');
        }
      } else {
        debugPrint(
            'Call �PNG

   IHDR   H   H   U�G   sRGB ���   DeXIfMM *    �i            �       �       H�       H    �1F�  jIDATx�[k�]�u^��;s��yx���s��1�<�ئ���#��Q���"54��"5��R�i�By4M#UI

M�F�"	�R3��؎g���&~�g<sg�������̾/�����Y�9k��Z{��g�}ψ��|�30����g`>����|�30����D�c�w�����X.K���H&c���+���f��| f��rM%#�Q�E�6�J!#��l6z��j)z�`�J���u��-�ɤ�����IO���8��BJN��7�X>��OE���r��l�(��i���PEG�� ��
�o�7]�F���hW��^������j�@�G3��R�����YYڕF�L��R(���L�m��h�����0 ^�tJ�-��F��-��x�Ψ�$�/"	)���H`A����$�2
!_yU�IgG��Wh�:Aq=�)TK���RE�6/}=��;s�ǹ�D�L!�8&���Ť�Si��D�ّ���Y��FǗ/�ĭ�M���Bݨh��y%%ASG��m���H��Q��8�����oɺ����Ɋ6�ם�	�E���?L,��k�Օ�d)��ђI���4�γ9���c��@�Ib� x��j�$�TG�}fFV�x��-�,W�nffV���v1��-�
�B�2�� �Ih#O��3�kp�<�i�s��$Ώ�$!�K�Ѧ�أY�dS��-Ԟ��l9��|J���-+����$�Iu��#q"	�2&��	�ڈb���UQЦb��mS"�h_��^y��߈ϪMw;��~�Do��d`�V�/��|{z����-=�tR�8�pDfK"����I0G-9����f|����\S^X���� =t�ܪ�8^��RQ��qA~�Ǣ�K�k9�K�u+�k�CCa��~�ȿ�ŧ�H.+�6@e��LO���Ա>⹢���r(�;%�L��q���?��|���ہ�	;��%�������~���������]b����+&�Ճ��PVռ��*ȱl�&����r�-+{�>Q���=�,�ӳ'/���?����������{�fϝ:�?>��F���� 9�V�`k���@3]ⰬAS�_e�ӫ��e����e���`m�L�,_�.\�4A宮��Ƌ�������Yl��`YJ�(a	5�ya�,'�^Oy>14`��k`<�}߶��������Pk��Ų�l��	�VK��>5�4h�A&��x��9�þ�r�9'?=����A�^1�������('c�z�����x��%�ۤ>��d��ai6>�)������5�{�n�)���ً�b/x'���Dm�\�nټF�s� �o�q�.+h���y(ۨ��M�}���� ��]ر̵�;�6�i�D���鸌�l|�3�9Qo���x�D�W0p^1�T�������Ix�>yZ��|�<��c�05�d��	b����Ju	��ظw�2�S�7@0hu�	0=2<���-Mx���R��_���N�yM�c'�����A�N�ڴ���5DAg�s�������\�h�L��"�e/W�@]׺�,a�Mm��m:��{��Km���"�,8�C���Nxț�"�, {9���0�>����S��u����<}����=��E�8��ڧ�f�2A�TF͗xv��t�xK�}uFe��iWi���隼ʢ���-����I?��M߈ڢ!��q�ydԕ��;��{���fַ���wFˤGꓣu���BL�V&�L_e dr	&���(��jK%�x�3y��"�e��|�8코mr&��!��슎�;��!$��=��J�qT��{��n+���n���	�#� m�͢��m��%n�E�J�ө�-�r�*����I�l�7���mʐ{C�4$p��'Ch%���u"�~37�L��1��ま��ч}3���v=����l�	4�v����5��AO���*�.�NV�#�a0�K�(�}r�T���$��R�~X`�`���C�s5,߀�];���]0��
"�־�	�ʂo��L�����铬��	B�u�ݍ;+�h�C`�$��X�Kʨ�DyYV��/���^,<R��������٬�ԳmA��iעQ�����&(�*�ZЎ��N1H�`�h�w`Ҏ�gN&�5��r��M?l+�6oY����X]"�m%~$����cu�o�����k�An��d%�,��������-���)W�a�u�i3�V����a����Eo�22�h�����6�I��QY�[A�U˚����Q�� �9Pc�-{���{�8٬��˙���RY�x1T�C���/���A��qt���z����$��m��Y�f'�M�^T��"�u���5l��[Pl��V��M��Į[H99+s��c4�?�O{Fk�d �4y(ۥBMn�GP\�u�J���5�����k��[��	�$4��ц�zϫ��$�$��SA:������e�2�l�I����>�	r#(߆	��p�#�ʨ���F@�=����|�p��41�5�ޡ0����"�zZ�L K��P?����1�>���;Di/�4�{zE������� ���J���	º�c����oc|�w�[�p3Ξ�F��ht�1�(c4�������x�<�LN�Q8r?3�Ԏ�ǻ&�<\%�q/��cbV{=��A�ޠI��OW��L.�ɴ���,�X�ށ�L�t8q�&�0/�����'pj�L0���㭜O/�W�U�W0ឭ��O���N}���А�ۇ�2����n����@#H���7ۊ�`2����æB�fB�A��I7rt���D�+�����+�eQߨt�'�#�y�)tJa�[�&�#_'�J��'��k��)��~�h�`tӆ���>FPxS�9�|�ḽ\rg@=�S7򜥹:�"��}��(� TS�G�{ӧ �z�O����Iעa��ebz\Μ���X�a�-݆�|M��+��^i/���ŷəS}5'��b�!A鸤�Oo'FpsX�'00h-S�;����>WK���I�����o��X[��c���md�}NS/�t�r��K����crt�,����I��X'
��0��Ǳ?X�3&�����7�[���5��@���=�E17�Y��t�饯�p��ȶ�����<�N,���Ħ��x%��ǔï�'��LX�o4��Y����I�{[�>���(�4��Z������Y�f�E���s�w�n�ؘ�jF�@��L�� �Q��xW�ӌ���U�3:�1YbI̛b��">���z� 4I8�brJ��rht?d��$ׁ�ٙU�S����K�z��q�n��#ߓ]�S���5$(�I̵e���`u/��gex�Ћ�5``���ݸ�]<�1Y��*lz��,e��p�U�ذ��"�=2r��[��ū��e��Ly��4M�%�ȉ�Rn�#e�3�ѐ l�uM+�^i���u�ӛ�7�l`)���+@V(�A*�BP�7�:&����^��yтS�d�����X�ݓ��W��򘴎&�I;y�U��:z ��/��nw��T��CB����=�O�`�#I�dt�q��%��.	�H~�3Y��l�	�&�������A@�� ������b�8\6�(�O��#GO�`O��w-A	�喙y8qvj�;S24�1y���ǘ�odf��,Wrw�� x����2�7:LV�~������Ϝ�aИB�4y�/��޻������k�t�A�6g��;�=~�Z紻7,Lӹ�Hn6��g�3�WG��d_ke3ey��X���ʄ0Xb�b��������˪���i=����F`|�%�F���i�y�d�)t���fuf�����ܺ��R�eYv��:ug��W���u�'#�a����w/[��X��i$iL�����/?ïo���l�:T^�y/=�'�I�"1����@�3Z�a���>*:mt�4�b�F��(�@sjqZ�ƚߕ_���&���BF&�S~[^g��G��.k��a�944Tz��uo\(��҉�58��#�=V�ߟ��E9��m�������^�m29�(����H��鳎��ǧu-1Ynbs�.��<���o����u��G�~U����\\xK7��b�A����e��ܽa%���wsY���M�����o��������Cus�v����K�޼�0�tX�vL���%n�ͥ��7<-~~�����*Y�b�͵��m�.9_��g���~�rk�-���m�Q{-����,vӯ8IL5L���H�HTG���8����h��YԤ�`�X��B:	�L���,����m0[жD�/�mKv�oo�CL]~��)�����Q�}��:r���O��$��tC��	b=>�zhÊ�S�\3��΄:d9�WV�c]�e`t�@��2�)&A�@�P�e�#a��VޞiGP~�|t�<������)ٶ�yh�P�h��LΎ忆����|A���'��0�SJ�m�I���AV��G�ǟ�Y|���]}a��1�XיKELNO��1Y $H6ڳ� ���➸,~��9��OҬSF�_xW���<�勲I�<U��;Vܣ�y~�t�8����}y%8���n��#c�_�s`OS����(��o%����"F�s{�$I;Cg�������7�w��O~2�l��|Ӗ�&�ޗ�-]�#�k�-�6e����߽�9�nLγo���;�z��s]�ekm�V��-_����;a����wE�ߍ������v���4�i?0���(���dކ	���F�8ׁ:X�j��|��~2z�ca�%נP�J��7^���Ѩ��0��C��Q�i��SU�D�D��&6	��D�.�K�� ����r���n�e}��c:x��O8�a�L�h��*��p�	�}�-�o�ߙ�^���P��1�.9�������m�^y�Z�G.i���Y�*�?�k1���m�VY[�Y����5Ȃx9~aa,�=��؝?z�A�W@���4#�h�LFn�~��^�jW$���Łu#\�	b(<&�I�����o�����a}�5�9��B>�f�lݴ%�w�_�ȹ3z�1�^�N��͓@vM�w��Ł�~�Ƌ�LA�QW.'�]�-�e`�j|��!�fk��4��"A�K�3qRx/&�,�Vn/��1I�C�~���{�����<�g`>W@��O���.    IEND�B`�                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                �PNG

   IHDR         �w=�   sRGB ���   DeXIfMM *    �i            �       �       �           �5u�  IDATHc`�����X_��������&�R���1�g<�q���gg��eNd�-��ﶶ6Q��qa�03d������k���3lڲ����3w�K��=��%(�L2��]������8�� ����E1�0(,�����������f&\, אb8���O@A��"TF��z��~��xT����s����fV�d�,;�-Cãs04n޲翴�9�;��?q�<�d� �`�#�A� 5Å��}���PZ�� �82d�,��P:%EB d��\"�o܉�d$�@���2,�c��"���;�܂z����(�3`���up�D�����$�� >����r(:`d���ED�&Ohd�,�B���� ��3� �P���� ###CD�/Á=+��1��� ���[ *�@e>�����f�t���j~>�JAf��ĕў�x�?26���If4��4-*`^�ia����5�4.jT88- ��U&Ȝ� �����Y+�    IEND�B`�                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              