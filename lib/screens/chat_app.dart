import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/status_service.dart';
import '../services/cloudinary_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_database.dart';
import '../utils/constants.dart';
import '../components/message_input.dart';
import 'call_handler.dart';
import 'chat/chat_list_screen.dart';
import 'incoming_call_screen.dart';

class ChatApp extends StatefulWidget {
  const ChatApp({Key? key}) : super(key: key);

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> with WidgetsBindingObserver {
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  // Services
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();
  final StatusService _statusService = StatusService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalDatabase _localDb = LocalDatabase();

  // UI state
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage = '';

  // User related data
  UserModel? _currentUser;

  // App state
  bool _isInitialized = false;
  bool _isAuthenticated = false;

  // Messaging state
  final List<MessageModel> _messages = [];
  final List<UserModel> _users = [];
  UserModel? _selectedUser;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  bool _isTyping = false;

  // Navigation state
  int _currentIndex = 0;
  bool _isSearchVisible = false;
  String _searchQuery = '';
  List<UserModel> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Chat state
  ChatModel? _selectedChat;
  UserModel? _selectedContact;
  AppScreen _currentScreen = AppScreen.signIn;
  final TextEditingController _nameController = TextEditingController();
  Timer? _typingTimer;

  // New state variable for checking cached user
  bool _isCheckingCachedUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print("--- ChatApp initState ---");

    // Initialize services
    _initializeLocalData();
    _initializeCloudinary();
    _notificationService.initialize();

    // Add listener to message controller to update send button state
    _messageController.addListener(() {
      setState(() {});
    });
  }

  // Initialize local data first, then try Firebase
  Future<void> _initializeLocalData() async {
    try {
      await _checkCachedUserAsync();
      await _checkCurrentUser();
    } catch (e) {
      print("Error initializing local data: $e");
    }
  }

  // Initialize Cloudinary
  Future<void> _initializeCloudinary() async {
    try {
      print("Cloudinary initialized");
    } catch (e) {
      print("Error initializing Cloudinary: $e");
    }
  }

