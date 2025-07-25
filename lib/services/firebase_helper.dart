import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Authentication helpers
  static Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  static Future<UserCredential?> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print('Create user error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Firestore helpers
  static CollectionReference get usersCollection =>
      _firestore.collection('users');

  static CollectionReference get chatsCollection =>
      _firestore.collection('chats');

  static CollectionReference get messagesCollection =>
      _firestore.collection('messages');

  static DocumentReference getUserDocument(String userId) =>
      usersCollection.doc(userId);

  static DocumentReference getChatDocument(String chatId) =>
      chatsCollection.doc(chatId);

  // Storage helpers
  static Reference getStorageReference(String path) =>
      _storage.ref().child(path);

  static Future<String?> uploadFile(String path, dynamic file) async {
    try {
      final ref = getStorageReference(path);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Utility functions
  static String generateChatId(String user1Id, String user2Id) {
    final sortedIds = [user1Id, user2Id]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  static Future<bool> userExists(String userId) async {
    try {
      final doc = await getUserDocument(userId).get();
      return doc.exists;
    } catch (e) {
      print('Check user exists error: $e');
      return false;
    }
  }
}