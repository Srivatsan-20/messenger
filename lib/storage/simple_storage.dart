import '../models/user_identity.dart';
import '../models/contact.dart';
import '../models/message.dart';

/// Simple in-memory storage for testing - no database required
class SimpleStorage {
  static UserIdentity? _currentIdentity;
  static final List<Contact> _contacts = [];
  static final List<Message> _messages = [];
  static final Map<String, dynamic> _settings = {};

  // Initialize - no database needed
  static Future<void> initialize() async {
    print('🔧 DEBUG: Initializing simple in-memory storage');
    // Nothing to do - everything is in memory
    print('🔧 DEBUG: Simple storage initialized successfully');
  }

  // User Identity Management
  static Future<void> saveUserIdentity(UserIdentity identity) async {
    print('🔧 DEBUG: Saving user identity: ${identity.userId}');
    _currentIdentity = identity;
  }

  static UserIdentity? getCurrentUserIdentity() {
    print('🔧 DEBUG: Getting current identity: ${_currentIdentity?.userId}');
    return _currentIdentity;
  }

  static Future<void> deleteUserIdentity() async {
    print('🔧 DEBUG: Deleting user identity');
    _currentIdentity = null;
  }

  // Contact Management
  static Future<void> saveContact(Contact contact) async {
    print('🔧 DEBUG: Saving contact: ${contact.userId}');
    // Remove existing contact with same userId
    _contacts.removeWhere((c) => c.userId == contact.userId);
    _contacts.add(contact);
  }

  static List<Contact> getAllContacts() {
    print('🔧 DEBUG: Getting all contacts: ${_contacts.length}');
    return List.from(_contacts);
  }

  static Contact? getContact(String userId) {
    try {
      return _contacts.firstWhere((c) => c.userId == userId);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteContact(String userId) async {
    print('🔧 DEBUG: Deleting contact: $userId');
    _contacts.removeWhere((c) => c.userId == userId);
  }

  static Future<void> updateContact(Contact contact) async {
    print('🔧 DEBUG: Updating contact: ${contact.userId}');
    await deleteContact(contact.userId);
    await saveContact(contact);
  }

  // Message Management
  static Future<void> saveMessage(Message message) async {
    print('🔧 DEBUG: Saving message: ${message.id}');
    _messages.add(message);
  }

  static List<Message> getConversationMessages(String conversationId, {int? limit}) {
    print('🔧 DEBUG: Getting messages for conversation: $conversationId');
    var messages = _messages.where((m) => m.conversationId == conversationId).toList();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    if (limit != null && messages.length > limit) {
      messages = messages.take(limit).toList();
    }
    
    return messages;
  }

  static List<String> getAllConversations() {
    print('🔧 DEBUG: Getting all conversations');
    final conversations = <String>[];
    
    for (final message in _messages) {
      if (!conversations.contains(message.conversationId)) {
        conversations.add(message.conversationId);
      }
    }
    
    return conversations;
  }

  static Future<void> deleteMessage(String messageId) async {
    print('🔧 DEBUG: Deleting message: $messageId');
    _messages.removeWhere((m) => m.id == messageId);
  }

  static Future<void> deleteConversation(String conversationId) async {
    print('🔧 DEBUG: Deleting conversation: $conversationId');
    _messages.removeWhere((m) => m.conversationId == conversationId);
  }

  // Settings Management
  static Future<void> saveSetting(String key, dynamic value) async {
    print('🔧 DEBUG: Saving setting: $key');
    _settings[key] = value;
  }

  static T? getSetting<T>(String key) {
    return _settings[key] as T?;
  }

  static Future<void> deleteSetting(String key) async {
    print('🔧 DEBUG: Deleting setting: $key');
    _settings.remove(key);
  }

  // Clear all data
  static Future<void> clearAllData() async {
    print('🔧 DEBUG: Clearing all data');
    _currentIdentity = null;
    _contacts.clear();
    _messages.clear();
    _settings.clear();
  }

  // Get statistics
  static Map<String, int> getStats() {
    return {
      'contacts': _contacts.length,
      'messages': _messages.length,
      'conversations': getAllConversations().length,
      'settings': _settings.length,
    };
  }
}
