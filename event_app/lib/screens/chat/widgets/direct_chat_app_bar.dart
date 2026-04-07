import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
/// Шапка личного чата — высота и кнопки как у [ChatAppBar], контент — собеседник.
class DirectChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DirectChatAppBar({
    super.key,
    required this.peerUserId,
    required this.title,
    required this.isMuted,
    required this.isBlocked,
    required this.canClearChat,
    required this.onMuteFor,
    required this.onUnmute,
    required this.onOpenProfile,
    required this.onDeleteChat,
    required this.onToggleBlockUser,
    this.subtitle,
    this.avatarUrl,
    required this.titleLetter,
  });

  final String peerUserId;
  final String title;
  final bool isMuted;
  final bool isBlocked;
  final bool canClearChat;
  final void Function(Duration duration) onMuteFor;
  final VoidCallback onUnmute;
  final VoidCallback onOpenProfile;
  final VoidCallback onDeleteChat;
  final VoidCallback onToggleBlockUser;
  final String? subtitle;
  final String? avatarUrl;
  final String titleLetter;

  static const double _toolbarHeight = 82;

  /// Совпадает с [ChatAppBar.kBarHeight] — отступ ленты под плавающий бар.
  static const double kBarHeight = _toolbarHeight;

  String? get _fullAvatarUrl => ApiClient.getFullImageUrl(avatarUrl);

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const subtitleColor = Color(0xFFB5BBC7);

    return AppBar(
      toolbarHeight: _toolbarHeight,
      titleSpacing: 0,
      title: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenProfile,
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
                  child: _buildAvatar(context),
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
                          Expanded(
                            child: Text(
                              title,
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
                          if (isMuted) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 16,
                              color: subtitleColor.withValues(alpha: 0.95),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFFAAABB0),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
                              color: subtitleColor.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Личные сообщения',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: subtitleColor.withValues(alpha: 0.95),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
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
        _MoreMenuButton(
          isMuted: isMuted,
          isBlocked: isBlocked,
          canClearChat: canClearChat,
          onMuteFor: onMuteFor,
          onUnmute: onUnmute,
          onOpenProfile: onOpenProfile,
          onDeleteChat: onDeleteChat,
          onToggleBlockUser: onToggleBlockUser,
        ),
      ],
      leading: _RoundIconButton(
        icon: Icons.arrow_back_rounded,
        onPressed: () => Navigator.of(context).maybePop(),
        alignEnd: false,
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final url = _fullAvatarUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5C6BC0),
            Color(0xFF3949AB),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: 50,
                height: 50,
                placeholder: (context, u) => Center(
                  child: Text(
                    titleLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                errorWidget: (context, u, e) => _letterPlaceholder(),
              )
            : _letterPlaceholder(),
      ),
    );
  }

  Widget _letterPlaceholder() {
    return Center(
      child: Text(
        titleLetter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
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

class _MoreMenuButton extends StatelessWidget {
  const _MoreMenuButton({
    required this.isMuted,
    required this.isBlocked,
    required this.canClearChat,
    required this.onMuteFor,
    required this.onUnmute,
    required this.onOpenProfile,
    required this.onDeleteChat,
    required this.onToggleBlockUser,
  });

  final bool isMuted;
  final bool isBlocked;
  final bool canClearChat;
  final void Function(Duration duration) onMuteFor;
  final VoidCallback onUnmute;
  final VoidCallback onOpenProfile;
  final VoidCallback onDeleteChat;
  final VoidCallback onToggleBlockUser;

  Future<void> _showNotificationsSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
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
            ),
            if (isMuted) ...[
              ListTile(
                leading: Icon(Icons.notifications_active_rounded, color: scheme.primary),
                title: const Text('Включить уведомления'),
                onTap: () {
                  Navigator.pop(ctx);
                  onUnmute();
                },
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
            ],
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: scheme.onSurfaceVariant),
              title: const Text('Отключить на 1 час'),
              onTap: () {
                Navigator.pop(ctx);
                onMuteFor(const Duration(hours: 1));
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: scheme.onSurfaceVariant),
              title: const Text('Отключить на 8 часов'),
              onTap: () {
                Navigator.pop(ctx);
                onMuteFor(const Duration(hours: 8));
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: scheme.onSurfaceVariant),
              title: const Text('Отключить на 2 дня'),
              onTap: () {
                Navigator.pop(ctx);
                onMuteFor(const Duration(days: 2));
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: scheme.onSurfaceVariant),
              title: const Text('Отключить навсегда'),
              onTap: () {
                Navigator.pop(ctx);
                onMuteFor(const Duration(days: 3650));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
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
                      leading: Icon(
                        isMuted
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_outlined,
                        color: scheme.primary,
                      ),
                      title: const Text(
                        'Уведомления',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: isMuted
                          ? Text(
                              'Отключены',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showNotificationsSheet(context);
                      },
                    ),
                    Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
                    ListTile(
                      leading: Icon(Icons.person_outline_rounded, color: scheme.primary),
                      title: const Text(
                        'Перейти в профиль',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        onOpenProfile();
                      },
                    ),
                    Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
                    if (canClearChat)
                      ListTile(
                        leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
                        title: Text(
                          'Очистить чат',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            color: scheme.error,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          onDeleteChat();
                        },
                      ),
                    ListTile(
                      leading: Icon(
                        isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                        color: scheme.error,
                      ),
                      title: Text(
                        isBlocked ? 'Разблокировать пользователя' : 'Заблокировать пользователя',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          color: scheme.error,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        onToggleBlockUser();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.more_horiz_rounded, size: 22),
          ),
        ),
      ),
    );
  }
}
