import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantPhotos;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final bool isGroup;
  final String? groupName;
  final String? groupPhotoUrl;
  final Map<String, bool> typingUsers; // Track which users are typing
  final int unreadCount;
  final bool isArchived;
  final bool isMuted;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    required this.participants,
    Map<String, String>? participantNames,
    Map<String, String>? participantPhotos,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.isGroup = false,
    this.groupName,
    this.groupPhotoUrl,
    Map<String, bool>? typingUsers,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isMuted = false,
    DateTime? updatedAt,
  }) : 
    participantNames = participantNames ?? {},
    participantPhotos = participantPhotos ?? {},
    typingUsers = typingUsers ?? {},
    updatedAt = updatedAt ?? DateTime.now();

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Convert participant names and photos maps
    Map<String, String> participantNames = {};
    if (data['participantNames'] != null) {
      (data['participantNames'] as Map<String, dynamic>).forEach((key, value) {
        participantNames[key] = value.toString();
      });
    }
    
    Map<String, String> participantPhotos = {};
    if (data['participantPhotos'] != null) {
      (data['participantPhotos'] as Map<String, dynamic>).forEach((key, value) {
        participantPhotos[key] = value.toString();
      });
    }
    
    // Convert typing users map
    Map<String, bool> typingUsers = {};
    if (data['typingUsers'] != null) {
      (data['typingUsers'] as Map<String, dynamic>).forEach((key, value) {
        typingUsers[key] = value as bool;
      });
    }
    
    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: participantNames,
      participantPhotos: participantPhotos,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      lastMessageText: data['lastMessageText'],
      lastMessageSenderId: data['lastMessageSenderId'],
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      groupPhotoUrl: data['groupPhotoUrl'],
      typingUsers: typingUsers,
      unreadCount: data['unreadCount'] ?? 0,
      isArchived: data['isArchived'] ?? false,
      isMuted: data['isMuted'] ?? false,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Create from Map (for local database)
  factory ChatModel.fromMap(Map<String, dynamic> data, String docId) {
    // Handle timestamps
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return DateTime.now();
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is DateTime) return timestamp;
      if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now();
    }

    return ChatModel(
      id: docId,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantPhotos: Map<String, String>.from(data['participantPhotos'] ?? {}),
      createdAt: parseTimestamp(data['createdAt']),
      lastMessageAt: data['lastMessageAt'] != null 
          ? parseTimestamp(data['lastMessageAt'])
          : null,
      lastMessageText: data['lastMessageText'],
      lastMessageSenderId: data['lastMessageSenderId'],
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      groupPhotoUrl: data['groupPhotoUrl'],
      typingUsers: Map<String, bool>.from(data['typingUsers'] ?? {}),
      unreadCount: data['unreadCount'] ?? 0,
      isArchived: data['isArchived'] ?? false,
      isMuted: data['isMuted'] ?? false,
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupPhotoUrl': groupPhotoUrl,
      'typingUsers': typingUsers,
      'unreadCount': unreadCount,
      'isArchived': isArchived,
      'isMuted': isMuted,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Helper method to generate a chat ID for two users
  static String getChatId(String uid1, String uid2) {
    // Sort UIDs to ensure consistent chat ID regardless of who initiates
    final sortedUids = [uid1, uid2]..sort();
    return '${sortedUids[0]}_${sortedUids[1]}';
  }
  
  // Get the name of the other participant in a one-to-one chat
  String getOtherParticipantName(String currentUserId) {
    if (isGroup) {
      return groupName ?? 'Group Chat';
    }
    
    for (final uid in participants) {
      if (uid != currentUserId) {
        return participantNames[uid] ?? 'User';
      }
    }
    
    return 'User';
  }
  
  // Get the photo URL of the other participant in a one-to-one chat
  String? getOtherParticipantPhoto(String currentUserId) {
    if (isGroup) {
      return groupPhotoUrl;
    }
    
    for (final uid in participants) {
      if (uid != currentUserId) {
        return participantPhotos[uid];
      }
    }
    
    return null;
  }
  
  // Get the ID of the other participant in a one-to-one chat
  String getOtherParticipantId(String currentUserId) {
    if (isGroup) {
      return ''; // Not applicable for group chats
    }
    
    for (final uid in participants) {
      if (uid != currentUserId) {
        return uid;
      }
    }
    
    return '';
  }
  
  // Check if any user is typing in this chat
  bool isAnyoneTyping(String currentUserId) {
    if (typingUsers.isEmpty) return false;
    
    // Check if any user other than current user is typing
    for (final entry in typingUsers.entries) {
      if (entry.key != currentUserId && entry.value == true) {
        return true;
      }
    }
    
    return false;
  }
  
  // Get list of users who are currently typing
  List<String> getTypingUsers(String currentUserId) {
    List<String> typingUserIds = [];
    
    typingUsers.forEach((userId, isTyping) {
      if (userId != currentUserId && isTyping) {
        typingUserIds.add(userId);
      }
    });
    
    return typingUserIds;
  }
  
  // Create a copy of this chat model with updated properties
  ChatModel copyWith({
    String? id,
    List<String>? participants,
    Map<String, String>? participantNames,
    Map<String, String>? participantPhotos,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessageText,
    String? lastMessageSenderId,
    bool? isGroup,
    String? groupName,
    String? groupPhotoUrl,
    Map<String, bool>? typingUsers,
    int? unreadCount,
    bool? isArchived,
    bool? isMuted,
    DateTime? updatedAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantNames: participantNames ?? this.participantNames,
      participantPhotos: participantPhotos ?? this.participantPhotos,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupPhotoUrl: groupPhotoUrl ?? this.groupPhotoUrl,
      typingUsers: typingUsers ?? this.typingUsers,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ChatModel(id: $id, participants: $participants)';
  }
} 