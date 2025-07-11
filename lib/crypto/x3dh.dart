import 'dart:typed_data';
import 'dart:convert';
import 'package:pointycastle/export.dart';
import 'key_generator.dart';
import 'encryption.dart';

// X3DH (Extended Triple Diffie-Hellman) Key Agreement Protocol
// Used for initial key exchange between two parties
class X3DHProtocol {
  // Identity key pair (long-term)
  late AsymmetricKeyPair<PublicKey, PrivateKey> identityKeyPair;
  
  // Signed prekey (medium-term, rotated periodically)
  late AsymmetricKeyPair<PublicKey, PrivateKey> signedPreKeyPair;
  late Uint8List signedPreKeySignature;
  
  // One-time prekeys (short-term, used once)
  final List<AsymmetricKeyPair<PublicKey, PrivateKey>> oneTimePreKeys = [];
  
  // Signing key pair for signatures
  late AsymmetricKeyPair<PublicKey, PrivateKey> signingKeyPair;

  X3DHProtocol() {
    _generateKeys();
  }

  void _generateKeys() {
    // Generate identity key pair
    identityKeyPair = KeyGenerator.generateCurve25519KeyPair();
    
    // Generate signing key pair
    signingKeyPair = KeyGenerator.generateEd25519KeyPair();
    
    // Generate signed prekey
    signedPreKeyPair = KeyGenerator.generateCurve25519KeyPair();
    
    // Sign the prekey
    final preKeyBytes = KeyGenerator.publicKeyToBytes(signedPreKeyPair.publicKey);
    signedPreKeySignature = EncryptionService.sign(
      preKeyBytes,
      signingKeyPair.privateKey as Ed25519PrivateKey,
    );
    
    // Generate one-time prekeys
    _generateOneTimePreKeys(10);
  }

  void _generateOneTimePreKeys(int count) {
    oneTimePreKeys.clear();
    for (int i = 0; i < count; i++) {
      oneTimePreKeys.add(KeyGenerator.generateCurve25519KeyPair());
    }
  }

  // Get public key bundle for sharing
  Map<String, dynamic> getPublicKeyBundle() {
    return {
      'identityKey': base64.encode(KeyGenerator.publicKeyToBytes(identityKeyPair.publicKey)),
      'signingKey': base64.encode(KeyGenerator.publicKeyToBytes(signingKeyPair.publicKey)),
      'signedPreKey': base64.encode(KeyGenerator.publicKeyToBytes(signedPreKeyPair.publicKey)),
      'signedPreKeySignature': base64.encode(signedPreKeySignature),
      'oneTimePreKeys': oneTimePreKeys.map((kp) => 
        base64.encode(KeyGenerator.publicKeyToBytes(kp.publicKey))
      ).toList(),
    };
  }

  // Perform X3DH as initiator (Alice)
  Map<String, dynamic> performX3DHInitiator(Map<String, dynamic> bobBundle) {
    // Parse Bob's bundle
    final bobIdentityKey = KeyGenerator.publicKeyFromBytes(
      base64.decode(bobBundle['identityKey'])
    );
    final bobSigningKey = KeyGenerator.publicKeyFromBytes(
      base64.decode(bobBundle['signingKey']),
      isSigningKey: true,
    );
    final bobSignedPreKey = KeyGenerator.publicKeyFromBytes(
      base64.decode(bobBundle['signedPreKey'])
    );
    final bobSignature = base64.decode(bobBundle['signedPreKeySignature']);
    
    // Verify Bob's signed prekey
    final preKeyBytes = KeyGenerator.publicKeyToBytes(bobSignedPreKey);
    if (!EncryptionService.verifySignature(
      preKeyBytes,
      bobSignature,
      bobSigningKey as Ed25519PublicKey,
    )) {
      throw Exception('Invalid signed prekey signature');
    }
    
    // Select a one-time prekey (if available)
    PublicKey? bobOneTimePreKey;
    if (bobBundle['oneTimePreKeys'] != null && 
        (bobBundle['oneTimePreKeys'] as List).isNotEmpty) {
      final oneTimeKeys = bobBundle['oneTimePreKeys'] as List;
      bobOneTimePreKey = KeyGenerator.publicKeyFromBytes(
        base64.decode(oneTimeKeys.first)
      );
    }
    
    // Generate ephemeral key pair
    final ephemeralKeyPair = KeyGenerator.generateCurve25519KeyPair();
    
    // Perform the four DH operations
    final dh1 = EncryptionService.performECDH(
      identityKeyPair.privateKey,
      bobSignedPreKey,
    );
    
    final dh2 = EncryptionService.performECDH(
      ephemeralKeyPair.privateKey,
      bobIdentityKey,
    );
    
    final dh3 = EncryptionService.performECDH(
      ephemeralKeyPair.privateKey,
      bobSignedPreKey,
    );
    
    Uint8List? dh4;
    if (bobOneTimePreKey != null) {
      dh4 = EncryptionService.performECDH(
        ephemeralKeyPair.privateKey,
        bobOneTimePreKey,
      );
    }
    
    // Combine DH outputs
    final dhOutputs = <int>[];
    dhOutputs.addAll(dh1);
    dhOutputs.addAll(dh2);
    dhOutputs.addAll(dh3);
    if (dh4 != null) {
      dhOutputs.addAll(dh4);
    }
    
    // Derive shared secret
    final sharedSecret = _deriveSharedSecret(Uint8List.fromList(dhOutputs));
    
    return {
      'sharedSecret': sharedSecret,
      'ephemeralPublicKey': base64.encode(
        KeyGenerator.publicKeyToBytes(ephemeralKeyPair.publicKey)
      ),
      'usedOneTimePreKey': bobOneTimePreKey != null,
    };
  }

