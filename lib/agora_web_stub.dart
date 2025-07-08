// Web stub implementation for Agora RTC Engine
// This file provides stub implementations for web platform compatibility

import 'dart:html' as html show window;
import 'package:flutter/foundation.dart';

// Stub class for Agora RTC Engine on web platform
class AgoraRtcEngineWebStub {
  static const String _platformNotSupported = 'Agora RTC Engine is not fully supported on web platform';

  // Initialize Agora Engine (stub implementation)
  static Future<void> initialize({
    required String appId,
    Map<String, dynamic>? config,
  }) async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      // For web platform, we might use Agora Web SDK in the future
      // For now, just log the initialization attempt
      debugPrint('Agora Web SDK initialization attempted with appId: $appId');
    }
  }

  // Join channel (stub implementation)
  static Future<void> joinChannel({
    required String token,
    required String channelName,
    required String uid,
    Map<String, dynamic>? options,
  }) async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to join channel: $channelName with uid: $uid');
    }
  }

  // Leave channel (stub implementation)
  static Future<void> leaveChannel() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to leave channel');
    }
  }

  // Enable video (stub implementation)
  static Future<void> enableVideo() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to enable video');
    }
  }

  // Disable video (stub implementation)
  static Future<void> disableVideo() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to disable video');
    }
  }

  // Enable audio (stub implementation)
  static Future<void> enableAudio() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to enable audio');
    }
  }

  // Disable audio (stub implementation)
  static Future<void> disableAudio() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to disable audio');
    }
  }

  // Mute local audio (stub implementation)
  static Future<void> muteLocalAudioStream(bool muted) async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to ${muted ? 'mute' : 'unmute'} local audio');
    }
  }

  // Mute local video (stub implementation)
  static Future<void> muteLocalVideoStream(bool muted) async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to ${muted ? 'mute' : 'unmute'} local video');
    }
  }

  // Switch camera (stub implementation)
  static Future<void> switchCamera() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to switch camera');
    }
  }

  // Set camera auto focus (stub implementation)
  static Future<void> setCameraAutoFocusFaceModeEnabled(bool enabled) async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to set camera auto focus: $enabled');
    }
  }

  // Enable speaker phone (stub implementation)
  static Future<void> setEnableSpeakerphone(bool enabled) async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to set speaker phone: $enabled');
    }
  }

  // Set channel profile (stub implementation)
  static Future<void> setChannelProfile(int profile) async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to set channel profile: $profile');
    }
  }

  // Set client role (stub implementation)
  static Future<void> setClientRole(int role) async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to set client role: $role');
    }
  }

  // Start preview (stub implementation)
  static Future<void> startPreview() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to start preview');
    }
  }

  // Stop preview (stub implementation)
  static Future<void> stopPreview() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to stop preview');
    }
  }

  // Destroy engine (stub implementation)
  static Future<void> destroy() async {
    if (kIsWeb) {
      debugPrint(_platformNotSupported);
      debugPrint('Attempted to destroy Agora engine');
    }
  }

  // Check if platform is supported
  static bool get isSupported => !kIsWeb;

  // Get platform name
  static String get platformName => kIsWeb ? 'Web' : 'Mobile';

  // Web-specific helper methods
  static void showWebNotSupportedMessage() {
    if (kIsWeb) {
      html.window.console.warn('Agora RTC Engine features are not available on web platform. '
          'Please use the mobile app for full video calling functionality.');
    }
  }

  // Future implementation placeholder for Agora Web SDK
  static Future<void> initializeWebSDK({
    required String appId,
    Map<String, dynamic>? config,
  }) async {
    if (kIsWeb) {
      debugPrint('Future implementation: Agora Web SDK initialization');
      // TODO: Implement Agora Web SDK integration
      // This would require including the Agora Web SDK JavaScript files
      // and creating a proper bridge between Flutter Web and Agora Web SDK
    }
  }

  // Error handling for unsupported operations
  static void throwIfNotSupported(String operation) {
    if (kIsWeb) {
      throw UnsupportedError('$operation is not supported on web platform. '
          'Please use the mobile app for full Agora functionality.');
    }
  }
}

// Platform check utilities
class AgoreWebPlatformCheck {
  static bool get isWebPlatform => kIsWeb;
  static bool get isMobilePlatform => !kIsWeb;
  
  static void logPlatformInfo() {
    debugPrint('Platform: ${kIsWeb ? 'Web' : 'Mobile'}');
    debugPrint('Agora support: ${AgoraRtcEngineWebStub.isSupported ? 'Full' : 'Limited (Web stub)'}');
  }
}

// Export for conditional imports
typedef AgoraWebStub = AgoraRtcEngineWebStub;