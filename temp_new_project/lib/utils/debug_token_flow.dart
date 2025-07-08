import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

/// A simple script to debug the token flow without Flutter UI
void main() async {
  print('Starting token flow debug test...');

  // Supabase function URL
  const String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';

  // Test parameters
  final String channelName =
      'test-channel-${DateTime.now().millisecondsSinceEpoch}';
  final int uid = Random().nextInt(100000) + 1;

  print('Test parameters:');
  print('- Channel Name: $channelName');
  print('- UID: $uid');

  // Test Supabase token generation
  print('\n1. Testing Supabase token generation...');
  try {
    final response = await http
        .post(
          Uri.parse(supabaseUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'channelName': channelName,
            'uid': uid,
            'role': 'publisher',
          }),
        )
        .timeout(const Duration(seconds: 15));

    print('Response status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;

      print('Token generated successfully');
      print('Token length: ${token.length}');
      print('Token prefix: ${token.substring(0, min(20, token.length))}...');
      print('Channel name from response: ${data['channelName']}');
      print('UID from response: ${data['uid']}');
      print('Role from response: ${data['role']}');
      print('Expires at: ${data['expiresAt']}');

      // Verify the token format
      if (token.startsWith('006b7487b8a48da4f89a4285c92e454a96f')) {
        print('✅ Token has correct prefix format');
      } else {
        print('❌ Token has incorrect prefix format');
      }

      if (token.length >= 100) {
        print('✅ Token has appropriate length');
      } else {
        print('❌ Token is too short: ${token.length} characters');
      }
    } else {
      print('Error response: ${response.body}');
    }
  } catch (e) {
    print('Error in Supabase token test: $e');
  }

  print('\nToken flow debug test completed.');
}
