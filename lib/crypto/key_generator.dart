import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class KeyGenerator {
  static final _secureRandom = SecureRandom('Fortuna')
    ..seed(KeyParameter(Uint8List.fromList(
        List.generate(32, (i) => Random.secure().nextInt(256)))));

  // Generate Curve25519 key pair
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateCurve25519KeyPair() {
    final keyGen = X25519KeyGenerator();
    keyGen.init(ParametersWithRandom(
      X25519KeyGenerationParameters(),
      _secureRandom,
    ));
    
    return keyGen.generateKeyPair();
  }

  // Generate Ed25519 signing key pair
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateEd25519KeyPair() {
    final keyGen = Ed25519KeyGenerator();
    keyGen.init(ParametersWithRandom(
      Ed25519KeyGenerationParameters(),
      _secureRandom,
    ));
    
    return keyGen.generateKeyPair();
  }

  // Generate random bytes
  static Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextUint8();
    }
    return bytes;
  }

  // Generate AES-256 key
  static Uint8List generateAESKey() {
    return generateRandomBytes(32); // 256 bits
  }

  // Generate unique user ID
  static String generateUserId() {
    const adjectives = [
      'blue', 'red', 'green', 'purple', 'orange', 'yellow', 'pink', 'cyan',
      'swift', 'brave', 'wise', 'calm', 'bold', 'kind', 'smart', 'cool',
      'bright', 'quick', 'silent', 'strong', 'gentle', 'fierce', 'noble'
    ];
    
    const animals = [
      'fox', 'wolf', 'eagle', 'lion', 'tiger', 'bear', 'hawk', 'owl',
      'deer', 'rabbit', 'cat', 'dog', 'horse', 'dolphin', 'whale', 'shark',
      'falcon', 'raven', 'swan', 'phoenix', 'dragon', 'unicorn', 'lynx'
    ];
    
    final random = Random.secure();
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final animal = animals[random.nextInt(animals.length)];
    final number = random.nextInt(100);
    
    return '$adjective$animal$number';
  }

  // HKDF (HMAC-based Key Derivation Function)
  static Uint8List hkdf(Uint8List inputKeyMaterial, Uint8List salt, Uint8List info, int length) {
    // Extract phase
    final hmac = Hmac(sha256, salt);
    final prk = Uint8List.fromList(hmac.convert(inputKeyMaterial).bytes);
    
    // Expand phase
    final output = <int>[];
    final hmacExpand = Hmac(sha256, prk);
    int n = (length / 32).ceil();
    
    Uint8List t = Uint8List(0);
    for (int i = 1; i <= n; i++) {
      final data = <int>[];
      data.addAll(t);
      data.addAll(info);
      data.add(i);
      
      t = Uint8List.fromList(hmacExpand.convert(data).bytes);
      output.addAll(t);
    }
    
    return Uint8List.fromList(output.take(length).toList());
  }

  // Key derivation for Double Ratchet
  static Map<String, Uint8List> deriveRatchetKeys(Uint8List rootKey, Uint8List dhOutput) {
    const info = 'OodaaMessengerRatchet';
    final derived = hkdf(dhOutput, rootKey, utf8.encode(info), 96); // 3 * 32 bytes
    
    return {
      'rootKey': derived.sublist(0, 32),
      'chainKey': derived.sublist(32, 64),
      'nextHeaderKey': derived.sublist(64, 96),
    };
  }

  // Derive message keys from chain key
  static Map<String, Uint8List> deriveMessageKeys(Uint8List chainKey) {
    const messageKeyConstant = 0x01;
    const chainKeyConstant = 0x02;
    
    final hmac = Hmac(sha256, chainKey);
    final messageKey = Uint8List.fromList(
      hmac.convert([messageKeyConstant]).bytes
    );
    final nextChainKey = Uint8List.fromList(
      hmac.convert([chainKeyConstant]).bytes
    );
    
    // Derive encryption and MAC keys from message key
    const info = 'OodaaMessengerMessageKeys';
    final derived = hkdf(messageKey, Uint8List(32), utf8.encode(info), 80); // 32 + 32 + 16
    
    return {
      'encryptionKey': derived.sublist(0, 32),
      'macKey': derived.sublist(32, 64),
      'iv': derived.sublist(64, 80),
      'nextChainKey': nextChainKey,
    };
  }

  // Convert public key to bytes
  static Uint8List publicKeyToBytes(PublicKey publicKey) {
    if (publicKey is X25519PublicKey) {
      return publicKey.u;
    } else if (publicKey is Ed25519PublicKey) {
      return publicKey.data;
    }
    throw ArgumentError('Unsupported public key type');
  }

  // Convert private key to bytes
  static Uint8List privateKeyToBytes(PrivateKey privateKey) {
    if (privateKey is X25519PrivateKey) {
      return privateKey.u;
    } else if (privateKey is Ed25519PrivateKey) {
      return privateKey.data;
    }
    throw ArgumentError('Unsupported private key type');
  }

  // Create public key from bytes
  static PublicKey publicKeyFromBytes(Uint8List bytes, {bool isSigningKey = false}) {
    if (isSigningKey) {
      return Ed25519PublicKey(bytes);
    } else {
      return X25519PublicKey(bytes);
    }
  }

  // Create private key from bytes
  static PrivateKey privateKeyFromBytes(Uint8List bytes, {bool isSigningKey = false}) {
    if (isSigningKey) {
      return Ed25519PrivateKey(bytes);
    } else {
      return X25519PrivateKey(bytes);
    }
  }
}
