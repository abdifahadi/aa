import 'dart:convert';

import 'package:http/http.dart' as http;

/// A utility class to test Supabase token generation functionality
class SupabaseTokenTester {
  // Supabase function URL for token generation
  static const String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';

  /// Test Supabase token generation with various scenarios
  static Future<Map<String, dynamic>> runTests() async {
    final List<Map<String, dynamic>> testResults = [];
    
    // Test 1: Valid token generation
    print('🧪 Running Test 1: Valid Token Generation');
    final test1 = await _testValidTokenGeneration();
    testResults.add({
      'testName': 'Valid Token Generation',
      'result': test1,
    });

    // Test 2: Invalid parameters
    print('🧪 Running Test 2: Invalid Parameters');
    final test2 = await _testInvalidParameters();
    testResults.add({
      'testName': 'Invalid Parameters',
      'result': test2,
    });

    // Test 3: Network timeout
    print('🧪 Running Test 3: Network Timeout');
    final test3 = await _testNetworkTimeout();
    testResults.add({
      'testName': 'Network Timeout',
      'result': test3,
    });

    return {
      'totalTests': testResults.length,
      'testResults': testResults,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Test valid token generation
  static Future<Map<String, dynamic>> _testValidTokenGeneration() async {
    try {
      final response = await http.post(
        Uri.parse(supabaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channelName': 'test-channel-${DateTime.now().millisecondsSinceEpoch}',
          'uid': 12345,
          'role': 'publisher',
          'expireTimeInSeconds': 3600,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'statusCode': response.statusCode,
          'token': data['token'] ?? 'No token in response',
          'message': 'Token generated successfully',
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'message': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Test with invalid parameters
  static Future<Map<String, dynamic>> _testInvalidParameters() async {
    try {
      final response = await http.post(
        Uri.parse(supabaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          // Missing channelName intentionally
          'uid': 'invalid-uid',
          'role': 'invalid-role',
        }),
      ).timeout(const Duration(seconds: 10));

      return {
        'success': response.statusCode != 200,
        'statusCode': response.statusCode,
        'message': response.statusCode != 200 
          ? 'Expected error received (test passed)'
          : 'Unexpected success with invalid parameters',
        'response': response.body,
      };
    } catch (e) {
      return {
        'success': true, // Error expected with invalid params
        'message': 'Expected error: $e',
      };
    }
  }

  /// Test network timeout
  static Future<Map<String, dynamic>> _testNetworkTimeout() async {
    try {
      final response = await http.post(
        Uri.parse(supabaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channelName': 'timeout-test-channel',
          'uid': 99999,
          'role': 'publisher',
        }),
      ).timeout(const Duration(milliseconds: 1)); // Very short timeout

      return {
        'success': false,
        'message': 'Unexpected completion within timeout',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': true, // Timeout expected
        'message': 'Expected timeout error: $e',
      };
    }
  }

  /// Quick token test for debugging
  static Future<void> quickTest() async {
    print('🔍 Quick Supabase Token Test');
    print('================================');
    
    final result = await _testValidTokenGeneration();
    
    if (result['success']) {
      print('✅ SUCCESS: ${result['message']}');
      if (result['token'] != null) {
        final token = result['token'].toString();
        print('📝 Token Length: ${token.length}');
        print('📝 Token Preview: ${token.length > 20 ? token.substring(0, 20) + "..." : token}');
      }
    } else {
      print('❌ FAILED: ${result['message']}');
    }
    
    print('================================');
  }
}

/// Main function to run tests independently
void main() async {
  print('🚀 Starting Supabase Token Tests');
  
  final results = await SupabaseTokenTester.runTests();
  
  print('\n📊 Test Results Summary:');
  print('Total Tests: ${results['totalTests']}');
  print('Timestamp: ${results['timestamp']}');
  
  final testResults = results['testResults'] as List;
  for (int i = 0; i < testResults.length; i++) {
    final test = testResults[i];
    final result = test['result'] as Map<String, dynamic>;
    final success = result['success'] ?? false;
    
    print('\n${i + 1}. ${test['testName']}: ${success ? '✅ PASSED' : '❌ FAILED'}');
    print('   Message: ${result['message']}');
    if (result.containsKey('statusCode')) {
      print('   Status Code: ${result['statusCode']}');
    }
  }
}