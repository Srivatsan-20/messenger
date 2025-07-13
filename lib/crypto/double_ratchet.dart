import 'dart:typed_data';
import 'dart:convert';
import 'package:pointycastle/export.dart' as pc;
import 'key_generator.dart' as kg;
import 'encryption.dart';

// Double Ratchet Protocol for forward secrecy
class DoubleRatchet {
  // Root key
  Uint8List rootKey;
  
  // Sending chain
  Uint8List? sendingChainKey;
  pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey>? sendingRatchetKeyPair;

  // Receiving chain
  Uint8List? receivingChainKey;
  pc.PublicKey? receivingRatchetPublicKey;
  
  // Message numbers
  int sendingMessageNumber = 0;
  int receivingMessageNumber = 0;
  int previousSendingChainLength = 0;
  
  // Skipped message keys for out-of-order messages
  final Map<String, Uint8List> skippedMessageKeys = {};
  
  // Maximum number of skipped message keys to store
  static const int maxSkippedMessageKeys = 1000;

  DoubleRatchet({required this.rootKey});

  // Initialize as sender (Alice)
  void initializeAsSender(pc.PublicKey bobRatchetPublicKey) {
    receivingRatchetPublicKey = bobRatchetPublicKey;
    sendingRatchetKeyPair = kg.KeyGenerator.generateCurve25519KeyPair();
    
    _performDHRatchetStep();
  }

  // Initialize as receiver (Bob)
  void initializeAsReceiver(pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> ratchetKeyPair) {
    sendingRatchetKeyPair = ratchetKeyPair;
  }

  // Encrypt a message
  Map<String, dynamic> encrypt(String plaintext) {
    if (sendingChainKey == null) {
      throw StateError('Sending chain not initialized');
    }

    // Derive message keys
    final messageKeys = kg.KeyGenerator.deriveMessageKeys(sendingChainKey!);
    sendingChainKey = messageKeys['nextChainKey'];
    
    // Encrypt the message
    final encrypted = EncryptionService.encryptAESGCM(
      plaintext,
      messageKeys['encryptionKey']!,
      iv: messageKeys['iv'],
    );
    
    // Create message header
    final header = _createMessageHeader();
    
    final result = {
      'header': header,
      'ciphertext': encrypted['ciphertext'],
      'iv': encrypted['iv'],
      'tag': encrypted['tag'],
      'messageNumber': sendingMessageNumber,
    };
    
    sendingMessageNumber++;
    return result;
  }

  // Decrypt a message
  String decrypt(Map<String, dynamic> encryptedMessage) {
    final header = encryptedMessage['header'] as Map<String, dynamic>;
    final messageNumber = encryptedMessage['messageNumber'] as int;
    
    // Check if we need to perform DH ratchet step
    final senderRatchetPublicKey = kg.KeyGenerator.publicKeyFromBytes(
      base64.decode(header['publicKey'])
    );
    
    if (receivingRatchetPublicKey == null || 
        !_publicKeysEqual(receivingRatchetPublicKey!, senderRatchetPublicKey)) {
      _skipMessageKeys(messageNumber);
      _performDHRatchetStep(senderRatchetPublicKey);
    }
    
    // Check for skipped message keys
    final skippedKey = _getSkippedMessageKey(header, messageNumber);
    if (skippedKey != null) {
      return _decryptWithKey(encryptedMessage, skippedKey);
    }
    
    // Skip messages if necessary
    _skipMessageKeys(messageNumber);
    
    // Derive message keys
    if (receivingChainKey == null) {
      throw StateError('Receiving chain not initialized');
    }
    
    final messageKeys = kg.KeyGenerator.deriveMessageKeys(receivingChainKey!);
    receivingChainKey = messageKeys['nextChainKey'];
    
    receivingMessageNumber++;
    
    return _decryptWithKey(encryptedMessage, messageKeys['encryptionKey']!);
  }

  // Perform DH ratchet step
  void _performDHRatchetStep([pc.PublicKey? remotePublicKey]) {
    if (remotePublicKey != null) {
      // Receiving ratchet step
      receivingRatchetPublicKey = remotePublicKey;
      
      if (sendingRatchetKeyPair != null) {
        final dhOutput = EncryptionService.performECDH(
          sendingRatchetKeyPair!.privateKey,
          remotePublicKey,
        );
        
        final derived = kg.KeyGenerator.deriveRatchetKeys(rootKey, dhOutput);
        rootKey = derived['rootKey']!;
        receivingChainKey = derived['chainKey'];
        receivingMessageNumber = 0;
      }

      // Sending ratchet step
      previousSendingChainLength = sendingMessageNumber;
      sendingMessageNumber = 0;
      sendingRatchetKeyPair = kg.KeyGenerator.generateCurve25519KeyPair();

      final dhOutput2 = EncryptionService.performECDH(
        sendingRatchetKeyPair!.privateKey,
        remotePublicKey,
      );

      final derived2 = kg.KeyGenerator.deriveRatchetKeys(rootKey, dhOutput2);
      rootKey = derived2['rootKey']!;
      sendingChainKey = derived2['chainKey'];
    } else {
      // Initial sending ratchet step
      if (receivingRatchetPublicKey != null && sendingRatchetKeyPair != null) {
        final dhOutput = EncryptionService.performECDH(
          sendingRatchetKeyPair!.privateKey,
          receivingRatchetPublicKey!,
        );
        
        final derived = kg.KeyGenerator.deriveRatchetKeys(rootKey, dhOutput);
        rootKey = derived['rootKey']!;
        sendingChainKey = derived['chainKey'];
      }
    }
  }

