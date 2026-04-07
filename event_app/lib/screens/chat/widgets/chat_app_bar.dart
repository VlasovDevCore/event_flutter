import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../models/event.dart';
import '../../../services/api_client.dart';
import '../../events/event_details_screen.dart';
import '../../home/widgets/event_preview_participants_row.dart';
import '../../home/widgets/preview_participant.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key, required this.event});

  final Event event;

  static const double _toolbarHeight = 82;

  /// Высота полосы контента app bar (без статус-бара). Для отступа ленты под «плавающий» бар.
  static const double kBarHeight = _toolbarHeight;

  /// Меньше суммарного отступа ленты: пузыри ближе к шапке; стык перекрывает градиент под app bar.
  static const double kListTopInsetTighten = 20;

  /// Верхний inset ленты сообщений (safe area + бар − [kListTopInsetTighten]).
  static double listTopPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kBarHeight - kListTopInsetTighten;

  static String _formatEventDateTimeLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now().toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(local.year, local.month, local.day);
    final tomorrow = today.add(const Duration(days: 1));

    String dayPart;
    if (dateDay == today) {
      dayPart = 'Сегодня';
    } else if (dateDay == tomorrow) {
      dayPart = 'Завтра';
    } else {
      const weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
      dayPart = weekdays[local.weekday % 7];
    }

    final time = DateFormat('HH:mm').format(local);
    return '$dayPart, $time';
  }

  static List<PreviewParticipant> _participantsFromEvent(Event event) {
    if (event.goingUserProfiles.isNotEmpty) {
      return event.goingUserProfiles
          .map(
            (p) => PreviewParticipant(
              label: p.displayName ?? p.username ?? p.email ?? 'U',
              avatarUrl: p.avatarUrl,
              status: p.status,
            ),
          )
          .toList();
    }
    return event.goingUsers
        .map(
          (email) => PreviewParticipant(
            label: email,
            avatarUrl: null,
            status: 1,
          ),
        )
        .toList();
  }

  static bool _isLoggedIn() =>
      Hive.box('authBox').get('token') != null;

  /// Есть ли у пользователя статус «приду» (можно снять участие).
  static bool _canLeaveEvent(Event event) {
    if (!_isLoggedIn()) return false;
    if (event.rsvpStatus == 1) return true;
    final myEmail =
        Hive.box('authBox').get('email')?.toString().trim().toLowerCase();
    if (myEmail != null &&
        myEmail.isNotEmpty &&
        event.goingUsers.any((e) => e.toLowerCase() == myEmail)) {
      return true;
    }
    final myId = Hive.box('authBox').get('userId')?.toString().trim();
    if (myId != null &&
        myId.isNotEmpty &&
        event.goingUserProfiles.any((p) => p.id == myId)) {
      return true;
    }
    return false;
  }

  static void _openEventDetails(BuildContext context, Event event) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailsScreen(event: event),
      ),
    );
  }

  static Future<void> _leaveEvent(BuildContext context, Event event) async {
    try {
      await ApiClient.instance.post(
        '/events/${event.id}/rsvp',
        body: {'status': 0},
        withAuth: true,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.statusCode == 401 ? 'Войдите в аккаунт' : e.message,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  static Future<void> _showLeaveConfirm(
    BuildContext context,
    Event event,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Выйти из события?',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Участие будет отменено, чат события станет недоступен из списка «Участвую».',
          style: TextStyle(fontFamily: 'Inter', height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: scheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Выйти',
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _leaveEvent(context, event);
    }
  }

  static void _showInfoSheet(BuildContext context, Event event) {
    final scheme = Theme.of(context).colorScheme;
    final canLeave = _canLeaveEvent(event);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF25262B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.notifications_none_rounded, color: scheme.primary),
              title: const Text(
                'Уведомления',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showNotificationsSheet(context, event);
              },
            ),
            Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
            ListTile(
              leading: Icon(Icons.event_rounded, color: scheme.primary),
              title: const Text(
                'Подробности события',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _openEventDetails(context, event);
              },
            ),
            if (canLeave) ...[
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: scheme.error),
                title: Text(
                  'Выйти из события',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: scheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLeaveConfirm(context, event);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Future<void> _showNotificationsSheet(BuildContext context, Event event) async {
    final scheme = Theme.of(context).colorScheme;

    Future<DateTime?> loadMutedUntil() async {
      try {
        final data = await ApiClient.instance.get(
          '/events/${event.id}/mute',
          withAuth: true,
        );
        final raw = data['muted_until'];
        if (raw is String && raw.trim().isNotEmpty) {
          return DateTime.tryParse(raw)?.toLocal();
        }
      } catch (_) {}
      return null;
    }

    Future<void> setMuteUntil(DateTime? untilUtc) async {
      await ApiClient.instance.post(
        '/events/${event.id}/mute',
        withAuth: true,
        body: {'muted_until': untilUtc?.toIso8601String()},
      );
    }

    DateTime? mutedUntil = await loadMutedUntil();
    bool isMutedNow() => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF25262B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final muted = isMutedNow();
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.notifications_none_rounded, color: scheme.primary),
                  title: const Text(
                    'Уведомления',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
                  ),
                  subtitle: muted
                      ? Text(
                          'Отключены',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        )
                      : null,
                ),
                if (muted) ...[
                  ListTile(
                    leading: Icon(Icons.notifications_active_rounded, color: scheme.primary),
                    title: const Text('Включить уведомления'),
                    onTap: () async {
                      await setMuteUntil(null);
                      mutedUntil = null;
                      if (ctx.mounted) setState(() {});
                      if (context.mounted) Navigator.pop(ctx);
                    },
                  ),
                  Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
                ],
                ListTile(
                  leading: Icon(Icons.notifications_off_outlined, color: scheme.onSurfaceVariant),
                  title: const Text('Отключить на 1 час'),
                  onTap: () async {
                    final until = DateTime.now().add(const Duration(hours: 1)).toUtc();
                    await setMuteUntil(until);
                    mutedUntil = until.toLocal();
                    if (ctx.mounted) setState(() {});
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.notifications_off_outlined, color: scheme.onSurfaceVariant),
                  title: const Text('Отключить на 8 часов'),
                  onTap: () async {
                    final until = DateTime.now().add(const Duration(hours: 8)).toUtc();
                    await setMuteUntil(until);
                    mutedUntil = until.toLocal();
                    if (ctx.mounted) setState(() {});
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.notifications_off_outlined, color: scheme.onSurfaceVariant),
                  title: const Text('Отключить на 2 дня'),
                  onTap: () async {
                    final until = DateTime.now().add(const Duration(days: 2)).toUtc();
                    await setMuteUntil(until);
                    mutedUntil = until.toLocal();
                    if (ctx.mounted) setState(() {});
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.notifications_off_outlined, color: scheme.onSurfaceVariant),
                  title: const Text('Отключить навсегда'),
                  onTap: () async {
                    final until = DateTime.now().add(const Duration(days: 3650)).toUtc();
                    await setMuteUntil(until);
                    mutedUntil = until.toLocal();
                    if (ctx.mounted) setState(() {});
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const subtitleColor = Color(0xFFB5BBC7);

    final date = event.endsAt ?? event.createdAt;
    final participants = _participantsFromEvent(event);
    final totalGoing = event.goingUsers.length;

    final color = Color(event.markerColorValue);
    final gradientStart = Color.lerp(color, Colors.white, 0.22) ?? color;
    final gradientEnd = Color.lerp(color, Colors.black, 0.22) ?? color;
    final iconData = IconData(
      event.markerIconCodePoint,
      fontFamily: 'MaterialIcons',
    );

    return AppBar(
      toolbarHeight: _toolbarHeight,
      titleSpacing: 0,
      title: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEventDetails(context, event),
          borderRadius: BorderRadius.circular(12),
          splashColor: scheme.primary.withValues(alpha: 0.12),
          highlightColor: scheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [gradientStart, gradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        iconData,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: subtitleColor.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _formatEventDateTimeLabel(date),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFFAAABB0),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 16,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: EventPreviewParticipantsRow(
                                participants: participants,
                                totalGoing: totalGoing,
                                previewLoading: false,
                                color: const Color(0xFF8FF5FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      actions: [
        _RoundIconButton(
          icon: Icons.info_outline_rounded,
          onPressed: () => _showInfoSheet(context, event),
          tooltip: 'О событии',
          alignEnd: true,
        ),
      ],
      leading: _RoundIconButton(
        icon: Icons.arrow_back_rounded,
        onPressed: () => Navigator.of(context).maybePop(),
        alignEnd: false,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.alignEnd = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn = Padding(
      padding: EdgeInsets.only(left: alignEnd ? 0 : 8, right: alignEnd ? 8 : 0),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: scheme.onSurface,
              size: 22,
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
