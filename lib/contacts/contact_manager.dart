import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/contact.dart';
import '../models/user_identity.dart';
import '../storage/simple_storage.dart';
import '../auth/identity_manager.dart';
import '../crypto/double_ratchet.dart';

class ContactManager extends ChangeNotifier {
  final IdentityManager _identityManager;
  
  List<Contact> _contacts = [];
  List<Contact> _onlineContacts = [];
  
  ContactManager(this._identityManager) {
    _loadContacts();
  }

  List<Contact> get contacts => _contacts;
  List<Contact> get onlineContacts => _onlineContacts;
  List<Contact> get favoriteContacts => _contacts.where((c) => c.isFavorite).toList();
  List<Contact> get blockedContacts => _contacts.where((c) => c.isBlocked).toList();

  // Load contacts from storage
  Future<void> _loadContacts() async {
    _contacts = SimpleStorage.getAllContacts();
    _onlineContacts = []; // SimpleStorage doesn't track online status yet
    notifyListeners();
  }

  // Add contact from QR code or invite link
  Future<bool> addContactFromQR(String qrData) async {
    try {
      final identity = UserIdentity.fromQRData(qrData);
      if (identity == null) {
        debugPrint('Invalid QR code format');
        return false;
      }

      // Check if contact already exists
      if (_contacts.any((c) => c.userId == identity.userId)) {
        debugPrint('Contact already exists');
        return false;
      }

      // Check if it's not our own identity
      if (_identityManager.currentIdentity?.userId == identity.userId) {
        debugPrint('Cannot add yourself as contact');
        return false;
      }

      // Create contact
      final contact = Contact.fromUserIdentity(identity);
      
      // Save to storage
      await SimpleStorage.saveContact(contact);
      
      // Add to local list
      _contacts.add(contact);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error adding contact from QR: $e');
      return false;
    }
  }

