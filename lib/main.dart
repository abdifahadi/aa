import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/chat_app.dart';
import 'screens/call_handler.dart' show CallHandler, navigatorKey;
import 'screens/developer_menu.dart';
import 'theme/theme_provider.dart';
import 'models/user_model.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/call_service.dart';
import 'services/local_database.dart';
import 'services/performance_service.dart';
import 'services/error_handler.dart';
import 'utils/constants.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/test/agora_call_verification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// Background message handler for Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize error handler first to catch all errors
  ErrorHandler().initialize();
  print("✅ Error handler initialized");

  // Initialize performance service for monitoring
  PerformanceService().initialize();
  print("✅ Performance service initialized");

  // Initialize local database first - this should work offline
  try {
    final localDb = LocalDatabase();
    await localDb.database; // This initializes the database
    print("✅ Local database initialized successfully");
  } catch (e) {
    ErrorHandler().handleDatabaseError(e, operation: 'database_initialization');
    print("❌ Error initializing local database: $e");
    // Continue anyway - the app should still work with reduced functionality
  }

  // Initialize connectivity service early
  try {
    final connectivityService = ConnectivityService();
    connectivityService.initialize();
    print("✅ Connectivity service initialized successfully");
  } catch (e) {
    ErrorHandler().handleNetworkError(e, operation: 'connectivity_initialization');
    print("❌ Error initializing connectivity service: $e");
    // Continue anyway
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print("✅ Firebase initialized successfully");
  } catch (e) {
    ErrorHandler().handleError(
      AppError(
        message: 'Failed to initialize Firebase: $e',
        code: 'FIREBASE_INIT_ERROR',
        severity: ErrorSeverity.high,
      ),
    );
    debugPrint('❌ Failed to initialize Firebase: $e');
    // Continue anyway
  }

  // Request camera and microphone permissions for Agora
  try {
    final permissions = await [Permission.camera, Permission.microphone].request();
    if (permissions[Permission.camera] != PermissionStatus.granted) {
      ErrorHandler().handlePermissionError('camera');
    }
    if (permissions[Permission.microphone] != PermissionStatus.granted) {
      ErrorHandler().handlePermissionError('microphone');
    }
    print("✅ Permissions requested");
  } catch (e) {
    ErrorHandler().handlePermissionError('camera_microphone');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Optimize system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Agora engine once at app startup
  try {
    final CallService callService = CallService();
    await callService.initializeAgoraEngine();
    print("✅ Agora engine initialized");
  } catch (e) {
    ErrorHandler().handleCallError(e);
    print("❌ Error initializing Agora: $e");
  }

  print('🚀 Starting app...');
  print('📱 App Name: ${AppConstants.appName}');
  print('🔢 Version: ${AppConstants.appVersion}');

  // Run the app with error boundary
  runApp(
    ErrorBoundary(
      child: ChangeNotifierProvider(
        create: (context) => ThemeProvider(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set the navigator key for the notification service
    _notificationService.setNavigatorKey(navigatorKey);
    debugPrint('🔑 Set navigator key in notification service');

    // Initialize notification service
    _notificationService.initialize();
    debugPrint('🔔 Initialized notification service in _MyAppState');

    // Enable wakelock for the app to keep processor running
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Disable wakelock
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Log app lifecycle state changes
    print("#### 📱 App lifecycle changed to: $state ####");

    if (state == AppLifecycleState.detached) {
      // App being terminated
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Abdi Wave Chat',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme,
            navigatorKey:
                navigatorKey, // Use the global navigator key from call_handler.dart
            darkTheme: ThemeData(
              primarySwatch: Colors.deepPurple,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              brightness: Brightness.dark,
                          colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            ),
            themeMode: themeProvider.themeMode,
            home: CallHandler(
                              child: AppLifecycleManager(
                    child: DeveloperMenuLauncher(child: const ChatApp())),
            ),
            routes: {
              '/agora_call_verification': (context) =>
                  const AgoraCallVerificationScreen(),
            },
          );
        },
      ),
    );
  }
}

// Widget to handle app lifecycle events for user status
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({Key? key, required this.child}) : super(key: key);

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;
  int _tapCount = 0;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConnectivity();
    _setUserOnline();

    // Subscribe to connectivity changes
    _connectivitySubscription =
        _connectivityService.connectionStream.listen((bool isConnected) {
      if (mounted) {
        setState(() {
          _isOnline = isConnected;
        });
        if (isConnected) {
          _setUserOnline();
        } else {
          _setUserOffline();
        }
      }
    });
  }

  void _handleTitleTap() {
    setState(() {
      _tapCount++;
    });

    // Reset tap count after 2 seconds
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      setState(() {
        _tapCount = 0;
      });
    });

    // Open developer menu after 5 taps
    if (_tapCount >= 5) {
      _tapCount = 0;
      _resetTimer?.cancel();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeveloperMenu()),
      );
    }
  }

  Future<void> _checkConnectivity() async {
    _isOnline = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      _checkConnectivity();
      _setUserOnline();
    } else if (state == AppLifecycleState.paused) {
      // App is in the background
      _setUserOffline();
    }
  }

  Future<void> _setUserOnline() async {
    if (_isOnline && _firebaseService.currentUser != null) {
      try {
        await _firebaseService.updateUserStatus(UserStatus.online);
      } catch (e) {
        print("Error setting user online: $e");
      }
    }
  }

  Future<void> _setUserOffline() async {
    if (_firebaseService.currentUser != null) {
      try {
        await _firebaseService.updateUserStatus(UserStatus.offline);
      } catch (e) {
        print("Error setting user offline: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Developer menu access button (hidden in top-right corner)
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: 30,
            height: 30,
            child: GestureDetector(
              onTap: _handleTitleTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Widget to handle developer menu access with multiple taps on app title
class DeveloperMenuLauncher extends StatefulWidget {
  final Widget child;

  const DeveloperMenuLauncher({Key? key, required this.child})
      : super(key: key);

  @override
  State<DeveloperMenuLauncher> createState() => _DeveloperMenuLauncherState();
}

class _DeveloperMenuLauncherState extends State<DeveloperMenuLauncher> {
  int _tapCount = 0;
  Timer? _resetTimer;

  void _handleTitleTap() {
    setState(() {
      _tapCount++;
    });

    // Reset tap count after 2 seconds
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      setState(() {
        _tapCount = 0;
      });
    });

    // Open developer menu after 5 taps
    if (_tapCount >= 5) {
      _tapCount = 0;
      _resetTimer?.cancel();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeveloperMenu()),
      );
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleTitleTap,
          child: const Text('Abdi Wave Chat'),
        ),
      ),
    );
  }
}

// Error boundary widget to catch and handle widget errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({Key? key, required this.child}) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool hasError = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Listen to error stream
    ErrorHandler().errorStream.listen((error) {
      if (error.severity == ErrorSeverity.critical && mounted) {
        setState(() {
          hasError = true;
          errorMessage = error.message;
        });
      }
    });
  }

  void _retry() {
    setState(() {
      hasError = false;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? 'An unexpected error occurred',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
