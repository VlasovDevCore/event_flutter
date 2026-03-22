import 'profile_avatar.dart';

class ProfileStats {
  const ProfileStats({
    required this.createdEventsCount,
    required this.totalGoingToMyEventsCount,
    required this.eventsIGoingCount,
    required this.eventsIGoingAsGuestCount,
    required this.followersCount,
  });

  const ProfileStats.empty()
      : createdEventsCount = 0,
        totalGoingToMyEventsCount = 0,
        eventsIGoingCount = 0,
        eventsIGoingAsGuestCount = 0,
        followersCount = 0;

  final int createdEventsCount;
  final int totalGoingToMyEventsCount;
  final int eventsIGoingCount;
  /// «Приду» на чужих встречах (не как создатель своей).
  final int eventsIGoingAsGuestCount;
  final int followersCount;
}

class ProfileMe {
  const ProfileMe({
    required this.email,
    required this.username,
    required this.status,
    required this.displayName,
    required this.bio,
    required this.birthDate,
    required this.gender,
    required this.avatarUrl,
    required this.allowMessagesFromNonFriends,
    this.createdAt,
  });

  factory ProfileMe.fromApi(Map<String, dynamic> map) {
    final birth = map['birth_date'] ?? map['birthDate'];
    String? birthDate;
    if (birth is String && birth.isNotEmpty) {
      birthDate = birth.length >= 10 ? birth.substring(0, 10) : birth;
    }
    final avatarUrl = map['avatar_url'] ?? map['avatarUrl'];
    final allowNonFriends = map['allow_messages_from_non_friends'] ?? map['allowMessagesFromNonFriends'];

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    DateTime? createdAt;
    final createdRaw = map['created_at'] ?? map['createdAt'];
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    return ProfileMe(
      email: (map['email'] as String?)?.trim(),
      username: (map['username'] as String?)?.trim(),
      status: parseInt(map['status']) ?? 1,
      displayName:
          (map['display_name'] as String?)?.trim() ?? (map['displayName'] as String?)?.trim(),
      bio: (map['bio'] as String?)?.trim(),
      birthDate: birthDate,
      gender: (map['gender'] as String?)?.trim(),
      avatarUrl: (avatarUrl as String?)?.trim(),
      allowMessagesFromNonFriends: allowNonFriends is bool ? allowNonFriends : true,
      createdAt: createdAt,
    );
  }

  final String? email;
  final String? username;
  final int status;
  final String? displayName;
  final String? bio;
  final String? birthDate; // YYYY-MM-DD
  final String? gender;
  final String? avatarUrl;
  final bool allowMessagesFromNonFriends;
  /// Дата регистрации (из API `created_at`).
  final DateTime? createdAt;

  String? resolvedAvatarUrl() => resolveAvatarUrl(avatarUrl);
}