  // Create message header
  Map<String, dynamic> _createMessageHeader() {
    if (sendingRatchetKeyPair == null) {
      throw StateError('Sending ratchet key pair not initialized');
    }
    
    return {
      'publicKey': base64.encode(
        kg.KeyGenerator.publicKeyToBytes(sendingRatchetKeyPair!.publicKey)
      ),
      'previousChainLength': previousSendingChainLength,
      'messageNumber': sendingMessageNumber,
    };
  }

  // Skip message keys for out-of-order delivery
  void _skipMessageKeys(int untilMessageNumber) {
    if (receivingChainKey == null) return;
    
    while (receivingMessageNumber < untilMessageNumber) {
      final messageKeys = kg.KeyGenerator.deriveMessageKeys(receivingChainKey!);
      receivingChainKey = messageKeys['nextChainKey'];

      final keyId = '${base64.encode(kg.KeyGenerator.publicKeyToBytes(receivingRatchetPublicKey!))}_$receivingMessageNumber';
      skippedMessageKeys[keyId] = messageKeys['encryptionKey']!;
      
      receivingMessageNumber++;
      
      // Limit the number of skipped keys
      if (skippedMessageKeys.length > maxSkippedMessageKeys) {
        final oldestKey = skippedMessageKeys.keys.first;
        skippedMessageKeys.remove(oldestKey);
      }
    }
  }

  // Get skipped message key
  Uint8List? _getSkippedMessageKey(Map<String, dynamic> header, int messageNumber) {
    final publicKey = header['publicKey'] as String;
    final keyId = '${publicKey}_$messageNumber';
    
    return skippedMessageKeys.remove(keyId);
  }

  // Decrypt with specific key
  String _decryptWithKey(Map<String, dynamic> encryptedMessage, Uint8List key) {
    return EncryptionService.decryptAESGCM(
      encryptedMessage['ciphertext'],
      key,
      encryptedMessage['iv'],
      encryptedMessage['tag'],
    );
  }

  // Compare public keys
  bool _publicKeysEqual(pc.PublicKey key1, pc.PublicKey key2) {
    final bytes1 = kg.KeyGenerator.publicKeyToBytes(key1);
    final bytes2 = kg.KeyGenerator.publicKeyToBytes(key2);
    
    return EncryptionService.constantTimeEquals(bytes1, bytes2);
  }

  // Serialize state for storage
  Map<String, dynamic> serialize() {
    return {
      'rootKey': base64.encode(rootKey),
      'sendingChainKey': sendingChainKey != null ? base64.encode(sendingChainKey!) : null,
      'receivingChainKey': receivingChainKey != null ? base64.encode(receivingChainKey!) : null,
      'sendingRatchetPrivateKey': sendingRatchetKeyPair != null
        ? base64.encode(kg.KeyGenerator.privateKeyToBytes(sendingRatchetKeyPair!.privateKey))
        : null,
      'sendingRatchetPublicKey': sendingRatchetKeyPair != null
        ? base64.encode(kg.KeyGenerator.publicKeyToBytes(sendingRatchetKeyPair!.publicKey))
        : null,
      'receivingRatchetPublicKey': receivingRatchetPublicKey != null
        ? base64.encode(kg.KeyGenerator.publicKeyToBytes(receivingRatchetPublicKey!))
        : null,
      'sendingMessageNumber': sendingMessageNumber,
      'receivingMessageNumber': receivingMessageNumber,
      'previousSendingChainLength': previousSendingChainLength,
      'skippedMessageKeys': skippedMessageKeys,
    };
  }

  // Deserialize state from storage
  static DoubleRatchet deserialize(Map<String, dynamic> data) {
    final ratchet = DoubleRatchet(
      rootKey: base64.decode(data['rootKey']),
    );
    
    if (data['sendingChainKey'] != null) {
      ratchet.sendingChainKey = base64.decode(data['sendingChainKey']);
    }
    
    if (data['receivingChainKey'] != null) {
      ratchet.receivingChainKey = base64.decode(data['receivingChainKey']);
    }
    
    if (data['sendingRatchetPrivateKey'] != null && data['sendingRatchetPublicKey'] != null) {
      final privateKey = kg.KeyGenerator.privateKeyFromBytes(
        base64.decode(data['sendingRatchetPrivateKey'])
      );
      final publicKey = kg.KeyGenerator.publicKeyFromBytes(
        base64.decode(data['sendingRatchetPublicKey'])
      );
      ratchet.sendingRatchetKeyPair = pc.AsymmetricKeyPair(publicKey, privateKey);
    }

    if (data['receivingRatchetPublicKey'] != null) {
      ratchet.receivingRatchetPublicKey = kg.KeyGenerator.publicKeyFromBytes(
        base64.decode(data['receivingRatchetPublicKey'])
      );
    }
    
    ratchet.sendingMessageNumber = data['sendingMessageNumber'] ?? 0;
    ratchet.receivingMessageNumber = data['receivingMessageNumber'] ?? 0;
    ratchet.previousSendingChainLength = data['previousSendingChainLength'] ?? 0;
    
    if (data['skippedMessageKeys'] != null) {
      final skipped = data['skippedMessageKeys'] as Map<String, dynamic>;
      for (final entry in skipped.entries) {
        ratchet.skippedMessageKeys[entry.key] = base64.decode(entry.value);
      }
    }
    
    return ratchet;
  }
}
