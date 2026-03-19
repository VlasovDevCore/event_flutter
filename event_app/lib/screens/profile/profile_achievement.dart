/// Одно достижение из API `/users/me/achievements` или `/users/:id/achievements`.
class ProfileAchievement {
  const ProfileAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.earned,
  });

  final String id;
  final String title;
  final String description;
  final String iconKey;
  final bool earned;

  static List<ProfileAchievement> listFromApi(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ProfileAchievement.fromApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory ProfileAchievement.fromApi(Map<String, dynamic> m) {
    return ProfileAchievement(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      iconKey: m['icon_key']?.toString() ?? 'star',
      earned: m['earned'] == true,
    );
  }
}
