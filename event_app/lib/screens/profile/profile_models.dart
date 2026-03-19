import 'profile_avatar.dart';

class ProfileStats {
  const ProfileStats({
    required this.createdEventsCount,
    required this.totalGoingToMyEventsCount,
    required this.eventsIGoingCount,
    required this.followersCount,
  });

  const ProfileStats.empty()
      : createdEventsCount = 0,
        totalGoingToMyEventsCount = 0,
        eventsIGoingCount = 0,
        followersCount = 0;

  final int createdEventsCount;
  final int totalGoingToMyEventsCount;
  final int eventsIGoingCount;
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
    required this.avatarColorValue,
    required this.avatarIconCodePoint,
    required this.avatarUrl,
    required this.allowMessagesFromNonFriends,
  });

  factory ProfileMe.fromApi(Map<String, dynamic> map) {
    final birth = map['birth_date'] ?? map['birthDate'];
    String? birthDate;
    if (birth is String && birth.isNotEmpty) {
      birthDate = birth.length >= 10 ? birth.substring(0, 10) : birth;
    }
    final avatarColor = map['avatar_color_value'] ?? map['avatarColorValue'];
    final avatarIcon = map['avatar_icon_code'] ?? map['avatarIconCodePoint'];
    final avatarUrl = map['avatar_url'] ?? map['avatarUrl'];
    final allowNonFriends = map['allow_messages_from_non_friends'] ?? map['allowMessagesFromNonFriends'];

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
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
      avatarColorValue: parseInt(avatarColor),
      avatarIconCodePoint: parseInt(avatarIcon),
      avatarUrl: (avatarUrl as String?)?.trim(),
      allowMessagesFromNonFriends: allowNonFriends is bool ? allowNonFriends : true,
    );
  }

  final String? email;
  final String? username;
  final int status;
  final String? displayName;
  final String? bio;
  final String? birthDate; // YYYY-MM-DD
  final String? gender;
  final int? avatarColorValue;
  final int? avatarIconCodePoint;
  final String? avatarUrl;
  final bool allowMessagesFromNonFriends;

  String? resolvedAvatarUrl() => resolveAvatarUrl(avatarUrl);
}

