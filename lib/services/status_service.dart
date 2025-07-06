import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import 'firebase_service.dart';

class StatusService {
  final FirebaseService _firebaseService = FirebaseService();
  
  // Timer for tracking typing status
  Timer? _typingTimer;
  bool _isTyping = false;
  
  // Get status text in Bengali
  String getStatusText(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return 'Online';
      case UserStatus.busy:
        return 'Busy';
      case UserStatus.away:
        return 'Away';
      case UserStatus.offline:
        return 'Offline';
    }
  }
  
  // Get status color
  Color getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.busy:
        return Colors.red;
      case UserStatus.away:
        return Colors.orange;
      case UserStatus.offline:
        return Colors.grey;
    }
  }
  
  // Update user status
  Future<void> updateUserStatus(String uid, UserStatus status) async {
    try {
      await _firebaseService.updateUserStatus(uid, status);
    } catch (e) {
      print("Error updating status: $e");
    }
  }
  
  // Set user as online
  Future<void> setUserOnline(String uid) async {
    try {
      await updateUserStatus(uid, UserStatus.online);
    } catch (e) {
      print("Error setting user online: $e");
    }
  }
  
  // Set user as offline
  Future<void> setUserOffline(String uid) async {
    try {
      await updateUserStatus(uid, UserStatus.offline);
    } catch (e) {
      print("Error setting user offline: $e");
    }
  }
  
  // Start typing indicator
  void startTypingTimer(String chatId, String userId) {
    // Set typing status to true
    _firebaseService.updateTypingStatus(chatId, userId, true);
    
    // Cancel any existing timer
    cancelTypingTimer();
    
    // Start a new timer
    _typingTimer = Timer(const Duration(seconds: 3), () {
      // After 3 seconds of no typing, set typing status to false
      _firebaseService.updateTypingStatus(chatId, userId, false);
      _isTyping = false;
    });
    
    _isTyping = true;
  }
  
  // Cancel typing timer
  void cancelTypingTimer() {
    if (_typingTimer != null && _typingTimer!.isActive) {
      _typingTimer!.cancel();
    }
  }
  
  // Reset typing status when sending message
  void resetTypingStatus(String chatId, String userId) {
    _firebaseService.updateTypingStatus(chatId, userId, false);
    _isTyping = false;
    cancelTypingTimer();
  }
  
  // Get typing status stream
  Stream<Map<String, bool>> getTypingStatusStream(String chatId) {
    return _firebaseService.getTypingStatusStream(chatId);
  }
  
  // Get user status stream
  Stream<UserStatus> getUserStatusStream(String uid) {
    return _firebaseService.getUserStatusStream(uid);
  }
  
  // Check if user is typing
  bool get isTyping => _isTyping;
  
  // Dispose resources
  void dispose() {
    cancelTypingTimer();
  }
  
  // Get status menu items
  List<PopupMenuEntry<UserStatus>> getStatusMenuItems() {
    return [
      PopupMenuItem<UserStatus>(
        value: UserStatus.online,
        child: Row(
          children: [
            Icon(Icons.circle, color: getStatusColor(UserStatus.online), size: 14),
            const SizedBox(width: 8),
            const Text('Online'),
          ],
        ),
      ),
      PopupMenuItem<UserStatus>(
        value: UserStatus.busy,
        child: Row(
          children: [
            Icon(Icons.circle, color: getStatusColor(UserStatus.busy), size: 14),
            const SizedBox(width: 8),
            const Text('Busy'),
          ],
        ),
      ),
      PopupMenuItem<UserStatus>(
        value: UserStatus.away,
        child: Row(
          children: [
            Icon(Icons.circle, color: getStatusColor(UserStatus.away), size: 14),
            const SizedBox(width: 8),
            const Text('Away'),
          ],
        ),
      ),
      PopupMenuItem<UserStatus>(
        value: UserStatus.offline,
        child: Row(
          children: [
            Icon(Icons.circle, color: getStatusColor(UserStatus.offline), size: 14),
            const SizedBox(width: 8),
            const Text('Offline'),
          ],
        ),
      ),
    ];
  }
  
  // Build status indicator dot
  Widget buildStatusDot(UserStatus status, {double size = 12.0, double borderWidth = 2.0}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: getStatusColor(status),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: borderWidth,
        ),
      ),
    );
  }
  
  // Build typing indicator
  Widget buildTypingIndicator(ChatModel chat, String currentUserId) {
    return StreamBuilder<Map<String, bool>>(
      stream: getTypingStatusStream(chat.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        
        // Check if anyone other than current user is typing
        bool isAnyoneTyping = false;
        String typingUserId = '';
        
        for (final entry in snapshot.data!.entries) {
          if (entry.key != currentUserId && entry.value == true) {
            isAnyoneTyping = true;
            typingUserId = entry.key;
            break;
          }
        }
        
        if (!isAnyoneTyping) {
          return const SizedBox.shrink();
        }
        
        // Get typing user's name
        String typingUserName = chat.participantNames[typingUserId] ?? 'Someone';
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              const SizedBox(
                width: 40,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: Text('•', style: TextStyle(fontSize: 24, color: Colors.grey)),
                    ),
                    Positioned(
                      left: 10,
                      child: Text('•', style: TextStyle(fontSize: 24, color: Colors.grey)),
                    ),
                    Positioned(
                      left: 20,
                      child: Text('•', style: TextStyle(fontSize: 24, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
              Text(
                '$typingUserName লিখছে...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 