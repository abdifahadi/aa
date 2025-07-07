import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../services/firebase_service.dart';
import '../../services/call_service.dart';
import '../../widgets/chat_widgets.dart';
import '../call_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chat;
  final UserModel currentUser;
  final FirebaseService firebaseService;

  const ChatScreen({
    Key? key,
    required this.chat,
    required this.currentUser,
    required this.firebaseService,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  bool _isLoadingMore = false;
  UserModel? _otherUser;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadOtherUser();
    _messageController.addListener(_onTypingChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    if (isCurrentlyTyping != _isTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });
      _updateTypingStatus(isCurrentlyTyping);
    }
  }

  void _updateTypingStatus(bool isTyping) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chat.id)
          .update({
        'typingUsers.${widget.currentUser.uid}': isTyping,
      });
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  void _loadOtherUser() async {
    try {
      final otherUserId = widget.chat.getOtherParticipantId(widget.currentUser.uid);
      if (otherUserId.isNotEmpty) {
        final user = await widget.firebaseService.getUserById(otherUserId);
        setState(() {
          _otherUser = user;
        });
      }
    } catch (e) {
      print('Error loading other user: $e');
    }
  }

  void _loadMessages() {
    setState(() {
      _isLoading = true;
    });

    try {
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chat.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        final messages = snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();
        
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // Mark messages as read
        _markMessagesAsRead();
      });
    } catch (e) {
      print('Error loading messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _markMessagesAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      bool hasUnreadMessages = false;

      for (final message in _messages) {
        if (message.senderId != widget.currentUser.uid && !message.isRead) {
          hasUnreadMessages = true;
          final messageRef = FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chat.id)
              .collection('messages')
              .doc(message.id);
          
          batch.update(messageRef, {'isRead': true});
        }
      }

      if (hasUnreadMessages) {
        await batch.commit();
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _sendMessage({MessageType type = MessageType.text, String? mediaUrl, String? mediaName, int? mediaSize}) async {
    final content = type == MessageType.text 
        ? _messageController.text.trim() 
        : mediaUrl ?? '';
    
    if (content.isEmpty) return;

    final message = MessageModel(
      id: '', // Will be set by Firestore
      senderId: widget.currentUser.uid,
      senderEmail: widget.currentUser.email,
      senderName: widget.currentUser.name,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      mediaUrl: mediaUrl,
      mediaName: mediaName,
      mediaSize: mediaSize,
    );

    try {
      // Add message to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chat.id)
          .collection('messages')
          .add(message.toMap());

      // Update chat's last message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chat.id)
          .update({
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
        'lastMessageText': type == MessageType.text ? content : _getMessagePreview(type),
        'lastMessageSenderId': widget.currentUser.uid,
      });

      if (type == MessageType.text) {
        _messageController.clear();
      }
      
      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('মেসেজ পাঠাতে সমস্যা হয়েছে')),
      );
    }
  }

  String _getMessagePreview(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 ছবি';
      case MessageType.video:
        return '🎥 ভিডিও';
      case MessageType.document:
        return '📄 ডকুমেন্ট';
      default:
        return 'মেসেজ';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'মিডিয়া শেয়ার করুন',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMediaOption(
                  icon: Icons.camera_alt,
                  label: 'ক্যামেরা',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _buildMediaOption(
                  icon: Icons.photo_library,
                  label: 'গ্যালারি',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                _buildMediaOption(
                  icon: Icons.videocam,
                  label: 'ভিডিও',
                  onTap: () => _pickVideo(),
                ),
                _buildMediaOption(
                  icon: Icons.attach_file,
                  label: 'ফাইল',
                  onTap: () => _pickDocument(),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        _uploadMediaFile(file, MessageType.image);
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ছবি নির্বাচন করতে সমস্যা হয়েছে')),
      );
    }
  }

  void _pickVideo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        _uploadMediaFile(file, MessageType.video);
      }
    } catch (e) {
      print('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ভিডিও নির্বাচন করতে সমস্যা হয়েছে')),
      );
    }
  }

  void _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        _uploadMediaFile(file, MessageType.document);
      }
    } catch (e) {
      print('Error picking document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফাইল নির্বাচন করতে সমস্যা হয়েছে')),
      );
    }
  }

  void _uploadMediaFile(File file, MessageType type) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Upload file to Firebase Storage (if implemented)
      // For now, we'll just use a placeholder URL
      final fileName = file.path.split('/').last;
      final fileSize = await file.length();
      
      // In a real implementation, you would upload to Firebase Storage here
      final mediaUrl = 'placeholder_url_${DateTime.now().millisecondsSinceEpoch}';
      
      Navigator.pop(context); // Hide loading indicator
      
      _sendMessage(
        type: type,
        mediaUrl: mediaUrl,
        mediaName: fileName,
        mediaSize: fileSize,
      );
    } catch (e) {
      Navigator.pop(context); // Hide loading indicator
      print('Error uploading media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফাইল আপলোড করতে সমস্যা হয়েছে')),
      );
    }
  }

  void _makeVoiceCall() async {
    if (_otherUser != null) {
      try {
        // Import call service
        final callService = CallService();
        
        // Start audio call
        final call = await callService.startCall(
          receiverId: _otherUser!.uid,
          receiverName: _otherUser!.name,
          receiverPhotoUrl: _otherUser!.photoUrl ?? '',
          callType: CallType.audio,
        );
        
        if (call != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CallScreen(
                call: call,
                isIncoming: false,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('কল করতে সমস্যা হয়েছে')),
          );
        }
      } catch (e) {
        print('Error making voice call: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('কল করতে সমস্যা হয়েছে')),
        );
      }
    }
  }

  void _makeVideoCall() async {
    if (_otherUser != null) {
      try {
        // Import call service
        final callService = CallService();
        
        // Start video call
        final call = await callService.startCall(
          receiverId: _otherUser!.uid,
          receiverName: _otherUser!.name,
          receiverPhotoUrl: _otherUser!.photoUrl ?? '',
          callType: CallType.video,
        );
        
        if (call != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CallScreen(
                call: call,
                isIncoming: false,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('কল করতে সমস্যা হয়েছে')),
          );
        }
      } catch (e) {
        print('Error making video call: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('কল করতে সমস্যা হয়েছে')),
        );
      }
    }
  }

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_otherUser != null) ...[
              CircleAvatar(
                radius: 40,
                backgroundImage: _otherUser!.photoUrl != null
                    ? NetworkImage(_otherUser!.photoUrl!)
                    : null,
                child: _otherUser!.photoUrl == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                _otherUser!.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                _otherUser!.email,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
            ],
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('ব্লক করুন'),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('চ্যাট মুছুন'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ব্যবহারকারী ব্লক করুন'),
        content: const Text('আপনি কি এই ব্যবহারকারীকে ব্লক করতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement block functionality
            },
            child: const Text('ব্লক করুন'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('চ্যাট মুছুন'),
        content: const Text('আপনি কি এই চ্যাটটি মুছে ফেলতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বাতিল'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat();
            },
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
  }

  void _deleteChat() async {
    try {
      // Delete all messages in the chat
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chat.id)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document
      batch.delete(FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chat.id));

      await batch.commit();
      
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('চ্যাট মুছে ফেলা হয়েছে')),
      );
    } catch (e) {
      print('Error deleting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('চ্যাট মুছতে সমস্যা হয়েছে')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUserName = widget.chat.getOtherParticipantName(widget.currentUser.uid);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _otherUser?.photoUrl != null
                  ? NetworkImage(_otherUser!.photoUrl!)
                  : null,
              child: _otherUser?.photoUrl == null
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherUserName,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_otherUser != null)
                    Text(
                      _getStatusText(_otherUser!.status),
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _makeVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _makeVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '$otherUserName এর সাথে কথোপকথন শুরু করুন',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderId == widget.currentUser.uid;
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: _otherUser?.photoUrl != null
                                        ? NetworkImage(_otherUser!.photoUrl!)
                                        : null,
                                    child: _otherUser?.photoUrl == null
                                        ? const Icon(Icons.person, size: 16)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildMessageContent(message, isMe),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatTime(message.timestamp),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isMe
                                                    ? Colors.white70
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                message.isRead
                                                    ? Icons.done_all
                                                    : Icons.done,
                                                size: 16,
                                                color: message.isRead
                                                    ? Colors.blue
                                                    : Colors.white70,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: widget.currentUser.photoUrl != null
                                        ? NetworkImage(widget.currentUser.photoUrl!)
                                        : null,
                                    child: widget.currentUser.photoUrl == null
                                        ? const Icon(Icons.person, size: 16)
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _showMediaOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    decoration: InputDecoration(
                      hintText: 'মেসেজ লিখুন...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMe) {
    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 48),
              ),
            ),
            if (message.mediaName != null)
              Text(
                message.mediaName!,
                style: TextStyle(
                  fontSize: 12,
                  color: isMe ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
          ],
        );
      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_filled, size: 48),
              ),
            ),
            if (message.mediaName != null)
              Text(
                message.mediaName!,
                style: TextStyle(
                  fontSize: 12,
                  color: isMe ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
          ],
        );
      case MessageType.document:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isMe ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.mediaName ?? 'ডকুমেন্ট',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        );
      default:
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        );
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getStatusText(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return 'অনলাইন';
      case UserStatus.offline:
        return 'অফলাইন';
      case UserStatus.away:
        return 'দূরে';
      case UserStatus.busy:
        return 'ব্যস্ত';
      default:
        return 'অজানা';
    }
  }
}