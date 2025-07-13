import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/contact.dart';
import '../../models/message.dart';

class ConversationTile extends StatelessWidget {
  final Contact contact;
  final Message? lastMessage;
  final VoidCallback onTap;
  final int unreadCount;

  const ConversationTile({
    super.key,
    required this.contact,
    this.lastMessage,
    required this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary,
        child: Text(
          contact.alias.isNotEmpty ? contact.alias[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        contact.alias,
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: lastMessage != null
          ? Text(
              _getMessagePreview(lastMessage!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                color: unreadCount > 0 
                    ? theme.colorScheme.onSurface 
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            )
          : Text(
              'No messages yet',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessage != null)
            Text(
              _formatTime(lastMessage!.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  String _getMessagePreview(Message message) {
    switch (message.type) {
      case MessageType.text:
        return message.encryptedContent.length > 50
            ? '${message.encryptedContent.substring(0, 50)}...'
            : message.encryptedContent;
      case MessageType.image:
        return '📷 Image';
      case MessageType.file:
        return '📎 File';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.video:
        return '🎥 Video';
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      // Today - show time
      return DateFormat.Hm().format(timestamp);
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      return DateFormat.E().format(timestamp);
    } else {
      // Older - show date
      return DateFormat.MMMd().format(timestamp);
    }
  }
}
