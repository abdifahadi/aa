import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../services/notification_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;

  const IncomingCallScreen({Key? key, required this.call}) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  final NotificationService _notificationService = NotificationService();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Timer _callTimeoutTimer;
  final bool _isCallAnswered = false;
  bool _isCallRejected = false;

  @override
  void initState() {
    super.initState();

    // Enable wakelock to keep screen on during incoming call
    WakelockPlus.enable();

    // Play ringtone
    _notificationService.playRingtone();

    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Set up call timeout (30 seconds)
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isCallAnswered && !_isCallRejected) {
        _handleMissedCall();
      }
    });

    // Listen for call status changes
    _listenToCallChanges();
  }

  void _listenToCallChanges() {
    _callService.getCallById(widget.call.id).listen((call) {
      // If call was canceled by the caller
      if (call != null && call.status == CallStatus.ended) {
        if (mounted && !_isCallAnswered && !_isCallRejected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call ended by caller'),
              duration: Duration(seconds: 2),
            ),
          );
          _notificationService.stopRingtone();
          Navigator.pop(context);
        }
      }
    }, onError: (error) {
      debugPrint('Error listening to call status: $error');
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _callTimeoutTimer.cancel();
    _notificationService.stopRingtone();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _answerCall() async {
    try {
      // Stop the ringtone
      _notificationService.stopRingtone();

      // Update call status to accepted
      await _callService.answerCall(widget.call.id);

      // Navigate to call screen with the call model
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              call: widget.call,
              isIncoming: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error answering call: $e');
    }
  }

  void _handleRejectCall() async {
    setState(() {
      _isCallRejected = true;
    });

    _notificationService.stopRingtone();

    // Update call status in Firestore
    await _callService.updateCallStatus(
      widget.call.id,
      CallStatus.rejected,
    );

    // Close the screen
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _handleMissedCall() async {
    _notificationService.stopRingtone();

    // Update call status in Firestore
    await _callService.updateCallStatus(
      widget.call.id,
      CallStatus.missed,
    );

    // Close the screen
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isVideoCall = widget.call.type == CallType.video;
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Call type indicator
              Text(
                isVideoCall ? 'Video Call' : 'Voice Call',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 20),

              // Caller name
              Text(
                widget.call.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // Incoming call text
              const Text(
                'Incoming call...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const Spacer(flex: 1),

              // Animated caller avatar
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: screenSize.width * 0.4,
                      height: screenSize.width * 0.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 3,
                        ),
                        image: widget.call.callerPhotoUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(widget.call.callerPhotoUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: widget.call.callerPhotoUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              // Call actions
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Decline button
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _handleRejectCall,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Decline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    // Accept button
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _answerCall,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isVideoCall ? Icons.videocam : Icons.call,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Accept',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
