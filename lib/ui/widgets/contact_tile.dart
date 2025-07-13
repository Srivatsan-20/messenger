import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/contact.dart';

class ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showLastSeen;

  const ContactTile({
    super.key,
    required this.contact,
    required this.onTap,
    this.onLongPress,
    this.showLastSeen = true,
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
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.publicKey.length > 20 
                ? '${contact.publicKey.substring(0, 20)}...'
                : contact.publicKey,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontFamily: 'monospace',
            ),
          ),
          if (showLastSeen && contact.lastSeen != null) ...[
            const SizedBox(height: 2),
            Text(
              'Last seen ${_formatLastSeen(contact.lastSeen!)}',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contact.status == ContactStatus.connected)
            Icon(
              Icons.verified,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          const SizedBox(width: 4),
          Icon(
            contact.isOnline ? Icons.circle : Icons.circle_outlined,
            size: 12,
            color: contact.isOnline ? Colors.green : Colors.grey,
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.MMMd().format(lastSeen);
    }
  }
}
