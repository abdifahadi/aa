import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class AgoraTokenTester {
  // Supabase function URL
  final String supabaseUrl =
      'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';

  // Agora App ID
  final String appId = 'b7487b8a48da4f89a4285c92e454a96f';

  // Generate and test token using Supabase function
  Future<Map<String, dynamic>> testSupabaseTokenGeneration() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? currentUser = auth.currentUser;

    if (currentUser == null) {
      return {
        'success': false,
        'message': 'No authenticated user found',
        'token': null,
      };
    }

    try {
      // Generate a unique channel name
      final String channelName = const Uuid().v4();
      final int uid = DateTime.now().millisecondsSinceEpoch % 100000;

      print('🧪 Testing token generation with Supabase');
      print('🧪 Channel Name: $channelName');
      print('🧪 UID: $uid');

      // Get fresh Firebase ID token
      final String? idToken = await currentUser.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'message': 'Failed to get Firebase ID token',
          'token': null,
        };
      }

      print('🧪 Got Firebase ID token (length: ${idToken.length})');

      // Call Supabase function
      final response = await http.post(
        Uri.parse(supabaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'X-Client-Info': 'flutter-agora-tester',
        },
        body: jsonEncode({
          'channelName': channelName,
          'uid': uid,
          'role': 'publisher',
          'expireTimeInSeconds': 600,
          'appId': appId,
        }),
      );

      print('🧪 Supabase response status code: ${response.statusCode}');

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message':
              'Supabase function returned status ${response.statusCode}: ${response.body}',
          'token': null,
          'statusCode': response.statusCode,
          'responseBody': response.body,
        };
      }

      // Parse response
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (!data.containsKey('token')) {
        return {
          'success': false,
          'message': 'Token not found in response',
          'response': data,
          'token': null,
        };
      }

      final String token = data['token'];

      return {
        'success': true,
        'message': 'Token generated successfully',
        'token': token,
        'channelName': channelName,
        'uid': uid,
        'tokenLength': token.length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'token': null,
      };
    }
  }

  // Widget to display token test results
  static Widget buildTestWidget(BuildContext context) {
    final tester = AgoraTokenTester();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agora Token Test'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: tester.testSupabaseTokenGeneration(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final result = snapshot.data!;
          final bool success = result['success'] ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  success
                      ? '✅ Token Generation Successful'
                      : '❌ Token Generation Failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: success ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Message: ${result['message']}'),
                const SizedBox(height: 8),
                if (success) ...[
                  Text('Channel Name: ${result['channelName']}'),
                  Text('UID: ${result['uid']}'),
                  Text('Token Length: ${result['tokenLength']}'),
                  const SizedBox(height: 16),
                  const Text('Token (first 20 chars):'),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${result['token'].toString().substring(0, 20)}...',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ] else ...[
                  if (result.containsKey('statusCode'))
                    Text('Status Code: ${result['statusCode']}'),
                  if (result.containsKey('responseBody'))
                    Text('Response: ${result['responseBody']}'),
                  if (result.containsKey('response'))
                    Text('Response Data: ${result['response']}'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
