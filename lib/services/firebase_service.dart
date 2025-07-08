import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:io';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Authentication stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (credential.user != null) {
        await createUserDocument(credential.user!, name);
      }

      return credential;
    } catch (e) {
      print('Error registering: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> createUserDocument(User user, String name) async {
    try {
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        name: name,
        createdAt: DateTime.now(),
        status: UserStatus.online,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap());
    } catch (e) {
      print('Error creating user document: $e');
      rethrow;
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Get current user model
  Future<UserModel?> getCurrentUserModel() async {
    try {
      if (currentUser == null) return null;
      return await getUserById(currentUser!.uid);
    } catch (e) {
      print('Error getting current user model: $e');
      return null;
    }
  }

  // Update user status
  Future<void> updateUserStatus(UserStatus status) async {
    try {
      if (currentUser == null) return;
      
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'status': status.toString().split('.').last,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? photoUrl,
    DateTime? dateOfBirth,
  }) async {
    try {
      if (currentUser == null) return;

      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (dateOfBirth != null) updates['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(currentUser!.uid).update(updates);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Get all users except current user
  Stream<List<UserModel>> getAllUsers() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .where(FieldPath.documentId, isNotEqualTo: currentUser!.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  // Search users by name or email
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (currentUser == null) return [];

      final queryLower = query.toLowerCase();
      
      // Search by name
      final nameQuery = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: queryLower)
          .where('name', isLessThan: queryLower + 'z')
          .where(FieldPath.documentId, isNotEqualTo: currentUser!.uid)
          .get();

      // Search by email
      final emailQuery = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThan: queryLower + 'z')
          .where(FieldPath.documentId, isNotEqualTo: currentUser!.uid)
          .get();

      Set<UserModel> users = {};
      users.addAll(nameQuery.docs.map((doc) => UserModel.fromFirestore(doc)));
      users.addAll(emailQuery.docs.map((doc) => UserModel.fromFirestore(doc)));

      return users.toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Create or get chat between two users
  Future<ChatModel> createOrGetChat(String otherUserId) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');

      final chatId = ChatModel.getChatId(currentUser!.uid, otherUserId);
      
      // Check if chat already exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      
      if (chatDoc.exists) {
        return ChatModel.fromFirestore(chatDoc);
      }

      // Get other user info
      final otherUser = await getUserById(otherUserId);
      final currentUserModel = await getCurrentUserModel();

      if (otherUser == null || currentUserModel == null) {
        throw Exception('Could not load user information');
      }

      // Create new chat
      final newChat = ChatModel(
        id: chatId,
        participants: [currentUser!.uid, otherUserId],
        participantNames: {
          currentUser!.uid: currentUserModel.name,
          otherUserId: otherUser.name,
        },
        participantPhotos: {
          currentUser!.uid: currentUserModel.photoUrl ?? '',
          otherUserId: otherUser.photoUrl ?? '',
        },
        createdAt: DateTime.now(),
      );

      await _firestore.collection('chats').doc(chatId).set(newChat.toMap());
      return newChat;
    } catch (e) {
      print('Error creating or getting chat: $e');
      rethrow;
    }
  }

  // Get user's chats
  Stream<List<ChatModel>> getUserChats() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser!.uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromFirestore(doc))
            .toList());
  }

  // Send text message
  Future<void> sendTextMessage({
    required String chatId,
    required String content,
    required String senderId,
    required String senderEmail,
    required String senderName,
  }) async {
    try {
      final message = MessageModel(
        id: '', // Will be set by Firestore
        senderId: senderId,
        senderEmail: senderEmail,
        senderName: senderName,
        content: content,
        type: MessageType.text,
        timestamp: DateTime.now(),
      );

      // Add message to Firestore
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      // Update chat's last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
        'lastMessageText': content,
        'lastMessageSenderId': senderId,
      });
    } catch (e) {
      print('Error sending text message: $e');
      rethrow;
    }
  }

  // Send media message
  Future<void> sendMediaMessage({
    required String chatId,
    required String content,
    required MessageType type,
    required String senderId,
    required String senderEmail,
    required String senderName,
    String? mediaUrl,
    String? mediaName,
    int? mediaSize,
  }) async {
    try {
      final message = MessageModel(
        id: '', // Will be set by Firestore
        senderId: senderId,
        senderEmail: senderEmail,
        senderName: senderName,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        mediaUrl: mediaUrl,
        mediaName: mediaName,
        mediaSize: mediaSize,
      );

      // Add message to Firestore
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      // Update chat's last message
      String lastMessageText;
      switch (type) {
        case MessageType.image:
          lastMessageText = '📷 ছবি';
          break;
        case MessageType.video:
          lastMessageText = '🎥 ভিডিও';
          break;
        case MessageType.document:
          lastMessageText = '📄 ডকুমেন্ট';
          break;
        default:
          lastMessageText = content;
      }

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
        'lastMessageText': lastMessageText,
        'lastMessageSenderId': senderId,
      });
    } catch (e) {
      print('Error sending media message: $e');
      rethrow;
    }
  }

  // Get messages for a chat
  Stream<List<MessageModel>> getChatMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      final batch = _firestore.batch();
      
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Upload file to Firebase Storage
  Future<String> uploadFile(String filePath, String fileName, String folder) async {
    try {
      final file = await _storage.ref().child('$folder/$fileName').putData(
        await _getFileBytes(filePath),
      );
      return await file.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  // Helper method to get file bytes (implement based on platform)
  Future<Uint8List> _getFileBytes(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }

  // Initialize Firestore (placeholder for chat_app.dart)
  Future<void> initializeFirestore() async {
    try {
      // Ensure Firestore is initialized
      await _firestore.enableNetwork();
      print('✅ Firestore initialized successfully');
    } catch (e) {
      print('❌ Error initializing Firestore: $e');
      rethrow;
    }
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    try {
      // Delete all messages
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Delete chat document
      batch.delete(_firestore.collection('chats').doc(chatId));
      
      await batch.commit();
    } catch (e) {
      print('Error deleting chat: $e');
      rethrow;
    }
  }

  // Update typing status
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'typingUsers.$userId': isTyping,
      });
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  // Get chat by ID
  Future<ChatModel?> getChatById(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (doc.exists) {
        return ChatModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting chat by ID: $e');
      return null;
    }
  }

  // Check if chat exists between two users
  Future<bool> chatExists(String user1Id, String user2Id) async {
    try {
      final chatId = ChatModel.getChatId(user1Id, user2Id);
      final doc = await _firestore.collection('chats').doc(chatId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if chat exists: $e');
      return false;
    }
  }

  // Get user profile from Firestore
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Get typing status stream
  Stream<Map<String, bool>> getTypingStatusStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data != null && data['typingUsers'] != null) {
        return Map<String, bool>.from(data['typingUsers']);
      }
      return <String, bool>{};
    });
  }

  // Get user status stream
  Stream<UserStatus> getUserStatusStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data != null && data['status'] != null) {
        final statusStr = data['status'] as String;
        try {
          return UserStatus.values.firstWhere(
            (e) => e.toString().split('.').last == statusStr,
            orElse: () => UserStatus.offline,
          );
        } catch (e) {
          return UserStatus.offline;
        }
      }
      return UserStatus.offline;
    });
  }

  // Refresh current user
  Future<void> refreshCurrentUser() async {
    try {
      await _auth.currentUser?.reload();
      debugPrint('✅ Current user refreshed');
    } catch (e) {
      debugPrint('❌ Error refreshing current user: $e');
      rethrow;
    }
  }

  // Upload file and get URL (placeholder implementation)
  Future<String?> uploadFileAndGetUrl(File file, String fileName, MessageType messageType) async {
    try {
      // This is a placeholder implementation
      // In a real app, you would upload to Firebase Storage or another service
      debugPrint('📤 Uploading file: $fileName');
      
      // Simulate upload delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Return a placeholder URL
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'https://placeholder.com/uploads/$timestamp/$fileName';
    } catch (e) {
      debugPrint('❌ Error uploading file: $e');
      return null;
    }
  }

  // Initialize Firestore
  Future<void> initializeFirestore() async {
    try {
      // Enable offline persistence
      await _firestore.enablePersistence();
      debugPrint('🔥 Firestore initialized with offline persistence');
    } catch (e) {
      debugPrint('Error initializing Firestore: $e');
    }
  }
}
