import 'package:flutter/material.dart';

class BlockedCard extends StatelessWidget {
  const BlockedCard({
    super.key,
    required this.isBlocked,
    required this.isBlockedBy,
  });

  /// Вы заблокировали пользователя.
  final bool isBlocked;

  /// Вас заблокировал пользователь.
  final bool isBlockedBy;

  @override
  Widget build(BuildContext context) {
    final message = isBlocked
        ? 'Вы заблокировали пользователя'
        : (isBlockedBy ? 'Вас заблокировал пользователь' : 'Блокировка');

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/friends/lock-dynamic-color.png',
              width: 34,
              height: 34,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
