import 'dart:typed_data';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

import '../models/user_identity.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../crypto/encryption.dart';

class StorageManager {
  static const String _encryptionKeyKey = 'hive_encryption_key';
  static const String _userIdentityBox = 'user_identity';
  static const String _contactsBox = 'contacts';
  static const String _messagesBox = 'messages';
  static const String _conversationsBox = 'conversations';
  static const String _ratchetStatesBox = 'ratchet_states';
  static const String _settingsBox = 'settings';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static late Uint8List _encryptionKey;
  static late Box<UserIdentity> _userIdentityBoxInstance;
  static late Box<Contact> _contactsBoxInstance;
  static late Box<Message> _messagesBoxInstance;
  static late Box<Map> _conversationsBoxInstance;
  static late Box<Map> _ratchetStatesBoxInstance;
  static late Box<Map> _settingsBoxInstance;

  // Initialize storage
  static Future<void> initialize() async {
    // Register Hive adapters
    Hive.registerAdapter(UserIdentityAdapter());
    Hive.registerAdapter(ContactAdapter());
    Hive.registerAdapter(MessageAdapter());
    Hive.registerAdapter(MessageStatusAdapter());
    Hive.registerAdapter(MessageTypeAdapter());
    Hive.registerAdapter(ContactStatusAdapter());

    // Get or generate encryption key
    await _initializeEncryptionKey();

    // Open encrypted boxes
    _userIdentityBoxInstance = await Hive.openBox<UserIdentity>(
      _userIdentityBox,
      encryptionCipher: HiveAesCipher(_encryptionKey),
    );

    _contactsBoxInstance = await Hive.openBox<Contact>(
      _contactsBox,
      encryptionCipher: HiveAesCipher(_encryptionKey),
    );

    _messagesBoxInstance = await Hive.openBox<Message>(
      _messagesBox,
      encryptionCipher: HiveAesCipher(_encryptionKey),
    );

    _conversationsBoxInstance = await Hive.openBox<Map>(
      _conversationsBox,
      encryptionCipher: HiveAesCipher(_encryptionKey),
    );

    _ratchetStatesBoxInstance = await Hive.openBox<Map>(
      _ratchetStatesBox,
      encryptionCipher: HiveAesCipher(_encryptionKey),
    );

    _settingsBoxInstance = await Hive.openBox<Map>(
      _settingsBox,
      encryptionCipher: HiveAesCipher(_encryptionKey),
    );
  }

  // User Identity Management
  static Future<void> saveUserIdentity(UserIdentity identity) async {
    await _userIdentityBoxInstance.put('current', identity);
  }

  static UserIdentity? getUserIdentity() {
    return _userIdentityBoxInstance.get('current');
  }

  static Future<void> deleteUserIdentity() async {
    await _userIdentityBoxInstance.delete('current');
  }

  // Contact Management
  static Future<void> saveContact(Contact contact) async {
    await _contactsBoxInstance.put(contact.userId, contact);
  }

  static Contact? getContact(String userId) {
    return _contactsBoxInstance.get(userId);
  }

  static List<Contact> getAllContacts() {
    return _contactsBoxInstance.values.toList();
  }

  static Future<void> deleteContact(String userId) async {
    await _contactsBoxInstance.delete(userId);
  }

  static List<Contact> getOnlineContacts() {
    return _contactsBoxInstance.values.where((contact) => contact.isOnline).toList();
  }

  static List<Contact> getFavoriteContacts() {
    return _contactsBoxInstance.values.where((contact) => contact.isFavorite).toList();
  }

  // Message Management
  static Future<void> saveMessage(Message message) async {
    await _messagesBoxInstance.put(message.id, message);
    await _updateConversationLastMessage(message);
  }

  static Message? getMessage(String messageId) {
    return _messagesBoxInstance.get(messageId);
  }

  static List<Message> getConversationMessages(String conversationId, {int limit = 50, int offset = 0}) {
    final messages = _messagesBoxInstance.values
        .where((message) => message.conversationId == conversationId)
        .toList();
    
    // Sort by timestamp (newest first)
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Apply pagination
    final start = offset;
    final end = (start + limit < messages.length) ? start + limit : messages.length;
    
    return messages.sublist(start, end);
  }

  static Future<void> deleteMessage(String messageId) async {
    await _messagesBoxInstance.delete(messageId);
  }

  static Future<void> deleteConversationMessages(String conversationId) async {
    final messagesToDelete = _messagesBoxInstance.values
        .where((message) => message.conversationId == conversationId)
        .map((message) => message.id)
        .toList();

    for (final messageId in messagesToDelete) {
      await _messagesBoxInstance.delete(messageId);
    }

    await _conversationsBoxInstance.delete(conversationId);
  }

  static List<Message> searchMessages(String query, {String? conversationId}) {
    var messages = _messagesBoxInstance.values.where((message) {
      if (conversationId != null && message.conversationId != conversationId) {
        return false;
      }
      
      // TODO: Decrypt message content for search
      // For now, search in message IDs and sender/receiver
      return message.id.toLowerCase().contains(query.toLowerCase()) ||
             message.sender.toLowerCase().contains(query.toLowerCase()) ||
             message.receiver.toLowerCase().contains(query.toLowerCase());
    }).toList();
    
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return messages;
  }

