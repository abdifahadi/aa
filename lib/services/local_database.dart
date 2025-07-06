import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../models/call_model.dart';
import '../utils/constants.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _database;
  final Completer<Database> _dbCompleter = Completer<Database>();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (!_dbCompleter.isCompleted) {
      _database = await _initDatabase();
      _dbCompleter.complete(_database);
    }
    return _dbCompleter.future;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), AppConstants.localDatabaseName);
    
    return await openDatabase(
      path,
      version: AppConstants.localDatabaseVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE ${AppConstants.usersTable} (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        displayName TEXT NOT NULL,
        profileImageUrl TEXT,
        phoneNumber TEXT,
        bio TEXT,
        status INTEGER NOT NULL DEFAULT 0,
        isOnline INTEGER NOT NULL DEFAULT 0,
        lastSeen INTEGER,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Chats table
    await db.execute('''
      CREATE TABLE ${AppConstants.chatsTable} (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL DEFAULT 0,
        name TEXT,
        description TEXT,
        imageUrl TEXT,
        participantIds TEXT NOT NULL,
        createdBy TEXT NOT NULL,
        lastMessage TEXT,
        lastMessageTime INTEGER,
        lastMessageSenderId TEXT,
        unreadCount INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        isMuted INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        syncStatus INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (createdBy) REFERENCES ${AppConstants.usersTable} (id)
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE ${AppConstants.messagesTable} (
        id TEXT PRIMARY KEY,
        chatId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        content TEXT NOT NULL,
        mediaUrl TEXT,
        thumbnailUrl TEXT,
        metadata TEXT,
        replyToMessageId TEXT,
        isEdited INTEGER NOT NULL DEFAULT 0,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        isRead INTEGER NOT NULL DEFAULT 0,
        deliveryStatus INTEGER NOT NULL DEFAULT 0,
        timestamp INTEGER NOT NULL,
        editedAt INTEGER,
        syncStatus INTEGER NOT NULL DEFAULT 0,
        localPath TEXT,
        uploadProgress REAL DEFAULT 0,
        FOREIGN KEY (chatId) REFERENCES ${AppConstants.chatsTable} (id),
        FOREIGN KEY (senderId) REFERENCES ${AppConstants.usersTable} (id),
        FOREIGN KEY (replyToMessageId) REFERENCES ${AppConstants.messagesTable} (id)
      )
    ''');

    // Calls table
    await db.execute('''
      CREATE TABLE ${AppConstants.callsTable} (
        id TEXT PRIMARY KEY,
        callerId TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        startTime INTEGER,
        endTime INTEGER,
        duration INTEGER DEFAULT 0,
        quality INTEGER DEFAULT 0,
        channelName TEXT,
        agoraToken TEXT,
        isVideoEnabled INTEGER NOT NULL DEFAULT 1,
        isAudioEnabled INTEGER NOT NULL DEFAULT 1,
        createdAt INTEGER NOT NULL,
        syncStatus INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (callerId) REFERENCES ${AppConstants.usersTable} (id),
        FOREIGN KEY (receiverId) REFERENCES ${AppConstants.usersTable} (id)
      )
    ''');

    // Create indexes for better performance
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Message indexes
    await db.execute('CREATE INDEX idx_messages_chat_id ON ${AppConstants.messagesTable} (chatId)');
    await db.execute('CREATE INDEX idx_messages_sender_id ON ${AppConstants.messagesTable} (senderId)');
    await db.execute('CREATE INDEX idx_messages_timestamp ON ${AppConstants.messagesTable} (timestamp DESC)');
    await db.execute('CREATE INDEX idx_messages_sync_status ON ${AppConstants.messagesTable} (syncStatus)');
    
    // Chat indexes
    await db.execute('CREATE INDEX idx_chats_updated_at ON ${AppConstants.chatsTable} (updatedAt DESC)');
    await db.execute('CREATE INDEX idx_chats_sync_status ON ${AppConstants.chatsTable} (syncStatus)');
    
    // User indexes
    await db.execute('CREATE INDEX idx_users_email ON ${AppConstants.usersTable} (email)');
    await db.execute('CREATE INDEX idx_users_sync_status ON ${AppConstants.usersTable} (syncStatus)');
    
    // Call indexes
    await db.execute('CREATE INDEX idx_calls_caller_id ON ${AppConstants.callsTable} (callerId)');
    await db.execute('CREATE INDEX idx_calls_receiver_id ON ${AppConstants.callsTable} (receiverId)');
    await db.execute('CREATE INDEX idx_calls_created_at ON ${AppConstants.callsTable} (createdAt DESC)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add new columns or tables for version 2
    }
  }

  // User operations
  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert(
      AppConstants.usersTable,
      _userToMap(user),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<User?> getUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.usersTable,
      where: 'id = ?',
      whereArgs: [userId],
    );
    
    if (maps.isNotEmpty) {
      return _mapToUser(maps.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.usersTable,
      orderBy: 'displayName ASC',
    );
    
    return List.generate(maps.length, (i) => _mapToUser(maps[i]));
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update(
      AppConstants.usersTable,
      _userToMap(user),
      where: 'id = ?',
      whereArgs: [user.uid],
    );
  }

  // Chat operations
  Future<void> insertChat(Chat chat) async {
    final db = await database;
    await db.insert(
      AppConstants.chatsTable,
      _chatToMap(chat),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Chat?> getChat(String chatId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.chatsTable,
      where: 'id = ?',
      whereArgs: [chatId],
    );
    
    if (maps.isNotEmpty) {
      return _mapToChat(maps.first);
    }
    return null;
  }

  Future<List<Chat>> getAllChats() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.chatsTable,
      orderBy: 'updatedAt DESC',
      limit: AppConstants.chatListLoadLimit,
    );
    
    return List.generate(maps.length, (i) => _mapToChat(maps[i]));
  }

  Future<void> updateChat(Chat chat) async {
    final db = await database;
    await db.update(
      AppConstants.chatsTable,
      _chatToMap(chat),
      where: 'id = ?',
      whereArgs: [chat.id],
    );
  }

  // Message operations
  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert(
      AppConstants.messagesTable,
      _messageToMap(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String chatId, {int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.messagesTable,
      where: 'chatId = ? AND isDeleted = 0',
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
      limit: limit ?? AppConstants.messageLoadLimit,
      offset: offset ?? 0,
    );
    
    return List.generate(maps.length, (i) => _mapToMessage(maps[i]));
  }

  Future<Message?> getMessage(String messageId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.messagesTable,
      where: 'id = ?',
      whereArgs: [messageId],
    );
    
    if (maps.isNotEmpty) {
      return _mapToMessage(maps.first);
    }
    return null;
  }

  Future<void> updateMessage(Message message) async {
    final db = await database;
    await db.update(
      AppConstants.messagesTable,
      _messageToMap(message),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.update(
      AppConstants.messagesTable,
      {'isDeleted': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markMessageAsRead(String messageId) async {
    final db = await database;
    await db.update(
      AppConstants.messagesTable,
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markChatMessagesAsRead(String chatId, String userId) async {
    final db = await database;
    await db.update(
      AppConstants.messagesTable,
      {'isRead': 1},
      where: 'chatId = ? AND senderId != ?',
      whereArgs: [chatId, userId],
    );
  }

  // Call operations
  Future<void> insertCall(Call call) async {
    final db = await database;
    await db.insert(
      AppConstants.callsTable,
      _callToMap(call),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Call>> getCallHistory({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.callsTable,
      orderBy: 'createdAt DESC',
      limit: limit ?? 50,
    );
    
    return List.generate(maps.length, (i) => _mapToCall(maps[i]));
  }

  Future<void> updateCall(Call call) async {
    final db = await database;
    await db.update(
      AppConstants.callsTable,
      _callToMap(call),
      where: 'id = ?',
      whereArgs: [call.id],
    );
  }

  // Sync operations
  Future<List<Message>> getUnsyncedMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.messagesTable,
      where: 'syncStatus = 0',
      orderBy: 'timestamp ASC',
    );
    
    return List.generate(maps.length, (i) => _mapToMessage(maps[i]));
  }

  Future<void> markMessageAsSynced(String messageId) async {
    final db = await database;
    await db.update(
      AppConstants.messagesTable,
      {'syncStatus': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> getUnreadMessageCount(String chatId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.messagesTable} WHERE chatId = ? AND isRead = 0',
      [chatId],
    );
    return result.first['count'] as int;
  }

  // Utility methods
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete(AppConstants.messagesTable);
    await db.delete(AppConstants.chatsTable);
    await db.delete(AppConstants.usersTable);
    await db.delete(AppConstants.callsTable);
  }

  Future<void> clearOldMessages() async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    await db.delete(
      AppConstants.messagesTable,
      where: 'timestamp < ? AND syncStatus = 1',
      whereArgs: [cutoffTime],
    );
  }

  Future<void> optimizeDatabase() async {
    final db = await database;
    await db.execute('VACUUM');
    await db.execute('REINDEX');
  }

  Future<int> getDatabaseSize() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA page_count');
    final pageCount = result.first['page_count'] as int;
    final pageSizeResult = await db.rawQuery('PRAGMA page_size');
    final pageSize = pageSizeResult.first['page_size'] as int;
    return pageCount * pageSize;
  }

  // Mapping methods
  Map<String, dynamic> _userToMap(User user) {
    return {
      'id': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'profileImageUrl': user.profileImageUrl,
      'phoneNumber': user.phoneNumber,
      'bio': user.bio,
      'status': user.status.index,
      'isOnline': user.isOnline ? 1 : 0,
      'lastSeen': user.lastSeen?.millisecondsSinceEpoch,
      'createdAt': user.createdAt.millisecondsSinceEpoch,
      'updatedAt': user.updatedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'syncStatus': 1,
    };
  }

  User _mapToUser(Map<String, dynamic> map) {
    return User(
      uid: map['id'],
      email: map['email'],
      displayName: map['displayName'],
      profileImageUrl: map['profileImageUrl'],
      phoneNumber: map['phoneNumber'],
      bio: map['bio'],
      status: UserStatus.values[map['status']],
      isOnline: map['isOnline'] == 1,
      lastSeen: map['lastSeen'] != null ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen']) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> _chatToMap(Chat chat) {
    return {
      'id': chat.id,
      'type': chat.type.index,
      'name': chat.name,
      'description': chat.description,
      'imageUrl': chat.imageUrl,
      'participantIds': jsonEncode(chat.participantIds),
      'createdBy': chat.createdBy,
      'lastMessage': chat.lastMessage,
      'lastMessageTime': chat.lastMessageTime?.millisecondsSinceEpoch,
      'lastMessageSenderId': chat.lastMessageSenderId,
      'unreadCount': chat.unreadCount,
      'isArchived': chat.isArchived ? 1 : 0,
      'isMuted': chat.isMuted ? 1 : 0,
      'createdAt': chat.createdAt.millisecondsSinceEpoch,
      'updatedAt': chat.updatedAt.millisecondsSinceEpoch,
      'syncStatus': 1,
    };
  }

  Chat _mapToChat(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      type: ChatType.values[map['type']],
      name: map['name'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      participantIds: List<String>.from(jsonDecode(map['participantIds'])),
      createdBy: map['createdBy'],
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime']) 
          : null,
      lastMessageSenderId: map['lastMessageSenderId'],
      unreadCount: map['unreadCount'],
      isArchived: map['isArchived'] == 1,
      isMuted: map['isMuted'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
    );
  }

  Map<String, dynamic> _messageToMap(Message message) {
    return {
      'id': message.id,
      'chatId': message.chatId,
      'senderId': message.senderId,
      'type': message.type.index,
      'content': message.content,
      'mediaUrl': message.mediaUrl,
      'thumbnailUrl': message.thumbnailUrl,
      'metadata': message.metadata != null ? jsonEncode(message.metadata) : null,
      'replyToMessageId': message.replyToMessageId,
      'isEdited': message.isEdited ? 1 : 0,
      'isDeleted': message.isDeleted ? 1 : 0,
      'isRead': message.isRead ? 1 : 0,
      'deliveryStatus': message.deliveryStatus.index,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'editedAt': message.editedAt?.millisecondsSinceEpoch,
      'syncStatus': 0, // New messages start as unsynced
    };
  }

  Message _mapToMessage(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      chatId: map['chatId'],
      senderId: map['senderId'],
      type: MessageType.values[map['type']],
      content: map['content'],
      mediaUrl: map['mediaUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      metadata: map['metadata'] != null ? jsonDecode(map['metadata']) : null,
      replyToMessageId: map['replyToMessageId'],
      isEdited: map['isEdited'] == 1,
      isDeleted: map['isDeleted'] == 1,
      isRead: map['isRead'] == 1,
      deliveryStatus: DeliveryStatus.values[map['deliveryStatus']],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      editedAt: map['editedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['editedAt']) : null,
    );
  }

  Map<String, dynamic> _callToMap(Call call) {
    return {
      'id': call.id,
      'callerId': call.callerId,
      'receiverId': call.receiverId,
      'type': call.type.index,
      'status': call.status.index,
      'startTime': call.startTime?.millisecondsSinceEpoch,
      'endTime': call.endTime?.millisecondsSinceEpoch,
      'duration': call.duration,
      'quality': call.quality?.index,
      'channelName': call.channelName,
      'agoraToken': call.agoraToken,
      'isVideoEnabled': call.isVideoEnabled ? 1 : 0,
      'isAudioEnabled': call.isAudioEnabled ? 1 : 0,
      'createdAt': call.createdAt.millisecondsSinceEpoch,
      'syncStatus': 1,
    };
  }

  Call _mapToCall(Map<String, dynamic> map) {
    return Call(
      id: map['id'],
      callerId: map['callerId'],
      receiverId: map['receiverId'],
      type: CallType.values[map['type']],
      status: CallStatus.values[map['status']],
      startTime: map['startTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['startTime']) : null,
      endTime: map['endTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['endTime']) : null,
      duration: map['duration'],
      quality: map['quality'] != null ? CallQuality.values[map['quality']] : null,
      channelName: map['channelName'],
      agoraToken: map['agoraToken'],
      isVideoEnabled: map['isVideoEnabled'] == 1,
      isAudioEnabled: map['isAudioEnabled'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}