import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isFromMe;
  
  const MessageBubble({
    super.key,
    required this.message,
    required this.isFromMe,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            // Sender avatar for received messages
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                message.sender.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          // Message bubble
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: isFromMe
                    ? AppTheme.sentMessageDecoration(isDark)
                    : AppTheme.receivedMessageDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message content
                    _buildMessageContent(context, isDark),
                    
                    const SizedBox(height: 4),
                    
                    // Message metadata
                    _buildMessageMetadata(context, isDark),
                  ],
                ),
              ),
            ),
          ),
          
          if (isFromMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isDark) {
    switch (message.type) {
      case MessageType.text:
        return _buildTextContent(isDark);
      case MessageType.image:
        return _buildImageContent(context, isDark);
      case MessageType.video:
        return _buildVideoContent(context, isDark);
      case MessageType.file:
        return _buildFileContent(context, isDark);
      case MessageType.audio:
        return _buildAudioContent(context, isDark);
    }
  }

  Widget _buildTextContent(bool isDark) {
    // TODO: Decrypt message content
    final content = 'Encrypted message'; // Placeholder
    
    return Text(
      content,
      style: AppTheme.messageStyle.copyWith(
        color: isFromMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.image,
              size: 48,
              color: Colors.grey,
            ),
          ),
        ),
        
        if (message.mediaPath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Image • ${_formatFileSize(message.mediaSize ?? 0)}',
            style: AppTheme.captionStyle.copyWith(
              color: isFromMe ? Colors.white70 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoContent(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.videocam,
                size: 48,
                color: Colors.grey,
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Icon(
                  Icons.play_circle_filled,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        if (message.mediaPath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Video • ${_formatFileSize(message.mediaSize ?? 0)}',
            style: AppTheme.captionStyle.copyWith(
              color: isFromMe ? Colors.white70 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileContent(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isFromMe ? Colors.white : Colors.grey.shade100).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 32,
            color: isFromMe ? Colors.white70 : Colors.grey.shade600,
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Document', // TODO: Get actual filename
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isFromMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                
                Text(
                  _formatFileSize(message.mediaSize ?? 0),
                  style: AppTheme.captionStyle.copyWith(
                    color: isFromMe ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          Icon(
            Icons.download,
            size: 20,
            color: isFromMe ? Colors.white70 : Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioContent(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isFromMe ? Colors.white : Colors.grey.shade100).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.play_circle_filled,
            size: 32,
            color: isFromMe ? Colors.white70 : AppTheme.primaryColor,
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: (isFromMe ? Colors.white : AppTheme.primaryColor).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.3, // TODO: Actual progress
                    child: Container(
                      decoration: BoxDecoration(
                        color: isFromMe ? Colors.white : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  '0:15', // TODO: Actual duration
                  style: AppTheme.captionStyle.copyWith(
                    color: isFromMe ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageMetadata(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Timestamp
        Text(
          _formatTime(message.timestamp),
          style: AppTheme.timestampStyle.copyWith(
            color: isFromMe ? Colors.white70 : Colors.grey.shade500,
          ),
        ),
        
        if (isFromMe) ...[
          const SizedBox(width: 4),
          
          // Message status
          _buildStatusIcon(isDark),
        ],
        
        if (message.expiresAt != null) ...[
          const SizedBox(width: 4),
          
          // Expiration indicator
          Icon(
            Icons.timer,
            size: 12,
            color: isFromMe ? Colors.white70 : Colors.grey.shade500,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(bool isDark) {
    IconData icon;
    Color color = isFromMe ? Colors.white70 : Colors.grey.shade500;
    
    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = AppTheme.primaryColor;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = AppTheme.errorColor;
        break;
      case MessageStatus.expired:
        icon = Icons.timer_off;
        color = Colors.grey;
        break;
    }
    
    return Icon(
      icon,
      size: 12,
      color: color,
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.of(context).pop();
                _copyMessage(context);
              },
            ),
            
            if (message.type != MessageType.text)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Save'),
                onTap: () {
                  Navigator.of(context).pop();
                  _saveMedia(context);
                },
              ),
            
            if (isFromMe)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteMessage(context);
                },
              ),
            
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Info'),
              onTap: () {
                Navigator.of(context).pop();
                _showMessageInfo(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _copyMessage(BuildContext context) {
    // TODO: Decrypt and copy message content
    Clipboard.setData(const ClipboardData(text: 'Encrypted message'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied')),
    );
  }

  void _saveMedia(BuildContext context) {
    // TODO: Implement media saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Media saving coming soon!')),
    );
  }

  void _deleteMessage(BuildContext context) {
    // TODO: Implement message deletion
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message deletion coming soon!')),
    );
  }

  void _showMessageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Sent', _formatDateTime(message.timestamp)),
            if (message.deliveredAt != null)
              _buildInfoRow('Delivered', _formatDateTime(message.deliveredAt!)),
            if (message.readAt != null)
              _buildInfoRow('Read', _formatDateTime(message.readAt!)),
            if (message.expiresAt != null)
              _buildInfoRow('Expires', _formatDateTime(message.expiresAt!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${_formatTime(dateTime)}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