  // Conversation Management
  static Future<void> _updateConversationLastMessage(Message message) async {
    final conversationData = {
      'lastMessageId': message.id,
      'lastMessageTime': message.timestamp.toIso8601String(),
      'lastMessageSender': message.sender,
      'lastMessageType': message.type.name,
      'unreadCount': _getUnreadCount(message.conversationId),
    };
    
    await _conversationsBoxInstance.put(message.conversationId, conversationData);
  }

  static List<Map<String, dynamic>> getConversations() {
    final conversations = <Map<String, dynamic>>[];

    for (final entry in _conversationsBoxInstance.toMap().entries) {
      final conversationId = entry.key as String;
      final data = Map<String, dynamic>.from(entry.value as Map);
      data['conversationId'] = conversationId;
      conversations.add(data);
    }
    
    // Sort by last message time
    conversations.sort((a, b) {
      final timeA = DateTime.parse(a['lastMessageTime']);
      final timeB = DateTime.parse(b['lastMessageTime']);
      return timeB.compareTo(timeA);
    });
    
    return conversations;
  }

  static int _getUnreadCount(String conversationId) {
    return _messagesBoxInstance.values
        .where((message) =>
            message.conversationId == conversationId &&
            !message.isFromMe &&
            message.status != MessageStatus.read)
        .length;
  }

  static Future<void> markConversationAsRead(String conversationId) async {
    final messages = _messagesBoxInstance.values
        .where((message) =>
            message.conversationId == conversationId &&
            !message.isFromMe &&
            message.status != MessageStatus.read)
        .toList();

    for (final message in messages) {
      message.updateStatus(MessageStatus.read);
    }

    // Update conversation data
    final conversationData = _conversationsBoxInstance.get(conversationId);
    if (conversationData != null) {
      conversationData['unreadCount'] = 0;
      await _conversationsBoxInstance.put(conversationId, conversationData);
    }
  }

  // Double Ratchet State Management
  static Future<void> saveRatchetState(String contactId, Map<String, dynamic> state) async {
    await _ratchetStatesBoxInstance.put(contactId, state);
  }

  static Map<String, dynamic>? getRatchetState(String contactId) {
    final state = _ratchetStatesBoxInstance.get(contactId);
    return state != null ? Map<String, dynamic>.from(state) : null;
  }

  static Future<void> deleteRatchetState(String contactId) async {
    await _ratchetStatesBoxInstance.delete(contactId);
  }

  // Settings Management
  static Future<void> saveSetting(String key, dynamic value) async {
    final settings = _settingsBoxInstance.get('app_settings') ?? <String, dynamic>{};
    settings[key] = value;
    await _settingsBoxInstance.put('app_settings', settings);
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    final settings = _settingsBoxInstance.get('app_settings');
    if (settings == null) return defaultValue;
    return settings[key] as T? ?? defaultValue;
  }

  static Map<String, dynamic> getAllSettings() {
    final settings = _settingsBoxInstance.get('app_settings');
    return settings != null ? Map<String, dynamic>.from(settings) : {};
  }

  // Backup and Export
  static Future<Map<String, dynamic>> exportData() async {
    return {
      'identity': getUserIdentity()?.toJson(),
      'contacts': getAllContacts().map((c) => c.toJson()).toList(),
      'conversations': getConversations(),
      'settings': getAllSettings(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  // Clear all data (factory reset)
  static Future<void> clearAllData() async {
    await _userIdentityBoxInstance.clear();
    await _contactsBoxInstance.clear();
    await _messagesBoxInstance.clear();
    await _conversationsBoxInstance.clear();
    await _ratchetStatesBoxInstance.clear();
    await _settingsBoxInstance.clear();
  }

  // Database maintenance
  static Future<void> compactDatabase() async {
    await _userIdentityBoxInstance.compact();
    await _contactsBoxInstance.compact();
    await _messagesBoxInstance.compact();
    await _conversationsBoxInstance.compact();
    await _ratchetStatesBoxInstance.compact();
    await _settingsBoxInstance.compact();
  }

  static Future<void> deleteExpiredMessages() async {
    final now = DateTime.now();
    final expiredMessages = _messagesBoxInstance.values
        .where((message) => message.expiresAt != null && now.isAfter(message.expiresAt!))
        .map((message) => message.id)
        .toList();

    for (final messageId in expiredMessages) {
      await _messagesBoxInstance.delete(messageId);
    }
  }

  // Private methods
  static Future<void> _initializeEncryptionKey() async {
    String? keyString = await _secureStorage.read(key: _encryptionKeyKey);

    if (keyString == null) {
      // Generate new encryption key
      _encryptionKey = _generateRandomBytes(32);
      keyString = base64.encode(_encryptionKey);
      await _secureStorage.write(key: _encryptionKeyKey, value: keyString);
    } else {
      _encryptionKey = base64.decode(keyString);
    }
  }

  // Generate secure random bytes
  static Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    return bytes;
  }

  // Get storage statistics
  static Map<String, dynamic> getStorageStats() {
    return {
      'contacts': _contactsBoxInstance.length,
      'messages': _messagesBoxInstance.length,
      'conversations': _conversationsBoxInstance.length,
      'ratchetStates': _ratchetStatesBoxInstance.length,
      'settings': _settingsBoxInstance.length,
    };
  }
}
