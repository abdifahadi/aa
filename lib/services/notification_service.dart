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
    try {
      // Request notification permissions
      await _requestNotificationPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Setup Firebase Messaging
      await _setupFirebaseMessaging();

      debugPrint('NotificationService: Initialization completed successfully');
    } catch (e) {
      debugPrint('NotificationService: Initialization failed: $e');
    }
  }

  Future<void> _requestNotificationPermissions() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Request other permissions
    await Permission.notification.request();
    await Permission.microphone.request();
    await Permission.camera.request();
  }

  Future<void> _setupFirebaseMessaging() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');

        if (message.data['type'] == 'call') {
          // Handle incoming call
          _handleCallNotificationData(message.data);
        } else {
          // Handle regular message notification
          _showLocalNotification(
            title: message.notification?.title ?? 'New Message',
            body: message.notification?.body ?? '',
            payload: message.data['chatId'] ?? '',
          );
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

    // Listen for incoming calls from Firestore
    _setupBackgroundCallListener();
  }

  void _handleCallNotificationData(Map<String, dynamic> data) {
    final String callId = data['callId'] ?? '';
    final String callerId = data['callerId'] ?? '';
    final String callerName = data['callerName'] ?? 'Unknown';
    final String callType = data['callType'] ?? 'audio';

    // Create a CallModel from the message data
    final CallModel call = CallModel(
      id: callId,
      callerId: callerId,
      callerName: callerName,
      callerPhotoUrl: data['callerPhotoUrl'] ?? '',
      receiverId: _auth.currentUser?.uid ?? '',
      receiverName: data['receiverName'] ?? '',
      receiverPhotoUrl: data['receiverPhotoUrl'] ?? '',
      channelId: data['channelId'] ?? '',
      token: data['token'] ?? '',
      type: callType == 'video' ? CallType.video : CallType.audio,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
      numericUid: int.tryParse(data['numericUid'] ?? '0') ?? 0,
      participants: [callerId, _auth.currentUser?.uid ?? ''],
    );

    showIncomingCallNotification(call);
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

    debugPrint('Setting up background call listener for user: ${currentUser.uid}');

    // Listen to the user's calls subcollection for incoming calls
    _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('calls')
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      debugPrint('Background listener received call snapshot: ${snapshot.docs.length} documents');

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
          debugPrint('Call is no longer ringing (status: ${call.status}), not showing UI');
        }
      } else {
        debugPrint('Call document not found for ID: $callId');
      }
    }).catchError((error) {
      debugPrint('Error fetching call document: $error');
    });
  }

  // Show incoming call notification
  void showIncomingCallNotification(CallModel call) {
    debugPrint('Showing incoming call notification for: ${call.callerName}');
    _activeCallId = call.id;
    
    // Start playing ringtone
    _playRingtone();
    
    // Show local notification
    _showIncomingCallLocalNotification(call);
  }

  // Show incoming call screen
  void showIncomingCallScreen(CallModel call) {
    debugPrint('Attempting to show incoming call screen');
    
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            call: call,
            onAccept: () => _acceptCall(call),
            onDecline: () => _declineCall(call),
          ),
          fullscreenDialog: true,
          settings: const RouteSettings(name: '/incoming_call'),
        ),
      );
    } else {
      debugPrint('Navigator key is null, cannot show incoming call screen');
    }
  }

  // Show incoming call local notification
  void _showIncomingCallLocalNotification(CallModel call) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'call_channel',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    _flutterLocalNotificationsPlugin.show(
      call.hashCode,
      'Incoming ${call.type == CallType.video ? 'Video' : 'Audio'} Call',
      'From ${call.callerName}',
      platformChannelSpecifics,
      payload: call.id,
    );
  }

  // Show general local notification
  void _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'message_channel',
      'Messages',
      channelDescription: 'Notifications for messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Play ringtone (public method for manual triggering)
  void playRingtone() async {
    _playRingtone();
  }

  // Play ringtone (internal method)
  void _playRingtone() async {
    if (!_isRingtonePlaying) {
      try {
        _isRingtonePlaying = true;
        // Using a default system sound, you can replace with custom ringtone
        await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
        debugPrint('Playing ringtone');
      } catch (e) {
        debugPrint('Error playing ringtone: $e');
        // Fallback to system sound
        _isRingtonePlaying = false;
      }
    }
  }

  // Stop ringtone
  void stopRingtone() async {
    if (_isRingtonePlaying) {
      try {
        await _audioPlayer.stop();
        _isRingtonePlaying = false;
        debugPrint('Stopped ringtone');
      } catch (e) {
        debugPrint('Error stopping ringtone: $e');
      }
    }
  }

  // Accept call
  Future<void> _acceptCall(CallModel call) async {
    debugPrint('Accepting call: ${call.id}');
    stopRingtone();
    
    // Update call status in Firestore
    try {
      await _firestore.collection('calls').doc(call.id).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      // Cancel notification
      await _flutterLocalNotificationsPlugin.cancel(call.hashCode);
      
    } catch (e) {
      debugPrint('Error accepting call: $e');
    }
  }

  // Decline call
  Future<void> _declineCall(CallModel call) async {
    debugPrint('Declining call: ${call.id}');
    stopRingtone();
    
    // Update call status in Firestore
    try {
      await _firestore.collection('calls').doc(call.id).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
      
      // Cancel notification
      await _flutterLocalNotificationsPlugin.cancel(call.hashCode);
      
      // Pop incoming call screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pop();
      }
      
    } catch (e) {
      debugPrint('Error declining call: $e');
    }
  }

  // Get FCM token
  Future<String?> getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  // Update FCM token in Firestore
  Future<void> updateFCMToken() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final token = await getFCMToken();
      if (token != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM token updated in Firestore');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // Cleanup
  void dispose() {
    _audioPlayer.dispose();
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
  
  if (message.data['type'] == 'call') {
    // Handle background call notification
    debugPrint('Background call notification received');
    // The actual call handling will be done when the app comes to foreground
  }
}