import 'package:flutter/material.dart';
import 'comprehensive_agora_validator.dart';
import '../models/call_model.dart';
import 'agora_call_test_report.dart';

/// Run a comprehensive Agora call flow test from the command line
Future<void> runComprehensiveAgoraTest() async {
  debugPrint('Starting comprehensive Agora call flow test...');

  // Create a validator
  final validator = ComprehensiveAgoraValidator();

  // Set up log listener
  validator.logStream.listen((log) {
    debugPrint(log);
  });

  try {
    // Run the test with a test receiver
    final result = await validator.runComprehensiveValidation(
      receiverId: 'test-receiver-id',
      receiverName: 'Test Receiver',
      callType: CallType.video,
    );

    // Print the result
    debugPrint('Test ${result ? 'PASSED' : 'FAILED'}');

    // Print the report
    final report = validator.report;
    debugPrint('=== Comprehensive Test Report ===');
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

    // Print recommendations if test failed
    if (!result) {
      _printRecommendations(report);
    }
  } catch (e) {
    debugPrint('Error running test: $e');
  } finally {
    // Clean up
    validator.dispose();
  }
}

/// Print recommendations based on test failures
void _printRecommendations(AgoraCallTestReport report) {
  debugPrint('=== Fix Recommendations ===');

  // Check which sub-tests failed
  for (final subTest in report.subTests) {
    if (!subTest.success) {
      switch (subTest.name) {
        case 'Numeric UID Consistency Check':
          debugPrint(
              '• Ensure the same algorithm is used for UID generation on both client and server');
          debugPrint(
              '• Verify that caller/receiver prefixes are applied consistently');
          debugPrint(
              '• Check for any randomness in the UID generation process');
          break;

        case 'Permission Check':
          debugPrint(
              '• Make sure to request camera and microphone permissions before starting a call');
          debugPrint(
              '• Handle permission denials gracefully with user-friendly messages');
          debugPrint(
              '• Consider adding a permission request screen before initiating calls');
          break;

        case 'Token Generation':
          debugPrint(
              '• Verify Supabase function is accessible and configured correctly');
          debugPrint('• Check Firebase authentication is working properly');
          debugPrint(
              '• Ensure proper parameters are passed to token generation');
          debugPrint(
              '• Verify the token format and length meet Agora requirements');
          break;

        case 'Call Creation and Firestore Verification':
          debugPrint('• Check Firestore security rules allow write access');
          debugPrint(
              '• Verify call document structure matches expected schema');
          debugPrint(
              '• Ensure numeric UIDs are stored correctly in the call document');
          debugPrint(
              '• Check for any race conditions in document creation/updates');
          break;

        case 'Engine Initialization and Configuration':
          debugPrint('• Verify Agora App ID is correct and active');
          debugPrint(
              '• Check that proper channel profile and client role are set');
          debugPrint(
              '• Ensure audio/video configurations are appropriate for the device');
          debugPrint(
              '• Consider adding retry logic for engine initialization failures');
          break;

        case 'Call Connection Timing Verification':
          debugPrint(
              '• Ensure caller waits for receiver to accept before joining channel');
          debugPrint(
              '• Verify Firestore listeners for call status changes are working');
          debugPrint('• Check for race conditions in the call acceptance flow');
          break;

        case 'Channel Join':
          debugPrint('• Verify token format and expiration');
          debugPrint(
              '• Check that channel name matches between caller and receiver');
          debugPrint('• Ensure proper permissions are granted');
          debugPrint('• Verify network connectivity is stable');
          break;

        case 'Remote User Verification':
          debugPrint(
              '• Check that both users are using the correct channel name');
          debugPrint('• Verify numeric UIDs are correctly generated and used');
          debugPrint('• Ensure token privileges allow joining the channel');
          break;

        case 'Two-way Media Stream Verification':
          debugPrint('• Check for network connectivity issues');
          debugPrint('• Verify audio/video permissions are granted');
          debugPrint('• Ensure proper media options are configured');
          debugPrint('• Check for device hardware issues');
          debugPrint('• Verify the remote user has enabled their audio/video');
          break;

        case 'Call Termination and Cleanup':
          debugPrint('• Ensure proper cleanup of Agora resources');
          debugPrint('• Verify Firestore updates are completed');
          debugPrint('• Check for any lingering listeners or subscriptions');
          break;

        default:
          debugPrint('• Unknown failure in: ${subTest.name}');
      }
    }
  }
}

/// Main entry point for running the test
void main() {
  runComprehensiveAgoraTest().then((_) {
    debugPrint('Test complete');
  });
}
