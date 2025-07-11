import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

import '../models/user_identity.dart';
import '../crypto/key_generator.dart';
import '../crypto/x3dh.dart';
import '../storage/storage_manager.dart';

class IdentityManager extends ChangeNotifier {
  static const String _identityKey = 'user_identity';
  static const String _privateKeyKey = 'private_key';
  static const String _signingPrivateKeyKey = 'signing_private_key';
  static const String _x3dhStateKey = 'x3dh_state';
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherForEncryption: KeyCipher.aes_cbc_pkcs7padding,
      storageCipherForEncryption: StorageCipher.aes_gcm_nopadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  UserIdentity? _currentIdentity;
  AsymmetricKeyPair<PublicKey, PrivateKey>? _identityKeyPair;
  AsymmetricKeyPair<PublicKey, PrivateKey>? _signingKeyPair;
  X3DHProtocol? _x3dhProtocol;

  UserIdentity? get currentIdentity => _currentIdentity;
  bool get hasIdentity => _currentIdentity != null;

  // Check if user has existing identity
  Future<bool> hasExistingIdentity() async {
    try {
      final identityData = await _secureStorage.read(key: _identityKey);
      return identityData != null;
    } catch (e) {
      debugPrint('Error checking existing identity: $e');
      return false;
    }
  }

  // Load existing identity
  Future<bool> loadIdentity() async {
    try {
      // Load identity data
      final identityData = await _secureStorage.read(key: _identityKey);
      if (identityData == null) return false;

      _currentIdentity = UserIdentity.fromJson(jsonDecode(identityData));

      // Load private keys
      await _loadPrivateKeys();

      // Load X3DH state
      await _loadX3DHState();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error loading identity: $e');
      return false;
    }
  }