  // Perform X3DH as receiver (Bob)
  Uint8List performX3DHReceiver(
    String aliceIdentityKey,
    String aliceEphemeralKey,
    bool usedOneTimePreKey,
  ) {
    // Parse Alice's keys
    final aliceIdentityPubKey = KeyGenerator.publicKeyFromBytes(
      base64.decode(aliceIdentityKey)
    );
    final aliceEphemeralPubKey = KeyGenerator.publicKeyFromBytes(
      base64.decode(aliceEphemeralKey)
    );
    
    // Perform the four DH operations (same as Alice but with roles reversed)
    final dh1 = EncryptionService.performECDH(
      signedPreKeyPair.privateKey,
      aliceIdentityPubKey,
    );
    
    final dh2 = EncryptionService.performECDH(
      identityKeyPair.privateKey,
      aliceEphemeralPubKey,
    );
    
    final dh3 = EncryptionService.performECDH(
      signedPreKeyPair.privateKey,
      aliceEphemeralPubKey,
    );
    
    Uint8List? dh4;
    if (usedOneTimePreKey && oneTimePreKeys.isNotEmpty) {
      // Use the first one-time prekey (in practice, track which one was used)
      dh4 = EncryptionService.performECDH(
        oneTimePreKeys.first.privateKey,
        aliceEphemeralPubKey,
      );
      // Remove the used one-time prekey
      oneTimePreKeys.removeAt(0);
    }
    
    // Combine DH outputs
    final dhOutputs = <int>[];
    dhOutputs.addAll(dh1);
    dhOutputs.addAll(dh2);
    dhOutputs.addAll(dh3);
    if (dh4 != null) {
      dhOutputs.addAll(dh4);
    }
    
    // Derive shared secret
    return _deriveSharedSecret(Uint8List.fromList(dhOutputs));
  }

  // Derive shared secret using HKDF
  Uint8List _deriveSharedSecret(Uint8List dhOutputs) {
    const salt = 'OodaaMessengerX3DH';
    const info = 'OodaaMessengerSharedSecret';
    
    return KeyGenerator.hkdf(
      dhOutputs,
      utf8.encode(salt),
      utf8.encode(info),
      32, // 256-bit shared secret
    );
  }

  // Rotate signed prekey (should be done periodically)
  void rotateSignedPreKey() {
    signedPreKeyPair = KeyGenerator.generateCurve25519KeyPair();
    
    final preKeyBytes = KeyGenerator.publicKeyToBytes(signedPreKeyPair.publicKey);
    signedPreKeySignature = EncryptionService.sign(
      preKeyBytes,
      signingKeyPair.privateKey as Ed25519PrivateKey,
    );
  }

  // Replenish one-time prekeys
  void replenishOneTimePreKeys() {
    if (oneTimePreKeys.length < 5) {
      _generateOneTimePreKeys(10);
    }
  }
}
