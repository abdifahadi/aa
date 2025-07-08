import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CallScreen extends StatefulWidget {
  final CallModel call;
  final bool isIncoming;

  const CallScreen({
    Key? key,
    required this.call,
    required this.isIncoming,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  final CallService _callService = CallService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Call state
  bool _isCallConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallEnded = false;
  bool _isVideoEnabled = false;
  bool _isVideoMuted = false;
  int _callDuration = 0;
  Timer? _callDurationTimer;
  StreamSubscription? _callStatusSubscription;

  // Video widgets
  Widget? _remoteVideo;
  Widget? _localVideo;
  int _remoteUid = 0;

  // Connection quality
  int _localQuality = 0;
  int _remoteQuality = 0;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Keep screen on during call
    WakelockPlus.enable();

    _initialize();
  }

  @override
  void dispose() {
    // Clean up resources
    _callDurationTimer?.cancel();
    _callStatusSubscription?.cancel();
    _statsTimer?.cancel();

    // Allow screen to turn off after call
    WakelockPlus.disable();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, re-enable video if needed
      if (_isVideoEnabled && !_isVideoMuted && _isCallConnected) {
        _callService.engine?.enableLocalVideo(true);
      }
    } else if (state == AppLifecycleState.paused) {
      // App went to background, disable video to save resources
      if (_isVideoEnabled && _isCallConnected) {
        _callService.engine?.enableLocalVideo(false);
      }
    }
  }

  Future<void> _initialize() async {
    // Set video status based on call type
    _isVideoEnabled = widget.call.type == CallType.video;

    // Monitor call status
    _monitorCallStatus();

    // If outgoing call, join immediately
    if (!widget.isIncoming) {
      _joinCall();
    }

    // Set speaker mode based on call type
    _isSpeakerOn = widget.call.type == CallType.video;
    _callService.enableSpeakerphone(_isSpeakerOn);

    // Register event handlers for video and audio
    _setupEventHandlers();

    // Start network quality monitoring
    _startNetworkQualityMonitoring();
  }

  void _setupEventHandlers() {
    if (_callService.engine == null) {
      debugPrint(
          '❌ Error: Agora engine is null when setting up event handlers');
      return;
    }

    _callService.registerEventHandler(
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('Remote user joined: $remoteUid');
        setState(() {
          _remoteUid = remoteUid;

          // Only set up remote video view for video calls
          if (widget.call.type == CallType.video) {
            _setupRemoteVideo(connection, remoteUid);
          }
        });
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint('Remote user left: $remoteUid, reason: $reason');
        setState(() {
          _remoteVideo = null;
        });

        // If remote user left due to dropped connection, show message
        if (reason == UserOfflineReasonType.userOfflineDropped) {
          _showError('Remote user lost connection');
        }
      },
      onLocalVideoStateChanged:
          (VideoSourceType source, LocalVideoStreamState state, dynamic error) {
        debugPrint('Local video state changed: $state, error: $error');
        if (state == LocalVideoStreamState.localVideoStreamStateCapturing) {
          _setupLocalVideo();
        } else if (error != 0) {
          // 0 is usually OK in most error enums
          debugPrint('❌ Local video error: $error');
          _showError('Camera error: $error');
        }
      },
      onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid,
          RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
        debugPrint(
            'Remote video state changed: uid=$remoteUid, state=$state, reason=$reason');

        if (state == RemoteVideoState.remoteVideoStateStarting) {
          debugPrint('Remote video is starting');
        } else if (state == RemoteVideoState.remoteVideoStateDecoding) {
          debugPrint('✅ Remote video is decoding - stream should be visible');
          // Ensure remote video view is set up when video starts decoding
          if (_remoteVideo == null && widget.call.type == CallType.video) {
            _setupRemoteVideo(connection, remoteUid);
          }
        } else if (state == RemoteVideoState.remoteVideoStateStopped) {
          debugPrint('❌ Remote video stopped: reason=$reason');
        } else if (state == RemoteVideoState.remoteVideoStateFailed) {
          debugPrint('❌ Remote video failed: reason=$reason');
          _showError('Remote video failed: $reason');
        }
      },
      onRemoteAudioStateChanged: (RtcConnection connection, int remoteUid,
          RemoteAudioState state, RemoteAudioStateReason reason, int elapsed) {
        debugPrint(
            'Remote audio state changed: uid=$remoteUid, state=$state, reason=$reason');

        if (state == RemoteAudioState.remoteAudioStateDecoding) {
          debugPrint('✅ Remote audio is working');
        } else if (state == RemoteAudioState.remoteAudioStateStopped) {
          debugPrint('❌ Remote audio stopped: reason=$reason');
        } else if (state == RemoteAudioState.remoteAudioStateFailed) {
          debugPrint('❌ Remote audio failed: reason=$reason');
          _showError('Remote audio failed: $reason');
        }
      },
      onAudioVolumeIndication: (RtcConnection connection,
          List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
        // Check if remote user is speaking
        for (var speaker in speakers) {
          if (speaker.uid == _remoteUid && speaker.volume! > 5) {
            debugPrint('Remote user is speaking: volume=${speaker.volume}');
          }
        }
      },
      onConnectionStateChanged: (RtcConnection connection,
          ConnectionStateType state, ConnectionChangedReasonType reason) {
        debugPrint('Connection state changed: state=$state, reason=$reason');

        if (state == ConnectionStateType.connectionStateConnected) {
          debugPrint('✅ Connected to Agora channel');
        } else if (state == ConnectionStateType.connectionStateDisconnected ||
            state == ConnectionStateType.connectionStateFailed) {
          debugPrint('❌ Disconnected from Agora channel: reason=$reason');
          _showError('Connection lost: $reason');

          // Show a more user-friendly error message for token issues
          if (reason ==
              ConnectionChangedReasonType.connectionChangedInvalidToken) {
            _showError('Connection error: Invalid token');
          } else if (reason ==
              ConnectionChangedReasonType.connectionChangedTokenExpired) {
            _showError('Connection error: Token expired');
          }
        }
      },
    );
  }

  // Separate method to set up remote video for better organization
  void _setupRemoteVideo(RtcConnection connection, int remoteUid) {
    if (!mounted || _callService.engine == null) return;

    try {
      debugPrint('Setting up remote video view for UID: $remoteUid');

      // Create the remote video view
      final remoteVideoView = AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _callService.engine!,
          canvas: VideoCanvas(uid: remoteUid),
          connection: connection,
        ),
      );

      // Update the UI
      setState(() {
        _remoteVideo = remoteVideoView;
      });

      debugPrint('✅ Remote video view set up successfully');

      // Ensure video is rendering properly
      _callService.engine!.setRemoteVideoStreamType(
        uid: remoteUid,
        streamType: VideoStreamType.videoStreamHigh,
      );
    } catch (e) {
      debugPrint('❌ Error setting up remote video: $e');
    }
  }

  void _setupLocalVideo() {
    if (!mounted || !_isVideoEnabled || _callService.engine == null) {
      debugPrint(
          'Cannot set up local video: mounted=$mounted, videoEnabled=$_isVideoEnabled, engine=${_callService.engine != null}');
      return;
    }

    debugPrint('Setting up local video view');

    try {
      // Ensure video is enabled in the engine
      _callService.engine!.enableVideo().then((_) {
        debugPrint('✅ Video enabled in engine');

        // Ensure camera is turned on
        _callService.engine!.enableLocalVideo(true);

        setState(() {
          _localVideo = AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _callService.engine!,
              canvas: const VideoCanvas(uid: 0), // Local video uses uid 0
            ),
          );
          debugPrint('✅ Local video view set up');
        });
      }).catchError((error) {
        debugPrint('❌ Error enabling video: $error');
      });
    } catch (e) {
      debugPrint('❌ Error in _setupLocalVideo: $e');
    }
  }

  void _startNetworkQualityMonitoring() {
    // Monitor network quality every 2 seconds
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_callService.engine != null && _isCallConnected) {
        // Use a safer approach to monitor network quality
        // The enableLastmileTest method is not available in the current version
        // We'll rely on connection state changes from the event handlers instead
      }
    });
  }

  void _monitorCallStatus() {
    _callStatusSubscription = _firestore
        .collection('calls')
        .doc(widget.call.id)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        _endCall();
        return;
      }

      final callData = snapshot.data() as Map<String, dynamic>;
      final status = callData['status'] as String? ?? '';

      if (status == 'ended' || status == 'rejected' || status == 'missed') {
        _endCall();
      } else if (status == 'accepted' && !_isCallConnected) {
        // Call was accepted, ensure audio is enabled
        _callService.enableAudio();

        // Start call timer if not already started
        if (_callDurationTimer == null) {
          _startCallTimer();
        }

        // Update UI
        setState(() {
          _isCallConnected = true;
        });
      }
    });
  }

  Future<void> _joinCall() async {
    try {
      final success = await _callService.joinCall(widget.call);

      if (success) {
        // Start call timer
        _startCallTimer();

        // Update UI
        setState(() {
          _isCallConnected = true;
        });

        // Update call status if this is an incoming call
        if (widget.isIncoming) {
          await _callService.answerCall(widget.call.id);
        }

        // Setup video if this is a video call
        if (_isVideoEnabled) {
          _setupLocalVideo();
        }
      } else {
        _showError('Failed to join call');
      }
    } catch (e) {
      _showError('Error joining call: $e');
    }
  }

  void _startCallTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _endCall() async {
    if (_isCallEnded) return;

    setState(() {
      _isCallEnded = true;
    });

    _callDurationTimer?.cancel();
    _statsTimer?.cancel();

    try {
      await _callService.endCall(widget.call.id);
      await _callService.leaveChannel();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _callService.muteLocalAudio(_isMuted);
  }

  void _onToggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _callService.enableSpeakerphone(_isSpeakerOn);
  }

  void _onToggleVideo() {
    if (!_isVideoEnabled) return; // Only for video calls

    setState(() {
      _isVideoMuted = !_isVideoMuted;
    });

    if (_callService.engine != null) {
      _callService.engine!.enableLocalVideo(!_isVideoMuted);
    }
  }

  void _onSwitchCamera() {
    if (!_isVideoEnabled) return; // Only for video calls

    if (_callService.engine != null) {
      _callService.engine!.switchCamera();
    }
  }

  void _onAcceptCall() {
    _joinCall();
  }

  void _onRejectCall() async {
    try {
      await _callService.rejectCall(widget.call.id);
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String remoteUserName = _auth.currentUser?.uid == widget.call.callerId
        ? widget.call.receiverName
        : widget.call.callerName;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade900,
                    Colors.black,
                  ],
                ),
              ),
            ),

            // Video views for video calls
            if (_isVideoEnabled) ...[
              // Remote video (full screen)
              if (_remoteVideo != null && _isCallConnected)
                Positioned.fill(child: _remoteVideo!),

              // Local video (picture-in-picture)
              if (_localVideo != null && !_isVideoMuted)
                Positioned(
                  right: 20,
                  top: 60,
                  width: 120,
                  height: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _localVideo!,
                  ),
                ),
            ],

            // Call content
            SafeArea(
              child: Column(
                children: [
                  // Status bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isCallConnected ? Icons.phone_in_talk : Icons.phone,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCallConnected
                              ? 'Connected - ${_formatDuration(_callDuration)}'
                              : widget.isIncoming
                                  ? 'Incoming Call'
                                  : 'Calling...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Network quality indicator
                  if (_isCallConnected)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _remoteQuality <= 2
                                ? Icons.signal_cellular_alt
                                : _remoteQuality <= 4
                                    ? Icons.signal_cellular_alt_2_bar
                                    : Icons.signal_cellular_alt_1_bar,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _remoteQuality <= 2
                                ? 'Good'
                                : _remoteQuality <= 4
                                    ? 'Fair'
                                    : 'Poor',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // User info (only show if video is not connected)
                  if (!_isVideoEnabled ||
                      _remoteVideo == null ||
                      !_isCallConnected)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage:
                                widget.call.callerPhotoUrl.isNotEmpty
                                    ? NetworkImage(
                                        _auth.currentUser?.uid ==
                                                widget.call.callerId
                                            ? widget.call.receiverPhotoUrl
                                            : widget.call.callerPhotoUrl,
                                      )
                                    : null,
                            child: widget.call.callerPhotoUrl.isEmpty
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            remoteUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isCallConnected
                                ? _isMuted
                                    ? 'Muted'
                                    : 'On Call'
                                : widget.isIncoming
                                    ? 'Incoming Call'
                                    : 'Calling...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Call controls
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: widget.isIncoming && !_isCallConnected
                        ? _buildIncomingCallControls()
                        : _buildOngoingCallControls(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCallButton(
          icon: Icons.call_end,
          color: Colors.red,
          onPressed: _onRejectCall,
          label: 'Decline',
        ),
        _buildCallButton(
          icon: Icons.call,
          color: Colors.green,
          onPressed: _onAcceptCall,
          label: 'Accept',
        ),
      ],
    );
  }

  Widget _buildOngoingCallControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCallButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              color: _isMuted ? Colors.red : Colors.white,
              onPressed: _onToggleMute,
              label: _isMuted ? 'Unmute' : 'Mute',
            ),
            _buildCallButton(
              icon: Icons.call_end,
              color: Colors.red,
              onPressed: _endCall,
              label: 'End',
              large: true,
            ),
            _buildCallButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              color: _isSpeakerOn ? Colors.blue : Colors.white,
              onPressed: _onToggleSpeaker,
              label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
            ),
          ],
        ),

        // Additional video controls
        if (_isVideoEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                  color: _isVideoMuted ? Colors.red : Colors.white,
                  onPressed: _onToggleVideo,
                  label: _isVideoMuted ? 'Show Video' : 'Hide Video',
                ),
                _buildCallButton(
                  icon: Icons.flip_camera_ios,
                  color: Colors.white,
                  onPressed: _onSwitchCamera,
                  label: 'Flip',
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    bool large = false,
  }) {
    return Column(
      children: [
        Container(
          width: large ? 70 : 60,
          height: large ? 70 : 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color == Colors.white ? Colors.grey.shade800 : color,
          ),
          child: IconButton(
            icon: Icon(icon),
            color: Colors.white,
            iconSize: large ? 30 : 24,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
