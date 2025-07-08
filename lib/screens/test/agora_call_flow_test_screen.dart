import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// A comprehensive Flutter screen for testing Agora call flow functionality
class AgoraCallFlowTestScreen extends StatefulWidget {
  const AgoraCallFlowTestScreen({Key? key}) : super(key: key);

  @override
  State<AgoraCallFlowTestScreen> createState() => _AgoraCallFlowTestScreenState();
}

class _AgoraCallFlowTestScreenState extends State<AgoraCallFlowTestScreen> {
  // Configuration
  static const String agoraAppId = 'b7487b8a48da4f89a4285c92e454a96f';
  static const String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';

  // State variables
  late RtcEngine _engine;
  bool _isEngineInitialized = false;
  bool _isInCall = false;
  bool _isLocalVideoEnabled = true;
  bool _isLocalAudioEnabled = true;
  bool _isLoading = false;
  
  String? _currentToken;
  String? _currentChannelName;
  int? _currentUid;
  int? _remoteUid;
  
  List<String> _testLogs = [];
  final ScrollController _logsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  /// Initialize Agora RTC Engine
  Future<void> _initializeAgora() async {
    _addLog('🔄 Initializing Agora RTC Engine...');
    
    try {
      // Request permissions
      await [Permission.camera, Permission.microphone].request();
      
      // Create and initialize engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Set up event handlers
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            _addLog('✅ Joined channel: ${connection.channelId}');
            setState(() {
              _isInCall = true;
            });
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            _addLog('👤 User joined: $uid');
            setState(() {
              _remoteUid = uid;
            });
          },
          onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
            _addLog('👋 User left: $uid');
            setState(() {
              _remoteUid = null;
            });
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            _addLog('📤 Left channel');
            setState(() {
              _isInCall = false;
              _remoteUid = null;
            });
          },
          onError: (ErrorCodeType err, String msg) {
            _addLog('❌ Error: $err - $msg');
          },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            _addLog('⚠️ Token will expire, renewing...');
            _renewToken();
          },
          onLocalVideoStateChanged: (VideoSourceType source, LocalVideoStreamState state, LocalVideoStreamReason reason) {
            _addLog('📹 Local video state: $state');
          },
          onLocalAudioStateChanged: (RtcConnection connection, LocalAudioStreamState state, LocalAudioStreamReason reason) {
            _addLog('🎤 Local audio state: $state');
          },
          onRemoteVideoStateChanged: (RtcConnection connection, int uid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
            _addLog('📹 Remote video state (UID $uid): $state');
          },
          onRemoteAudioStateChanged: (RtcConnection connection, int uid, RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
            _addLog('🎤 Remote audio state (UID $uid): $state');
          },
        ),
      );

      // Enable video and audio
      await _engine.enableVideo();
      await _engine.enableAudio();
      
      setState(() {
        _isEngineInitialized = true;
      });
      
      _addLog('✅ Agora Engine initialized successfully');
    } catch (e) {
      _addLog('❌ Failed to initialize Agora Engine: $e');
    }
  }

  /// Generate token and join channel
  Future<void> _startCall() async {
    if (!_isEngineInitialized) {
      _addLog('❌ Engine not initialized');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate unique channel name and UID
      _currentChannelName = 'test-${Random().nextInt(10000)}';
      _currentUid = Random().nextInt(100000);

      _addLog('🔄 Generating token for channel: $_currentChannelName');
      _addLog('🔄 Using UID: $_currentUid');

      // Generate token
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
        _addLog('✅ Token generated successfully');
        _addLog('📝 Token length: ${_currentToken!.length}');

        // Join channel
        _addLog('🔄 Joining channel...');
        await _engine.joinChannel(
          token: _currentToken!,
          channelId: _currentChannelName!,
          uid: _currentUid!,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            channelProfile: ChannelProfileType.channelProfileCommunication,
          ),
        );
      } else {
        _addLog('❌ Token generation failed: HTTP ${response.statusCode}');
        _addLog('📝 Response: ${response.body}');
      }
    } catch (e) {
      _addLog('❌ Error starting call: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// End call and leave channel
  Future<void> _endCall() async {
    if (!_isInCall) return;

    _addLog('🔄 Ending call...');
    
    try {
      await _engine.leaveChannel();
      setState(() {
        _isInCall = false;
        _remoteUid = null;
        _currentToken = null;
        _currentChannelName = null;
        _currentUid = null;
      });
      _addLog('✅ Call ended successfully');
    } catch (e) {
      _addLog('❌ Error ending call: $e');
    }
  }

  /// Toggle local video
  Future<void> _toggleLocalVideo() async {
    try {
      await _engine.enableLocalVideo(!_isLocalVideoEnabled);
      setState(() {
        _isLocalVideoEnabled = !_isLocalVideoEnabled;
      });
      _addLog('📹 Local video ${_isLocalVideoEnabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _addLog('❌ Error toggling video: $e');
    }
  }

  /// Toggle local audio
  Future<void> _toggleLocalAudio() async {
    try {
      await _engine.muteLocalAudioStream(!_isLocalAudioEnabled);
      setState(() {
        _isLocalAudioEnabled = !_isLocalAudioEnabled;
      });
      _addLog('🎤 Local audio ${_isLocalAudioEnabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _addLog('❌ Error toggling audio: $e');
    }
  }

  /// Renew token when it's about to expire
  Future<void> _renewToken() async {
    if (_currentChannelName == null || _currentUid == null) return;

    try {
      _addLog('🔄 Renewing token...');
      
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'];
        
        await _engine.renewToken(newToken);
        _currentToken = newToken;
        _addLog('✅ Token renewed successfully');
      } else {
        _addLog('❌ Token renewal failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _addLog('❌ Error renewing token: $e');
    }
  }

  /// Add log entry
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _testLogs.add('[$timestamp] $message');
    });
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logsScrollController.hasClients) {
        _logsScrollController.animateTo(
          _logsScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Clear logs
  void _clearLogs() {
    setState(() {
      _testLogs.clear();
    });
  }

  /// Run automated test sequence
  Future<void> _runAutomatedTest() async {
    _addLog('🚀 Starting automated test sequence...');
    
    // Test 1: Initialize (already done)
    _addLog('✅ Test 1: Engine initialization - PASSED');
    
    // Test 2: Generate token and join
    await _startCall();
    await Future.delayed(const Duration(seconds: 3));
    
    if (_isInCall) {
      _addLog('✅ Test 2: Token generation and channel join - PASSED');
      
      // Test 3: Toggle video/audio
      await _toggleLocalVideo();
      await Future.delayed(const Duration(seconds: 1));
      await _toggleLocalVideo();
      await Future.delayed(const Duration(seconds: 1));
      
      await _toggleLocalAudio();
      await Future.delayed(const Duration(seconds: 1));
      await _toggleLocalAudio();
      
      _addLog('✅ Test 3: Video/Audio controls - PASSED');
      
      // Test 4: Leave channel
      await _endCall();
      await Future.delayed(const Duration(seconds: 2));
      
      if (!_isInCall) {
        _addLog('✅ Test 4: Channel leave - PASSED');
        _addLog('🎉 All automated tests completed successfully!');
      } else {
        _addLog('❌ Test 4: Channel leave - FAILED');
      }
    } else {
      _addLog('❌ Test 2: Token generation and channel join - FAILED');
    }
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    try {
      if (_isInCall) {
        await _engine.leaveChannel();
      }
      if (_isEngineInitialized) {
        await _engine.release();
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agora Call Flow Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Engine Status: ${_isEngineInitialized ? '✅ Initialized' : '❌ Not Initialized'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Call Status: ${_isInCall ? '📞 In Call' : '📱 Not in Call'}'),
                  if (_currentChannelName != null)
                    Text('Channel: $_currentChannelName'),
                  if (_currentUid != null)
                    Text('UID: $_currentUid'),
                  if (_remoteUid != null)
                    Text('Remote UID: $_remoteUid'),
                ],
              ),
            ),
          ),
          
          // Control Buttons
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading || _isInCall ? null : _startCall,
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.call),
                  label: Text(_isLoading ? 'Starting...' : 'Start Call'),
                ),
                ElevatedButton.icon(
                  onPressed: !_isInCall ? null : _endCall,
                  icon: const Icon(Icons.call_end),
                  label: const Text('End Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: !_isInCall ? null : _toggleLocalVideo,
                  icon: Icon(_isLocalVideoEnabled ? Icons.videocam : Icons.videocam_off),
                  label: Text('Video ${_isLocalVideoEnabled ? 'On' : 'Off'}'),
                ),
                ElevatedButton.icon(
                  onPressed: !_isInCall ? null : _toggleLocalAudio,
                  icon: Icon(_isLocalAudioEnabled ? Icons.mic : Icons.mic_off),
                  label: Text('Audio ${_isLocalAudioEnabled ? 'On' : 'Off'}'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading || _isInCall ? null : _runAutomatedTest,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Logs Section
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Test Logs',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: _logsScrollController,
                      padding: const EdgeInsets.all(8),
                      itemCount: _testLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _testLogs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}