  // Add contact from public key bundle
  Future<bool> addContactFromBundle(Map<String, dynamic> bundle) async {
    try {
      final identity = UserIdentity(
        userId: bundle['userId'],
        publicKey: bundle['identityKey'],
        alias: bundle['alias'] ?? 'Unknown User',
        profilePicture: bundle['profilePicture'],
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      return await addContactFromQR(identity.toQRData());
    } catch (e) {
      debugPrint('Error adding contact from bundle: $e');
      return false;
    }
  }

  // Update contact
  Future<void> updateContact(Contact contact) async {
    await SimpleStorage.saveContact(contact);
    
    final index = _contacts.indexWhere((c) => c.userId == contact.userId);
    if (index != -1) {
      _contacts[index] = contact;
      notifyListeners();
    }
  }

  // Delete contact
  Future<void> deleteContact(String userId) async {
    await SimpleStorage.deleteContact(userId);
    await SimpleStorage.deleteConversation(_getConversationId(userId));
    // Note: SimpleStorage doesn't have ratchet states yet
    
    _contacts.removeWhere((c) => c.userId == userId);
    _onlineContacts.removeWhere((c) => c.userId == userId);
    notifyListeners();
  }

  // Block/unblock contact
  Future<void> setContactBlocked(String userId, bool blocked) async {
    final contact = getContact(userId);
    if (contact != null) {
      contact.setBlocked(blocked);
      await updateContact(contact);
    }
  }

  // Set contact as favorite
  Future<void> setContactFavorite(String userId, bool favorite) async {
    final contact = getContact(userId);
    if (contact != null) {
      contact.isFavorite = favorite;
      await updateContact(contact);
    }
  }

  // Update contact alias
  Future<void> updateContactAlias(String userId, String alias) async {
    final contact = getContact(userId);
    if (contact != null) {
      contact.customAlias = alias;
      await updateContact(contact);
    }
  }

  // Get contact by user ID
  Contact? getContact(String userId) {
    try {
      return _contacts.firstWhere((c) => c.userId == userId);
    } catch (e) {
      return null;
    }
  }

  // Update contact online status
  Future<void> updateContactOnlineStatus(String userId, bool isOnline) async {
    final contact = getContact(userId);
    if (contact != null) {
      contact.updateOnlineStatus(isOnline);
      await updateContact(contact);
      
      if (isOnline && !_onlineContacts.any((c) => c.userId == userId)) {
        _onlineContacts.add(contact);
      } else if (!isOnline) {
        _onlineContacts.removeWhere((c) => c.userId == userId);
      }
      
      notifyListeners();
    }
  }

  // Search contacts
  List<Contact> searchContacts(String query) {
    if (query.isEmpty) return _contacts;
    
    final lowercaseQuery = query.toLowerCase();
    return _contacts.where((contact) {
      return contact.displayName.toLowerCase().contains(lowercaseQuery) ||
             contact.userId.toLowerCase().contains(lowercaseQuery) ||
             contact.alias.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Get conversation ID for contact
  String _getConversationId(String contactUserId) {
    final myUserId = _identityManager.currentIdentity?.userId ?? '';
    final users = [myUserId, contactUserId]..sort();
    return '${users[0]}_${users[1]}';
  }

  // Share contact via QR code
  String generateContactQR(String userId) {
    final contact = getContact(userId);
    if (contact == null) return '';
    
    return contact.toUserIdentity().toQRData();
  }

  // Share own identity
  String generateMyQR() {
    final identity = _identityManager.currentIdentity;
    if (identity == null) return '';
    
    return identity.toQRData();
  }

  // Share invite link
  Future<void> shareInviteLink() async {
    final identity = _identityManager.currentIdentity;
    if (identity == null) return;
    
    final inviteLink = identity.toQRData();
    await Share.share(
      'Join me on Oodaa Messenger: $inviteLink',
      subject: 'Oodaa Messenger Invite',
    );
  }

  // Handle deep link
  Future<bool> handleInviteLink(String link) async {
    try {
      final uri = Uri.parse(link);
      if (uri.scheme == 'oodaa' && uri.host == 'connect') {
        return await addContactFromQR(link);
      }
      return false;
    } catch (e) {
      debugPrint('Error handling invite link: $e');
      return false;
    }
  }

  // Export contacts
  Future<String> exportContacts() async {
    final contactsData = _contacts.map((c) => c.toJson()).toList();
    return jsonEncode({
      'contacts': contactsData,
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    });
  }

  // Import contacts
  Future<int> importContacts(String jsonData) async {
    try {
      final data = jsonDecode(jsonData);
      final contactsList = data['contacts'] as List;
      
      int importedCount = 0;
      for (final contactData in contactsList) {
        try {
          final contact = Contact(
            userId: contactData['userId'],
            publicKey: contactData['publicKey'],
            alias: contactData['alias'],
            profilePicture: contactData['profilePicture'],
            addedAt: DateTime.parse(contactData['addedAt']),
            lastSeen: DateTime.parse(contactData['lastSeen']),
            customAlias: contactData['customAlias'],
            isFavorite: contactData['isFavorite'] ?? false,
          );
          
          // Check if contact already exists
          if (!_contacts.any((c) => c.userId == contact.userId)) {
            await SimpleStorage.saveContact(contact);
            _contacts.add(contact);
            importedCount++;
          }
        } catch (e) {
          debugPrint('Error importing contact: $e');
        }
      }
      
      notifyListeners();
      return importedCount;
    } catch (e) {
      debugPrint('Error importing contacts: $e');
      return 0;
    }
  }

  // Get contact statistics
  Map<String, int> getContactStats() {
    return {
      'total': _contacts.length,
      'online': _onlineContacts.length,
      'favorites': favoriteContacts.length,
      'blocked': blockedContacts.length,
    };
  }

  // Perform key exchange with contact
  Future<bool> performKeyExchange(String contactUserId) async {
    final contact = getContact(contactUserId);
    if (contact == null) return false;
    
    try {
      // Get contact's public key bundle
      final contactBundle = {
        'userId': contact.userId,
        'identityKey': contact.publicKey,
        // TODO: Get actual X3DH bundle from contact
        'signedPreKey': contact.publicKey, // Placeholder
        'signedPreKeySignature': '', // Placeholder
        'oneTimePreKeys': [], // Placeholder
      };
      
      // Perform X3DH key exchange
      final result = await _identityManager.performKeyExchange(contactBundle);
      if (result == null) return false;
      
      // Initialize Double Ratchet
      final ratchet = DoubleRatchet(rootKey: result['sharedSecret']);
      
      // Save ratchet state (simplified for now)
      await SimpleStorage.saveSetting('ratchet_$contactUserId', ratchet.serialize());
      
      // Update contact status
      contact.status = ContactStatus.connected;
      await updateContact(contact);
      
      return true;
    } catch (e) {
      debugPrint('Error performing key exchange: $e');
      return false;
    }
  }

  // Refresh contacts (reload from storage)
  Future<void> refreshContacts() async {
    await _loadContacts();
  }

  // Clean up offline contacts
  Future<void> cleanupOfflineContacts() async {
    final now = DateTime.now();
    final offlineThreshold = now.subtract(const Duration(days: 30));
    
    final contactsToUpdate = _contacts.where((contact) => 
      contact.isOnline && contact.lastSeen.isBefore(offlineThreshold)
    ).toList();
    
    for (final contact in contactsToUpdate) {
      contact.updateOnlineStatus(false);
      await updateContact(contact);
    }
    
    _onlineContacts.removeWhere((contact) => 
      contact.lastSeen.isBefore(offlineThreshold)
    );
    
    notifyListeners();
  }
}
