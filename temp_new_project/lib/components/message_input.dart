import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/message_model.dart';
import '../services/cloudinary_service.dart';

class MessageInput extends StatefulWidget {
  final Function(MessageModel) onSendMessage;
  final String currentUserId;
  final String chatId;
  final String senderName;
  final String senderEmail;
  final bool isEnabled;

  const MessageInput({
    Key? key,
    required this.onSendMessage,
    required this.currentUserId,
    required this.chatId,
    required this.senderName,
    required this.senderEmail,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isTyping = false;
  bool _isUploading = false;
  
  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (_isTyping != hasText) {
      setState(() {
        _isTyping = hasText;
      });
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || !widget.isEnabled) return;

    _textController.clear();
    setState(() {
      _isTyping = false;
    });

    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: widget.currentUserId,
      senderEmail: widget.senderEmail,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isRead: false,
      senderName: widget.senderName,
    );

    widget.onSendMessage(message);
  }

  Future<void> _sendImageMessage() async {
    if (!widget.isEnabled || _isUploading) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        final imageFile = File(image.path);
        final imageUrl = await CloudinaryService.uploadImage(
          imageFile,
          folder: 'chat_images',
        );

        if (imageUrl != null) {
          final message = MessageModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: widget.currentUserId,
            senderEmail: widget.senderEmail,
            content: imageUrl,
            type: MessageType.image,
            timestamp: DateTime.now(),
            isRead: false,
            mediaUrl: imageUrl,
            senderName: widget.senderName,
          );

          widget.onSendMessage(message);
        } else {
          _showErrorSnackBar('Failed to upload image');
        }
      }
    } catch (e) {
      print('Error sending image: $e');
      _showErrorSnackBar('Error selecting image');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _sendCameraImage() async {
    if (!widget.isEnabled || _isUploading) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        final imageFile = File(image.path);
        final imageUrl = await CloudinaryService.uploadImage(
          imageFile,
          folder: 'chat_images',
        );

        if (imageUrl != null) {
          final message = MessageModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: widget.currentUserId,
            senderEmail: widget.senderEmail,
            content: imageUrl,
            type: MessageType.image,
            timestamp: DateTime.now(),
            isRead: false,
            mediaUrl: imageUrl,
            senderName: widget.senderName,
          );

          widget.onSendMessage(message);
        } else {
          _showErrorSnackBar('Failed to upload image');
        }
      }
    } catch (e) {
      print('Error taking photo: $e');
      _showErrorSnackBar('Error taking photo');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _sendVideoMessage() async {
    if (!widget.isEnabled || _isUploading) return;

    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        setState(() {
          _isUploading = true;
        });

        final videoFile = File(video.path);
        final videoUrl = await CloudinaryService.uploadVideo(
          videoFile,
          folder: 'chat_videos',
        );

        if (videoUrl != null) {
          final message = MessageModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: widget.currentUserId,
            senderEmail: widget.senderEmail,
            content: videoUrl,
            type: MessageType.video,
            timestamp: DateTime.now(),
            isRead: false,
            mediaUrl: videoUrl,
            senderName: widget.senderName,
          );

          widget.onSendMessage(message);
        } else {
          _showErrorSnackBar('Failed to upload video');
        }
      }
    } catch (e) {
      print('Error sending video: $e');
      _showErrorSnackBar('Error selecting video');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.pop(context);
                _sendImageMessage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _sendCameraImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.purple),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _sendVideoMessage();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            IconButton(
              icon: Icon(
                Icons.attach_file,
                color: widget.isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              onPressed: widget.isEnabled && !_isUploading 
                  ? _showAttachmentOptions 
                  : null,
            ),
            
            // Text input field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: widget.isEnabled && !_isUploading,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _isUploading 
                        ? 'Uploading...' 
                        : 'Type a message...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    border: InputBorder.none,
                    suffixIcon: _isUploading
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
            ),
            
            const SizedBox(width: 8.0),
            
            // Send button
            Container(
              decoration: BoxDecoration(
                color: _isTyping && widget.isEnabled 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                ),
                onPressed: _isTyping && widget.isEnabled && !_isUploading
                    ? _sendTextMessage
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}