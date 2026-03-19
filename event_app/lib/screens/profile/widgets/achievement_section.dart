import 'package:flutter/material.dart';

import '../profile_achievement.dart';

IconData achievementIcon(String iconKey) {
  switch (iconKey) {
    case 'add_location':
      return Icons.add_location_alt_outlined;
    case 'event':
      return Icons.event_available_outlined;
    case 'celebration':
      return Icons.celebration_outlined;
    case 'person_add':
      return Icons.person_add_alt_1_outlined;
    case 'groups':
      return Icons.groups_outlined;
    case 'military_tech':
      return Icons.military_tech_outlined;
    default:
      return Icons.emoji_events_outlined;
  }
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
          children: [
            Text('Достижения', style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('$earnedCount / ${items.length}'),
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
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
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: earned ? 1 : 0,
      color: earned ? colorScheme.primaryContainer.withValues(alpha: 0.35) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: earned ? colorScheme.primary.withValues(alpha: 0.35) : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        achievementIcon(achievement.iconKey),
                        size: 32,
                        color: earned ? colorScheme.primary : colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(achievement.description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Text(
                    earned ? 'Получено' : 'Ещё не получено',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: earned ? colorScheme.primary : colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    achievementIcon(achievement.iconKey),
                    size: 28,
                    color: earned ? colorScheme.primary : colorScheme.outline,
                  ),
                  const Spacer(),
                  if (!earned) Icon(Icons.lock_outline, size: 18, color: colorScheme.outline),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                achievement.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: earned ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
