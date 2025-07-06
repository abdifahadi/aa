import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/call_service.dart';

class AgoraTokenTest {
  static Future<void> testTokenGeneration() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return;
      }

      // Get fresh Firebase ID token
      final idToken = await user.getIdToken(true);
      if (idToken != null && idToken.isNotEmpty) {
        debugPrint('✅ Got Firebase ID token: ${idToken.substring(0, 20)}...');
      } else {
        debugPrint('❌ Failed to get Firebase ID token');
        return;
      }

      // Test Supabase token generation
      const supabaseUrl =
          'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';
      const channelName = 'test_channel';
      final uid = user.uid;

      // Generate numeric UID (simplified version for testing)
      final numericUid = _generateSimpleNumericUid(uid);

      debugPrint('Testing token generation with:');
      debugPrint('- Channel: $channelName');
      debugPrint('- UID: $uid');
      debugPrint('- Numeric UID: $numericUid');

      try {
        final response = await http.post(
          Uri.parse(supabaseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'channelName': channelName,
            'uid': numericUid,
            'role': 'publisher',
            'expireTimeInSeconds': 600,
          }),
        );

        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['token'] != null) {
            debugPrint(
                '✅ Token generated successfully: ${data['token'].substring(0, 20)}...');
          } else {
            debugPrint('❌ No token in response');
          }
        } else {
          debugPrint('❌ Failed to generate token: ${response.body}');
        }
      } catch (e) {
        debugPrint('❌ Error testing token generation: $e');
      }

      // Test CallService
      final callService = CallService();
      try {
        final engine = await callService.initializeAgoraEngine();
        debugPrint('✅ Agora engine initialized');

        // Test token generation through CallService
        // This would be done internally by the startCall method

        debugPrint('✅ Token test completed');
      } catch (e) {
        debugPrint('❌ Error testing CallService: $e');
      }
    } catch (e) {
      debugPrint('❌ Error in token test: $e');
    }
  }

  // Simple numeric UID generator for testing
  static int _generateSimpleNumericUid(String uid) {
    int hash = 0;
    for (int i = 0; i < uid.length; i++) {
      hash = ((hash << 5) - hash) + uid.codeUnitAt(i);
      hash = hash & hash;
    }

    // Use the same modulo as in the main implementation
    int positiveHash = hash.abs() % 1000000000;
    return positiveHash == 0 ? 1 : positiveHash;
  }
}
