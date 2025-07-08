import 'package:cloud_firestore/cloud_firestore.dart';

// Message types
enum MessageType { text, image, video, document, audio }

// Message status
enum MessageStatus { sending, sent, delivered, read, failed }

class MessageModel {
  final String id;
  final String senderId;
  final String senderEmail;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? mediaUrl;
  final String? mediaName;
  final int? mediaSize;
  final String? thumbnailUrl;
  final String? replyToMessageId;
  final bool isEdited;
  final bool isDeleted;
  final bool isRead;
  final MessageStatus status;
  final Map<String, dynamic>? metadata;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.mediaUrl,
    this.mediaName,
    this.mediaSize,
    this.thumbnailUrl,
    this.replyToMessageId,
    this.isEdited = false,
    this.isDeleted = false,
    this.isRead = false,
    this.status = MessageStatus.sent,
    this.metadata,
  });

  // Convert MessageModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'content': content,
      'type': type.toString().split('.').last,
      'timestamp': timestamp,
      'mediaUrl': mediaUrl,
      'mediaName': mediaName,
      'mediaSize': mediaSize,
      'thumbnailUrl': thumbnailUrl,
      'replyToMessageId': replyToMessageId,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'isRead': isRead,
      'status': status.toString().split('.').last,
      'metadata': metadata ?? {},
    };
  }

  // Create MessageModel from Firestore document
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel.fromMap(data, doc.id);
  }

  // Create MessageModel from Map
  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    // Parse message type
    MessageType parseType(String typeStr) {
      switch (typeStr) {
        case 'image':
          return MessageType.image;
        case 'video':
          return MessageType.video;
        case 'document':
          return MessageType.document;
        case 'audio':
          return MessageType.audio;
        default:
          return MessageType.text;
      }
    }

    // Parse message status
    MessageStatus parseStatus(String statusStr) {
      switch (statusStr) {
        case 'sending':
          return MessageStatus.sending;
        case 'delivered':
          return MessageStatus.delivered;
        case 'read':
          return MessageStatus.read;
        case 'failed':
          return MessageStatus.failed;
        default:
          return MessageStatus.sent;
      }
    }

    // Handle timestamps
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return DateTime.now();
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is DateTime) return timestamp;
      if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now();
    }

    return MessageModel(
      id: docId,
      senderId: map['senderId'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      content: map['content'] ?? '',
      type: parseType(map['type'] ?? 'text'),
      timestamp: parseTimestamp(map['timestamp']),
      mediaUrl: map['mediaUrl'],
      mediaName: map['mediaName'],
      mediaSize: map['mediaSize']?.toInt(),
      thumbnailUrl: map['thumbnailUrl'],
      replyToMessageId: map['replyToMessageId'],
      isEdited: map['isEdited'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      isRead: map['isRead'] ?? false,
      status: parseStatus(map['status'] ?? 'sent'),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Create a copy with updated fields
  MessageModel copyWith({
    String? id,
    String? senderId,
    String? senderEmail,
    String? senderName,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    String? mediaUrl,
    String? mediaName,
    int? mediaSize,
    String? thumbnailUrl,
    String? replyToMessageId,
    bool? isEdited,
    bool? isDeleted,
    bool? isRead,
    MessageStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderEmail: senderEmail ?? this.senderEmail,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaName: mediaName ?? this.mediaName,
      mediaSize: mediaSize ?? this.mediaSize,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, senderId: $senderId, type: $type, content: $content)';
  }
}
