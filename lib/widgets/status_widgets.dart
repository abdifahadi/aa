import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// A simple widget that displays a colored dot representing a user's status
class StatusDot extends StatelessWidget {
  final UserStatus status;
  final double size;

  const StatusDot({
    Key? key,
    required this.status,
    this.size = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: getStatusColor(),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
    );
  }

  /// Returns the appropriate color for the current status
  Color getStatusColor() {
    switch (status) {
      case UserStatus.online:
        return Colors.green;
      case UserStatus.busy:
        return Colors.red;
      case UserStatus.away:
        return Colors.orange;
      case UserStatus.offline:
        return Colors.grey;
    }
  }
}

/// A widget that displays a typing indicator with the user's name
class TypingIndicator extends StatelessWidget {
  final String userName;

  const TypingIndicator({
    Key? key,
    required this.userName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          // Animated dots (simplified for now)
          const SizedBox(
            width: 40,
            child:
                Text('•••', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
          // Typing text
          Text(
            '$userName is typing...',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that allows the user to select their status
class StatusSelector extends StatelessWidget {
  final UserStatus currentStatus;
  final Function(UserStatus) onStatusChanged;

  const StatusSelector({
    Key? key,
    required this.currentStatus,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<UserStatus>(
      tooltip: 'Change Status',
      icon: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.person),
          Positioned(
            right: 0,
            bottom: 0,
            child: StatusDot(status: currentStatus, size: 8),
          ),
        ],
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<UserStatus>(
          value: UserStatus.online,
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.green, size: 14),
              SizedBox(width: 8),
              Text('Online'),
            ],
          ),
        ),
        const PopupMenuItem<UserStatus>(
          value: UserStatus.busy,
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.red, size: 14),
              SizedBox(width: 8),
              Text('Busy'),
            ],
          ),
        ),
        const PopupMenuItem<UserStatus>(
          value: UserStatus.away,
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.orange, size: 14),
              SizedBox(width: 8),
              Text('Away'),
            ],
          ),
        ),
        const PopupMenuItem<UserStatus>(
          value: UserStatus.offline,
          child: Row(
            children: [
              Icon(Icons.circle, color: Colors.grey, size: 14),
              SizedBox(width: 8),
              Text('Offline'),
            ],
          ),
        ),
      ],
      onSelected: onStatusChanged,
    );
  }
}
