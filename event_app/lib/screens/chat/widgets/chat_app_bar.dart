import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../models/event.dart';
import '../../../services/api_client.dart';
import '../../events/event_details_screen.dart';
import '../../home/widgets/event_preview_participants_row.dart';
import '../../home/widgets/preview_participant.dart';

// ============================================================================
// Вспомогательные виджеты для меню
// ============================================================================

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    required this.iconColor,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color iconColor;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 23, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: isDestructive ? Colors.red : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFFAAABB0),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemWithoutIcon extends StatelessWidget {
  const _MenuItemWithoutIcon({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

    Widget btn = SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(child: Icon(icon, color: scheme.onSurface, size: 22)),
        ),
      ),
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }

    if (alignEnd) {
      btn = Padding(padding: const EdgeInsets.only(right: 8), child: btn);
    } else {
      btn = Padding(padding: const EdgeInsets.only(left: 8), child: btn);
    }

    return btn;
  }
}

// ============================================================================
// ChatAppBar
// ============================================================================

class ChatAppBar extends StatefulWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key, required this.event});

  final Event event;

  static const double _toolbarHeight = 80;
  static const double kBarHeight = 10;
  static const double kListTopInsetTighten = 20;

  static double listTopPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kBarHeight - kListTopInsetTighten;

  @override
  State<ChatAppBar> createState() => _ChatAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);
}

