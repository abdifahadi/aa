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
            'Call ‰PNG

   IHDR   H   H   Uí³G   sRGB ®Îé   DeXIfMM *    ‡i                            H        H    1Fï  jIDATxí[kŒ]Õu^çŞ;sçŞyxüšñsŒí1Æ<ìØ¦…Œ„#””Q•Ò„"54 †"5¥­RúiûBy4M#UI

M•FÄ"	ŠR3€ÆØgìñØ&~g<sgîëôûÖŞëÌ¾/×Ğş°«Yö9kíµ×Z{­µgŸ}ÏˆÌÃ|æ30ŸùÌg`>ó˜ÏÀ|æ30ŸÿóD—cñw¾ß¹”X.K§©İH&c‘Ÿ–+òõŠfšÊ| fÇí³³rM%#ƒQ¾E²6®J!#òÍl6z÷˜j)zÉ`şJÜçäŸuÅ÷-êÉ¤«’ò´ŒIO‹ÂÕ8’©BJN—7£X>ñåOE§Ôr„l±(ëÊi—˜ŞPEGÂö ¤Ó
±oÈ7]ªFòñî¶hW­µ^¢½–ğ™ŒÿjÓ@üG3…óR©”äúåYYÚ•Fì±LÍÆR(‹Š±LÑmÀ…hğ‹šŒ§0 ^™tJ–-”·FâŸö-îxêÎ¨Œ$ä/"	)’ÄH`A¯‚ªø$Ã2
!_yUùIgG´ÃWhÔ:Aq=ı)TK§³ÅREî¸6/}=æçœ;s½Ç¹‡DÀL!—8&Œ‰ÃÅ¤¥SiéÈDÒÙ‘–¥½YéÉFÇ—/ĞÄ­€MÙÀÓBİ¨h’y%%ASG‰óm’¢H»«Qùò8˜®ÍááoÉº®…ìÉÉŠ6Ø×ò	°EˆÉÀ?L,ÂükÇÕ•d)’ÉÑ’I“—’4£Î³9¨•Æc€¼@­Ib€ x ¦j’$ÊTG¤}fFV£x„¼-´,W¹nffVÎª²v1ÄĞ-˜
’BÚ2œÉ öIh#Oıõ3škpğ’<½i¥sÛ”$Î€$!¦K¾Ñ¦Ø£Y¬dSè®-Ô–ül9–Ş|JîÜÔ-+¶“¶$ IuØç#q"	˜2&¬¤	ÁÚˆb•‚—UQĞ¦bªªmS"Óh_÷ò^yñÓßˆÏªMw;´‰~ñ«Doü–d`²Væ/ÿ£|{zòÛÜÒ-=¹tR™8›pDfK"ÇĞôéI0G-9¦£áf|š°ºÀ\S^X¹ô±ó±Œ =tÉÜªâ8^ˆâRQ¾ÙqA~ï¹Ç¢‰KÙk9‚KÛu+Ûk’CCa¯‘~ó¨È¿½Å§“H.+É6@e›µLOÿğÁÔ±>â¹¢ãÛÄr(‹;%šLËØqÜ÷ğ?Ä÷|õÁÖÛ–	;òó%›¸ÆÍõ¸®~°Ñ÷Şùş‘­ë]bªô§´+&´ÕƒÈPVÕ¼Ñ*È±lú&£ºÔór‰-+{¬>Q£‡€=’,ÁÓ³'/ùã§å?±Şü÷ŸŠö»ÚÚ{ÓfÏ:Ú?>½²Fš˜’¯ 9›V¹`kœõõ@3]â°¬AS¾_eÛÓ«…ÜeëÃóÄeáü”`m•L±,_ë.\Ğ4Aå®®œÆ‹¦ŞùÌĞÑYl÷¸`YJÊ(a	5¾yaõ,'ú^Oy>14`²´k`<–}ß¶ù¤òÔ÷¶´ìPkÔÊÅ²ÃlÖã¦	ê©VKø—>54hˆA&€ÂxÁ­9ÚÃ¾‚rİ9'?=‹’¨A ^1êñ¿†ÖàÙï('c¼zĞıÒäxÛê¨%ÖÛ¤>ëdşÎai6>Ö)¬ÍÁ¶Æ5µ{÷nœ)ÇÅôÙ‹Áb/x'ˆİëDm°\£nÙ¼Fç·s€ ÔoÃqœ.+h öy(Û¨°ºM¹}ò¾µ± ï“¿´Å]Ø±Ìµã;ˆ6ë¡i‚Dş¹Çé¸ŒÕl|3€9QoÀø½x¤DßW0p^1ÇT«™ÄÀé¤òÔIx >yZëë|™<õÁcŠ05úd¶€	b›œµ˜Ju	ÒÆØ¸w€2ÆSš7@0hu’	0=2<Ÿ•¡-Mxõ×èRÇë_â¦ú³NíyMc'ş Øš®A”N§Ú´­‹³5DAg©súÈ÷ª¦\öh¥L˜ê²"Ğe/Wß@]×ºÖ,a¡Mmím:éÆ{Ëá½KmÎàø"–,8òCš“ñNxÈ›Â"í, {9ÊëÈ0“>­§Œ—S›¤uÏñÁº<}êòòí¨=Ğ§EŒ8¾ÚÚ§ífĞ2A©TFÍ—xv°ÆtäxK¾}uFeĞèiWi‰ Œéš¼Ê¢ å Ç-šúÿI?¬§MßˆÚ¢!€ñ¦q†ydÔ•›Õ;éÚ{Ë¥ÓfÖ·èõ®wFË¤Gê“£u¾ŞäBLÓV&İL_e dr	&°²Ò(˜ŸjK%æx¬3y“ó"¨e‚Ê|Ò8ì½”mr&ƒã!…¤ìŠ‡;ùÔ!$º¤=“ïJıqT{æ¶n+æô¼n¨ŸØ	§#™ mËÍ¢úèm©à%n­EÕJŠÓ©«-’r¹*œıØùIƒlÈ7†“¹mÊ{Cù4$p¾³'Ch%¾şÆu"~37°Läà1‘³ã¾—«Ñ‡}3ŸøÅv=“˜ò‹‰l¹	4êvıõ¶‘5åĞAO»¨ë*ğ.ÖNV¾#Âa0Kİ(Ò}rêTÔÃú$„ÎR~X`ú`´·¡Còs5,ß€„];€‘Œ]0õõ
"ŸÖ¾ú	¾Ê‚oâÄL–‰²é“¬‡¦	B®uëİ;+•hÖC`˜$ëéXâœKÊ¨ÓDyYV«/‡úœ^,<R¢±ÈÍ™º¼®Ù¬ÃÔ³mA«öi×¢Q¿ÈàÕš&(•*ëZĞóôN1H`öhÛw`ÒµgN&5§ûr¢ïM?l+6oY‡ÓñX]"ëm%~$í“éÁ’cu¦oõõ¸ù”k¯An³Èd%ë,Õ‹–ØØ¾‚˜-º¦Í)Wèƒa‡u¤i3¼Vö‰ôâaÿ°ÈÄEoƒ22ÍhÚÀ»œÁ6„I¢ıQY”[AóUËš ®ş’Q•Ö ‚9PcŒ-{àğŞ{ß8Ù¬ÖËË™óõÉRYÈx1T”CŒ«£/Å×áA€ó¨qtˆêz¡µÛ$º÷m´ºYûf'ÄM§^TİÂ"Éu¯î–Ğ5l†[PlĞäŒV¦ñMßøÄ®[H99+sšõc4™?¦O{Fkûd …4y(Û¥BMnÍGP\ÑuêJä¬ 5şÆÅõÿkÀ·[Óû	Ñ$4òšê˜Ñ†ÃzÏ«˜Ê$“$¡ÀSA:“¼’„úÆeÉ2šlÒIûõÁ°>€	r#(ß†	±èpñ•#Ê¨“ªÏF@„=À¶¶á|špğ41¤5›Ş¡0˜¦‚"ÊzZËL KŒòP?‰ãÒÑ1ß>•ªç;Di/¬4ê{zEÖª¨ìÂÓû ‚µïJµ÷¦	Âº£c§µüå’oc|Ôw€[Ÿp3ÎâFáêhtÕ1Ü(c4›·²ÑÄÚÓx¤<ÒLN‚Q8r?3¡Ô¶Ç»&<\%íq/ÕÃcbV{=ÅõA¡Ş I‚îOW¢ÑL.›É´£¶Ì,ÃX±î¥µŞ°Lãt8q‚&è0/£‰íò'pj±L0¾¾ã­œO/ÏWìUÎW0á­„µOû¼¬N}´øõĞ Û‡³2“‘¾ùnµÂìÂ@#H™Ï7ÛŠ­`2À¶ÔëšÃ¦BÒfBƒAÅØI7rt¤ íDß+±œë—¥+†eQß¨tä'¥#‡y˜)tJaª[¦&°#_'ÕJ¯ê'£Îk‚”)òç¿~±hÇ`tÓ†—ğ>FPxSÂ9ª|–á¸½\rg@=«S7òœ¥¹:Ú"¿€}Šî(˜ TSGï{Ó§ €zİOÉà¯I×¢aìÆebz\Îœ›…ÏXÅa«-İ†×|MÒß+ÙÎ^i/¯“ŞÅ·É™S}5'ŸÎbí½!Aé¸¤ëOo'FpsXÂ'00h-SÄ;ËÑòê>WK²‰Iø²ò¼éoğÃX[ÖâcòãğmdÌ}NS/ëtªríÖKßÀëò‹³crtø,´˜ÖÀI”ÊX'
³¹0‰ßÇ±?XÜ3&·ì–±Ã7Ë[ÿµ5İí@¿„è=¸E17‰YÏtóé¥¯ôp§øÈ¶ûºƒâ×<N,“öÃÄ¦˜êx%“¯Ç”Ã¯µ'ÒLX¨o4ëé¶Y¹ñÖïI”{[ö>„öø(¹4è¹Z–Óã§äìÄY¹fÅE¹ı®sò‹wïn©Ø˜ºjF÷@¹Lû ŠQáçxWôÓŒÖ×ÙUÚ3:1YbIÌ›b“ó">˜œšzê 4I8£brJéİrht?dËè$×†Ù™UÏSº£¤‰KøzºqÛn¹æ#ß“]ñSƒ…í5$(·IÌµeğÀæ`u/¬œgexûĞ‹¤5``²¹»İ¸Ò]<Ó1Y“óš*lz†Í,eõ‚pˆUÎØ°åÇ"Ù=2rü°[ÁÂÅ«Š¡eØÑLy½˜4M°%ğÈ‰ÃRnÛ#eÑ3‰Ñ l—uM+ì^iÿúÌuˆÓ›7€l`)¾¬Ä+@V(¦A*ÁBP®7€:&à‘Ã^ÇÃyÑ‚S²dõëèıƒXĞİ“•˜W•‰ò˜´&I;y‡UÎë:z —â£/ÇÏnwÌİT­âCBÀŞÛ=‹O´`œ#IŸdtØq­Ê%Áó¬.	ÖH~Â3Y«ó˜l“	±&Ù×ŞôšŒA@³š ëÈúèÈb˜8\6Â(OÁ’#GO`Oıw-A	Âï©ºy8qvjâ;S24Ë1y™ÂÇ˜Áodf,Wrwøæ x¨„³2Ñ7:LV~¾û¼ä–÷ÏœÀaĞ˜B‡4yÍ/·–Ş»êÓòàÚÏk’tªA6g‹³;ÿ=~şZç´»7,LÓ¹êHn6ƒ¯gğ¾ƒ3WGÜŞd_ke3eyöÁXÚñÒÊ„0Xb‚b£•›Ÿ¬³Ëªˆ¿éi=™ÔáúF`|â%ËFäÌøiíy­dâ)t€òífufÂ÷­ùŒÜºäãRªeYv:ugˆ¶Wö­şu¨'#©ašîÍw/[±æXöíi$iLƒÆçĞò/?Ã¯o€š·lï:T^Åy/=°'—IÌ"1 Ùñõ@“3Z™aÿ¨œ>*:mtÙ4âbìF–(¿@sjqZıÆšß•_éû„&çëÿBF&ßS~[^gÎóG½ø.k—¸a‘944Tzğéuo\(•¤Ò‰Ç58œ•#Ù=V’ßŸ”şE9ÉãmÖÕù€¡ËÏ^ê§m29š(µëêHˆ›é³¯ÓÇ§u-1Ynbsé.™©<ß¢€o•ããşuÈGû~U“óµ÷ş\\xK7Àœb´A˜šÖÕeÀ•Ü½a%•¥¶wsYüí€MæÛñû†oûø…Šœºˆ…Cus­v¶œ’°KÓŞ¼š0ÚtXÎvLáÃô‚%nÑÍ¥ºä³7<-~~à‚£†£*Y‡bùÍµÈmı.9_Ùÿg²ÿü~írk•-âÓØmøQ{-ôØİÑ,vÓ¯8IL5L±ŞÎH²HTGÖıÓ8Šõùh¬÷YÔ¤`çX™¶B:	LÖ‚,×ëóñm0[Ğ¶D¶/•mKvÈooøCL]~—‚)Åú¿µîQ¹}Ùİ:r¾¼ïO“ä¨$ØÓtCñ·–	b=>¢zhÃŠÎS‚\3ÒéÎ„:d9¦WVc]”e`tŒ@”Ì2ä)&A»@„PŸe•#aöøVŞiGP~£|tâ<»÷óø»‘)Ù¶ôyhã“PÀh‡¿LÎå¿†äÌÊï|AöÒ'Ÿ0®SJã¢mÀIŞš®AVùÈGóÇŸÿY|ıÖõ]}aºò1ØX×™KELNO¸Ø1Y $H6Ú³’ ¯˜â¸,~¹ö9¼­OÒ¬SFï_xWÙó¤<¾å‹²Iâ‚<Uš;VÜ£Éy~ïtä8¥Ö÷}y%8‚¯ønüÜ#cÃ_Üs`OSŸ¯éÙ(°õo%—éÔú"FÎs{ş$I;Cgƒï›¾–„Í7ãw·õO~2úlëÇ|Ó–¯&–Ş—–-]¦#„k‡-Ä6e†Ç÷Ëß½ñ9nLÎ³oş±ì;óz²¨s]âºekmVŒì-_º›Çè;a¸–¼wEÓß¿ôÊëû†vŒ4øi?0¬ï½£(äàdŞ†	¤±F‹8×:X»j­Ü|Ãö~2zìcaÕ%× PğJ¡Ş7^¿ûè‰Ñ¨ÌÃ0ŞÉCçŞQŠiòã“SUìDDßÃ&6	ñŞD‚.ùK¤® âè÷‡rÙÜ·nşe}òéc:xª…O8a±Lìh¼Ø*ïpî	Æ}Ó-›oÁß™ä^ íúP¯º1€.9÷øÊş•»¶mú^yÜZ®G.iäû—Yÿ*Á?İk1’†´mÓVY[´YŸ–¯º5È‚x9~aa,å=öşØ?z¯AşW@ğÁÙ4#Ûhâ¶LFnß~›¬^¶jW$™ûî‰Åu#\µ	b(<&åIàôÌô£oîßıüèa}Â5†9ÇáB>¸f½lİ´%Îwä_àÈ¹3zª1»^åªN…Í“@vM¦wÅÚ~šÆ‹íLA§QW.'İ]İ-«e`Åj|â—ÿ!äfkÙ4üÿ"AÌKñ3qRx/&,øVn/ø1I°C~€•é¥{£ÇñáÌ<Ìg`>W@şòOÉâî.    IEND®B`‚                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                ‰PNG

   IHDR         àw=ø   sRGB ®Îé   DeXIfMM *    ‡i                                        â5u­  IDATHc`ê€ŸŒÓX_¼»ÀøÿÀÆÿ&ŒRõÿŸ1şg<óŸ‘qƒ„î†³ggıÆeNd”-şşï¶¶6Qöóqa°03d›óâÅk†§Î3lÚ²‡áèÑ3w˜KŸÜ=¾—%(âL2Šæ]¶¡ÿŸ8÷Ÿ ©©ééE1¤0(,ıÿ‡Ÿ™—©ééÅf&\, ×b8Ì°O@A‹€"TFÁâz°¼~ıöxTöÿş‰sÿÿúõfV¤dÈ,;¤-CÃ£s04nŞ²ç¿´‚9Û;‡ÿ?qò<†d ³`À#”A© 5Ã…îÜ}À‘ÉPZÑÆ ¸82dÈ,˜ÜP:%EB dáò•›\"ÖoÜ‰¡d$Ï@¤à€2,cèÂ"ğæÍ;†Ü‚z†Îîé(²3`’ÉupÎDÁ‘ÿ‚$Œ¤ >’ÿŸr(:`dÀÙED„&Ohd¨,ËBÑòòå ÿÿ3˜ ÜPÙÊş„ ###CD˜/Ã=+ıİ1”ƒÌ ™“€[ *¸@e> ¢¬À°fÅt†Îj~>¬JAf€ÌÂÄ•Ñ¿xõ?26ïÿ„If44-*`^¢ia²„ÚÅ5ö4.jT88- ù†U&Èœ¡ ‹ªœ±äY+ğ    IEND®B`‚                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              