import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

/// A utility class for detailed Agora call logging
class AgoraCallLogger {
  static final AgoraCallLogger _instance = AgoraCallLogger._internal();
  factory AgoraCallLogger() => _instance;
  AgoraCallLogger._internal();

  static const String _logFileName = 'agora_call_logs.txt';
  static const int _maxLogSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogLines = 10000;

  File? _logFile;
  final List<String> _logBuffer = [];
  Timer? _flushTimer;
  bool _isInitialized = false;

  // Initialize the logger
  static Future<void> initialize() async {
    final instance = AgoraCallLogger._instance;
    if (instance._isInitialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      instance._logFile = File('${directory.path}/${_logFileName}');
      
      // Create log file if it doesn't exist
      if (!await instance._logFile!.exists()) {
        await instance._logFile!.create();
        await instance._writeToFile('=== Agora Call Logger Initialized ===');
      }

      // Set up periodic flush
      instance._flushTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        instance._flushLogs();
      });

      instance._isInitialized = true;
      debugPrint('✅ AgoraCallLogger initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing AgoraCallLogger: $e');
    }
  }

  // Log a message
  static void log(String message, {String? category, LogLevel level = LogLevel.info}) {
    final instance = AgoraCallLogger._instance;
    
    if (!AppConstants.enableLogging && level != LogLevel.error) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final categoryStr = category != null ? '[$category] ' : '';
    final levelStr = '[${level.name.toUpperCase()}] ';
    final logMessage = '$timestamp $levelStr$categoryStr$message';

    // Add to buffer
    instance._logBuffer.add(logMessage);
    
    // Debug print for immediate feedback
    if (AppConstants.enableDebugMode) {
      debugPrint('📝 AGORA: $logMessage');
    }

    // Flush if buffer is getting large
    if (instance._logBuffer.length > 100) {
      instance._flushLogs();
    }
  }

  // Log call initiation
  static void logCallInitiation(String callId, String receiverId, String callType) {
    log(
      'Call initiated - ID: $callId, Receiver: $receiverId, Type: $callType',
      category: 'CALL_INIT',
      level: LogLevel.info,
    );
  }

  // Log call acceptance
  static void logCallAcceptance(String callId, String acceptedBy) {
    log(
      'Call accepted - ID: $callId, Accepted by: $acceptedBy',
      category: 'CALL_ACCEPT',
      level: LogLevel.info,
    );
  }

  // Log call rejection
  static void logCallRejection(String callId, String rejectedBy, String reason) {
    log(
      'Call rejected - ID: $callId, Rejected by: $rejectedBy, Reason: $reason',
      category: 'CALL_REJECT',
      level: LogLevel.info,
    );
  }

  // Log call end
  static void logCallEnd(String callId, int duration, String reason) {
    log(
      'Call ended - ID: $callId, Duration: ${duration}s, Reason: $reason',
      category: 'CALL_END',
      level: LogLevel.info,
    );
  }

  // Log engine events
  static void logEngineEvent(String event, Map<String, dynamic> data) {
    final dataStr = jsonEncode(data);
    log(
      'Engine event: $event - Data: $dataStr',
      category: 'ENGINE',
      level: LogLevel.debug,
    );
  }

  // Log token generation
  static void logTokenGeneration(String channelId, bool success, String? error) {
    log(
      'Token generation - Channel: $channelId, Success: $success${error != null ? ', Error: $error' : ''}',
      category: 'TOKEN',
      level: success ? LogLevel.info : LogLevel.error,
    );
  }

  // Log connection status
  static void logConnectionStatus(String status, String details) {
    log(
      'Connection status: $status - $details',
      category: 'CONNECTION',
      level: LogLevel.info,
    );
  }

  // Log media status
  static void logMediaStatus(String mediaType, String status, String details) {
    log(
      'Media status - Type: $mediaType, Status: $status, Details: $details',
      category: 'MEDIA',
      level: LogLevel.info,
    );
  }

  // Log error
  static void logError(String error, {String? category, StackTrace? stackTrace}) {
    log(
      'Error: $error${stackTrace != null ? '\nStack trace: $stackTrace' : ''}',
      category: category ?? 'ERROR',
      level: LogLevel.error,
    );
  }

  // Log warning
  static void logWarning(String warning, {String? category}) {
    log(
      'Warning: $warning',
      category: category ?? 'WARNING',
      level: LogLevel.warning,
    );
  }

  // Log permission request
  static void logPermissionRequest(String permission, bool granted) {
    log(
      'Permission request - $permission: ${granted ? 'GRANTED' : 'DENIED'}',
      category: 'PERMISSION',
      level: granted ? LogLevel.info : LogLevel.warning,
    );
  }

  // Log network quality
  static void logNetworkQuality(int uid, int quality) {
    log(
      'Network quality - UID: $uid, Quality: $quality',
      category: 'NETWORK',
      level: LogLevel.debug,
    );
  }

  // Flush logs to file
  void _flushLogs() {
    if (_logBuffer.isEmpty || _logFile == null) return;

    try {
      final logsToWrite = List<String>.from(_logBuffer);
      _logBuffer.clear();

      _writeToFile(logsToWrite.join('\n'));
    } catch (e) {
      debugPrint('❌ Error flushing logs: $e');
    }
  }

  // Write to log file
  Future<void> _writeToFile(String content) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString(
        '$content\n',
        mode: FileMode.append,
      );

      // Check file size and rotate if needed
      await _checkAndRotateLog();
    } catch (e) {
      debugPrint('❌ Error writing to log file: $e');
    }
  }

  // Check and rotate log file if it's too large
  Future<void> _checkAndRotateLog() async {
    if (_logFile == null) return;

    try {
      final stat = await _logFile!.stat();
      
      if (stat.size > _maxLogSize) {
        await _rotateLog();
      }
    } catch (e) {
      debugPrint('❌ Error checking log size: $e');
    }
  }

  // Rotate log file
  Future<void> _rotateLog() async {
    if (_logFile == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupFile = File('${directory.path}/agora_call_logs_backup.txt');
      
      // Move current log to backup
      if (await _logFile!.exists()) {
        await _logFile!.copy(backupFile.path);
      }
      
      // Create new log file
      await _logFile!.writeAsString('=== Log Rotated ===\n');
      
      debugPrint('📝 Log file rotated');
    } catch (e) {
      debugPrint('❌ Error rotating log: $e');
    }
  }

  // Get all logs
  static Future<List<String>> getAllLogs() async {
    final instance = AgoraCallLogger._instance;
    
    try {
      if (instance._logFile == null || !await instance._logFile!.exists()) {
        return ['No logs available'];
      }

      final content = await instance._logFile!.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      // Add buffered logs
      lines.addAll(instance._logBuffer);
      
      return lines;
    } catch (e) {
      debugPrint('❌ Error reading logs: $e');
      return ['Error reading logs: $e'];
    }
  }

  // Clear all logs
  static Future<void> clearLogs() async {
    final instance = AgoraCallLogger._instance;
    
    try {
      instance._logBuffer.clear();
      
      if (instance._logFile != null && await instance._logFile!.exists()) {
        await instance._logFile!.writeAsString('=== Logs Cleared ===\n');
      }
      
      debugPrint('🧹 Agora call logs cleared');
    } catch (e) {
      debugPrint('❌ Error clearing logs: $e');
    }
  }

  // Export logs as string
  static Future<String> exportLogs() async {
    final logs = await getAllLogs();
    return logs.join('\n');
  }

  // Get log file size
  static Future<int> getLogFileSize() async {
    final instance = AgoraCallLogger._instance;
    
    try {
      if (instance._logFile == null || !await instance._logFile!.exists()) {
        return 0;
      }

      final stat = await instance._logFile!.stat();
      return stat.size;
    } catch (e) {
      debugPrint('❌ Error getting log file size: $e');
      return 0;
    }
  }

  // Get formatted log file size
  static Future<String> getLogFileSizeFormatted() async {
    final size = await getLogFileSize();
    
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  // Search logs
  static Future<List<String>> searchLogs(String query) async {
    final logs = await getAllLogs();
    return logs.where((log) => log.toLowerCase().contains(query.toLowerCase())).toList();
  }

  // Get logs for specific category
  static Future<List<String>> getLogsByCategory(String category) async {
    final logs = await getAllLogs();
    return logs.where((log) => log.contains('[$category]')).toList();
  }

  // Dispose resources
  static void dispose() {
    final instance = AgoraCallLogger._instance;
    
    instance._flushTimer?.cancel();
    instance._flushLogs(); // Final flush
    instance._isInitialized = false;
  }
}

// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}
