import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

/// A script to debug the CallService token generation flow
void main() async {
  print('Starting CallService token generation debug test...');

  // Supabase function URL - same as in CallService
  const String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';

  // Test parameters
  final String channelName =
      'test-channel-${DateTime.now().millisecondsSinceEpoch}';
  final String uidString = 'user-${Random().nextInt(100000)}';

  // Generate a numeric uid based on the string uid
  // This replicates the logic in CallService._generateNumericUidFromString
  final int numericUid = _generateNumericUidFromString(uidString);

  print('Test parameters:');
  print('- Channel Name: $channelName');
  print('- String UID: $uidString');
  print('- Numeric UID: $numericUid');

  // Test Supabase token generation
  print('\n1. Testing Supabase token generation with numeric UID...');
  try {
    final response = await http
        .post(
          Uri.parse(supabaseUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'channelName': channelName,
            'uid': numericUid, // Send numeric uid as a number, not a string
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

      // Save token for later verification
      final generatedToken = token;

      // Simulate storing the token in CallModel
      print('\n2. Simulating storing token in CallModel...');
      final callModel = {
        'id': channelName,
        'channelId': channelName,
        'token': generatedToken,
        'numericUid': numericUid,
      };

      print('CallModel created with:');
      print('- Channel ID: ${callModel['channelId']}');
      print('- Token length: ${callModel['token'].toString().length}');
      print(
          '- Token prefix: ${callModel['token'].toString().substring(0, min(20, callModel['token'].toString().length))}...');
      print('- Numeric UID: ${callModel['numericUid']}');

      // Simulate using the token in joinChannel
      print('\n3. Simulating using token in joinChannel()...');
      print('Would call engine.joinChannel() with:');
      print(
          '- Token: ${callModel['token'].toString().substring(0, min(20, callModel['token'].toString().length))}...');
      print('- Channel ID: ${callModel['channelId']}');
      print('- UID: ${callModel['numericUid']}');

      print('\n✅ Complete flow test successful');
    } else {
      print('Error response: ${response.body}');
    }
  } catch (e) {
    print('Error in token flow test: $e');
  }

  print('\nCallService token generation debug test completed.');
}

// Helper method to generate a consistent numeric uid from a string
// This is a copy of the method in CallService
int _generateNumericUidFromString(String str) {
  // Simple hash function to convert string to integer
  // We use modulo to keep the number within a reasonable range (under 100000)
  int hash = 0;
  for (int i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.codeUnitAt(i);
    hash = hash & hash; // Convert to 32bit integer
  }

  // Ensure it's positive and within a reasonable range
  int positiveHash = hash.abs() % 100000;

  // Avoid using 0 as it's a special value in Agora
  if (positiveHash == 0) positiveHash = 1;

  print('Generated numeric uid $positiveHash from string uid $str');
  return positiveHash;
}
