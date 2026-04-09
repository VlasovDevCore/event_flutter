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

  static const double _toolbarHeight = 80;
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
      title: GestureDetector(
        onTap: onOpenProfile,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 50, height: 50, child: _buildAvatar(context)),
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
                            const SizedBox(width: 4),
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

  Widget _buildAvatar(BuildContext context) {
    final url = _fullAvatarUrl;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(
                    Icons.person,
                    color: scheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  Icons.person,
                  color: scheme.onSurfaceVariant,
                  size: 24,
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

  void _showMainMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                icon: isMuted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_outlined,
                title: 'Уведомления',
                subtitle: isMuted ? 'Отключены' : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _showNotificationsSheet(context);
                },
                iconColor: scheme.primary,
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              _MenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Перейти в профиль',
                onTap: () {
                  Navigator.pop(ctx);
                  onOpenProfile();
                },
                iconColor: Colors.white,
              ),
              if (canClearChat) ...[
                Divider(
                  height: 1,
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
                _MenuItem(
                  icon: Icons.delete_outline_rounded,
                  title: 'Очистить чат',
                  onTap: () {
                    Navigator.pop(ctx);
                    onDeleteChat();
                  },
                  iconColor: Colors.white,
                  isDestructive: true,
                ),
              ],
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              _MenuItem(
                icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                title: isBlocked
                    ? 'Разблокировать пользователя'
                    : 'Заблокировать пользователя',
                onTap: () {
                  Navigator.pop(ctx);
                  onToggleBlockUser();
                },
                iconColor: Colors.white,
                isDestructive: true,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                subtitle: isMuted ? 'Отключены' : null,
                iconColor: scheme.primary,
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),

              // Опции отключения (без иконок)
              _MenuItemWithoutIcon(
                title: 'Отключить на 1 час',
                onTap: () {
                  Navigator.pop(ctx);
                  onMuteFor(const Duration(hours: 1));
                },
              ),
              _MenuItemWithoutIcon(
                title: 'Отключить на 8 часов',
                onTap: () {
                  Navigator.pop(ctx);
                  onMuteFor(const Duration(hours: 8));
                },
              ),
              _MenuItemWithoutIcon(
                title: 'Отключить на 2 дня',
                onTap: () {
                  Navigator.pop(ctx);
                  onMuteFor(const Duration(days: 2));
                },
              ),
              _MenuItemWithoutIcon(
                title: 'Отключить навсегда',
                onTap: () {
                  Navigator.pop(ctx);
                  onMuteFor(const Duration(days: 3650));
                },
              ),

              // "Включить уведомления" в самом низу (только если уведомления отключены)
              if (isMuted) ...[
                Divider(
                  height: 1,
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
                _MenuItem(
                  icon: Icons.notifications_active_rounded,
                  title: 'Включить уведомления',
                  onTap: () {
                    Navigator.pop(ctx);
                    onUnmute();
                  },
                  iconColor: Colors.green, // Зелёная иконка
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
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
          onTap: () => _showMainMenu(context),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Center(child: Icon(Icons.more_vert, size: 22)),
          ),
        ),
      ),
    );
  }
}

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
                    fontSize: 16,
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