  // Check cached user
  Future<void> _checkCachedUserAsync() async {
    setState(() {
      _isCheckingCachedUser = true;
    });

    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final localUser = await _localDb.getUserById(user.uid);
        if (localUser != null && mounted) {
          setState(() {
            _currentUser = localUser;
            _currentScreen = AppScreen.main;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error checking cached user: $e");
    } finally {
      setState(() {
        _isCheckingCachedUser = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _statusService.dispose();
    _notificationService.dispose();
    _messagesSubscription?.cancel();
    _userSubscription?.cancel();
    _typingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Updated to handle bottom navigation bar index change with animation
  void _onNavItemTapped(int index) {
    if (_currentIndex == index) {
      setState(() {});
      return;
    }

    setState(() {
      _currentIndex = index;
      _selectedChat = null;
      _selectedContact = null;
      _isSearchVisible = false;
      _searchController.clear();
      _searchQuery = '';
      _searchResults.clear();
    });
  }

  // Toggle search visibility
  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _searchController.clear();
        _searchQuery = '';
        _searchResults.clear();
      } else {
        if (_currentIndex == 0) {
          Future.delayed(const Duration(milliseconds: 100), () {
            FocusScope.of(context).requestFocus(_searchFocusNode);
          });
        }
      }
    });
  }

  Future<void> _checkCurrentUser() async {
    print("--- _checkCurrentUser started ---");

    if (_currentUser == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = _firebaseService.currentUser;
      print("--- Current user: ${user?.uid} ---");

      final isConnected = await _connectivityService.checkConnectivity();

      if (user != null) {
        if (isConnected) {
          try {
            final firebaseUser = await _firebaseService.getUserProfile(user.uid);
            if (firebaseUser != null) {
              print("--- User profile from Firebase: ${firebaseUser.name} ---");

              await _localDb.saveUser(firebaseUser);

              if (_currentUser == null ||
                  (_currentUser?.lastSeen == null ||
                      firebaseUser.lastSeen != null &&
                          firebaseUser.lastSeen!.isAfter(_currentUser!.lastSeen!))) {
                setState(() {
                  _currentUser = firebaseUser;
                });
              }
            }
          } catch (e) {
            print("Error getting user profile from Firebase: $e");
          }
        }

        if (_currentUser == null) {
          final localUser = await _localDb.getUserById(user.uid);
          if (localUser != null) {
            print("--- User profile from local DB: ${localUser.name} ---");
            setState(() {
              _currentUser = localUser;
            });
          }
        }
      }

      if (_currentUser != null) {
        if (isConnected) {
          try {
            await _firebaseService.initializeFirestore();
            await _checkUserProfile();
          } catch (e) {
            print("Error initializing Firestore: $e");
          }
        }

        setState(() {
          _isAuthenticated = true;
          _currentScreen = AppScreen.main;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isAuthenticated = false;
          _currentScreen = AppScreen.signIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error in _checkCurrentUser: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkUserProfile() async {
    print("Checking user profile...");
  }

  // Sign out functionality
  Future<void> _signOut() async {
    try {
      await _firebaseService.signOut();
      await _localDb.clearUserData();
      setState(() {
        _currentUser = null;
        _isAuthenticated = false;
        _currentScreen = AppScreen.signIn;
      });
    } catch (e) {
      print("Error signing out: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('সাইন আউট করতে সমস্যা হয়েছে: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'অনুগ্রহ করে সাইন ইন করুন',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Navigate to sign in screen or show sign in dialog
                  _showSignInOptions();
                },
                child: const Text('সাইন ইন'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showProfile();
                  break;
                case 'settings':
                  _showSettings();
                  break;
                case 'signout':
                  _signOut();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('প্রোফাইল'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('সেটিংস'),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Text('সাইন আউট'),
              ),
            ],
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'চ্যাট',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'যোগাযোগ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'কল',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'সেটিংস',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'চ্যাট';
      case 1:
        return 'যোগাযোগ';
      case 2:
        return 'কল';
      case 3:
        return 'সেটিংস';
      default:
        return 'চ্যাট অ্যাপ';
    }
  }

  Widget _buildCurrentScreen() {
    if (_currentUser == null) {
      return const Center(
        child: Text('ব্যবহারকারীর তথ্য লোড হচ্ছে...'),
      );
    }

    switch (_currentIndex) {
      case 0:
        return ChatListScreen(
          currentUser: _currentUser!,
          firebaseService: _firebaseService,
        );
      case 1:
        return _buildContactsScreen();
      case 2:
        return _buildCallsScreen();
      case 3:
        return _buildSettingsScreen();
      default:
        return ChatListScreen(
          currentUser: _currentUser!,
          firebaseService: _firebaseService,
        );
    }
  }

  Widget _buildContactsScreen() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: _currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('কোনো যোগাযোগ পাওয়া যায়নি'),
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
              trailing: IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () => _startChatWithUser(user),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCallsScreen() {
    return const Center(
      child: Text('কল ইতিহাস এখানে দেখানো হবে'),
    );
  }

  Widget _buildSettingsScreen() {
    return ListView(
      children: [
        if (_currentUser != null) ...[
          UserAccountsDrawerHeader(
            accountName: Text(_currentUser!.name),
            accountEmail: Text(_currentUser!.email),
            currentAccountPicture: CircleAvatar(
              backgroundImage: _currentUser!.photoUrl != null
                  ? NetworkImage(_currentUser!.photoUrl!)
                  : null,
              child: _currentUser!.photoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('প্রোফাইল'),
          onTap: _showProfile,
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('নোটিফিকেশন'),
          onTap: () {
            // Navigate to notification settings
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip),
          title: const Text('প্রাইভেসি'),
          onTap: () {
            // Navigate to privacy settings
          },
        ),
        ListTile(
          leading: const Icon(Icons.help),
          title: const Text('সাহায্য'),
          onTap: () {
            // Navigate to help screen
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('সাইন আউট', style: TextStyle(color: Colors.red)),
          onTap: _signOut,
        ),
      ],
    );
  }

  void _showSignInOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('সাইন ইন'),
        content: const Text('অনুগ্রহ করে সাইন ইন করুন'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement sign in logic
            },
            child: const Text('সাইন ইন'),
          ),
        ],
      ),
    );
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('প্রোফাইল'),
        content: _currentUser != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: _currentUser!.photoUrl != null
                        ? NetworkImage(_currentUser!.photoUrl!)
                        : null,
                    child: _currentUser!.photoUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUser!.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(_currentUser!.email),
                ],
              )
            : const Text('প্রোফাইল লোড হচ্ছে...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বন্ধ করুন'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    setState(() {
      _currentIndex = 3;
    });
  }

  void _startChatWithUser(UserModel user) async {
    try {
      final chatId = ChatModel.getChatId(_currentUser!.uid, user.uid);
      
      // Check if chat already exists
      final existingChat = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();

      ChatModel chat;
      if (existingChat.exists) {
        chat = ChatModel.fromFirestore(existingChat);
      } else {
        // Create new chat
        chat = ChatModel(
          id: chatId,
          participants: [_currentUser!.uid, user.uid],
          participantNames: {
            _currentUser!.uid: _currentUser!.name,
            user.uid: user.name,
          },
          participantPhotos: {
            _currentUser!.uid: _currentUser!.photoUrl ?? '',
            user.uid: user.photoUrl ?? '',
          },
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .set(chat.toMap());
      }

      // Navigate to chat list and then the chat will be available
      setState(() {
        _currentIndex = 0;
      });
    } catch (e) {
      print('Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('চ্যাট শুরু করতে সমস্যা হয়েছে')),
      );
    }
  }
}