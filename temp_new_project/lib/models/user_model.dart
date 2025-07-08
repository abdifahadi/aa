import 'package:cloud_firestore/cloud_firestore.dart';

enum UserStatus {
  online,
  offline,
  busy,
  away
}

class UserModel {
  final String uid;
  final String email;
  final String name;
  final DateTime? dateOfBirth;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final UserStatus status;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.dateOfBirth,
    this.photoUrl,
    required this.createdAt,
    this.lastSeen,
    this.status = UserStatus.offline,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Convert string status to enum
    UserStatus userStatus = UserStatus.offline;
    if (data['status'] != null) {
      try {
        final status = data['status'].toString();
        userStatus = UserStatus.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == status.toLowerCase(),
          orElse: () => UserStatus.offline,
        );
      } catch (e) {
        print("Error parsing user status: $e");
        userStatus = UserStatus.offline;
      }
    }
    
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      photoUrl: data['photoUrl'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
      status: userStatus,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data) {
    // Convert string status to enum
    UserStatus userStatus = UserStatus.offline;
    if (data['status'] != null) {
      try {
        final status = data['status'].toString();
        userStatus = UserStatus.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == status.toLowerCase(),
          orElse: () => UserStatus.offline,
        );
      } catch (e) {
        print("Error parsing user status: $e");
        userStatus = UserStatus.offline;
      }
    }
    
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      photoUrl: data['photoUrl'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
      status: userStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'status': status.toString().split('.').last,
    };
  }
  
  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    DateTime? dateOfBirth,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastSeen,
    UserStatus? status,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
    );
  }
} 