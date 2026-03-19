/// Подписки / дружба с другим пользователем (ответ `/friends/relationship/:id`).
class ProfileRelationship {
  const ProfileRelationship({
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isFriends,
  });

  const ProfileRelationship.empty()
      : isFollowing = false,
        isFollowedBy = false,
        isFriends = false;

  factory ProfileRelationship.fromApi(Map<String, dynamic> data) {
    return ProfileRelationship(
      isFollowing: data['isFollowing'] == true,
      isFollowedBy: data['isFollowedBy'] == true,
      isFriends: data['isFriends'] == true,
    );
  }

  final bool isFollowing;
  final bool isFollowedBy;
  final bool isFriends;
}

/// Блокировки между текущим пользователем и другим (ответ `/blocks/status/:id`).
class ProfileBlockStatus {
  const ProfileBlockStatus({
    required this.isBlocked,
    required this.isBlockedBy,
  });

  const ProfileBlockStatus.empty()
      : isBlocked = false,
        isBlockedBy = false;

  factory ProfileBlockStatus.fromApi(Map<String, dynamic> data) {
    return ProfileBlockStatus(
      isBlocked: data['isBlocked'] == true,
      isBlockedBy: data['isBlockedBy'] == true,
    );
  }

  final bool isBlocked;
  final bool isBlockedBy;
}