  // Create new identity
  Future<UserIdentity> createIdentity({
    String? customAlias,
    String? profilePicturePath,
  }) async {
    try {
      // Generate unique user ID
      final userId = KeyGenerator.generateUserId();
      
      // Generate identity key pair
      _identityKeyPair = KeyGenerator.generateCurve25519KeyPair();
      
      // Generate signing key pair
      _signingKeyPair = KeyGenerator.generateEd25519KeyPair();
      
      // Create user identity
      _currentIdentity = UserIdentity(
        userId: userId,
        publicKey: base64.encode(
          KeyGenerator.publicKeyToBytes(_identityKeyPair!.publicKey)
        ),
        alias: customAlias ?? _generateDefaultAlias(userId),
        profilePicture: profilePicturePath,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      // Initialize X3DH protocol
      _x3dhProtocol = X3DHProtocol();

      // Save to secure storage
      await _saveIdentity();
      await _savePrivateKeys();
      await _saveX3DHState();

      // Save to local database
      await StorageManager.saveUserIdentity(_currentIdentity!);

      notifyListeners();
      return _currentIdentity!;
    } catch (e) {
      debugPrint('Error creating identity: $e');
      rethrow;
    }
  }

  // Update identity
  Future<void> updateIdentity({
    String? alias,
    String? profilePicturePath,
  }) async {
    if (_currentIdentity == null) return;

    _currentIdentity = UserIdentity(
      userId: _currentIdentity!.userId,
      publicKey: _currentIdentity!.publicKey,
      alias: alias ?? _currentIdentity!.alias,
      profilePicture: profilePicturePath ?? _currentIdentity!.profilePicture,
      createdAt: _currentIdentity!.createdAt,
      lastSeen: DateTime.now(),
    );

    await _saveIdentity();
    await StorageManager.saveUserIdentity(_currentIdentity!);
    notifyListeners();
  }

  // Get public key bundle for sharing
  Map<String, dynamic>? getPublicKeyBundle() {
    if (_x3dhProtocol == null) return null;
    
    final bundle = _x3dhProtocol!.getPublicKeyBundle();
    bundle['userId'] = _currentIdentity!.userId;
    bundle['alias'] = _currentIdentity!.alias;
    bundle['profilePicture'] = _currentIdentity!.profilePicture;
    
    return bundle;
  }

  // Perform X3DH key exchange as initiator
  Future<Map<String, dynamic>?> performKeyExchange(Map<String, dynamic> contactBundle) async {
    if (_x3dhProtocol == null) return null;
    
    try {
      return _x3dhProtocol!.performX3DHInitiator(contactBundle);
    } catch (e) {
      debugPrint('Error performing key exchange: $e');
      return null;
    }
  }

  // Perform X3DH key exchange as receiver
  Future<Uint8List?> receiveKeyExchange(
    String aliceIdentityKey,
    String aliceEphemeralKey,
    bool usedOneTimePreKey,
  ) async {
    if (_x3dhProtocol == null) return null;
    
    try {
      final sharedSecret = _x3dhProtocol!.performX3DHReceiver(
        aliceIdentityKey,
        aliceEphemeralKey,
        usedOneTimePreKey,
      );
      
      // Save updated X3DH state
      await _saveX3DHState();
      
      return sharedSecret;
    } catch (e) {
      debugPrint('Error receiving key exchange: $e');
      return null;
    }
  }

  // Generate backup phrase for identity
  Future<String> generateBackupPhrase() async {
    if (_identityKeyPair == null || _signingKeyPair == null) {
      throw StateError('No identity to backup');
    }

    final backupData = {
      'userId': _currentIdentity!.userId,
      'alias': _currentIdentity!.alias,
      'identityPrivateKey': base64.encode(
        KeyGenerator.privateKeyToBytes(_identityKeyPair!.privateKey)
      ),
      'signingPrivateKey': base64.encode(
        KeyGenerator.privateKeyToBytes(_signingKeyPair!.privateKey)
      ),
      'createdAt': _currentIdentity!.createdAt.toIso8601String(),
    };

    // TODO: Implement BIP39 mnemonic generation for user-friendly backup
    // For now, return base64 encoded JSON
    return base64.encode(utf8.encode(jsonEncode(backupData)));
  }

  // Restore identity from backup phrase
  Future<bool> restoreFromBackup(String backupPhrase) async {
    try {
      // TODO: Implement BIP39 mnemonic decoding
      // For now, decode base64 JSON
      final backupData = jsonDecode(utf8.decode(base64.decode(backupPhrase)));

      // Restore private keys
      final identityPrivateKey = KeyGenerator.privateKeyFromBytes(
        base64.decode(backupData['identityPrivateKey'])
      );
      final signingPrivateKey = KeyGenerator.privateKeyFromBytes(
        base64.decode(backupData['signingPrivateKey']),
        isSigningKey: true,
      );

      // Regenerate public keys
      // TODO: Implement proper public key derivation from private keys
      _identityKeyPair = AsymmetricKeyPair(
        KeyGenerator.generateCurve25519KeyPair().publicKey, // Placeholder
        identityPrivateKey,
      );
      _signingKeyPair = AsymmetricKeyPair(
        KeyGenerator.generateEd25519KeyPair().publicKey, // Placeholder
        signingPrivateKey,
      );

      // Restore identity
      _currentIdentity = UserIdentity(
        userId: backupData['userId'],
        publicKey: base64.encode(
          KeyGenerator.publicKeyToBytes(_identityKeyPair!.publicKey)
        ),
        alias: backupData['alias'],
        createdAt: DateTime.parse(backupData['createdAt']),
        lastSeen: DateTime.now(),
      );

      // Initialize X3DH protocol
      _x3dhProtocol = X3DHProtocol();

      // Save restored identity
      await _saveIdentity();
      await _savePrivateKeys();
      await _saveX3DHState();
      await StorageManager.saveUserIdentity(_currentIdentity!);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      return false;
    }
  }

  // Delete identity (factory reset)
  Future<void> deleteIdentity() async {
    try {
      await _secureStorage.delete(key: _identityKey);
      await _secureStorage.delete(key: _privateKeyKey);
      await _secureStorage.delete(key: _signingPrivateKeyKey);
      await _secureStorage.delete(key: _x3dhStateKey);
      
      await StorageManager.clearAllData();
      
      _currentIdentity = null;
      _identityKeyPair = null;
      _signingKeyPair = null;
      _x3dhProtocol = null;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting identity: $e');
      rethrow;
    }
  }

  // Private methods
  Future<void> _saveIdentity() async {
    if (_currentIdentity == null) return;
    
    await _secureStorage.write(
      key: _identityKey,
      value: jsonEncode(_currentIdentity!.toJson()),
    );
  }

  Future<void> _savePrivateKeys() async {
    if (_identityKeyPair == null || _signingKeyPair == null) return;
    
    await _secureStorage.write(
      key: _privateKeyKey,
      value: base64.encode(
        KeyGenerator.privateKeyToBytes(_identityKeyPair!.privateKey)
      ),
    );
    
    await _secureStorage.write(
      key: _signingPrivateKeyKey,
      value: base64.encode(
        KeyGenerator.privateKeyToBytes(_signingKeyPair!.privateKey)
      ),
    );
  }

  Future<void> _loadPrivateKeys() async {
    final privateKeyData = await _secureStorage.read(key: _privateKeyKey);
    final signingPrivateKeyData = await _secureStorage.read(key: _signingPrivateKeyKey);
    
    if (privateKeyData != null && signingPrivateKeyData != null) {
      final identityPrivateKey = KeyGenerator.privateKeyFromBytes(
        base64.decode(privateKeyData)
      );
      final signingPrivateKey = KeyGenerator.privateKeyFromBytes(
        base64.decode(signingPrivateKeyData),
        isSigningKey: true,
      );
      
      // TODO: Derive public keys from private keys properly
      _identityKeyPair = AsymmetricKeyPair(
        KeyGenerator.publicKeyFromBytes(base64.decode(_currentIdentity!.publicKey)),
        identityPrivateKey,
      );
      _signingKeyPair = AsymmetricKeyPair(
        KeyGenerator.generateEd25519KeyPair().publicKey, // Placeholder
        signingPrivateKey,
      );
    }
  }

  Future<void> _saveX3DHState() async {
    if (_x3dhProtocol == null) return;
    
    await _secureStorage.write(
      key: _x3dhStateKey,
      value: jsonEncode(_x3dhProtocol!.getPublicKeyBundle()),
    );
  }

  Future<void> _loadX3DHState() async {
    final x3dhData = await _secureStorage.read(key: _x3dhStateKey);
    if (x3dhData != null) {
      // TODO: Properly restore X3DH state
      _x3dhProtocol = X3DHProtocol();
    }
  }

  String _generateDefaultAlias(String userId) {
    // Extract emoji and name from userId (e.g., "bluefox42" -> "🦊 Blue Fox")
    final emojiMap = {
      'fox': '🦊', 'wolf': '🐺', 'eagle': '🦅', 'lion': '🦁', 'tiger': '🐅',
      'bear': '🐻', 'hawk': '🦅', 'owl': '🦉', 'deer': '🦌', 'rabbit': '🐰',
      'cat': '🐱', 'dog': '🐶', 'horse': '🐴', 'dolphin': '🐬', 'whale': '🐋',
      'shark': '🦈', 'falcon': '🦅', 'raven': '🐦‍⬛', 'swan': '🦢', 'phoenix': '🔥',
      'dragon': '🐉', 'unicorn': '🦄', 'lynx': '🐱',
    };
    
    // Find animal in userId
    String emoji = '🌟';
    String displayName = userId;
    
    for (final entry in emojiMap.entries) {
      if (userId.toLowerCase().contains(entry.key)) {
        emoji = entry.value;
        // Capitalize first letter of each word
        displayName = userId.replaceAllMapped(
          RegExp(r'([a-z])([a-z]*)', caseSensitive: false),
          (match) => '${match.group(1)!.toUpperCase()}${match.group(2)!.toLowerCase()}',
        );
        break;
      }
    }
    
    return '$emoji $displayName';
  }
}
