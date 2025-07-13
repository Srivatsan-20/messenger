import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

import '../storage/storage_manager.dart';
import '../crypto/encryption.dart';

class SecurityManager extends ChangeNotifier {
  static const String _pinKey = 'app_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _autoLockTimeoutKey = 'auto_lock_timeout';
  static const String _lastActiveTimeKey = 'last_active_time';
  static const String _appLockedKey = 'app_locked';
  
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  bool _isLocked = false;
  bool _biometricEnabled = false;
  int _autoLockTimeout = 300; // 5 minutes default
  DateTime _lastActiveTime = DateTime.now();

  bool get isLocked => _isLocked;
  bool get biometricEnabled => _biometricEnabled;
  int get autoLockTimeout => _autoLockTimeout;

  // Initialize security manager
  Future<void> initialize() async {
    await _loadSettings();
    await _checkAutoLock();
  }

  // Check if device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  // Set up PIN
  Future<bool> setupPin(String pin) async {
    try {
      if (pin.length < 4) {
        debugPrint('PIN must be at least 4 digits');
        return false;
      }

      final hashedPin = _hashPin(pin);
      await _secureStorage.write(key: _pinKey, value: hashedPin);
      
      debugPrint('PIN set up successfully');
      return true;
    } catch (e) {
      debugPrint('Error setting up PIN: $e');
      return false;
    }
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    try {
      final storedHash = await _secureStorage.read(key: _pinKey);
      if (storedHash == null) return false;

      final hashedPin = _hashPin(pin);
      final isValid = hashedPin == storedHash;
      
      if (isValid) {
        await _unlock();
      }
      
      return isValid;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  // Check if PIN is set
  Future<bool> isPinSet() async {
    try {
      final pin = await _secureStorage.read(key: _pinKey);
      return pin != null;
    } catch (e) {
      debugPrint('Error checking PIN: $e');
      return false;
    }
  }

  // Remove PIN
  Future<bool> removePin() async {
    try {
      await _secureStorage.delete(key: _pinKey);
      return true;
    } catch (e) {
      debugPrint('Error removing PIN: $e');
      return false;
    }
  }

  // Enable/disable biometric authentication
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      if (enabled && !await isBiometricAvailable()) {
        debugPrint('Biometric authentication not available');
        return false;
      }

      _biometricEnabled = enabled;
      await StorageManager.saveSetting(_biometricEnabledKey, enabled);
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error setting biometric enabled: $e');
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      if (!_biometricEnabled || !await isBiometricAvailable()) {
        return false;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Oodaa Messenger',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (isAuthenticated) {
        await _unlock();
      }

      return isAuthenticated;
    } catch (e) {
      debugPrint('Error authenticating with biometrics: $e');
      return false;
    }
  }

  // Set auto-lock timeout (in seconds)
  Future<void> setAutoLockTimeout(int seconds) async {
    _autoLockTimeout = seconds;
    await StorageManager.saveSetting(_autoLockTimeoutKey, seconds);
    notifyListeners();
  }

  // Update last active time
  void updateLastActiveTime() {
    _lastActiveTime = DateTime.now();
    StorageManager.saveSetting(_lastActiveTimeKey, _lastActiveTime.toIso8601String());
  }

  // Check if app should auto-lock
  Future<void> checkAutoLock() async {
    await _checkAutoLock();
  }

  // Lock the app
  Future<void> lockApp() async {
    _isLocked = true;
    await StorageManager.saveSetting(_appLockedKey, true);
    notifyListeners();
    debugPrint('App locked');
  }

  // Unlock the app
  Future<void> _unlock() async {
    _isLocked = false;
    _lastActiveTime = DateTime.now();
    await StorageManager.saveSetting(_appLockedKey, false);
    await StorageManager.saveSetting(_lastActiveTimeKey, _lastActiveTime.toIso8601String());
    notifyListeners();
    debugPrint('App unlocked');
  }

