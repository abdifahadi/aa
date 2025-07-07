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
        uid TEXT NOT NULL,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        photoUrl TEXT,
        dateOfBirth INTEGER,
        status INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        lastSeen INTEGER,
        syncStatus INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Chats table
    await db.execute('''
      CREATE TABLE ${AppConstants.chatsTable} (
        id TEXT PRIMARY KEY,
        participants TEXT NOT NULL,
        participantNames TEXT NOT NULL,
        participantPhotos TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        lastMessageAt INTEGER,
        lastMessageText TEXT,
        lastMessageSenderId TEXT,
        syncStatus INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE ${AppConstants.messagesTable} (
        id TEXT PRIMARY KEY,
        senderId TEXT NOT NULL,
        senderEmail TEXT NOT NULL,
        senderName TEXT NOT NULL,
        content TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        timestamp INTEGER NOT NULL,
        mediaUrl TEXT,
        mediaName TEXT,
        mediaSize INTEGER,
        thumbnailUrl TEXT,
        replyToMessageId TEXT,
        isEdited INTEGER NOT NULL DEFAULT 0,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        isRead INTEGER NOT NULL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        syncStatus INTEGER NOT NULL DEFAULT 0,
        isPending INTEGER NOT NULL DEFAULT 0,
        retryCount INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Calls table
    await db.execute('''
      CREATE TABLE ${AppConstants.callsTable} (
        id TEXT PRIMARY KEY,
        callerId TEXT NOT NULL,
        callerName TEXT NOT NULL,
        callerPhotoUrl TEXT,
        receiverId TEXT NOT NULL,
        receiverName TEXT NOT NULL,
        receiverPhotoUrl TEXT,
        status INTEGER NOT NULL DEFAULT 0,
        type INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        channelId TEXT NOT NULL,
        token TEXT,
        participants TEXT NOT NULL,
        numericUid INTEGER NOT NULL,
        endedAt INTEGER,
        receiverAnswered INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        syncStatus INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes for better performance
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Message indexes
    await db.execute('CREATE INDEX idx_messages_sender_id ON ${AppConstants.messagesTable} (senderId)');
    await db.execute('CREATE INDEX idx_messages_timestamp ON ${AppConstants.messagesTable} (timestamp DESC)');
    await db.execute('CREATE INDEX idx_messages_sync_status ON ${AppConstants.messagesTable} (syncStatus)');
    
    // Chat indexes
    await db.execute('CREATE INDEX idx_chats_last_message ON ${AppConstants.chatsTable} (lastMessageAt DESC)');
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

  // User operations using UserModel
  Future<void> insertUser(UserModel user) async {
    final db = await database;
    await db.insert(
      AppConstants.usersTable,
      _userModelToMap(user),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.usersTable,
      where: 'uid = ?',
      whereArgs: [userId],
    );
    
    if (maps.isNotEmpty) {
      return _mapToUserModel(maps.first);
    }
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.usersTable,
      orderBy: 'name ASC',
    );
    
    return List.generate(maps.length, (i) => _mapToUserModel(maps[i]));
  }

  Future<void> updateUser(UserModel user) async {
    final db = await database;
    await db.update(
      AppConstants.usersTable,
      _userModelToMap(user),
      where: 'uid = ?',
      whereArgs: [user.uid],
    );
  }

  Future<void> deleteUser(String userId) async {
    final db = await database;
    await db.delete(
      AppConstants.usersTable,
      where: 'uid = ?',
      whereArgs: [userId],
    );
  }

  // Chat operations using ChatModel
  Future<void> insertChat(ChatModel chat) async {
    final db = await database;
    await db.insert(
      AppConstants.chatsTable,
      _chatToMap(chat),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ChatModel?> getChat(String chatId) async {
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

  Future<List<ChatModel>> getAllChats() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.chatsTable,
      orderBy: 'lastMessageAt DESC',
      limit: AppConstants.chatListLoadLimit,
    );
    
    return List.generate(maps.length, (i) => _mapToChat(maps[i]));
  }

  Future<void> updateChat(ChatModel chat) async {
    final db = await database;
    await db.update(
      AppConstants.chatsTable,
      _chatToMap(chat),
      where: 'id = ?',
      whereArgs: [chat.id],
    );
  }

  Future<void> deleteChat(String chatId) async {
    final db = await database;
    await db.delete(
      AppConstants.chatsTable,
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  // Message operations using MessageModel
  Future<void> insertMessage(MessageModel message) async {
    final db = await database;
    await db.insert(
      AppConstants.messagesTable,
      _messageToMap(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageModel>> getMessages(String chatId, {int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.messagesTable,
      where: 'senderId IN (SELECT participants FROM ${AppConstants.chatsTable} WHERE id = ?) AND isDeleted = 0',
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
      limit: limit ?? AppConstants.messageLoadLimit,
      offset: offset ?? 0,
    );
    
    return List.generate(maps.length, (i) => _mapToMessage(maps[i]));
  }

  Future<MessageModel?> getMessage(String messageId) async {
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

  Future<void> updateMessage(MessageModel message) async {
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
      where: 'senderId != ?',
      whereArgs: [userId],
    );
  }

  // Call operations using CallModel
  Future<void> insertCall(CallModel call) async {
    final db = await database;
    await db.insert(
      AppConstants.callsTable,
      _callToMap(call),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CallModel>> getCallHistory({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.callsTable,
      orderBy: 'createdAt DESC',
      limit: limit ?? 50,
    );
    
    return List.generate(maps.length, (i) => _mapToCallModel(maps[i]));
  }

  Future<void> updateCall(CallModel call) async {
    final db = await database;
    await db.update(
      AppConstants.callsTable,
      _callToMap(call),
      where: 'id = ?',
      whereArgs: [call.id],
    );
  }

  Future<void> deleteCall(String callId) async {
    final db = await database;
    await db.delete(
      AppConstants.callsTable,
      where: 'id = ?',
      whereArgs: [callId],
    );
  }

  // Sync operations
  Future<List<MessageModel>> getUnsyncedMessages() async {
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
      'SELECT COUNT(*) as count FROM ${AppConstants.messagesTable} WHERE isRead = 0',
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

  // Pending messages methods for offline sync
  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final db = await database;
    return await db.query(
      'pending_messages',
      where: 'status = ? OR status = ?',
      whereArgs: ['pending', 'error'],
      orderBy: 'created_at ASC',
    );
  }

  Future<String> savePendingMessage({
    required String chatId,
    required String senderId,
    required String senderEmail,
    required String senderName,
    required String content,
    required MessageType type,
    String? mediaUrl,
    String? mediaName,
    int? mediaSize,
    String? localFilePath,
    MessageStatus status = MessageStatus.sent,
  }) async {
    final db = await database;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Create pending_messages table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_messages (
        id TEXT PRIMARY KEY,
        chatId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        senderEmail TEXT NOT NULL,
        senderName TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        mediaUrl TEXT,
        mediaName TEXT,
        mediaSize INTEGER,
        localFilePath TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        retryCount INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    
    await db.insert('pending_messages', {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'content': content,
      'type': type.toString().split('.').last,
      'mediaUrl': mediaUrl,
      'mediaName': mediaName,
      'mediaSize': mediaSize,
      'localFilePath': localFilePath,
      'status': 'pending',
      'retryCount': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    
    return id;
  }

  Future<void> updatePendingMessageStatus(String messageId, String status) async {
    final db = await database;
    await db.update(
      'pending_messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> incrementRetryCount(String messageId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE pending_messages SET retryCount = retryCount + 1 WHERE id = ?',
      [messageId],
    );
  }

  Future<void> deletePendingMessage(String messageId) async {
    final db = await database;
    await db.delete(
      'pending_messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // Mapping methods for UserModel
  Map<String, dynamic> _userModelToMap(UserModel user) {
    return {
      'id': user.uid,
      'uid': user.uid,
      'email': user.email,
      'name': user.name,
      'photoUrl': user.photoUrl,
      'dateOfBirth': user.dateOfBirth?.millisecondsSinceEpoch,
      'status': user.status.index,
      'createdAt': user.createdAt.millisecondsSinceEpoch,
      'lastSeen': user.lastSeen?.millisecondsSinceEpoch,
      'syncStatus': 1,
    };
  }

  UserModel _mapToUserModel(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      name: map['name'],
      photoUrl: map['photoUrl'],
      dateOfBirth: map['dateOfBirth'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'])
          : null,
      status: UserStatus.values[map['status']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastSeen: map['lastSeen'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen'])
          : null,
    );
  }

  // Mapping methods for ChatModel
  Map<String, dynamic> _chatToMap(ChatModel chat) {
    return {
      'id': chat.id,
      'participants': jsonEncode(chat.participants),
      'participantNames': jsonEncode(chat.participantNames),
      'participantPhotos': jsonEncode(chat.participantPhotos),
      'createdAt': chat.createdAt.millisecondsSinceEpoch,
      'lastMessageAt': chat.lastMessageAt?.millisecondsSinceEpoch,
      'lastMessageText': chat.lastMessageText,
      'lastMessageSenderId': chat.lastMessageSenderId,
      'syncStatus': 1,
    };
  }

  ChatModel _mapToChat(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'],
      participants: List<String>.from(jsonDecode(map['participants'])),
      participantNames: Map<String, String>.from(jsonDecode(map['participantNames'])),
      participantPhotos: Map<String, String>.from(jsonDecode(map['participantPhotos'])),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      lastMessageAt: map['lastMessageAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageAt'])
          : null,
      lastMessageText: map['lastMessageText'],
      lastMessageSenderId: map['lastMessageSenderId'],
    );
  }

  // Mapping methods for MessageModel
  Map<String, dynamic> _messageToMap(MessageModel message) {
    return {
      'id': message.id,
      'senderId': message.senderId,
      'senderEmail': message.senderEmail,
      'senderName': message.senderName,
      'content': message.content,
      'type': message.type.index,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'mediaUrl': message.mediaUrl,
      'mediaName': message.mediaName,
      'mediaSize': message.mediaSize,
      'thumbnailUrl': message.thumbnailUrl,
      'replyToMessageId': message.replyToMessageId,
      'isEdited': message.isEdited ? 1 : 0,
      'isDeleted': message.isDeleted ? 1 : 0,
      'isRead': message.isRead ? 1 : 0,
      'status': message.status.index,
      'metadata': message.metadata != null ? jsonEncode(message.metadata) : null,
      'syncStatus': 0, // New messages start as unsynced
    };
  }

  MessageModel _mapToMessage(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      senderId: map['senderId'],
      senderEmail: map['senderEmail'],
      senderName: map['senderName'],
      content: map['content'],
      type: MessageType.values[map['type']],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      mediaUrl: map['mediaUrl'],
      mediaName: map['mediaName'],
      mediaSize: map['mediaSize'],
      thumbnailUrl: map['thumbnailUrl'],
      replyToMessageId: map['replyToMessageId'],
      isEdited: map['isEdited'] == 1,
      isDeleted: map['isDeleted'] == 1,
      isRead: map['isRead'] == 1,
      status: MessageStatus.values[map['status']],
      metadata: map['metadata'] != null ? jsonDecode(map['metadata']) : null,
    );
  }

  // Mapping methods for CallModel
  Map<String, dynamic> _callToMap(CallModel call) {
    return {
      'id': call.id,
      'callerId': call.callerId,
      'callerName': call.callerName,
      'callerPhotoUrl': call.callerPhotoUrl,
      'receiverId': call.receiverId,
      'receiverName': call.receiverName,
      'receiverPhotoUrl': call.receiverPhotoUrl,
      'status': call.status.index,
      'type': call.type.index,
      'createdAt': call.createdAt.millisecondsSinceEpoch,
      'channelId': call.channelId,
      'token': call.token,
      'participants': jsonEncode(call.participants),
      'numericUid': call.numericUid,
      'endedAt': call.endedAt?.millisecondsSinceEpoch,
      'receiverAnswered': call.receiverAnswered == true ? 1 : 0,
      'metadata': call.metadata != null ? jsonEncode(call.metadata) : null,
      'syncStatus': 1,
    };
  }

  CallModel _mapToCallModel(Map<String, dynamic> map) {
    return CallModel(
      id: map['id'],
      callerId: map['callerId'],
      callerName: map['callerName'],
      callerPhotoUrl: map['callerPhotoUrl'],
      receiverId: map['receiverId'],
      receiverName: map['receiverName'],
      receiverPhotoUrl: map['receiverPhotoUrl'],
      status: CallStatus.values[map['status']],
      type: CallType.values[map['type']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      channelId: map['channelId'],
      token: map['token'],
      participants: List<String>.from(jsonDecode(map['participants'])),
      numericUid: map['numericUid'],
      endedAt: map['endedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['endedAt'])
          : null,
      receiverAnswered: map['receiverAnswered'] == 1,
      metadata: map['metadata'] != null ? jsonDecode(map['metadata']) : null,
    );
  }

  // User operations for new methods
  Future<void> saveUser(UserModel user) async {
    await insertUser(user);
  }

  Future<UserModel?> getUserById(String userId) async {
    return await getUser(userId);
  }

  // Chat operations for new methods
  Future<void> saveChat(ChatModel chat) async {
    await insertChat(chat);
  }

  Future<ChatModel?> getChatById(String chatId) async {
    return await getChat(chatId);
  }

  // Message operations for new methods
  Future<void> saveMessage(MessageModel message) async {
    await insertMessage(message);
  }

  Future<MessageModel?> getMessageById(String messageId) async {
    return await getMessage(messageId);
  }

  Future<List<MessageModel>> getMessagesByChatId(String chatId) async {
    return await getMessages(chatId);
  }

  // Call operations for new methods
  Future<void> saveCall(CallModel call) async {
    await insertCall(call);
  }

  Future<CallModel?> getCallById(String callId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.callsTable,
      where: 'id = ?',
      whereArgs: [callId],
    );

    if (maps.isNotEmpty) {
      return _mapToCallModel(maps.first);
    }
    return null;
  }

  Future<List<CallModel>> getAllCalls() async {
    return await getCallHistory();
  }

  // Pending message operations for offline sync
  Future<void> savePendingMessage(MessageModel message) async {
    final messageMap = _messageToMap(message);
    messageMap['isPending'] = 1;
    final db = await database;
    await db.insert(
      AppConstants.messagesTable,
      messageMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageModel>> getPendingMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.messagesTable,
      where: 'isPending = 1',
    );
    return maps.map((map) => _mapToMessage(map)).toList();
  }
}