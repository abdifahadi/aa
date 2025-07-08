import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class ChatList extends StatefulWidget {
  final List<ChatModel> chats;
  final UserModel currentUser;
  final Function(ChatModel) onChatSelected;
  final FirebaseService? firebaseService;
  final bool isSearching;
  final String searchQuery;

  const ChatList({
    Key? key,
    required this.chats,
    required this.currentUser,
    required this.onChatSelected,
    this.firebaseService,
    this.isSearching = false,
    this.searchQuery = '',
  }) : super(key: key);

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  // User cache to avoid repeated database calls
  final Map<String, UserModel> _userCache = {};

  @override
  Widget build(BuildContext context) {
    if (widget.chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isSearching
                  ? 'কোনো চ্যাট পাওয়া যায়নি "${widget.searchQuery}"'
                  : 'এখনও কোনো চ্যাট নেই',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (!widget.isSearching)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'নতুন চ্যাট শুরু করুন!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.chats.length,
      itemBuilder: (context, index) {
        final chat = widget.chats[index];
        final otherUserId = chat.participants.firstWhere(
          (id) => id != widget.currentUser.uid,
          orElse: () => '',
        );

        // If we don't have firebaseService, use the chat's participant data directly
        if (widget.firebaseService == null) {
          return _buildChatTile(
              chat,
              UserModel(
                uid: otherUserId,
                email: '',
                name: chat.getOtherParticipantName(widget.currentUser.uid),
                photoUrl: chat.getOtherParticipantPhoto(widget.currentUser.uid),
                createdAt: DateTime.now(),
              ));
        }

        return FutureBuilder<UserModel?>(
          future: _getCachedUser(otherUserId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text('লোড হচ্ছে...'),
              );
            }

            final otherUser = snapshot.data!;
            return _buildChatTile(chat, otherUser);
          },
        );
      },
    );
  }

  Widget _buildChatTile(ChatModel chat, UserModel otherUser) {
    final hasUnread = chat.lastMessageText != null &&
        chat.lastMessageSenderId != widget.currentUser.uid;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            otherUser.photoUrl != null && otherUser.photoUrl!.isNotEmpty
                ? NetworkImage(otherUser.photoUrl!)
                : null,
        child: otherUser.photoUrl == null || otherUser.photoUrl!.isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(
        otherUser.name,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: chat.lastMessageText != null
          ? Text(
              chat.lastMessageText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (chat.lastMessageAt != null)
            Text(
              _formatTime(chat.lastMessageAt!),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          const SizedBox(height: 4),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                "1",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      onTap: () => widget.onChatSelected(chat),
    );
  }

  // Get user from cache or fetch from database
  Future<UserModel?> _getCachedUser(String userId) async {
    // Return from cache if available
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    // Fetch from database and add to cache
    final user = await widget.firebaseService?.getUserById(userId);
    if (user != null) {
      _userCache[userId] = user;
    }
    return user;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'গতকাল';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
