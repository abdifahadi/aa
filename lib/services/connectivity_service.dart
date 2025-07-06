import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();
  
  // Connectivity instance
  final Connectivity _connectivity = Connectivity();
  
  // Stream controller for connectivity status
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  
  // Stream getter
  Stream<bool> get connectionStream => _connectionStatusController.stream;
  
  // Current connection status
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  // Subscription to connectivity changes
  StreamSubscription? _connectivitySubscription;
  
  // Last connection check timestamp
  DateTime? _lastConnectionCheck;
  
  // Initialize the service
  void initialize() {
    _checkInitialConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  // Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      _lastConnectionCheck = DateTime.now();
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      _lastConnectionCheck = DateTime.now();
    }
  }
  
  // Update connection status based on connectivity result
  void _updateConnectionStatus(dynamic result) {
    bool previousStatus = _isConnected;
    
    if (result is ConnectivityResult) {
      _isConnected = (result != ConnectivityResult.none);
      _connectionStatusController.add(_isConnected);
      debugPrint('Connection status updated: $_isConnected (${result.name})');
    } else if (result is List<ConnectivityResult> && result.isNotEmpty) {
      final firstResult = result.first;
      _isConnected = (firstResult != ConnectivityResult.none);
      _connectionStatusController.add(_isConnected);
      debugPrint('Connection status updated from list: $_isConnected (${firstResult.name})');
    } else {
      _isConnected = false;
      _connectionStatusController.add(false);
      debugPrint('Connection status updated: no connectivity (unknown result type)');
    }
    
    _lastConnectionCheck = DateTime.now();
    
    // Log connectivity change
    if (previousStatus != _isConnected) {
      debugPrint('❗ Connectivity changed: ${previousStatus ? 'ONLINE → OFFLINE' : 'OFFLINE → ONLINE'}');
    }
  }
  
  // Check current connectivity and return result
  Future<bool> checkConnectivity() async {
    try {
      // If we checked connectivity recently, return cached result
      if (_lastConnectionCheck != null && 
          DateTime.now().difference(_lastConnectionCheck!).inSeconds < 5) {
        return _isConnected;
      }
      
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return _isConnected;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }
  
  // Force a connectivity check
  Future<bool> forceConnectivityCheck() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return _isConnected;
    } catch (e) {
      debugPrint('Error forcing connectivity check: $e');
      return false;
    }
  }
  
  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionStatusController.close();
  }
} 