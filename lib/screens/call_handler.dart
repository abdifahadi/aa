import 'package:flutter/material.dart';
import 'dart:async';
import '../services/call_service.dart';
import '../services/notification_service.dart';
import '../models/call_model.dart';
import 'incoming_call_screen.dart';
import 'call_screen.dart';

// Global navigator key for navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Call State enum definition
enum CallState {
  idle,
  ringing,
  connecting,
  connected,
  ended,
  declined,
  failed,
  missed
}

class CallHandler extends StatefulWidget {
  final Widget child;

  const CallHandler({Key? key, required this.child}) : super(key: key);

  @override
  State<CallHandler> createState() => _CallHandlerState();
}

class _CallHandlerState extends State<CallHandler> with WidgetsBindingObserver {
  final CallService _callService = CallService();
  final NotificationService _notificationService = NotificationService();
  
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription? _callStateSubscription;
  
  CallModel? _currentIncomingCall;
  bool _isInCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCallHandling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingCallSubscription?.cancel();
    _callStateSubscription?.cancel();
    super.dispose();
  }

  void _setupCallHandling() {
    // Set the navigator key for notifications
    _notificationService.setNavigatorKey(navigatorKey);
    
    // Listen for incoming calls from call service
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    // This would typically listen to a stream from CallService
    // For now, we'll implement a basic listener structure
    debugPrint('Setting up incoming call listeners');
  }

  void _handleIncomingCall(CallModel call) {
    print('📞 CallHandler: Handling incoming call from ${call.callerName}');
    
    setState(() {
      _currentIncomingCall = call;
    });

    // Show incoming call screen
    if (navigatorKey.currentState != null && !_isInCall) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            call: call,
            onAccept: () => _acceptCall(call),
            onDecline: () => _declineCall(call),
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  void _handleCallStateChange(CallState state) {
    print('📞 CallHandler: Call state changed to $state');
    
    switch (state) {
      case CallState.connected:
        setState(() {
          _isInCall = true;
        });
        break;
      case CallState.ended:
      case CallState.declined:
      case CallState.failed:
      case CallState.missed:
        setState(() {
          _isInCall = false;
          _currentIncomingCall = null;
        });
        
        // Pop any call-related screens
        if (navigatorKey.currentState != null) {
          // Remove all call screens from stack
          navigatorKey.currentState!.popUntil((route) {
            return route.settings.name != '/incoming_call' && 
                   route.settings.name != '/call_screen';
          });
        }
        break;
      default:
        break;
    }
  }

  Future<void> _acceptCall(CallModel call) async {
    print('📞 CallHandler: Accepting call from ${call.callerName}');
    
    try {
      final success = await _callService.acceptCall(call);
      
      if (success) {
        setState(() {
          _isInCall = true;
          _currentIncomingCall = null;
        });

        // Navigate to call screen
        if (navigatorKey.currentState != null) {
          // Pop incoming call screen first
          navigatorKey.currentState!.pop();
          
          // Navigate to call screen
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => CallScreen(
                call: call,
                isIncoming: true,
              ),
              settings: const RouteSettings(name: '/call_screen'),
            ),
          );
        }
      } else {
        _showErrorSnackBar('Failed to accept call');
      }
    } catch (e) {
      print('❌ CallHandler: Error accepting call: $e');
      _showErrorSnackBar('Failed to accept call');
    }
  }

  Future<void> _declineCall(CallModel call) async {
    print('📞 CallHandler: Declining call from ${call.callerName}');
    
    try {
      await _callService.rejectCall(call.id);
      
      setState(() {
        _currentIncomingCall = null;
      });

      // Pop incoming call screen
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pop();
      }
    } catch (e) {
      print('❌ CallHandler: Error declining call: $e');
      _showErrorSnackBar('Failed to decline call');
    }
  }

  void _showErrorSnackBar(String message) {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('📞 CallHandler: App lifecycle state changed to $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground
        debugPrint('App resumed - refreshing call state');
        break;
      case AppLifecycleState.paused:
        // App is in background
        debugPrint('App paused - maintaining call state');
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        debugPrint('App detached - cleaning up call resources');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => widget.child,
          settings: settings,
        );
      },
    );
  }
}

// Extension to easily access call handler from anywhere
extension CallHandlerExtension on BuildContext {
  CallService get callService => CallService();
  
  Future<void> initiateCall(String targetUserId, String targetUserName, String targetUserPhotoUrl, CallType callType) async {
    try {
      final call = await callService.startCall(
        receiverId: targetUserId,
        receiverName: targetUserName,
        receiverPhotoUrl: targetUserPhotoUrl,
        callType: callType,
      );
      
      if (call != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              call: call,
              isIncoming: false,
            ),
            settings: const RouteSettings(name: '/call_screen'),
          ),
        );
      } else {
        ScaffoldMessenger.of(this).showSnackBar(
          const SnackBar(
            content: Text('Failed to start call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error initiating call: $e');
      ScaffoldMessenger.of(this).showSnackBar(
        const SnackBar(
          content: Text('Failed to initiate call'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}