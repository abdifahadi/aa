import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'local_database.dart';
import 'firebase_service.dart';
import 'connectivity_service.dart';
import '../models/message_model.dart';

class OfflineSyncService {
  // Singleton instance
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  // Dependencies
  final LocalDatabase _localDb = LocalDatabase();
  final FirebaseService _firebaseService = FirebaseService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // State
  bool _isInitialized = false;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  // Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Create directory for offline media storage
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final directory = Directory('${appDir.path}/offline_media');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        debugPrint(
            'OfflineSyncService: Created offline media directory at ${directory.path}');
      }
    } catch (e) {
      debugPrint(
          'OfflineSyncService: Error creating offline media directory: $e');
    }

    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivityService.connectionStream.listen((isConnected) {
      if (isConnected) {
        _triggerSync();
      }
    });

    // Setup periodic sync check (every 5 minutes)
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final isConnected = await _connectivityService.checkConnectivity();
      if (isConnected) {
        _triggerSync();
      }
    });

    _isInitialized = true;

    // Trigger initial sync if we're online
    final isConnected = await _connectivityService.checkConnectivity();
    if (isConnected) {
      _triggerSync();
    }
  }

  // Trigger sync of pending messages
  Future<void> _triggerSync() async {
    if (_isSyncing) return; // Prevent multiple syncs

    try {
      _isSyncing = true;

      // Get all pending messages
      final pendingMessages = await _localDb.getPendingMessages();

      if (pendingMessages.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint(
          'OfflineSyncService: Found ${pendingMessages.length} pending messages to sync');

      // Process each pending message
      for (final message in pendingMessages) {
        await _processPendingMessage(message);
      }
    } catch (e) {
      debugPrint('OfflineSyncService: Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Process a single pending message
  Future<void> _processPendingMessage(Map<String, dynamic> message) async {
    final id = message['id'] as String;
    final chatId = message['chatId'] as String;
    final type = message['type'] as String;

    try {
      // Update status to processing
      await _localDb.updatePendingMessageStatus(id, 'processing');

      // Determine the message type and call appropriate method
      if (type == 'text') {
        await _firebaseService.sendTextMessage(
          chatId,
          message['content'],
          message['senderId'],
          message['senderEmail'],
          message['senderName'] ?? 'User',
        );
      } else {
        // For media messages
        String? mediaUrl = message['mediaUrl'];
        final localFilePath = message['localFilePath'];

        // If we have a local file but no media URL, upload it first
        if (mediaUrl == null && localFilePath != null) {
          final file = File(localFilePath);
          if (await file.exists()) {
            // Upload file and get URL
            // This depends on your file upload implementation
            mediaUrl = await _uploadFileFromPath(
                file, message['mediaName'] ?? 'file', type);
          }
        }

        // Only proceed if we have a media URL
        if (mediaUrl != null) {
          await _firebaseService.sendMediaMessage(
            chatId: chatId,
            content: message['content'],
            mediaUrl: mediaUrl,
            mediaName: message['mediaName'] ?? 'file',
            type: type,
            senderId: message['senderId'],
            senderEmail: message['senderEmail'],
            senderName: message['senderName'] ?? 'User',
            mediaSize: message['mediaSize'],
          );
        } else {
          throw Exception('No media URL or local file available for message');
        }
      }

      // Message was sent successfully
      await _localDb.deletePendingMessage(id);
      debugPrint('OfflineSyncService: Successfully synced message $id');
    } catch (e) {
      debugPrint('OfflineSyncService: Error processing message $id: $e');

      // Increment retry count
      await _localDb.incrementRetryCount(id);

      // Update status to error
      await _localDb.updatePendingMessageStatus(id, 'error');

      // If this message has been retried too many times, mark it as failed
      if ((message['retryCount'] as int) >= 5) {
        await _localDb.updatePendingMessageStatus(id, 'failed');
      }
    }
  }

  // Helper method to upload a file from a local path
  Future<String?> _uploadFileFromPath(
      File file, String fileName, String type) async {
    try {
      // This implementation depends on your file upload logic
      // For this example, we'll use the CloudinaryService through FirebaseService

      // Determine media type
      MessageType messageType;
      switch (type.toLowerCase()) {
        case 'image':
          messageType = MessageType.image;
          break;
        case 'video':
          messageType = MessageType.video;
          break;
        case 'document':
          messageType = MessageType.document;
          break;
        default:
          messageType = MessageType.text;
      }

      // Use a Firebase method to upload (assuming one exists)
      return await _firebaseService.uploadFileAndGetUrl(
          file, fileName, messageType);
    } catch (e) {
      debugPrint('OfflineSyncService: Error uploading file: $e');
      return null;
    }
  }

  // Force a sync (can be called from UI)
  Future<void> forceSyncNow() async {
    final isConnected = await _connectivityService.forceConnectivityCheck();
    if (isConnected) {
      return _triggerSync();
    } else {
      debugPrint('OfflineSyncService: Cannot force sync - offline');
    }
  }

  // Queue a message to be sent when online
  Future<void> queueMessageForSending({
    required String chatId,
    required String content,
    required String senderId,
    required String senderEmail,
    required String senderName,
    required MessageType type,
    String? mediaUrl,
    String? mediaName,
    int? mediaSize,
    File? mediaFile,
    MessageStatus status = MessageStatus.sent,
  }) async {
    String? localFilePath;

    // If there's a media file, save it locally first
    if (mediaFile != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final offlineDir = Directory('${appDir.path}/offline_media');
        if (!await offlineDir.exists()) {
          await offlineDir.create(recursive: true);
        }

        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${mediaFile.path.split('/').last}';
        final savedFile = await mediaFile.copy('${offlineDir.path}/$filename');
        localFilePath = savedFile.path;
        debugPrint('OfflineSyncService: Saved media file to $localFilePath');
      } catch (e) {
        debugPrint('OfflineSyncService: Error saving media file: $e');
      }
    }

    // Save as pending message
    final id = await _localDb.savePendingMessage(
      chatId: chatId,
      senderId: senderId,
      senderEmail: senderEmail,
      senderName: senderName,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      mediaName: mediaName,
      mediaSize: mediaSize,
      localFilePath: localFilePath,
      status: status,
    );

    debugPrint(
        'OfflineSyncService: Queued message $id for sending when online');

    // Try to sync immediately if we're online
    final isConnected = await _connectivityService.checkConnectivity();
    if (isConnected) {
      _triggerSync();
    }
  }

  // Get count of pending messages
  Future<int> getPendingMessageCount() async {
    final pendingMessages = await _localDb.getPendingMessages();
    return pendingMessages.length;
  }

  // Dispose
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
  }
}
