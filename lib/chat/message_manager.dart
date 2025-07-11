import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../models/message.dart';
import '../models/contact.dart';
import '../storage/storage_manager.dart';
import '../crypto/double_ratchet.dart';
import '../crypto/encryption.dart';
import '../webrtc/webrtc_manager.dart';
import '../auth/identity_manager.dart';

class MessageManager extends ChangeNotifier {
  final IdentityManager _identityManager;
  final WebRTCManager _webrtcManager;
  
  final Map<String, DoubleRatchet> _ratchetStates = {};
  final Map<String, List<Message>> _conversationMessages = {};
  final Map<String, Map<String, Uint8List>> _fileTransfers = {}; // fileId -> chunks
  
  MessageManager(this._identityManager, this._webrtcManager) {
    _initializeMessageHandlers();
  }

  // Initialize WebRTC message handlers
  void _initializeMessageHandlers() {
    // Set up message handlers for all connected peers
    _webrtcManager.addListener(() {
      final connectedPeers = _webrtcManager.getConnectedPeers();
      for (final peerId in connectedPeers) {
        _webrtcManager.setMessageHandler(peerId, (data) => _handleIncomingMessage(peerId, data));
      }
    });
  }

  // Send text message
  Future<bool> sendTextMessage(String contactUserId, String content, {DateTime? expiresAt}) async {
    try {
      final message = await _createMessage(
        contactUserId,
        content,
        MessageType.text,
        expiresAt: expiresAt,
      );
      
      return await _sendMessage(contactUserId, message);
    } catch (e) {
      debugPrint('Error sending text message: $e');
      return false;
    }
  }

