import 'dart:convert';
import 'package:http/http.dart' as http;

/// A simple script to test Supabase token generation without Agora SDK
void main() async {
  // Supabase function URL
  const String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';

  // Test with valid parameters
  await testTokenGeneration(
    supabaseUrl: supabaseUrl,
    channelName: 'test-channel',
    uid: 12345,
    role: 'publisher',
    testName: 'VALID REQUEST TEST',
  );

  // Test with invalid parameters (missing channelName)
  await testTokenGeneration(
    supabaseUrl: supabaseUrl,
    channelName: null,
    uid: 12345,
    role: 'publisher',
    testName: 'INVALID REQUEST TEST (Missing channelName)',
  );
}

/// Test token generation with given parameters
Future<void> testTokenGeneration({
  required String supabaseUrl,
  required String? channelName,
  required int uid,
  required String role,
  required String testName,
}) async {
  print('\n============================================');
  print(testName);
  print('============================================');
  print('URL: $supabaseUrl');
  if (channelName != null) {
    print('Channel Name: $channelName');
  } else {
    print('Channel Name: [NOT PROVIDED]');
  }
  print('UID: $uid');
  print('Role: $role');
  print('============================================');

  try {
    print('\nSending HTTP request...');

    // Create request body
    final Map<String, dynamic> requestBody = {};
    if (channelName != null) {
      requestBody['channelName'] = channelName;
    }
    requestBody['uid'] = uid;
    requestBody['role'] = role;

    print('Request Body: ${jsonEncode(requestBody)}');

    // Make HTTP request
    final response = await http
        .post(
          Uri.parse(supabaseUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 15));

    print('\n--- HTTP RESPONSE ---');
    print('Status Code: ${response.statusCode}');
    print('Response Length: ${response.body.length} bytes');

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        print('\n--- TOKEN DETAILS ---');
        print('Token: ${data['token']}');
        print('Token Length: ${data['token'].toString().length}');
        print('Channel Name: ${data['channelName']}');
        print('UID: ${data['uid']}');
        print('Role: ${data['role']}');
        print('Expires At: ${data['expiresAt']}');
        print('\nTEST RESULT: SUCCESS ✅');
      } catch (e) {
        print('\nError parsing response: $e');
        print('Raw response: ${response.body}');
        print('\nTEST RESULT: FAILED ❌');
      }
    } else {
      try {
        final errorData = jsonDecode(response.body);
        print('\n--- ERROR DETAILS ---');
        print('Error: ${errorData['error']}');
        if (errorData['stack'] != null) {
          print('Stack: ${errorData['stack']}');
        }
        print('\nTEST RESULT: FAILED (Expected for invalid test) ❌');
      } catch (e) {
        print('\nError parsing error response: $e');
        print('Raw error response: ${response.body}');
        print('\nTEST RESULT: FAILED ❌');
      }
    }
  } catch (e) {
    print('\nError: $e');
    print('\nTEST RESULT: FAILED ❌');
  }

  print('============================================');
}
