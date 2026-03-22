/// Одно достижение из API `/users/me/achievements` или `/users/:id/achievements`.
class ProfileAchievement {
  const ProfileAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.earned,
    required this.progress,
    required this.progressCurrent,
    required this.progressTarget,
  });

  final String id;
  final String title;
  final String description;
  final String iconKey;
  final bool earned;
  /// 0..1 — с сервера; для старых ответов без поля выводится из [earned].
  final double progress;
  /// Текущее и целевое значение для подписи «N / M»; при [progressTarget] == 0 счётчик не показывается.
  final int progressCurrent;
  final int progressTarget;

  /// Для отображения «N / M»: текущее не больше цели (не бывает 10/5).
  int get progressCurrentDisplay =>
      progressTarget <= 0 ? 0 : (progressCurrent > progressTarget ? progressTarget : progressCurrent);

  static List<ProfileAchievement> listFromApi(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ProfileAchievement.fromApi(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory ProfileAchievement.fromApi(Map<String, dynamic> m) {
    final earned = m['earned'] == true;
    final rawProgress = m['progress'];
    double progress;
    if (rawProgress is num) {
      progress = rawProgress.toDouble().clamp(0.0, 1.0);
    } else {
      progress = earned ? 1.0 : 0.0;
    }
    final pc = m['progress_current'];
    final pt = m['progress_target'];
    final progressCurrent = pc is num ? pc.toInt() : 0;
    final progressTarget = pt is num ? pt.toInt() : 0;

    return ProfileAchievement(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      iconKey: m['icon_key']?.toString() ?? 'trophy-dynamic-color',
      earned: earned,
      progress: progress,
      progressCurrent: progressCurrent,
      progressTarget: progressTarget,
    );
  }
}