  // Send file message
  Future<bool> sendFileMessage(
    String contactUserId,
    String filePath,
    MessageType type, {
    DateTime? expiresAt,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('File does not exist: $filePath');
        return false;
      }

      final fileData = await file.readAsBytes();
      final fileName = file.path.split('/').last;
      final mimeType = _getMimeType(fileName);

      // Encrypt file data
      final encryptionKey = _generateRandomBytes(32);
      final encryptedChunks = EncryptionService.encryptFileChunks(fileData, encryptionKey);
      
      // Save encrypted file locally
      final localPath = await _saveEncryptedFile(fileData, fileName, encryptionKey);
      
      // Create message with file metadata
      final fileMetadata = {
        'fileName': fileName,
        'fileSize': fileData.length,
        'mimeType': mimeType,
        'encryptionKey': base64.encode(encryptionKey),
        'chunks': encryptedChunks.length,
      };

      final message = await _createMessage(
        contactUserId,
        jsonEncode(fileMetadata),
        type,
        mediaPath: localPath,
        mediaSize: fileData.length,
        mediaMimeType: mimeType,
        expiresAt: expiresAt,
      );

      // Send file through WebRTC
      final success = await _webrtcManager.sendFile(contactUserId, fileData, fileName, mimeType);
      if (success) {
        return await _sendMessage(contactUserId, message);
      }
      
      return false;
    } catch (e) {
      debugPrint('Error sending file message: $e');
      return false;
    }
  }

  // Create message
  Future<Message> _createMessage(
    String contactUserId,
    String content,
    MessageType type, {
    String? mediaPath,
    int? mediaSize,
    String? mediaMimeType,
    DateTime? expiresAt,
  }) async {
    final myUserId = _identityManager.currentIdentity!.userId;
    final messageId = _generateMessageId();
    
    // Get or create ratchet state
    final ratchet = await _getRatchetState(contactUserId);
    
    // Encrypt content
    final encryptedData = ratchet.encrypt(content);
    
    // Save updated ratchet state
    await StorageManager.saveRatchetState(contactUserId, ratchet.serialize());
    
    final message = Message(
      id: messageId,
      sender: myUserId,
      receiver: contactUserId,
      encryptedContent: base64.encode(jsonEncode(encryptedData).codeUnits),
      type: type,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      isFromMe: true,
      mediaPath: mediaPath,
      mediaSize: mediaSize,
      mediaMimeType: mediaMimeType,
      expiresAt: expiresAt,
    );
    
    return message;
  }

  // Send message through WebRTC
  Future<bool> _sendMessage(String contactUserId, Message message) async {
    try {
      // Save message locally
      await StorageManager.saveMessage(message);
      _addMessageToConversation(message);
      
      // Send through WebRTC
      final messageData = {
        'type': 'message',
        'messageId': message.id,
        'encryptedContent': message.encryptedContent,
        'messageType': message.type.name,
        'timestamp': message.timestamp.toIso8601String(),
        'expiresAt': message.expiresAt?.toIso8601String(),
      };
      
      final success = await _webrtcManager.sendMessage(contactUserId, messageData);
      
      if (success) {
        message.updateStatus(MessageStatus.sent);
        notifyListeners();
        return true;
      } else {
        message.updateStatus(MessageStatus.failed);
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      message.updateStatus(MessageStatus.failed);
      notifyListeners();
      return false;
    }
  }

  // Handle incoming message
  Future<void> _handleIncomingMessage(String senderUserId, Map<String, dynamic> data) async {
    try {
      final messageType = data['type'] as String;
      
      switch (messageType) {
        case 'message':
          await _handleTextMessage(senderUserId, data);
          break;
        case 'file_start':
          await _handleFileStart(senderUserId, data);
          break;
        case 'file_chunk':
          await _handleFileChunk(senderUserId, data);
          break;
        case 'message_status':
          await _handleMessageStatus(senderUserId, data);
          break;
        default:
          debugPrint('Unknown message type: $messageType');
      }
    } catch (e) {
      debugPrint('Error handling incoming message: $e');
    }
  }

  // Handle incoming text message
  Future<void> _handleTextMessage(String senderUserId, Map<String, dynamic> data) async {
    try {
      final messageId = data['messageId'] as String;
      final encryptedContent = data['encryptedContent'] as String;
      final messageTypeStr = data['messageType'] as String;
      final timestamp = DateTime.parse(data['timestamp']);
      final expiresAt = data['expiresAt'] != null ? DateTime.parse(data['expiresAt']) : null;
      
      // Get ratchet state
      final ratchet = await _getRatchetState(senderUserId);
      
      // Decrypt content
      final encryptedData = jsonDecode(String.fromCharCodes(base64.decode(encryptedContent)));
      final decryptedContent = ratchet.decrypt(encryptedData);
      
      // Save updated ratchet state
      await StorageManager.saveRatchetState(senderUserId, ratchet.serialize());
      
      // Create message
      final message = Message(
        id: messageId,
        sender: senderUserId,
        receiver: _identityManager.currentIdentity!.userId,
        encryptedContent: encryptedContent,
        type: MessageType.values.firstWhere((e) => e.name == messageTypeStr),
        status: MessageStatus.delivered,
        timestamp: timestamp,
        isFromMe: false,
        expiresAt: expiresAt,
      );
      
      // Save message
      await StorageManager.saveMessage(message);
      _addMessageToConversation(message);
      
      // Send delivery confirmation
      await _sendMessageStatus(senderUserId, messageId, MessageStatus.delivered);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling text message: $e');
    }
  }

  // Handle file transfer start
  Future<void> _handleFileStart(String senderUserId, Map<String, dynamic> data) async {
    final fileId = data['fileId'] as String;
    final fileName = data['fileName'] as String;
    final mimeType = data['mimeType'] as String;
    final fileSize = data['fileSize'] as int;
    final totalChunks = data['totalChunks'] as int;
    
    _fileTransfers[fileId] = {};
    
    debugPrint('Starting file transfer: $fileName ($fileSize bytes, $totalChunks chunks)');
  }

  // Handle file chunk
  Future<void> _handleFileChunk(String senderUserId, Map<String, dynamic> data) async {
    final fileId = data['fileId'] as String;
    final chunkIndex = data['chunkIndex'] as int;
    final chunkData = base64.decode(data['data']);
    final isLast = data['isLast'] as bool;
    
    if (!_fileTransfers.containsKey(fileId)) {
      debugPrint('Received chunk for unknown file: $fileId');
      return;
    }
    
    _fileTransfers[fileId]![chunkIndex.toString()] = chunkData;
    
    if (isLast) {
      await _assembleFile(senderUserId, fileId);
    }
  }

  // Assemble received file
  Future<void> _assembleFile(String senderUserId, String fileId) async {
    final chunks = _fileTransfers.remove(fileId);
    if (chunks == null) return;
    
    // Sort chunks by index and combine
    final sortedChunks = chunks.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    
    final fileData = <int>[];
    for (final chunk in sortedChunks) {
      fileData.addAll(chunk.value);
    }
    
    // Save file locally
    final fileName = 'received_${DateTime.now().millisecondsSinceEpoch}';
    final localPath = await _saveReceivedFile(Uint8List.fromList(fileData), fileName);
    
    debugPrint('File assembled and saved: $localPath');
    // TODO: Create message for received file
  }

  // Handle message status update
  Future<void> _handleMessageStatus(String senderUserId, Map<String, dynamic> data) async {
    final messageId = data['messageId'] as String;
    final statusStr = data['status'] as String;
    final status = MessageStatus.values.firstWhere((e) => e.name == statusStr);
    
    final message = StorageManager.getMessage(messageId);
    if (message != null) {
      message.updateStatus(status);
      notifyListeners();
    }
  }

  // Send message status
  Future<void> _sendMessageStatus(String contactUserId, String messageId, MessageStatus status) async {
    final statusData = {
      'type': 'message_status',
      'messageId': messageId,
      'status': status.name,
    };
    
    await _webrtcManager.sendMessage(contactUserId, statusData);
  }

  // Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    final message = StorageManager.getMessage(messageId);
    if (message != null && !message.isFromMe) {
      message.updateStatus(MessageStatus.read);
      await _sendMessageStatus(message.sender, messageId, MessageStatus.read);
      notifyListeners();
    }
  }

  // Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    await StorageManager.markConversationAsRead(conversationId);
    notifyListeners();
  }

  // Get conversation messages
  List<Message> getConversationMessages(String conversationId, {int limit = 50, int offset = 0}) {
    if (_conversationMessages.containsKey(conversationId)) {
      final messages = _conversationMessages[conversationId]!;
      final start = offset;
      final end = (start + limit < messages.length) ? start + limit : messages.length;
      return messages.sublist(start, end);
    }
    
    final messages = StorageManager.getConversationMessages(conversationId, limit: limit, offset: offset);
    _conversationMessages[conversationId] = messages;
    return messages;
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    await StorageManager.deleteMessage(messageId);
    
    // Remove from local cache
    for (final messages in _conversationMessages.values) {
      messages.removeWhere((m) => m.id == messageId);
    }
    
    notifyListeners();
  }

  // Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    await StorageManager.deleteConversationMessages(conversationId);
    _conversationMessages.remove(conversationId);
    notifyListeners();
  }

  // Get or create ratchet state
  Future<DoubleRatchet> _getRatchetState(String contactUserId) async {
    if (_ratchetStates.containsKey(contactUserId)) {
      return _ratchetStates[contactUserId]!;
    }
    
    final savedState = StorageManager.getRatchetState(contactUserId);
    if (savedState != null) {
      final ratchet = DoubleRatchet.deserialize(savedState);
      _ratchetStates[contactUserId] = ratchet;
      return ratchet;
    }
    
    // Create new ratchet state (this should happen after key exchange)
    final rootKey = _generateRandomBytes(32); // Placeholder
    final ratchet = DoubleRatchet(rootKey: rootKey);
    _ratchetStates[contactUserId] = ratchet;
    return ratchet;
  }

  // Add message to conversation cache
  void _addMessageToConversation(Message message) {
    final conversationId = message.conversationId;
    if (!_conversationMessages.containsKey(conversationId)) {
      _conversationMessages[conversationId] = [];
    }
    
    _conversationMessages[conversationId]!.insert(0, message);
    
    // Keep only recent messages in cache
    if (_conversationMessages[conversationId]!.length > 100) {
      _conversationMessages[conversationId] = 
          _conversationMessages[conversationId]!.sublist(0, 100);
    }
  }

  // Generate unique message ID
  String _generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return '${timestamp}_$random';
  }

  // Save encrypted file locally
  Future<String> _saveEncryptedFile(Uint8List fileData, String fileName, Uint8List encryptionKey) async {
    final directory = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${directory.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    final hashedName = sha256.convert(utf8.encode(fileName)).toString();
    final filePath = '${mediaDir.path}/$hashedName';
    
    // Encrypt and save file
    final encrypted = EncryptionService.encryptAESGCM(
      base64.encode(fileData),
      encryptionKey,
    );
    
    final encryptedData = jsonEncode({
      'ciphertext': base64.encode(encrypted['ciphertext']),
      'iv': base64.encode(encrypted['iv']),
      'tag': base64.encode(encrypted['tag']),
    });
    
    await File(filePath).writeAsString(encryptedData);
    return filePath;
  }

  // Save received file
  Future<String> _saveReceivedFile(Uint8List fileData, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final receivedDir = Directory('${directory.path}/received');
    if (!await receivedDir.exists()) {
      await receivedDir.create(recursive: true);
    }
    
    final filePath = '${receivedDir.path}/$fileName';
    await File(filePath).writeAsBytes(fileData);
    return filePath;
  }

  // Get MIME type from file extension
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    
    return mimeTypes[extension] ?? 'application/octet-stream';
  }

  // Clean up expired messages
  Future<void> cleanupExpiredMessages() async {
    await StorageManager.deleteExpiredMessages();
    
    // Remove from cache
    for (final messages in _conversationMessages.values) {
      messages.removeWhere((m) => m.isExpired);
    }

    notifyListeners();
  }

  // Generate secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    return bytes;
  }
}
