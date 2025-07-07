import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

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

  bool _isInitialized = false;
  String? _fcmToken;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request permission for notifications
      final permission = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );

      if (permission.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
      } else {
        debugPrint('❌ Notification permission denied');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('🔄 FCM Token refreshed: $token');
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');

    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create notification channels for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _createNotificationChannels();
    }
  }

  Future<void> _createNotificationChannels() async {
    const messagesChannel = AndroidNotificationChannel(
      AppConstants.defaultNotificationChannelId,
      AppConstants.defaultNotificationChannelName,
      description: 'Notifications for new messages',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const callsChannel = AndroidNotificationChannel(
      AppConstants.callNotificationChannelId,
      AppConstants.callNotificationChannelName,
      description: 'Notifications for incoming calls',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('ringtone'),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messagesChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callsChannel);
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground message received: ${message.messageId}');
    
    // Show local notification for foreground messages
    _showLocalNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('📨 Background message received: ${message.messageId}');
    // Handle background message processing here
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.messageId}');
    // Handle navigation based on notification data
    _handleNotificationNavigation(message.data);
  }

  // Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');
    // Handle navigation based on payload
  }

  // Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'message':
        // Navigate to chat screen
        debugPrint('Navigate to chat: ${data['chatId']}');
        break;
      case 'call':
        // Navigate to call screen
        debugPrint('Navigate to call: ${data['callId']}');
        break;
      default:
        debugPrint('Unknown notification type: $type');
    }
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = AppConstants.defaultNotificationChannelId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      AppConstants.defaultNotificationChannelId,
      AppConstants.defaultNotificationChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Send message notification
  Future<void> sendMessageNotification({
    required String title,
    required String body,
    required String chatId,
    required String senderId,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: 'message:$chatId:$senderId',
    );
  }

  // Send call notification
  Future<void> sendCallNotification({
    required String callerName,
    required String callType,
    required String callId,
  }) async {
    await _showLocalNotification(
      title: 'Incoming $callType call',
      body: 'From $callerName',
      payload: 'call:$callId',
      channelId: AppConstants.callNotificationChannelId,
    );
  }

  // Play ringtone for incoming calls
  Future<void> playRingtone() async {
    try {
      // This would typically use a plugin like just_audio to play ringtone
      debugPrint('🔔 Playing ringtone...');
      // Implementation would depend on your audio plugin choice
    } catch (e) {
      debugPrint('❌ Error playing ringtone: $e');
    }
  }

  // Stop ringtone
  Future<void> stopRingtone() async {
    try {
      debugPrint('🔕 Stopping ringtone...');
      // Implementation would depend on your audio plugin choice
    } catch (e) {
      debugPrint('❌ Error stopping ringtone: $e');
    }
  }

  // Show test notification
  Future<void> showTestNotification() async {
    await _showLocalNotification(
      title: 'Test Notification',
      body: 'This is a test notification from developer menu',
      payload: 'test',
    );
  }

  // Get FCM token
  Future<String?> getFCMToken() async {
    try {
      _fcmToken ??= await _firebaseMessaging.getToken();
      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Update badge count (iOS)
  Future<void> updateBadgeCount(int count) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _firebaseMessaging.setAutoInitEnabled(true);
      // Badge count is typically managed by the server or through a plugin
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