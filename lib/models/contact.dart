import 'package:hive/hive.dart';
import 'user_identity.dart';

part 'contact.g.dart';

@HiveType(typeId: 4)
enum ContactStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  connected,
  @HiveField(2)
  blocked,
  @HiveField(3)
  offline,
}

@HiveType(typeId: 5)
class Contact extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String publicKey;

  @HiveField(2)
  String alias;

  @HiveField(3)
  String? profilePicture;

  @HiveField(4)
  ContactStatus status;

  @HiveField(5)
  DateTime addedAt;

  @HiveField(6)
  DateTime lastSeen;

  @HiveField(7)
  bool isOnline;

  @HiveField(8)
  String? lastMessageId;

  @HiveField(9)
  DateTime? lastMessageTime;

  @HiveField(10)
  int unreadCount;

  @HiveField(11)
  String? customAlias; // User-defined nickname

  @HiveField(12)
  bool isFavorite;

  @HiveField(13)
  bool isBlocked;

  @HiveField(14)
  String? sharedSecret; // For Double Ratchet

  Contact({
    required this.userId,
    required this.publicKey,
    required this.alias,
    this.profilePicture,
    this.status = ContactStatus.pending,
    required this.addedAt,
    required this.lastSeen,
    this.isOnline = false,
    this.lastMessageId,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.customAlias,
    this.isFavorite = false,
    this.isBlocked = false,
    this.sharedSecret,
  });

  // Create contact from UserIdentity
  factory Contact.fromUserIdentity(UserIdentity identity) {
    return Contact(
      userId: identity.userId,
      publicKey: identity.publicKey,
      alias: identity.alias,
      profilePicture: identity.profilePicture,
      addedAt: DateTime.now(),
      lastSeen: identity.lastSeen,
    );
  }

  // Convert to UserIdentity
  UserIdentity toUserIdentity() {
    return UserIdentity(
      userId: userId,
      publicKey: publicKey,
      alias: alias,
      profilePicture: profilePicture,
      createdAt: addedAt,
      lastSeen: lastSeen,
    );
  }

  // Get display name (custom alias or original alias)
  String get displayName => customAlias ?? alias;

  // Get conversation ID
  String getConversationId(String myUserId) {
    final users = [myUserId, userId]..sort();
    return '${users[0]}_${users[1]}';
  }

  // Update online status
  void updateOnlineStatus(bool online) {
    isOnline = online;
    if (online) {
      lastSeen = DateTime.now();
    }
    save();
  }

  // Update last message info
  void updateLastMessage(String messageId, DateTime messageTime) {
    lastMessageId = messageId;
    lastMessageTime = messageTime;
    save();
  }

  // Increment unread count
  void incrementUnreadCount() {
    unreadCount++;
    save();
  }

  // Clear unread count
  void clearUnreadCount() {
    unreadCount = 0;
    save();
  }

  // Block/unblock contact
  void setBlocked(bool blocked) {
    isBlocked = blocked;
    status = blocked ? ContactStatus.blocked : ContactStatus.connected;
    save();
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'publicKey': publicKey,
      'alias': alias,
      'profilePicture': profilePicture,
      'status': status.name,
      'addedAt': addedAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
      'isOnline': isOnline,
      'lastMessageId': lastMessageId,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'customAlias': customAlias,
      'isFavorite': isFavorite,
      'isBlocked': isBlocked,
    };
  }

  @override
  String toString() {
    return 'Contact(userId: $userId, alias: $alias, status: $status)';
  }
}
