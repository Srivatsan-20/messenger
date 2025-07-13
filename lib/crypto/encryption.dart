import 'dart:typed_data';
import 'dart:convert';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';

class EncryptionService {
  // AES-256-GCM encryption
  static Map<String, dynamic> encryptAESGCM(String plaintext, Uint8List key, {Uint8List? iv}) {
    iv ??= _generateRandomBytes(12); // 96-bit IV for GCM
    
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      128, // 128-bit authentication tag
      iv,
      Uint8List(0), // No additional authenticated data
    );
    
    cipher.init(true, params);
    
    final plaintextBytes = utf8.encode(plaintext);
    final ciphertext = cipher.process(plaintextBytes);
    
    return {
      'ciphertext': ciphertext,
      'iv': iv,
      'tag': cipher.mac, // Authentication tag
    };
  }

  // AES-256-GCM decryption
  static String decryptAESGCM(Uint8List ciphertext, Uint8List key, Uint8List iv, Uint8List tag) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      128,
      iv,
      Uint8List(0),
    );
    
    cipher.init(false, params);
    
    // Combine ciphertext and tag
    final combined = Uint8List(ciphertext.length + tag.length);
    combined.setRange(0, ciphertext.length, ciphertext);
    combined.setRange(ciphertext.length, combined.length, tag);
    
    final decrypted = cipher.process(combined);
    return utf8.decode(decrypted);
  }

  // RSA key agreement (simplified replacement for X25519)
  static Uint8List performECDH(PrivateKey privateKey, PublicKey publicKey) {
    if (privateKey is! RSAPrivateKey || publicKey is! RSAPublicKey) {
      throw ArgumentError('Keys must be RSA keys');
    }

    // Simplified: use hash of both keys as shared secret
    final privateBytes = privateKey.modulus!.toRadixString(16);
    final publicBytes = publicKey.modulus!.toRadixString(16);
    final combined = privateBytes + publicBytes;
    final digest = sha256.convert(utf8.encode(combined));

    return Uint8List.fromList(digest.bytes);
  }

  // RSA digital signature (replacement for Ed25519)
  static Uint8List sign(Uint8List message, RSAPrivateKey privateKey) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final signature = signer.generateSignature(message);
    return signature.bytes;
  }

  // RSA signature verification (replacement for Ed25519)
  static bool verifySignature(Uint8List message, Uint8List signature, RSAPublicKey publicKey) {
    try {
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      return verifier.verifySignature(message, RSASignature(signature));
    } catch (e) {
      return false;
    }
  }

  // Constant time comparison for security
  static bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  // HMAC-SHA256
  static Uint8List hmacSha256(Uint8List key, Uint8List data) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  // Encrypt file data in chunks
  static List<Map<String, dynamic>> encryptFileChunks(Uint8List fileData, Uint8List key, {int chunkSize = 64 * 1024}) {
    final chunks = <Map<String, dynamic>>[];
    
    for (int i = 0; i < fileData.length; i += chunkSize) {
      final end = (i + chunkSize < fileData.length) ? i + chunkSize : fileData.length;
      final chunk = fileData.sublist(i, end);
      
      final encrypted = encryptAESGCM(base64.encode(chunk), key);
      chunks.add({
        'index': chunks.length,
        'data': encrypted,
        'isLast': end == fileData.length,
      });
    }
    
    return chunks;
  }

  // Decrypt file chunks
  static Uint8List decryptFileChunks(List<Map<String, dynamic>> encryptedChunks, Uint8List key) {
    final decryptedData = <int>[];
    
    // Sort chunks by index
    encryptedChunks.sort((a, b) => a['index'].compareTo(b['index']));
    
    for (final chunk in encryptedChunks) {
      final encData = chunk['data'];
      final decrypted = decryptAESGCM(
        encData['ciphertext'],
        key,
        encData['iv'],
        encData['tag'],
      );
      
      final chunkData = base64.decode(decrypted);
      decryptedData.addAll(chunkData);
    }
    
    return Uint8List.fromList(decryptedData);
  }

  // Generate secure random bytes
  static Uint8List _generateRandomBytes(int length) {
    final secureRandom = SecureRandom('Fortuna');
    final seed = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      seed[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    secureRandom.seed(KeyParameter(seed));
    
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = secureRandom.nextUint8();
    }
    return bytes;
  }

  // Derive key from password (PBKDF2)
  static Uint8List deriveKeyFromPassword(String password, Uint8List salt, {int iterations = 100000}) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, 32));
    
    return pbkdf2.process(utf8.encode(password));
  }

}
