import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../profile_achievement.dart';

/// Путь к PNG в [assets/achievements/]. Поддерживает старые `icon_key` с бэка (Material-имена).
String achievementImageAsset(String iconKey) {
  if (iconKey.isEmpty) {
    return 'assets/achievements/trophy-dynamic-color.png';
  }
  switch (iconKey) {
    case 'add_location':
      return 'assets/achievements/calender-dynamic-color.png';
    case 'event':
      return 'assets/achievements/hash-dynamic-color.png';
    case 'celebration':
      return 'assets/achievements/takeaway-cup-dynamic-color.png';
    case 'person_add':
      return 'assets/achievements/minecraft-dynamic-color.png';
    case 'groups':
      return 'assets/achievements/crow-dynamic-color.png';
    case 'military_tech':
    case 'star':
      return 'assets/achievements/trophy-dynamic-color.png';
  }
  return 'assets/achievements/$iconKey.png';
}

Widget _achievementProgressCaption(
  BuildContext context,
  ProfileAchievement a, {
  required Color color,
}) {
  if (a.progressTarget <= 0) return const SizedBox.shrink();
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      '${a.progressCurrentDisplay} / ${a.progressTarget}',
      textAlign: TextAlign.center,
      style: theme.textTheme.labelMedium?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Полоса прогресса: [p] 0..1, визуально не шире 100%.
Widget _achievementProgressBar({
  required double progress,
  required bool earned,
  required double height,
}) {
  final p = math.min(1.0, math.max(0.0, progress));
  return ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0x33FFFFFF)),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: p,
              child: Container(
                decoration: BoxDecoration(
                  gradient: earned
                      ? const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : LinearGradient(
                          colors: [
                            Colors.grey.shade700,
                            Colors.grey.shade600,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showAchievementDialog(BuildContext context, ProfileAchievement achievement) {
  final theme = Theme.of(context);
  final earned = achievement.earned;
  final p = achievement.progress.clamp(0.0, 1.0);

  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF232323),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AchievementImage(
                          iconKey: achievement.iconKey,
                          earned: earned,
                          size: 64, // Увеличил с 48 до 64
                        ),
                        const SizedBox(height: 12),
                        Text(
                          achievement.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Inter', // Добавил шрифт Inter
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      achievement.description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        height: 1.35,
                        fontFamily: 'Inter', // Добавил шрифт Inter
                      ),
                    ),
                    const SizedBox(height: 16),
                    _achievementProgressBar(
                      progress: p,
                      earned: earned,
                      height: 6,
                    ),
                    _achievementProgressCaption(
                      ctx,
                      achievement,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      earned ? 'Получено' : 'Ещё не получено',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: earned ? const Color(0xFFFFD700) : Colors.white54,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter', // Добавил шрифт Inter
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
              color: Colors.black,
              iconSize: 23,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Секция «Достижения»: сетка карточек (получено / заблокировано).
class AchievementSection extends StatelessWidget {
  const AchievementSection({
    super.key,
    required this.items,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  final List<ProfileAchievement> items;
  final bool isLoading;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Не удалось загрузить достижения',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Повторить')),
            ],
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final earnedCount = items.where((e) => e.earned).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Достижения',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 19,
              ),
            ),
            Text(
              '$earnedCount / ${items.length}',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final w = constraints.maxWidth;
            final cols = w >= 400 ? 3 : 2;
            final tileW = (w - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: items.map((a) {
                return SizedBox(
                  width: tileW,
                  child: _AchievementTile(achievement: a),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final ProfileAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earned = achievement.earned;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAchievementDialog(context, achievement),
        borderRadius: BorderRadius.circular(12),
        highlightColor: Colors.black.withValues(alpha: 0.1), // Цвет при удержании (светлый)
        splashColor: Colors.black.withValues(alpha: 0.2), // Цвет волны при нажатии
        hoverColor: Colors.black.withValues(alpha: 0.05), // Цвет при наведении (для веба)
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _AchievementImage(
                        iconKey: achievement.iconKey,
                        earned: earned,
                        size: 60,
                      ),
                      if (!earned)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: Colors.white54,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                achievement.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              _achievementProgressBar(
                progress: achievement.progress.clamp(0.0, 1.0),
                earned: earned,
                height: 5,
              ),
              _achievementProgressCaption(
                context,
                achievement,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementImage extends StatelessWidget {
  const _AchievementImage({
    required this.iconKey,
    required this.earned,
    required this.size,
  });

  final String iconKey;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final path = achievementImageAsset(iconKey);
    return Opacity(
      opacity: earned ? 1 : 0.45,
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.emoji_events_outlined,
            size: size,
            color: earned ? colorScheme.primary : colorScheme.outline,
          );
        },
      ),
    );
  }
}