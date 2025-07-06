import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

/// A utility class for detailed Agora call logging
class AgoraCallLogger {
  static final AgoraCallLogger _instance = AgoraCallLogger._internal();
  factory AgoraCallLogger() => _instance;
  AgoraCallLogger._internal();

  final List<String> _logs = [];
  StreamController<String>? _logStreamController;
  File? _logFile;
  bool _initialized = false;

  Stream<String>? get logStream => _logStreamController?.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    _logStreamController = StreamController<String>.broadcast();

    try {
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _logFile = File('${directory.path}/agora_call_log_$timestamp.txt');
        await _logFile!.create();
        debugPrint('📝 Agora call log file created at: ${_logFile!.path}');
      }
    } catch (e) {
      debugPrint('❌ Error creating log file: $e');
    }

    _initialized = true;
  }

  void log(String message, {bool printToConsole = true}) {
    final timestamp = DateTime.now().toString();
    final logEntry = '[$timestamp] $message';

    _logs.add(logEntry);

    if (printToConsole) {
      debugPrint(logEntry);
    }

    _logStreamController?.add(logEntry);

    // Write to file if available
    _writeToFile(logEntry);
  }

  Future<void> _writeToFile(String logEntry) async {
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString('$logEntry\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('❌ Error writing to log file: $e');
      }
    }
  }

  List<String> getLogs() {
    return List.unmodifiable(_logs);
  }

  Future<String> getLogsAsString() async {
    return _logs.join('\n');
  }

  Future<void> clearLogs() async {
    _logs.clear();

    if (_logFile != null && await _logFile!.exists()) {
      try {
        await _logFile!.delete();
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _logFile = File('${directory.path}/agora_call_log_$timestamp.txt');
        await _logFile!.create();
      } catch (e) {
        debugPrint('❌ Error clearing log file: $e');
      }
    }
  }

  Future<void> dispose() async {
    await _logStreamController?.close();
  }
}
