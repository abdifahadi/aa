import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:io'; // For Platform
import 'package:crypto/crypto.dart'; // For SHA-256
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import '../models/call_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloud Functions instance
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Collection references
  final CollectionReference _callsCollection =
      FirebaseFirestore.instance.collection('calls');

  // Agora App ID - Replace with your App ID
  final String appId = 'b7487b8a48da4f89a4285c92e454a96f';

  // Agora App Certificate - ONLY for development testing, replace with secure method in production
  final String appCertificate = '3305146df1a942e5ae0c164506e16007';

  // Agora RTC Engine instance
  RtcEngine? _engine;

  // Call timeout duration in seconds
  final int callTimeoutSeconds = 30;

  // Supabase function URL - Replace with your Supabase project URL
  final String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';

  // Expose engine for testing purposes
  RtcEngine? get engine => _engine;

  // Public method to generate tokens for testing
  Future<String> generateTokenForTesting(
      String channelName, String? uid) async {
    if (uid == null) {
      throw ArgumentError('User ID cannot be null');
    }
    return _generateTokenWithSupabase(channelName, uid);
  }

  // Generate numeric UID from string for Agora (public method)
  int generateNumericUidFromString(String uid, {bool isReceiver = false}) {
    if (uid.isEmpty) return 1;

    // Add a role suffix to differentiate caller from receiver
    final String uidWithRole = uid + (isReceiver ? "_receiver" : "_caller");

    // Simple hash function to convert string to integer
    int hash = 0;
    for (int i = 0; i < uidWithRole.length; i++) {
      hash = ((hash << 5) - hash) + uidWithRole.codeUnitAt(i);
      hash = hash & hash; // Convert to 32bit integer
    }

    // Ensure it's positive and within a reasonable range
    int positiveHash = hash.abs() % 1000000000;

    // Avoid using 0 as it's a special value in Agora
    if (positiveHash == 0) positiveHash = 1;

    debugPrint(
        'Generated fallback numeric uid $positiveHash from string uid $uid (${isReceiver ? "receiver" : "caller"})');
    return positiveHash;
  }

  // Initialize Agora engine
  Future<RtcEngine> initializeAgoraEngine() async {
    if (_engine != null) {
      debugPrint('✅ Reusing existing Agora engine');
      return _engine!;
    }

    try {
      debugPrint('🎙️ Initializing Agora engine...');
      
      // Create Agora engine
      _engine = createAgoraRtcEngine();
      
      // Initialize the engine
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Enable audio volume indication
      await _engine!.enableAudioVolumeIndication(
        interval: 1000,
        smooth: 3,
        reportVad: true,
      );

      debugPrint('✅ Agora engine initialized successfully');
      return _engine!;
    } catch (e) {
      debugPrint('❌ Error initializing Agora engine: $e');
      _engine = null;
      rethrow;
    }
  }

  // Check permissions for call
  Future<bool> _checkPermissions(CallType callType) async {
    List<Permission> permissions = [Permission.microphone];
    
    if (callType == CallType.video) {
      permissions.add(Permission.camera);
    }

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    for (Permission permission in permissions) {
      if (statuses[permission] != PermissionStatus.granted) {
        debugPrint('❌ Permission denied: $permission');
        return false;
      }
    }
    
    return true;
  }

  // Generate token with Supabase
  Future<String> _generateTokenWithSupabase(String channelName, String uid, {bool isReceiver = false}) async {
    try {
      debugPrint('🔑 Generating token with Supabase for channel: $channelName, uid: $uid');
      
      final response = await http.post(
        Uri.parse(supabaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_SUPABASE_ANON_KEY', // Replace with actual key
        },
        body: jsonEncode({
          'channelName': channelName,
          'uid': uid,
          'role': 'publisher',
          'expirationTimeInSeconds': 3600,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;
        debugPrint('✅ Token generated successfully: ${token.substring(0, 20)}...');
        return token;
      } else {
        throw Exception('Failed to generate token: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error generating token with Supabase: $e');
      rethrow;
    }
  }

  // Start a new call
  Future<CallModel?> startCall({
    required String receiverId,
    required String receiverName,
    required String receiverPhotoUrl,
    required CallType callType,
  }) async {
    try {
      // Get current user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No current user found');
        return null;
      }

      // Check permissions first
      if (!await _checkPermissions(callType)) {
        debugPrint('❌ Permission denied for call');
        return null;
      }

      // Generate a unique channel ID
      final String channelId = const Uuid().v4();

      // Generate a numeric UID for the caller based on their user ID
      final int numericUid = generateNumericUidFromString(currentUser.uid, isReceiver: false);
      debugPrint('Generated numeric uid $numericUid for caller ${currentUser.uid}');

      // Generate token
      String? token;
      try {
        token = await _generateTokenWithSupabase(channelId, currentUser.uid, isReceiver: false);
        
        if (token.isEmpty) {
          debugPrint('❌ Failed to generate token for call (empty token)');
          return null;
        }

        if (token.length < 100) {
          debugPrint('❌ Generated token is too short (${token.length} chars)');
          return null;
        }

        debugPrint('✅ Token received: ${token.substring(0, 20)}...');
      } catch (e) {
        debugPrint('❌ Token generation failed: $e');
        return null;
      }

      // Create participants array for easier querying
      final List<String> participants = [currentUser.uid, receiverId];

      // Create a call document
      final CallModel call = CallModel(
        id: channelId,
        callerId: currentUser.uid,
        callerName: currentUser.displayName ?? 'User',
        callerPhotoUrl: currentUser.photoURL ?? '',
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhotoUrl: receiverPhotoUrl,
        status: CallStatus.ringing,
        type: callType,
        createdAt: DateTime.now(),
        channelId: channelId,
        token: token,
        participants: participants,
        numericUid: numericUid,
      );

      // Save the call document with the channelId as document ID
      await _callsCollection.doc(channelId).set(call.toMap());
      debugPrint('📞 Call document created: $channelId');

      // Set up a timeout to automatically mark the call as missed if not answered
      _setupCallTimeout(channelId);

      // Send notification to receiver
      await _sendCallNotification(call);

      return call;
    } catch (e) {
      debugPrint('❌ Error starting call: $e');
      return null;
    }
  }

  // Set up call timeout
  void _setupCallTimeout(String callId) {
    Timer(Duration(seconds: callTimeoutSeconds), () async {
      try {
        // Check if call is still ringing
        final callDoc = await _callsCollection.doc(callId).get();
        if (callDoc.exists) {
          final callData = callDoc.data() as Map<String, dynamic>;
          final status = callData['status'] as String;
          
          if (status == 'ringing' || status == 'dialing') {
            // Mark as missed
            await _updateCallStatus(callId, CallStatus.missed);
            debugPrint('⏰ Call timeout: $callId marked as missed');
          }
        }
      } catch (e) {
        debugPrint('❌ Error handling call timeout: $e');
      }
    });
  }

  // Send call notification
  Future<void> _sendCallNotification(CallModel call) async {
    try {
      // This would trigger the Firebase Function to send the notification
      debugPrint('📤 Call notification should be sent automatically by Firebase Function');
    } catch (e) {
      debugPrint('❌ Error sending call notification: $e');
    }
  }

  // Update call status
  Future<void> _updateCallStatus(String callId, CallStatus status) async {
    try {
      await _callsCollection.doc(callId).update({
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('📞 Call status updated: $callId -> $status');
    } catch (e) {
      debugPrint('❌ Error updating call status: $e');
    }
  }

  // Join a call
  Future<bool> joinCall(CallModel call) async {
    try {
      debugPrint('📞 Joining call: ${call.id}');
      
      // Initialize Agora engine if not already initialized
      if (_engine == null) {
        _engine = await initializeAgoraEngine();
        if (_engine == null) {
          debugPrint('❌ Failed to initialize Agora engine');
          return false;
        }
      }

      // Get current user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No current user found');
        return false;
      }

      // Determine if this is the caller or receiver
      final bool isCaller = currentUser.uid == call.callerId;
      
      // Generate the proper UID for this user
      final int uid = isCaller
          ? call.numericUid
          : generateNumericUidFromString(currentUser.uid, isReceiver: true);

      debugPrint('Using UID: $uid (${isCaller ? "caller" : "receiver"})');

      // Configure channel options based on call type
      final options = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        publishCameraTrack: call.type == CallType.video,
        autoSubscribeAudio: true,
        autoSubscribeVideo: call.type == CallType.video,
        enableAudioRecordingOrPlayout: true,
      );

      // Register event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('✅ Successfully joined channel: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('👤 User joined: $remoteUid');
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('👤 User left: $remoteUid, reason: $reason');
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('❌ Agora error: $err - $msg');
          },
        ),
      );

      // Join the channel
      await _engine!.joinChannel(
        token: call.token,
        channelId: call.channelId,
        uid: uid,
        options: options,
      );

      debugPrint('✅ Joined Agora channel successfully');
      
      // Update call status to ongoing if receiver is joining
      if (!isCaller) {
        await _updateCallStatus(call.id, CallStatus.ongoing);
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error joining call: $e');
      return false;
    }
  }

  // Leave call
  Future<void> leaveCall(String callId) async {
    try {
      debugPrint('📞 Leaving call: $callId');
      
      if (_engine != null) {
        await _engine!.leaveChannel();
        debugPrint('✅ Left Agora channel');
      }

      // Update call status to ended
      await _updateCallStatus(callId, CallStatus.ended);
    } catch (e) {
      debugPrint('❌ Error leaving call: $e');
    }
  }

  // End call
  Future<void> endCall(String callId) async {
    try {
      await leaveCall(callId);
    } catch (e) {
      debugPrint('❌ Error ending call: $e');
    }
  }

  // Accept incoming call
  Future<bool> acceptCall(CallModel call) async {
    try {
      debugPrint('📞 Accepting call: ${call.id}');
      
      // Update status to accepted
      await _updateCallStatus(call.id, CallStatus.accepted);
      
      // Join the call
      return await joinCall(call);
    } catch (e) {
      debugPrint('❌ Error accepting call: $e');
      return false;
    }
  }

  // Reject incoming call
  Future<void> rejectCall(String callId) async {
    try {
      debugPrint('📞 Rejecting call: $callId');
      await _updateCallStatus(callId, CallStatus.rejected);
    } catch (e) {
      debugPrint('❌ Error rejecting call: $e');
    }
  }

  // Toggle mute
  Future<bool> toggleMute() async {
    try {
      if (_engine != null) {
        // This should track the current mute state and toggle it
        bool isMuted = false; // You should track this state in the class
        await _engine!.muteLocalAudioStream(!isMuted);
        debugPrint('🔇 Audio ${!isMuted ? "muted" : "unmuted"}');
        return !isMuted;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error toggling mute: $e');
      return false;
    }
  }

  // Toggle camera
  Future<bool> toggleCamera() async {
    try {
      if (_engine != null) {
        // This should track the current camera state and toggle it
        bool isEnabled = true; // You should track this state in the class
        await _engine!.muteLocalVideoStream(!isEnabled);
        debugPrint('📹 Camera ${!isEnabled ? "disabled" : "enabled"}');
        return !isEnabled;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error toggling camera: $e');
      return false;
    }
  }

  // Enable/disable speakerphone
  Future<void> enableSpeakerphone(bool enabled) async {
    try {
      if (_engine != null) {
        await _engine!.setEnableSpeakerphone(enabled);
        debugPrint('🔊 Speakerphone ${enabled ? "enabled" : "disabled"}');
      }
    } catch (e) {
      debugPrint('❌ Error setting speakerphone: $e');
    }
  }

  // Switch camera
  Future<void> switchCamera() async {
    try {
      if (_engine != null) {
        await _engine!.switchCamera();
        debugPrint('🔄 Camera switched');
      }
    } catch (e) {
      debugPrint('❌ Error switching camera: $e');
    }
  }

  // Get call by ID
  Future<CallModel?> getCall(String callId) async {
    try {
      final doc = await _callsCollection.doc(callId).get();
      if (doc.exists) {
        return CallModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting call: $e');
      return null;
    }
  }

  // Listen to call updates
  Stream<CallModel?> listenToCall(String callId) {
    return _callsCollection.doc(callId).snapshots().map((doc) {
      if (doc.exists) {
        return CallModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  // Listen to incoming calls for a user
  Stream<QuerySnapshot> listenToIncomingCalls(String userId) {
    return _callsCollection
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  // Test Agora connection
  Future<bool> testAgoraConnection(String channelId, String token, int uid) async {
    try {
      debugPrint('🧪 Testing Agora connection...');
      
      if (_engine == null) {
        await initializeAgoraEngine();
      }

      if (_engine == null) {
        debugPrint('❌ Failed to initialize engine for test');
        return false;
      }

      // Try to join channel briefly
      await _engine!.joinChannel(
        token: token,
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Leave immediately
      await _engine!.leaveChannel();
      
      debugPrint('✅ Agora connection test successful');
      return true;
    } catch (e) {
      debugPrint('❌ Agora connection test failed: $e');
      return false;
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.release();
        _engine = null;
        debugPrint('🗑️ Agora engine disposed');
      }
    } catch (e) {
      debugPrint('❌ Error disposing call service: $e');
    }
  }

  // Register event handler for call events
  void registerEventHandler(Function(CallEvent) handler, {
    Function(int, int)? onUserJoined,
    Function(int, int)? onUserOffline,
    Function(VideoState)? onLocalVideoStateChanged,
    Function(int, VideoState)? onRemoteVideoStateChanged,
    Function(int, AudioState)? onRemoteAudioStateChanged,
    Function(List<AudioVolumeInfo>)? onAudioVolumeIndication,
    Function(ConnectionState)? onConnectionStateChanged,
  }) {
    // Store the event handler for call events
    debugPrint('🎯 Registering event handler for call events');
    
    // Set up engine event handlers if engine is available
    if (_engine != null) {
      // Register engine event handlers here
      // This is where you'd wire up the actual Agora SDK event handlers
    }
  }

  // Enable audio (fixed method signature)
  Future<void> enableAudio([bool enable = true]) async {
    try {
      if (_engine != null) {
        if (enable) {
          await _engine!.enableAudio();
        } else {
          await _engine!.disableAudio();
        }
        debugPrint('🔊 Audio ${enable ? "enabled" : "disabled"}');
      }
    } catch (e) {
      debugPrint('❌ Error enabling audio: $e');
    }
  }

  // Answer call
  Future<void> answerCall(String callId) async {
    try {
      debugPrint('📞 Answering call: $callId');
      // Add your call answering logic here
      // This might involve joining a channel or updating call status
    } catch (e) {
      debugPrint('❌ Error answering call: $e');
    }
  }

  // Leave channel
  Future<void> leaveChannel() async {
    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        debugPrint('🚪 Left channel');
      }
    } catch (e) {
      debugPrint('❌ Error leaving channel: $e');
    }
  }

  // Mute local audio
  Future<void> muteLocalAudio(bool mute) async {
    try {
      if (_engine != null) {
        await _engine!.muteLocalAudioStream(mute);
        debugPrint('🔇 Local audio ${mute ? "muted" : "unmuted"}');
      }
    } catch (e) {
      debugPrint('❌ Error muting local audio: $e');
    }
  }
}