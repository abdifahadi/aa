import 'package:flutter/foundation.dart';

class Logger {
  static const bool _isDebugMode = kDebugMode;
  
  static void debug(String message, [String? tag]) {
    if (_isDebugMode) {
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('DEBUG: $tagPrefix$message');
    }
  }
  
  static void info(String message, [String? tag]) {
    if (_isDebugMode) {
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('INFO: $tagPrefix$message');
    }
  }
  
  static void warning(String message, [String? tag]) {
    if (_isDebugMode) {
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('WARNING: $tagPrefix$message');
    }
  }
  
  static void error(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    if (_isDebugMode) {
      final tagPrefix = tag != null ? '[$tag] ' : '';
      debugPrint('ERROR: $tagPrefix$message');
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
    }
  }
}