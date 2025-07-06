import 'package:flutter/material.dart';
import 'agora_call_flow_validator.dart';
import '../models/call_model.dart';

/// Run a complete Agora call flow test from the command line
Future<void> runAgoraCallFlowTest() async {
  debugPrint('Starting Agora call flow test...');

  // Create a validator
  final validator = AgoraCallFlowValidator();

  // Set up log listener
  validator.logStream.listen((log) {
    debugPrint(log);
  });

  try {
    // Run the test with a test receiver
    final result = await validator.validateCompleteFlow(
      receiverId: 'test-receiver-id',
      receiverName: 'Test Receiver',
      callType: CallType.video,
    );

    // Print the result
    debugPrint('Test ${result ? 'PASSED' : 'FAILED'}');

    // Print the report
    final report = validator.report;
    debugPrint('=== Test Report ===');
    debugPrint('Test: ${report.testName}');
    debugPrint('Status: ${report.success ? 'PASSED' : 'FAILED'}');
    debugPrint('Duration: ${report.duration.inSeconds} seconds');

    // Print sub-tests
    debugPrint('--- Sub-tests ---');
    for (final subTest in report.subTests) {
      debugPrint('${subTest.success ? '✓' : '✗'} ${subTest.name}');
    }

    // Print failures
    if (report.failures.isNotEmpty) {
      debugPrint('--- Failures ---');
      for (final failure in report.failures) {
        debugPrint('• $failure');
      }
    }
  } catch (e) {
    debugPrint('Error running test: $e');
  } finally {
    // Clean up
    validator.dispose();
  }
}

/// Main entry point for running the test
void main() {
  runAgoraCallFlowTest().then((_) {
    debugPrint('Test complete');
  });
}
