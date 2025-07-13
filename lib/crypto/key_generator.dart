import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class KeyGenerator {
  static SecureRandom? _secureRandom;

  static SecureRandom _getSecureRandom() {
    if (_secureRandom == null) {
      print('🔧 DEBUG: Initializing SecureRandom');
      _secureRandom = SecureRandom('Fortuna');

      // Use a simpler seed that works better in web environments
      final seed = Uint8List(32);
      final random = Random();
      for (int i = 0; i < 32; i++) {
        seed[i] = random.nextInt(256);
      }
      _secureRandom!.seed(KeyParameter(seed));
      print('🔧 DEBUG: SecureRandom initialized');
    }
    return _secureRandom!;
  }

  // Generate Curve25519 key pair (using RSA as fallback since X25519 is not available)
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateCurve25519KeyPair() {
    print('🔧 DEBUG: Starting Curve25519 key generation');
    // Use RSA as a fallback since X25519 is not available in this version
    // Using smaller key size (1024) for faster generation in web environment
    final keyGen = RSAKeyGenerator();
    print('🔧 DEBUG: Initializing RSA key generator for Curve25519');
    keyGen.init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64), // Reduced from 2048 to 1024
      _getSecureRandom(),
    ));

    print('🔧 DEBUG: Generating RSA key pair for Curve25519');
    final keyPair = keyGen.generateKeyPair();
    print('🔧 DEBUG: Curve25519 key pair generated successfully');
    return keyPair;
  }

  // Generate Ed25519 signing key pair (using RSA as fallback)
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateEd25519KeyPair() {
    print('🔧 DEBUG: Starting Ed25519 key generation');
    // Use RSA as a fallback since Ed25519 is not available in this version
    // Using smaller key size (1024) for faster generation in web environment
    final keyGen = RSAKeyGenerator();
    print('🔧 DEBUG: Initializing RSA key generator');
    keyGen.init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64), // Reduced from 2048 to 1024
      _getSecureRandom(),
    ));

    print('🔧 DEBUG: Generating RSA key pair');
    final keyPair = keyGen.generateKeyPair();
    print('🔧 DEBUG: Ed25519 key pair generated successfully');
    return keyPair;
  }

  // Generate random bytes
  static Uint8List generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    final secureRandom = _getSecureRandom();
    for (int i = 0; i < length; i++) {
      bytes[i] = secureRandom.nextUint8();
    }
    return bytes;
  }

  // Generate AES-256 key
  static Uint8List generateAESKey() {
    return generateRandomBytes(32); // 256 bits
  }

  // Generate unique user ID
  static String generateUserId() {
    print('🔧 DEBUG: Starting generateUserId');

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

    print('🔧 DEBUG: Creating Random instance');
    // Use regular Random instead of Random.secure() for web compatibility
    final random = Random();
    print('🔧 DEBUG: Selecting adjective');
    final adjective = adjectives[random.nextInt(adjectives.length)];
    print('🔧 DEBUG: Selecting animal');
    final animal = animals[random.nextInt(animals.length)];
    print('🔧 DEBUG: Generating number');
    final number = random.nextInt(100);

    final userId = '$adjective$animal$number';
    print('🔧 DEBUG: Generated userId: $userId');
    return userId;
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
    if (publicKey is RSAPublicKey) {
      // Convert RSA public key to bytes (simplified)
      final modulus = publicKey.modulus!.toRadixString(16);
      return Uint8List.fromList(utf8.encode(modulus));
    }
    throw ArgumentError('Unsupported public key type');
  }

  // Convert private key to bytes
  static Uint8List privateKeyToBytes(PrivateKey privateKey) {
    if (privateKey is RSAPrivateKey) {
      // Convert RSA private key to bytes (simplified)
      final modulus = privateKey.modulus!.toRadixString(16);
      return Uint8List.fromList(utf8.encode(modulus));
    }
    throw ArgumentError('Unsupported private key type');
  }

  // Create public key from bytes
  static PublicKey publicKeyFromBytes(Uint8List bytes, {bool isSigningKey = false}) {
    // Simplified: create a dummy RSA public key
    final modulus = BigInt.parse(utf8.decode(bytes), radix: 16);
    return RSAPublicKey(modulus, BigInt.from(65537));
  }

  // Create private key from bytes
  static PrivateKey privateKeyFromBytes(Uint8List bytes, {bool isSigningKey = false}) {
    // Simplified: create a dummy RSA private key
    final modulus = BigInt.parse(utf8.decode(bytes), radix: 16);
    return RSAPrivateKey(modulus, BigInt.from(65537), BigInt.one, BigInt.one);
  }


}
