import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  video,
  document,
}

enum MessageStatus {
  sent,
  delivered,
  seen,
}

class MessageModel {
  final String id;
  final String senderId;
  final String senderEmail;
  final String? senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? mediaUrl;
  final String? mediaName;
  final int? mediaSize;
  final bool isRead;
  final String? thumbnailUrl;
  final MessageStatus status;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.mediaUrl,
    this.mediaName,
    this.mediaSize,
    this.isRead = false,
    this.thumbnailUrl,
    this.status = MessageStatus.sent,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      senderName: data['senderName'],
      content: data['content'] ?? '',
      type: _getMessageType(data['type'] ?? 'text'),
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      mediaUrl: data['mediaUrl'],
      mediaName: data['mediaName'],
      mediaSize: data['mediaSize'],
      isRead: data['isRead'] ?? false,
      thumbnailUrl: data['thumbnailUrl'],
      status: _getMessageStatus(data['status'] ?? 'sent'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'content': content,
      'type': _getMessageTypeString(type),
      'timestamp': Timestamp.fromDate(timestamp),
      'mediaUrl': mediaUrl,
      'mediaName': mediaName,
      'mediaSize': mediaSize,
      'isRead': isRead,
      'thumbnailUrl': thumbnailUrl,
      'status': _getMessageStatusString(status),
    };
  }

  static MessageType _getMessageType(String type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'document':
        return MessageType.document;
      case 'text':
      default:
        return MessageType.text;
    }
  }

  static String _getMessageTypeString(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.document:
        return 'document';
      case MessageType.text:
      default:
        return 'text';
    }
  }

  static MessageStatus _getMessageStatus(String status) {
    switch (status) {
      case 'delivered':
        return MessageStatus.delivered;
      case 'seen':
        return MessageStatus.seen;
      case 'sent':
      default:
        return MessageStatus.sent;
    }
  }

  static String _getMessageStatusString(MessageStatus status) {
    switch (status) {
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.seen:
        return 'seen';
      case MessageStatus.sent:
      default:
        return 'sent';
    }
  }
}
