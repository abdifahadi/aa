import 'package:cloud_firestore/cloud_firestore.dart';

// Call types
enum CallType { audio, video }

// Call status
enum CallStatus {
  dialing, // Initial state when call is being placed
  ringing, // Call is ringing on receiver's device
  accepted, // Call has been accepted by receiver
  ongoing, // Call is connected and active
  ended, // Call has been ended normally
  missed, // Call was not answered
  rejected, // Call was rejected by receiver
  failed // Call failed due to technical issues
}

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String callerPhotoUrl;
  final String receiverId;
  final String receiverName;
  final String receiverPhotoUrl;
  final CallStatus status;
  final CallType type;
  final DateTime createdAt;
  final String channelId;
  final String? token;
  final List<String> participants;
  final int numericUid;
  final DateTime? endedAt;
  final bool? receiverAnswered;
  final Map<String, dynamic>? metadata;

  CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.callerPhotoUrl,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhotoUrl,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.channelId,
    this.token,
    required this.participants,
    required this.numericUid,
    this.endedAt,
    this.receiverAnswered,
    this.metadata,
  });

  // Convert CallModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhotoUrl': receiverPhotoUrl,
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'createdAt': createdAt,
      'channelId': channelId,
      'token': token,
      'participants': participants,
      'numericUid': numericUid,
      'endedAt': endedAt,
      'receiverAnswered': receiverAnswered ?? false,
      'metadata': metadata ?? {},
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Alias for toMap for better naming convention
  Map<String, dynamic> toJson() => toMap();

  // Create CallModel from Firestore document
  factory CallModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CallModel.fromMap(data, doc.id);
  }

  // Create CallModel from Firestore document
  factory CallModel.fromMap(Map<String, dynamic> map, String docId) {
    // Parse status string to enum
    CallStatus parseStatus(String statusStr) {
      switch (statusStr) {
        case 'dialing':
          return CallStatus.dialing;
        case 'ringing':
          return CallStatus.ringing;
        case 'accepted':
          return CallStatus.accepted;
        case 'ongoing':
          return CallStatus.ongoing;
        case 'ended':
          return CallStatus.ended;
        case 'missed':
          return CallStatus.missed;
        case 'rejected':
          return CallStatus.rejected;
        case 'failed':
          return CallStatus.failed;
        default:
          return CallStatus.ended; // Default to ended if unknown
      }
    }

    // Parse call type string to enum
    CallType parseType(String typeStr) {
      return typeStr == 'video' ? CallType.video : CallType.audio;
    }

    // Handle timestamps that might be null or different types
    DateTime? parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return null;
      if (timestamp is Timestamp) return timestamp.toDate();
      if (timestamp is DateTime) return timestamp;
      return null;
    }

    return CallModel(
      id: docId,
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? 'Unknown',
      callerPhotoUrl: map['callerPhotoUrl'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? 'Unknown',
      receiverPhotoUrl: map['receiverPhotoUrl'] ?? '',
      status: parseStatus(map['status'] ?? 'ended'),
      type: parseType(map['type'] ?? 'audio'),
      createdAt: parseTimestamp(map['createdAt']) ?? DateTime.now(),
      channelId: map['channelId'] ?? docId,
      token: map['token'],
      participants: List<String>.from(map['participants'] ?? []),
      numericUid: map['numericUid'] ?? 0,
      endedAt: parseTimestamp(map['endedAt']),
      receiverAnswered: map['receiverAnswered'] ?? false,
      metadata: map['metadata'],
    );
  }

  // Create a copy of CallModel with updated fields
  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerPhotoUrl,
    String? receiverId,
    String? receiverName,
    String? receiverPhotoUrl,
    CallStatus? status,
    CallType? type,
    DateTime? createdAt,
    String? channelId,
    String? token,
    List<String>? participants,
    int? numericUid,
    DateTime? endedAt,
    bool? receiverAnswered,
    Map<String, dynamic>? metadata,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhotoUrl: callerPhotoUrl ?? this.callerPhotoUrl,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhotoUrl: receiverPhotoUrl ?? this.receiverPhotoUrl,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      channelId: channelId ?? this.channelId,
      token: token ?? this.token,
      participants: participants ?? this.participants,
      numericUid: numericUid ?? this.numericUid,
      endedAt: endedAt ?? this.endedAt,
      receiverAnswered: receiverAnswered ?? this.receiverAnswered,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper method to check if this user is the caller
  bool isUserCaller(String userId) {
    return callerId == userId;
  }

  // Helper method to get the other participant's ID
  String getOtherParticipantId(String userId) {
    return isUserCaller(userId) ? receiverId : callerId;
  }

  // Helper method to get call duration if ended
  Duration? getCallDuration() {
    if (endedAt != null && status == CallStatus.ended) {
      return endedAt!.difference(createdAt);
    }
    return null;
  }

  // Helper method to get user-friendly status text
  String getStatusText() {
    switch (status) {
      case CallStatus.dialing:
        return 'Calling...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.accepted:
        return 'Call accepted';
      case CallStatus.ongoing:
        return 'On call';
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.missed:
        return 'Missed call';
      case CallStatus.rejected:
        return 'Call rejected';
      case CallStatus.failed:
        return 'Call failed';
    }
  }

  @override
  String toString() {
    return 'CallModel(id: $id, callerId: $callerId, receiverId: $receiverId, status: $status, type: $type)';
  }
}
