import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../components/chat_list.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final UserModel currentUser;
  final FirebaseService firebaseService;

  const ChatListScreen({
    Key? key,
    required this.currentUser,
    required this.firebaseService,
  }) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ChatModel> _allChats = [];
  List<ChatModel> _filteredChats = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
      if (_isSearching) {
        _filteredChats = _allChats.where((chat) {
          final searchLower = _searchController.text.toLowerCase();
          final otherUserName = chat.getOtherParticipantName(widget.currentUser.uid).toLowerCase();
          final lastMessage = chat.lastMessageText?.toLowerCase() ?? '';
          return otherUserName.contains(searchLower) || lastMessage.contains(searchLower);
        }).toList();
      } else {
        _filteredChats = List.from(_allChats);
      }
    });
  }

  void _loadChats() {
    setState(() {
      _isLoading = true;
    });

    try {
      FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: widget.currentUser.uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        final chats = snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
        setState(() {
          _allChats = chats;
          _filteredChats = _isSearching ? _filteredChats : List.from(chats);
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error loading chats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onChatSelected(ChatModel chat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chat: chat,
          currentUser: widget.currentUser,
          firebaseService: widget.firebaseService,
        ),
      ),
    );
  }

  void _startNewChat() {
    // Show dialog to select user for new chat
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('নতুন চ্যাট'),
        content: const Text('নতুন চ্যাট শুরু করার জন্য একজন ব্যবহারকারী নির্বাচন করুন।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to user selection screen
              _showUserSelectionBottomSheet();
            },
            child: const Text('নির্বাচন করুন'),
          ),
        ],
      ),
    );
  }

  void _showUserSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'নতুন চ্যাট',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, isNotEqualTo: widget.currentUser.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('কোনো ব্যবহারকারী পাওয়া যায়নি'),
                    );
                  }

                  final users = snapshot.data!.docs
                      .map((doc) => UserModel.fromFirestore(doc))
                      .toList();

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.photoUrl != null
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: user.photoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        onTap: () {
                          Navigator.pop(context);
                          _createNewChat(user);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewChat(UserModel otherUser) async {
    try {
      final chatId = ChatModel.getChatId(widget.currentUser.uid, otherUser.uid);
      
      // Check if chat already exists
      final existingChat = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      if (existingChat.exists) {
        final chat = ChatModel.fromFirestore(existingChat);
        _onChatSelected(chat);
        return;
      }

      // Create new chat
      final newChat = ChatModel(
        id: chatId,
        participants: [widget.currentUser.uid, otherUser.uid],
        participantNames: {
          widget.currentUser.uid: widget.currentUser.name,
          otherUser.uid: otherUser.name,
        },
        participantPhotos: {
          widget.currentUser.uid: widget.currentUser.photoUrl ?? '',
          otherUser.uid: otherUser.photoUrl ?? '',
        },
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .set(newChat.toMap());

      _onChatSelected(newChat);
    } catch (e) {
      print('Error creating new chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('চ্যাট তৈরি করতে সমস্যা হয়েছে')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('চ্যাট'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredChats = List.from(_allChats);
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
            },
          ),
        ],
        bottom: _isSearching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'চ্যাট খুঁজুন...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                    ),
                    autofocus: true,
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ChatList(
              chats: _filteredChats,
              currentUser: widget.currentUser,
              onChatSelected: _onChatSelected,
              firebaseService: widget.firebaseService,
              isSearching: _isSearching,
              searchQuery: _searchController.text,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        child: const Icon(Icons.chat),
      ),
    );
  }
}