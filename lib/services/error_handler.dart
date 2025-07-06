import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

class AppError {
  final String message;
  final String? code;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final String? stackTrace;
  final Map<String, dynamic>? context;

  AppError({
    required this.message,
    this.code,
    this.severity = ErrorSeverity.medium,
    DateTime? timestamp,
    this.stackTrace,
    this.context,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'code': code,
      'severity': severity.toString(),
      'timestamp': timestamp.toIso8601String(),
      'stackTrace': stackTrace,
      'context': context,
    };
  }
}

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final List<AppError> _errorHistory = [];
  final StreamController<AppError> _errorStream = StreamController<AppError>.broadcast();
  
  // Error callbacks
  final List<Function(AppError)> _errorCallbacks = [];
  
  // Error rate limiting
  final Map<String, DateTime> _lastErrorTimes = {};
  final Map<String, int> _errorCounts = {};
  
  static const int maxErrorHistorySize = 100;
  static const Duration rateLimitDuration = Duration(seconds: 10);
  static const int maxSameErrorCount = 5;

  Stream<AppError> get errorStream => _errorStream.stream;

  void initialize() {
    // Set up global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      final error = AppError(
        message: details.exception.toString(),
        severity: ErrorSeverity.high,
        stackTrace: details.stack.toString(),
        context: {
          'library': details.library,
          'context': details.context?.toString(),
        },
      );
      handleError(error, showToUser: false);
    };

    // Handle platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      final appError = AppError(
        message: error.toString(),
        severity: ErrorSeverity.critical,
        stackTrace: stack.toString(),
      );
      handleError(appError, showToUser: false);
      return true;
    };
  }

  void dispose() {
    _errorStream.close();
  }

  // Main error handling method
  void handleError(
    AppError error, {
    bool showToUser = true,
    bool logError = true,
    bool reportToCrashlytics = true,
  }) {
    // Rate limiting to prevent spam
    if (_shouldRateLimit(error)) {
      return;
    }

    // Add to error history
    _addToHistory(error);

    // Log the error
    if (logError) {
      _logError(error);
    }

    // Report to crashlytics (if enabled)
    if (reportToCrashlytics && AppConstants.enableCrashlytics) {
      _reportToCrashlytics(error);
    }

    // Show to user if needed
    if (showToUser) {
      _showErrorToUser(error);
    }

    // Notify callbacks
    for (final callback in _errorCallbacks) {
      try {
        callback(error);
      } catch (e) {
        developer.log('Error in error callback: $e', name: AppConstants.debugTag);
      }
    }

    // Emit to stream
    _errorStream.add(error);
  }

  // Convenience methods for different error types
  void handleNetworkError(dynamic error, {String? operation}) {
    final appError = AppError(
      message: 'Network error: ${error.toString()}',
      code: 'NETWORK_ERROR',
      severity: ErrorSeverity.medium,
      context: {'operation': operation},
    );
    handleError(appError);
  }

  void handleAuthError(dynamic error) {
    final appError = AppError(
      message: 'Authentication error: ${error.toString()}',
      code: 'AUTH_ERROR',
      severity: ErrorSeverity.high,
      context: {'type': 'authentication'},
    );
    handleError(appError);
  }

  void handleDatabaseError(dynamic error, {String? operation}) {
    final appError = AppError(
      message: 'Database error: ${error.toString()}',
      code: 'DATABASE_ERROR',
      severity: ErrorSeverity.high,
      context: {'operation': operation},
    );
    handleError(appError);
  }

  void handleMediaError(dynamic error, {String? mediaType, String? operation}) {
    final appError = AppError(
      message: 'Media error: ${error.toString()}',
      code: 'MEDIA_ERROR',
      severity: ErrorSeverity.medium,
      context: {
        'mediaType': mediaType,
        'operation': operation,
      },
    );
    handleError(appError);
  }

  void handleCallError(dynamic error, {String? callId}) {
    final appError = AppError(
      message: 'Call error: ${error.toString()}',
      code: 'CALL_ERROR',
      severity: ErrorSeverity.high,
      context: {'callId': callId},
    );
    handleError(appError);
  }

  void handlePermissionError(String permission) {
    final appError = AppError(
      message: 'Permission denied: $permission',
      code: 'PERMISSION_ERROR',
      severity: ErrorSeverity.medium,
      context: {'permission': permission},
    );
    handleError(appError);
  }

  // Rate limiting logic
  bool _shouldRateLimit(AppError error) {
    final errorKey = '${error.code ?? 'unknown'}_${error.message}';
    final now = DateTime.now();
    
    // Check if we've seen this error recently
    if (_lastErrorTimes.containsKey(errorKey)) {
      final lastTime = _lastErrorTimes[errorKey]!;
      final timeDiff = now.difference(lastTime);
      
      if (timeDiff < rateLimitDuration) {
        _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
        
        // If we've seen this error too many times, rate limit it
        if (_errorCounts[errorKey]! > maxSameErrorCount) {
          return true;
        }
      } else {
        // Reset count after rate limit duration
        _errorCounts[errorKey] = 1;
      }
    } else {
      _errorCounts[errorKey] = 1;
    }
    
    _lastErrorTimes[errorKey] = now;
    return false;
  }

  void _addToHistory(AppError error) {
    _errorHistory.add(error);
    
    // Keep history size manageable
    if (_errorHistory.length > maxErrorHistorySize) {
      _errorHistory.removeAt(0);
    }
  }

  void _logError(AppError error) {
    final logLevel = _getLogLevel(error.severity);
    final message = '[${error.severity.toString().toUpperCase()}] '
        '${error.code != null ? '[${error.code}] ' : ''}'
        '${error.message}';
    
    if (AppConstants.enableLogging) {
      developer.log(
        message,
        name: AppConstants.debugTag,
        level: logLevel,
        error: error.message,
        stackTrace: error.stackTrace != null ? StackTrace.fromString(error.stackTrace!) : null,
      );
    }
  }

  int _getLogLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return 500; // INFO
      case ErrorSeverity.medium:
        return 900; // WARNING
      case ErrorSeverity.high:
        return 1000; // SEVERE
      case ErrorSeverity.critical:
        return 1200; // SHOUT
    }
  }

  void _reportToCrashlytics(AppError error) {
    // Here you would integrate with Firebase Crashlytics or another crash reporting service
    // Example:
    // FirebaseCrashlytics.instance.recordError(
    //   error.message,
    //   error.stackTrace != null ? StackTrace.fromString(error.stackTrace!) : null,
    //   fatal: error.severity == ErrorSeverity.critical,
    //   information: error.context,
    // );
  }

  void _showErrorToUser(AppError error) {
    final userMessage = _getUserFriendlyMessage(error);
    
    // Show error to user based on severity
    switch (error.severity) {
      case ErrorSeverity.low:
        // Don't show low severity errors to users
        break;
      case ErrorSeverity.medium:
        _showSnackBar(userMessage, isError: true);
        break;
      case ErrorSeverity.high:
      case ErrorSeverity.critical:
        _showErrorDialog(userMessage, error);
        break;
    }
  }

  String _getUserFriendlyMessage(AppError error) {
    if (error.code != null) {
      switch (error.code) {
        case 'NETWORK_ERROR':
          return AppConstants.networkErrorMessage;
        case 'AUTH_ERROR':
          return AppConstants.authErrorMessage;
        case 'PERMISSION_ERROR':
          if (error.context?['permission'] == 'camera') {
            return AppConstants.cameraPermissionMessage;
          } else if (error.context?['permission'] == 'microphone') {
            return AppConstants.microphonePermissionMessage;
          } else if (error.context?['permission'] == 'storage') {
            return AppConstants.storagePermissionMessage;
          }
          break;
        default:
          break;
      }
    }
    
    // Return a generic message for unknown errors
    return error.severity == ErrorSeverity.critical
        ? 'A critical error occurred. Please restart the app.'
        : AppConstants.serverErrorMessage;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    // This would typically show a SnackBar in your app
    // You'll need to implement this based on your app's navigation structure
    developer.log('SnackBar: $message', name: AppConstants.debugTag);
  }

  void _showErrorDialog(String message, AppError error) {
    // This would typically show an error dialog in your app
    // You'll need to implement this based on your app's navigation structure
    developer.log('Error Dialog: $message', name: AppConstants.debugTag);
  }

  // Public API methods
  void addErrorCallback(Function(AppError) callback) {
    _errorCallbacks.add(callback);
  }

  void removeErrorCallback(Function(AppError) callback) {
    _errorCallbacks.remove(callback);
  }

  List<AppError> getErrorHistory() {
    return List.unmodifiable(_errorHistory);
  }

  List<AppError> getRecentErrors({Duration? since}) {
    final cutoff = since != null 
        ? DateTime.now().subtract(since)
        : DateTime.now().subtract(const Duration(hours: 1));
    
    return _errorHistory.where((error) => error.timestamp.isAfter(cutoff)).toList();
  }

  Map<String, int> getErrorStatistics() {
    final stats = <String, int>{};
    
    for (final error in _errorHistory) {
      final key = error.code ?? 'unknown';
      stats[key] = (stats[key] ?? 0) + 1;
    }
    
    return stats;
  }

  void clearErrorHistory() {
    _errorHistory.clear();
    _errorCounts.clear();
    _lastErrorTimes.clear();
  }

  // Recovery methods
  Future<void> attemptRecovery(String errorCode) async {
    switch (errorCode) {
      case 'NETWORK_ERROR':
        await _attemptNetworkRecovery();
        break;
      case 'AUTH_ERROR':
        await _attemptAuthRecovery();
        break;
      case 'DATABASE_ERROR':
        await _attemptDatabaseRecovery();
        break;
      default:
        developer.log('No recovery method for error code: $errorCode', name: AppConstants.debugTag);
    }
  }

  Future<void> _attemptNetworkRecovery() async {
    // Implement network recovery logic
    // e.g., retry failed requests, check connectivity
  }

  Future<void> _attemptAuthRecovery() async {
    // Implement auth recovery logic
    // e.g., refresh tokens, re-authenticate
  }

  Future<void> _attemptDatabaseRecovery() async {
    // Implement database recovery logic
    // e.g., reinitialize database, clear corrupt data
  }

  // Safe execution wrapper
  Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? fallbackValue,
    bool showError = true,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      final appError = AppError(
        message: 'Error in ${operationName ?? 'operation'}: ${error.toString()}',
        stackTrace: stackTrace.toString(),
        context: {'operation': operationName},
      );
      
      handleError(appError, showToUser: showError);
      return fallbackValue;
    }
  }

  // Sync safe execution
  T? safeExecuteSync<T>(
    T Function() operation, {
    String? operationName,
    T? fallbackValue,
    bool showError = true,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      final appError = AppError(
        message: 'Error in ${operationName ?? 'operation'}: ${error.toString()}',
        stackTrace: stackTrace.toString(),
        context: {'operation': operationName},
      );
      
      handleError(appError, showToUser: showError);
      return fallbackValue;
    }
  }
}

// Extension for easier error handling
extension ErrorHandlingExtensions on Future {
  Future<T?> handleErrors<T>({
    String? operationName,
    T? fallbackValue,
    bool showError = true,
  }) {
    return ErrorHandler().safeExecute<T>(
      () => this as Future<T>,
      operationName: operationName,
      fallbackValue: fallbackValue,
      showError: showError,
    );
  }
}