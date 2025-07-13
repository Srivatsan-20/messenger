import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../chat/message_manager.dart';
import '../../contacts/contact_manager.dart';
import '../../models/message.dart';
import '../../models/contact.dart';
import '../widgets/conversation_tile.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        elevation: 0,
      ),
      body: Consumer2<MessageManager, ContactManager>(
        builder: (context, messageManager, contactManager, child) {
          final conversations = messageManager.getConversations();
          
          if (conversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start a conversation by adding a contact',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final contactId = conversations[index];
              final contact = contactManager.getContact(contactId);
              final lastMessage = messageManager.getLastMessage(contactId);
              
              if (contact == null) {
                return const SizedBox.shrink();
              }
              
              return ConversationTile(
                contact: contact,
                lastMessage: lastMessage,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(contact: contact),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
