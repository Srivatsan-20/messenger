import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';

import '../models/message.dart';
import '../crypto/encryption.dart';

class MediaManager {
  static const int maxImageSize = 1920; // Max width/height for images
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB max file size
  static const double imageQuality = 0.8; // JPEG quality

  // Pick image from gallery or camera
  static Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: maxImageSize.toDouble(),
        maxHeight: maxImageSize.toDouble(),
        imageQuality: (imageQuality * 100).round(),
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  // Pick video from gallery or camera
  static Future<File?> pickVideo({bool fromCamera = false}) async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // 5 minute max
      );
      
      if (video != null) {
        final file = File(video.path);
        final fileSize = await file.length();
        
        if (fileSize > maxFileSize) {
          debugPrint('Video file too large: ${fileSize / (1024 * 1024)}MB');
          return null;
        }
        
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }

  // Pick any file
  static Future<File?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();
        
        if (fileSize > maxFileSize) {
          debugPrint('File too large: ${fileSize / (1024 * 1024)}MB');
          return null;
        }
        
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }

  // Compress image
  static Future<Uint8List?> compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Resize if too large
      img.Image resized = image;
      if (image.width > maxImageSize || image.height > maxImageSize) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? maxImageSize : null,
          height: image.height > image.width ? maxImageSize : null,
        );
      }
      
      // Encode as JPEG with quality compression
      final compressed = img.encodeJpg(resized, quality: (imageQuality * 100).round());
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  // Save media file securely
  static Future<String?> saveMediaFile(
    Uint8List data,
    String fileName,
    MessageType type, {
    bool encrypt = true,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${directory.path}/media/${type.name}');
      
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final hash = sha256.convert(data).toString().substring(0, 8);
      final extension = fileName.split('.').last;
      final uniqueFileName = '${timestamp}_$hash.$extension';
      final filePath = '${mediaDir.path}/$uniqueFileName';
      
      if (encrypt) {
        // Encrypt the file data
        final encryptionKey = _generateRandomBytes(32);
        final encrypted = EncryptionService.encryptAESGCM(
          base64.encode(data),
          encryptionKey,
        );
        
        final encryptedData = {
          'ciphertext': base64.encode(encrypted['ciphertext']),
          'iv': base64.encode(encrypted['iv']),
          'tag': base64.encode(encrypted['tag']),
          'key': base64.encode(encryptionKey),
          'originalName': fileName,
          'mimeType': _getMimeType(fileName),
        };
        
        await File(filePath).writeAsString(jsonEncode(encryptedData));
      } else {
        await File(filePath).writeAsBytes(data);
      }
      
      return filePath;
    } catch (e) {
      debugPrint('Error saving media file: $e');
      return null;
    }
  }

  // Load media file
  static Future<Uint8List?> loadMediaFile(String filePath, {bool encrypted = true}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      if (encrypted) {
        final encryptedData = jsonDecode(await file.readAsString());
        final decrypted = EncryptionService.decryptAESGCM(
          base64.decode(encryptedData['ciphertext']),
          base64.decode(encryptedData['key']),
          base64.decode(encryptedData['iv']),
          base64.decode(encryptedData['tag']),
        );
        
        return base64.decode(decrypted);
      } else {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error loading media file: $e');
      return null;
    }
  }

  // Get media file info
  static Future<Map<String, dynamic>?> getMediaFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final encryptedData = jsonDecode(await file.readAsString());
      return {
        'originalName': encryptedData['originalName'],
        'mimeType': encryptedData['mimeType'],
        'size': await file.length(),
        'encrypted': true,
      };
    } catch (e) {
      debugPrint('Error getting media file info: $e');
      return null;
    }
  }

  // Delete media file
  static Future<bool> deleteMediaFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting media file: $e');
      return false;
    }
  }

  // Export media file to gallery/downloads
  static Future<bool> exportMediaFile(String filePath, String outputName) async {
    try {
      final data = await loadMediaFile(filePath);
      if (data == null) return false;
      
      // Get downloads directory
      Directory? outputDir;
      if (Platform.isAndroid) {
        outputDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        outputDir = await getApplicationDocumentsDirectory();
      }
      
      if (outputDir == null || !await outputDir.exists()) {
        return false;
      }
      
      final outputFile = File('${outputDir.path}/$outputName');
      await outputFile.writeAsBytes(data);
      
      debugPrint('Media exported to: ${outputFile.path}');
      return true;
    } catch (e) {
      debugPrint('Error exporting media file: $e');
      return false;
    }
  }

  // Clean up old media files
  static Future<void> cleanupOldMedia({int maxAgeInDays = 30}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${directory.path}/media');
      
      if (!await mediaDir.exists()) return;
      
      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeInDays));
      
      await for (final entity in mediaDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            debugPrint('Deleted old media file: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old media: $e');
    }
  }

  // Get media storage statistics
  static Future<Map<String, dynamic>> getMediaStats() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${directory.path}/media');
      
      if (!await mediaDir.exists()) {
        return {
          'totalFiles': 0,
          'totalSize': 0,
          'imageFiles': 0,
          'videoFiles': 0,
          'otherFiles': 0,
        };
      }
      
      int totalFiles = 0;
      int totalSize = 0;
      int imageFiles = 0;
      int videoFiles = 0;
      int otherFiles = 0;
      
      await for (final entity in mediaDir.list(recursive: true)) {
        if (entity is File) {
          totalFiles++;
          final stat = await entity.stat();
          totalSize += stat.size;
          
          final path = entity.path.toLowerCase();
          if (path.contains('/image/')) {
            imageFiles++;
          } else if (path.contains('/video/')) {
            videoFiles++;
          } else {
            otherFiles++;
          }
        }
      }
      
      return {
        'totalFiles': totalFiles,
        'totalSize': totalSize,
        'imageFiles': imageFiles,
        'videoFiles': videoFiles,
        'otherFiles': otherFiles,
      };
    } catch (e) {
      debugPrint('Error getting media stats: $e');
      return {
        'totalFiles': 0,
        'totalSize': 0,
        'imageFiles': 0,
        'videoFiles': 0,
        'otherFiles': 0,
      };
    }
  }

  // Helper methods
  static String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'zip': 'application/zip',
    };
    
    return mimeTypes[extension] ?? 'application/octet-stream';
  }

  static Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    return bytes;
  }
}
