import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// A comprehensive token flow testing utility for Agora integration
class TokenFlowTester {
  static const String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';
  static const String agoraAppId = 'b7487b8a48da4f89a4285c92e454a96f';

  late RtcEngine _engine;
  bool _isEngineInitialized = false;
  String? _currentToken;
  String? _currentChannelName;
  int? _currentUid;

  /// Initialize Agora RTC Engine
  Future<bool> initializeEngine() async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      
      _isEngineInitialized = true;
      print('✅ Agora Engine initialized successfully');
      return true;
    } catch (e) {
      print('❌ Failed to initialize Agora Engine: $e');
      return false;
    }
  }

  /// Test complete token flow from generation to channel join
  Future<Map<String, dynamic>> testCompleteTokenFlow() async {
    final List<Map<String, dynamic>> steps = [];
    bool overallSuccess = true;

    // Step 1: Initialize Engine
    print('🔄 Step 1: Initializing Agora Engine...');
    final initResult = await initializeEngine();
    steps.add({
      'step': 'Engine Initialization',
      'success': initResult,
      'message': initResult ? 'Engine initialized' : 'Engine initialization failed',
    });
    if (!initResult) overallSuccess = false;

    // Step 2: Generate Token
    print('🔄 Step 2: Generating token...');
    final tokenResult = await _generateToken();
    steps.add({
      'step': 'Token Generation',
      'success': tokenResult['success'],
      'message': tokenResult['message'],
      'token': tokenResult['token'],
    });
    if (!tokenResult['success']) overallSuccess = false;

    // Step 3: Test Token Validity
    if (tokenResult['success'] && _isEngineInitialized) {
      print('🔄 Step 3: Testing token validity...');
      final validityResult = await _testTokenValidity();
      steps.add({
        'step': 'Token Validity Test',
        'success': validityResult['success'],
        'message': validityResult['message'],
      });
      if (!validityResult['success']) overallSuccess = false;
    }

    // Step 4: Test Channel Join/Leave
    if (overallSuccess && _currentToken != null) {
      print('🔄 Step 4: Testing channel join/leave...');
      final joinResult = await _testChannelJoinLeave();
      steps.add({
        'step': 'Channel Join/Leave Test',
        'success': joinResult['success'],
        'message': joinResult['message'],
      });
      if (!joinResult['success']) overallSuccess = false;
    }

    // Step 5: Cleanup
    print('🔄 Step 5: Cleaning up...');
    await _cleanup();
    steps.add({
      'step': 'Cleanup',
      'success': true,
      'message': 'Resources cleaned up',
    });

    return {
      'overallSuccess': overallSuccess,
      'steps': steps,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Generate token using Supabase function
  Future<Map<String, dynamic>> _generateToken() async {
    try {
      _currentChannelName = 'test-${Random().nextInt(10000)}';
      _currentUid = Random().nextInt(100000);

      final response = await http.post(
        Uri.parse(supabaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channelName': _currentChannelName,
          'uid': _currentUid,
          'role': 'publisher',
          'expireTimeInSeconds': 3600,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentToken = data['token'];
        
        return {
          'success': true,
          'message': 'Token generated successfully',
          'token': _currentToken,
          'channelName': _currentChannelName,
          'uid': _currentUid,
        };
      } else {
        return {
          'success': false,
          'message': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Token generation error: $e',
      };
    }
  }

  /// Test token validity by attempting to join channel
  Future<Map<String, dynamic>> _testTokenValidity() async {
    if (!_isEngineInitialized || _currentToken == null || _currentChannelName == null) {
      return {
        'success': false,
        'message': 'Engine not initialized or token/channel not available',
      };
    }

    try {
      // Set up event handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('✅ Token valid - joined channel successfully');
          },
          onError: (ErrorCodeType err, String msg) {
            print('❌ Agora Error: $err - $msg');
          },
        ),
      );

      // Test join with token
      await _engine.joinChannel(
        token: _currentToken!,
        channelId: _currentChannelName!,
        uid: _currentUid!,
        options: const ChannelMediaOptions(),
      );

      // Wait a moment for connection
      await Future.delayed(const Duration(seconds: 2));

      return {
        'success': true,
        'message': 'Token is valid for channel join',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Token validity test failed: $e',
      };
    }
  }

  /// Test channel join and leave operations
  Future<Map<String, dynamic>> _testChannelJoinLeave() async {
    try {
      bool joinSuccess = false;
      bool leaveSuccess = false;

      // Set up event handlers for monitoring
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            joinSuccess = true;
            print('✅ Channel join successful');
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            leaveSuccess = true;
            print('✅ Channel leave successful');
          },
          onError: (ErrorCodeType err, String msg) {
            print('❌ Channel operation error: $err - $msg');
          },
        ),
      );

      // Join channel
      await _engine.joinChannel(
        token: _currentToken!,
        channelId: _currentChannelName!,
        uid: _currentUid!,
        options: const ChannelMediaOptions(),
      );

      // Wait for join
      await Future.delayed(const Duration(seconds: 3));

      // Leave channel
      await _engine.leaveChannel();

      // Wait for leave
      await Future.delayed(const Duration(seconds: 2));

      if (joinSuccess && leaveSuccess) {
        return {
          'success': true,
          'message': 'Channel join/leave test successful',
        };
      } else {
        return {
          'success': false,
          'message': 'Join: $joinSuccess, Leave: $leaveSuccess',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Channel join/leave test error: $e',
      };
    }
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    try {
      if (_isEngineInitialized) {
        await _engine.leaveChannel();
        await _engine.release();
        _isEngineInitialized = false;
      }
      _currentToken = null;
      _currentChannelName = null;
      _currentUid = null;
      print('✅ Cleanup completed');
    } catch (e) {
      print('⚠️ Cleanup error: $e');
    }
  }

  /// Quick token flow test
  static Future<void> quickTest() async {
    print('🚀 Starting Token Flow Test');
    print('============================');
    
    final tester = TokenFlowTester();
    final result = await tester.testCompleteTokenFlow();
    
    print('\n📊 Test Results:');
    print('Overall Success: ${result['overallSuccess'] ? '✅' : '❌'}');
    
    final steps = result['steps'] as List;
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      print('${i + 1}. ${step['step']}: ${step['success'] ? '✅' : '❌'}');
      print('   ${step['message']}');
    }
    
    print('============================');
  }
}

/// Main function for standalone testing
void main() async {
  await TokenFlowTester.quickTest();
}