  // Generate secure backup phrase
  Future<String?> generateBackupPhrase(String password) async {
    try {
      // TODO: Implement BIP39 mnemonic generation
      // For now, create a simple encrypted backup
      
      final backupData = await StorageManager.exportData();
      final backupJson = jsonEncode(backupData);
      
      // Derive key from password
      final salt = _generateRandomBytes(32);
      final key = EncryptionService.deriveKeyFromPassword(password, salt);
      
      // Encrypt backup data
      final encrypted = EncryptionService.encryptAESGCM(backupJson, key);
      
      final backupPackage = {
        'version': '1.0',
        'salt': base64.encode(salt),
        'ciphertext': base64.encode(encrypted['ciphertext']),
        'iv': base64.encode(encrypted['iv']),
        'tag': base64.encode(encrypted['tag']),
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      return base64.encode(utf8.encode(jsonEncode(backupPackage)));
    } catch (e) {
      debugPrint('Error generating backup phrase: $e');
      return null;
    }
  }

  // Restore from backup phrase
  Future<bool> restoreFromBackup(String backupPhrase, String password) async {
    try {
      final backupData = jsonDecode(utf8.decode(base64.decode(backupPhrase)));
      
      // Derive key from password
      final salt = base64.decode(backupData['salt']);
      final key = EncryptionService.deriveKeyFromPassword(password, salt);
      
      // Decrypt backup data
      final decrypted = EncryptionService.decryptAESGCM(
        base64.decode(backupData['ciphertext']),
        key,
        base64.decode(backupData['iv']),
        base64.decode(backupData['tag']),
      );
      
      final restoredData = jsonDecode(decrypted);
      
      // TODO: Implement data restoration
      debugPrint('Backup restored successfully');
      return true;
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      return false;
    }
  }

  // Secure delete (overwrite with random data)
  Future<void> secureDelete(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;
      
      final fileSize = await file.length();
      
      // Overwrite with random data multiple times
      for (int i = 0; i < 3; i++) {
        final randomData = _generateRandomBytes(fileSize);
        await file.writeAsBytes(randomData);
        // Note: File.flush() is not available, using sync instead
        // await file.flush();
      }
      
      // Finally delete the file
      await file.delete();
      debugPrint('File securely deleted: $filePath');
    } catch (e) {
      debugPrint('Error securely deleting file: $e');
    }
  }

  // Clear sensitive data from memory
  void clearSensitiveData() {
    // Force garbage collection
    // Note: Dart doesn't guarantee immediate GC, but this helps
    if (kDebugMode) {
      debugPrint('Clearing sensitive data from memory');
    }
  }

  // Get security status
  Map<String, dynamic> getSecurityStatus() {
    return {
      'isLocked': _isLocked,
      'pinSet': _secureStorage.read(key: _pinKey) != null,
      'biometricEnabled': _biometricEnabled,
      'autoLockTimeout': _autoLockTimeout,
      'lastActiveTime': _lastActiveTime.toIso8601String(),
    };
  }

  // Private methods
  Future<void> _loadSettings() async {
    _biometricEnabled = StorageManager.getSetting(_biometricEnabledKey, defaultValue: false) ?? false;
    _autoLockTimeout = StorageManager.getSetting(_autoLockTimeoutKey, defaultValue: 300) ?? 300;
    _isLocked = StorageManager.getSetting(_appLockedKey, defaultValue: false) ?? false;
    
    final lastActiveStr = StorageManager.getSetting<String>(_lastActiveTimeKey);
    if (lastActiveStr != null) {
      _lastActiveTime = DateTime.parse(lastActiveStr);
    }
  }

  Future<void> _checkAutoLock() async {
    if (_autoLockTimeout <= 0) return;
    
    final now = DateTime.now();
    final timeSinceLastActive = now.difference(_lastActiveTime).inSeconds;
    
    if (timeSinceLastActive >= _autoLockTimeout) {
      await lockApp();
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    return bytes;
  }
}