class _ChatAppBarState extends State<ChatAppBar> {
  bool _isMuted = false;
  static const double _toolbarHeight = 80;

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
          (email) =>
              PreviewParticipant(label: email, avatarUrl: null, status: 1),
        )
        .toList();
  }

  static bool _isLoggedIn() => Hive.box('authBox').get('token') != null;

  static bool _canLeaveEvent(Event event) {
    if (!_isLoggedIn()) return false;
    if (event.rsvpStatus == 1) return true;
    final myEmail = Hive.box(
      'authBox',
    ).get('email')?.toString().trim().toLowerCase();
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
      MaterialPageRoute<void>(builder: (_) => EventDetailsScreen(event: event)),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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

  void _showInfoSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canLeave = _canLeaveEvent(widget.event);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _MenuItem(
                icon: Icons.notifications_none_rounded,
                title: 'Уведомления',
                onTap: () {
                  Navigator.pop(ctx);
                  _showNotificationsSheet(context);
                },
                iconColor: Colors.white,
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              _MenuItem(
                icon: Icons.event_rounded,
                title: 'Подробности события',
                subtitle: widget.event.title,
                onTap: () {
                  Navigator.pop(ctx);
                  _openEventDetails(context, widget.event);
                },
                iconColor: scheme.primary,
              ),
              if (canLeave) ...[
                Divider(
                  height: 1,
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
                _MenuItem(
                  icon: Icons.logout_rounded,
                  title: 'Выйти из события',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLeaveConfirm(context, widget.event);
                  },
                  iconColor: Colors.white,
                  isDestructive: true,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationsSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;

    Future<DateTime?> loadMutedUntil() async {
      try {
        final data = await ApiClient.instance.get(
          '/events/${widget.event.id}/mute',
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
        '/events/${widget.event.id}/mute',
        withAuth: true,
        body: {'muted_until': untilUtc?.toIso8601String()},
      );
      if (untilUtc == null) {
        setState(() => _isMuted = false);
      } else {
        setState(() => _isMuted = untilUtc.isAfter(DateTime.now()));
      }
    }

    DateTime? mutedUntil = await loadMutedUntil();
    bool isMutedNow() =>
        mutedUntil != null && mutedUntil!.isAfter(DateTime.now());

    if (mounted) {
      setState(() => _isMuted = isMutedNow());
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSheet) {
          final muted = isMutedNow();
          return Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  _MenuItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Уведомления',
                    subtitle: muted ? 'Отключены' : null,
                    iconColor: scheme.primary,
                  ),
                  Divider(
                    height: 1,
                    color: scheme.outline.withValues(alpha: 0.2),
                  ),
                  _MenuItemWithoutIcon(
                    title: 'Отключить на 1 час',
                    onTap: () async {
                      final until = DateTime.now()
                          .add(const Duration(hours: 1))
                          .toUtc();
                      await setMuteUntil(until);
                      if (ctx.mounted) setStateSheet(() {});
                      if (context.mounted) Navigator.pop(ctx);
                    },
                  ),
                  _MenuItemWithoutIcon(
                    title: 'Отключить на 8 часов',
                    onTap: () async {
                      final until = DateTime.now()
                          .add(const Duration(hours: 8))
                          .toUtc();
                      await setMuteUntil(until);
                      if (ctx.mounted) setStateSheet(() {});
                      if (context.mounted) Navigator.pop(ctx);
                    },
                  ),
                  _MenuItemWithoutIcon(
                    title: 'Отключить на 2 дня',
                    onTap: () async {
                      final until = DateTime.now()
                          .add(const Duration(days: 2))
                          .toUtc();
                      await setMuteUntil(until);
                      if (ctx.mounted) setStateSheet(() {});
                      if (context.mounted) Navigator.pop(ctx);
                    },
                  ),
                  _MenuItemWithoutIcon(
                    title: 'Отключить навсегда',
                    onTap: () async {
                      final until = DateTime.now()
                          .add(const Duration(days: 3650))
                          .toUtc();
                      await setMuteUntil(until);
                      if (ctx.mounted) setStateSheet(() {});
                      if (context.mounted) Navigator.pop(ctx);
                    },
                  ),
                  if (muted) ...[
                    Divider(
                      height: 1,
                      color: scheme.outline.withValues(alpha: 0.2),
                    ),
                    _MenuItem(
                      icon: Icons.notifications_active_rounded,
                      title: 'Включить уведомления',
                      onTap: () async {
                        await setMuteUntil(null);
                        if (ctx.mounted) setStateSheet(() {});
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      iconColor: Colors.lightGreen,
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadMuteStatus() async {
    try {
      final data = await ApiClient.instance.get(
        '/events/${widget.event.id}/mute',
        withAuth: true,
      );
      final raw = data['muted_until'];
      if (raw is String && raw.trim().isNotEmpty) {
        final until = DateTime.tryParse(raw)?.toLocal();
        if (mounted) {
          setState(() {
            _isMuted = until != null && until.isAfter(DateTime.now());
          });
        }
      } else {
        if (mounted) setState(() => _isMuted = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isMuted = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMuteStatus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const subtitleColor = Color(0xFFB5BBC7);

    final date = widget.event.endsAt ?? widget.event.createdAt;
    final participants = _participantsFromEvent(widget.event);
    final totalGoing = widget.event.goingUsers.length;

    final color = Color(widget.event.markerColorValue);
    final gradientStart = Color.lerp(color, Colors.white, 0.22) ?? color;
    final gradientEnd = Color.lerp(color, Colors.black, 0.22) ?? color;
    final iconData = IconData(
      widget.event.markerIconCodePoint,
      fontFamily: 'MaterialIcons',
    );

    return AppBar(
      toolbarHeight: _toolbarHeight,
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () => _openEventDetails(context, widget.event),
        child: Material(
          color: Colors.transparent,
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
                      child: Icon(iconData, size: 20, color: Colors.white),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.event.title,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isMuted) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 17,
                              color: const Color(0xFFB5BBC7).withOpacity(0.9),
                            ),
                          ],
                        ],
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
                              softWrap: false,
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
                          EventPreviewParticipantsRow(
                            participants: participants,
                            totalGoing: totalGoing,
                            previewLoading: false,
                            color: Colors.white,
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
          icon: Icons.more_vert,
          onPressed: () => _showInfoSheet(context),
          alignEnd: true,
        ),
      ],
      leading: Padding(
        padding: const EdgeInsets.only(left: 0, right: 6, top: 18, bottom: 18),
        child: _RoundIconButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).maybePop(),
          alignEnd: false,
        ),
      ),
    );
  }
}
