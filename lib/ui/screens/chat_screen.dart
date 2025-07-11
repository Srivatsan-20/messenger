import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contact.dart';
import '../../models/message.dart';
import '../../chat/message_manager.dart';
import '../../webrtc/webrtc_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends StatefulWidget {
  final Contact contact;
  
  const ChatScreen({super.key, required this.contact});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  
  List<Message> _messages = [];
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkConnection();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messageManager = context.read<MessageManager>();
      final conversationId = _getConversationId();
      
      final messages = messageManager.getConversationMessages(conversationId);
      
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      
      // Mark conversation as read
      await messageManager.markConversationAsRead(conversationId);
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateToBottom();
        }
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkConnection() {
    final webrtcManager = context.read<WebRTCManager>();
    setState(() {
      _isConnected = webrtcManager.isConnectedToPeer(widget.contact.userId);
    });
  }

  String _getConversationId() {
    // This should match the logic in MessageManager
    final users = [widget.contact.userId, 'myUserId']..sort(); // TODO: Get actual user ID
    return '${users[0]}_${users[1]}';
  }

  Future<void> _sendMessage(String content, {MessageType type = MessageType.text}) async {
    if (content.trim().isEmpty) return;
    
    try {
      final messageManager = context.read<MessageManager>();
      
      final success = await messageManager.sendTextMessage(
        widget.contact.userId,
        content.trim(),
      );
      
      if (success) {
        _messageController.clear();
        await _loadMessages(); // Refresh messages
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _sendMediaMessage(MessageType type) async {
    // TODO: Implement media message sending
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Media messages coming soon!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Contact avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                widget.contact.displayName.substring(0, 2).toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Contact info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  Row(
                    children: [
                      // Online status indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isConnected ? AppTheme.onlineColor : AppTheme.offlineColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      
                      const SizedBox(width: 6),
                      
                      Text(
                        _isConnected ? 'Connected' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Encryption indicator
                      AppTheme.encryptedIndicator(size: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              // TODO: Implement video call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video calls coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {
              // TODO: Implement voice call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice calls coming soon!')),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'contact_info':
                  // TODO: Navigate to contact info
                  break;
                case 'clear_chat':
                  _showClearChatDialog();
                  break;
                case 'block_contact':
                  _showBlockContactDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'contact_info',
                child: Text('Contact Info'),
              ),
              const PopupMenuItem(
                value: 'clear_chat',
                child: Text('Clear Chat'),
              ),
              const PopupMenuItem(
                value: 'block_contact',
                child: Text('Block Contact'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.errorColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 16,
                    color: AppTheme.errorColor,
                  ),
                  
                  const SizedBox(width: 8),
                  
                  Text(
                    'Not connected - messages will be sent when online',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ),
          
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final showDateHeader = index == 0 || 
                              !_isSameDay(_messages[index - 1].timestamp, message.timestamp);
                          
                          return Column(
                            children: [
                              if (showDateHeader)
                                _buildDateHeader(message.timestamp),
                              
                              MessageBubble(
                                message: message,
                                isFromMe: message.isFromMe,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          
          // Message input
          ChatInput(
            controller: _messageController,
            onSendMessage: _sendMessage,
            onSendMedia: _sendMediaMessage,
            enabled: true, // TODO: Check if contact is not blocked
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'No messages yet',
              style: AppTheme.subheadingStyle.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Send a message to start the conversation',
              style: AppTheme.captionStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        dateText,
        style: AppTheme.captionStyle.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to delete all messages in this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // TODO: Implement clear chat
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showBlockContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Contact'),
        content: Text('Are you sure you want to block ${widget.contact.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // TODO: Implement block contact
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}

extension ScrollControllerExtension on ScrollController {
  void animateToBottom() {
    if (hasClients) {
      animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}
