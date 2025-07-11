import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 1)
enum MessageStatus {
  @HiveField(0)
  sending,
  @HiveField(1)
  sent,
  @HiveField(2)
  delivered,
  @HiveField(3)
  read,
  @HiveField(4)
  failed,
  @HiveField(5)
  expired,
}

@HiveType(typeId: 2)
enum MessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  video,
  @HiveField(3)
  file,
  @HiveField(4)
  audio,
}

@HiveType(typeId: 3)
class Message extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String sender;

  @HiveField(2)
  String receiver;

  @HiveField(3)
  String encryptedContent;

  @HiveField(4)
  MessageType type;

  @HiveField(5)
  MessageStatus status;

  @HiveField(6)
  DateTime timestamp;

  @HiveField(7)
  DateTime? deliveredAt;

  @HiveField(8)
  DateTime? readAt;

  @HiveField(9)
  String? mediaPath; // Local path for media files

  @HiveField(10)
  int? mediaSize; // Size in bytes

  @HiveField(11)
  String? mediaMimeType;

  @HiveField(12)
  bool isFromMe;

  @HiveField(13)
  String? replyToMessageId;

  @HiveField(14)
  DateTime? expiresAt; // For disappearing messages

  Message({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.encryptedContent,
    required this.type,
    required this.status,
    required this.timestamp,
    this.deliveredAt,
    this.readAt,
    this.mediaPath,
    this.mediaSize,
    this.mediaMimeType,
    required this.isFromMe,
    this.replyToMessageId,
    this.expiresAt,
  });

  // Get conversation ID (sorted user IDs)
  String get conversationId {
    final users = [sender, receiver]..sort();
    return '${users[0]}_${users[1]}';
  }

  // Check if message has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Update status
  void updateStatus(MessageStatus newStatus) {
    status = newStatus;
    
    switch (newStatus) {
      case MessageStatus.delivered:
        deliveredAt = DateTime.now();
        break;
      case MessageStatus.read:
        readAt = DateTime.now();
        break;
      default:
        break;
    }
    
    save(); // Save to Hive
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'receiver': receiver,
      'encryptedContent': encryptedContent,
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'mediaPath': mediaPath,
      'mediaSize': mediaSize,
      'mediaMimeType': mediaMimeType,
      'isFromMe': isFromMe,
      'replyToMessageId': replyToMessageId,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Message(id: $id, sender: $sender, type: $type, status: $status)';
  }
}
