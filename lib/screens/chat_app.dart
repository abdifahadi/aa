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
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to continue'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchVisible)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          Expanded(
            child: _buildCurrentScreen(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildChatsScreen();
      case 1:
        return _buildContactsScreen();
      case 2:
        return _buildSettingsScreen();
      default:
        return _buildChatsScreen();
    }
  }

  Widget _buildChatsScreen() {
    return const Center(
      child: Text('Chats Screen'),
    );
  }

  Widget _buildContactsScreen() {
    return const Center(
      child: Text('Contacts Screen'),
    );
  }

  Widget _buildSettingsScreen() {
    return const Center(
      child: Text('Settings Screen'),
    );
  }
}