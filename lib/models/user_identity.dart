import 'package:hive/hive.dart';

part 'user_identity.g.dart';

@HiveType(typeId: 0)
class UserIdentity extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String publicKey;

  @HiveField(2)
  String alias;

  @HiveField(3)
  String? profilePicture;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime lastSeen;

  UserIdentity({
    required this.userId,
    required this.publicKey,
    required this.alias,
    this.profilePicture,
    required this.createdAt,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'publicKey': publicKey,
      'alias': alias,
      'profilePicture': profilePicture,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    return UserIdentity(
      userId: json['userId'],
      publicKey: json['publicKey'],
      alias: json['alias'],
      profilePicture: json['profilePicture'],
      createdAt: DateTime.parse(json['createdAt']),
      lastSeen: DateTime.parse(json['lastSeen']),
    );
  }

  // Generate QR code data for sharing
  String toQRData() {
    return 'oodaa://connect?uid=$userId&pub=$publicKey&alias=${Uri.encodeComponent(alias)}';
  }

  // Parse QR code data
  static UserIdentity? fromQRData(String qrData) {
    try {
      final uri = Uri.parse(qrData);
      if (uri.scheme != 'oodaa' || uri.host != 'connect') {
        return null;
      }

      final userId = uri.queryParameters['uid'];
      final publicKey = uri.queryParameters['pub'];
      final alias = uri.queryParameters['alias'];

      if (userId == null || publicKey == null || alias == null) {
        return null;
      }

      return UserIdentity(
        userId: userId,
        publicKey: publicKey,
        alias: Uri.decodeComponent(alias),
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'UserIdentity(userId: $userId, alias: $alias)';
  }
}
