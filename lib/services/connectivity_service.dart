import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/constants.dart';

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();
  
  // Connectivity instance
  final Connectivity _connectivity = Connectivity();
  
  // Stream controller for connectivity status
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  // Stream getter
  Stream<bool> get connectionStream => _connectionController.stream;
  
  // Current connection status
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // Subscription to connectivity changes
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Last connection check timestamp
  DateTime? _lastConnectionCheck;
  
  // Initialize the service
  Future<void> initialize() async {
    if (_lastConnectionCheck != null) return;

    try {
      // Check initial connectivity
      await checkConnectivity();

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          debugPrint('❌ Connectivity stream error: $error');
        },
      );

      _lastConnectionCheck = DateTime.now();
      debugPrint('✅ ConnectivityService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing ConnectivityService: $e');
    }
  }
  
  // Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) async {
    debugPrint('📶 Connectivity changed: $result');
    
    bool wasConnected = _isConnected;
    await _updateConnectionStatus(result);
    
    // Only emit if status actually changed
    if (wasConnected != _isConnected) {
      _connectionController.add(_isConnected);
      
      if (_isConnected) {
        debugPrint('✅ Connection restored');
      } else {
        debugPrint('❌ Connection lost');
      }
    }
  }
  
  // Update connection status based on connectivity result
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    switch (result) {
      case ConnectivityResult.none:
        _isConnected = false;
        break;
      case ConnectivityResult.mobile:
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.vpn:
        // Additional check to ensure we can actually reach the internet
        _isConnected = await _hasInternetConnection();
        break;
      default:
        _isConnected = false;
    }
  }
  
  // Check current connectivity and return result
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(result);
      debugPrint('📶 Connectivity check: $result (connected: $_isConnected)');
      return _isConnected;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      _isConnected = false;
      return false;
    }
  }
  
  // Force a connectivity check
  Future<bool> forceConnectivityCheck() async {
    try {
      // First check basic connectivity
      final result = await _connectivity.checkConnectivity();
      
      if (result == ConnectivityResult.none) {
        _isConnected = false;
        return false;
      }

      // Then check actual internet connection
      _isConnected = await _hasInternetConnection();
      debugPrint('🔄 Forced connectivity check: $_isConnected');
      
      // Emit the result
      _connectionController.add(_isConnected);
      
      return _isConnected;
    } catch (e) {
      debugPrint('❌ Error in forced connectivity check: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }
  
  // Test actual internet connection by pinging a reliable server
  Future<bool> _hasInternetConnection() async {
    try {
      // Try to connect to Google's DNS
      final result = await InternetAddress.lookup('google.com')
          .timeout(AppConstants.networkTimeout);
      
      final hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (!hasConnection) {
        // Fallback to another reliable service
        try {
          final fallbackResult = await InternetAddress.lookup('cloudflare.com')
              .timeout(const Duration(seconds: 5));
          return fallbackResult.isNotEmpty && fallbackResult[0].rawAddress.isNotEmpty;
        } catch (e) {
          debugPrint('❌ Fallback connectivity test failed: $e');
          return false;
        }
      }
      
      return hasConnection;
    } catch (e) {
      debugPrint('❌ Internet connection test failed: $e');
      return false;
    }
  }
  
  // Get detailed connectivity information
  Future<Map<String, dynamic>> getConnectivityInfo() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final hasInternet = await _hasInternetConnection();
      
      return {
        'type': result.toString().split('.').last,
        'hasInternet': hasInternet,
        'isConnected': _isConnected,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting connectivity info: $e');
      return {
        'type': 'unknown',
        'hasInternet': false,
        'isConnected': false,
        'timestamp': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }
  
  // Wait for connection to be available
  Future<bool> waitForConnection({Duration? timeout}) async {
    final timeoutDuration = timeout ?? const Duration(seconds: 30);
    
    if (_isConnected) {
      return true;
    }

    try {
      final completer = Completer<bool>();
      late StreamSubscription subscription;
      
      subscription = connectionStream.listen((isConnected) {
        if (isConnected && !completer.isCompleted) {
          subscription.cancel();
          completer.complete(true);
        }
      });

      // Set up timeout
      Timer(timeoutDuration, () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('❌ Error waiting for connection: $e');
      return false;
    }
  }
  
  // Get connection type string
  String getConnectionTypeString() {
    if (!_isConnected) return 'No Connection';
    
    // This would require additional platform-specific implementation
    // For now, return a generic connected status
    return 'Connected';
  }
  
  // Check if on WiFi
  Future<bool> isOnWiFi() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.wifi;
    } catch (e) {
      debugPrint('❌ Error checking WiFi status: $e');
      return false;
    }
  }
  
  // Check if on mobile data
  Future<bool> isOnMobileData() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.mobile;
    } catch (e) {
      debugPrint('❌ Error checking mobile data status: $e');
      return false;
    }
  }
  
  // Start periodic connectivity monitoring
  void startPeriodicCheck() {
    Timer.periodic(AppConstants.connectivityCheckInterval, (timer) async {
      if (_lastConnectionCheck == null) {
        timer.cancel();
        return;
      }
      
      await checkConnectivity();
    });
  }
  
  // Get network quality indicator (simple implementation)
  Future<String> getNetworkQuality() async {
    if (!_isConnected) return 'No Connection';
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Simple ping test
      await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      
      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds;
      
      if (responseTime < 100) {
        return 'Excellent';
      } else if (responseTime < 300) {
        return 'Good';
      } else if (responseTime < 600) {
        return 'Fair';
      } else {
        return 'Poor';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
  
  // Test connection to specific host
  Future<bool> testConnection(String host, {Duration? timeout}) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(timeout ?? const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Connection test to $host failed: $e');
      return false;
    }
  }
  
  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
    _lastConnectionCheck = null;
  }
} 