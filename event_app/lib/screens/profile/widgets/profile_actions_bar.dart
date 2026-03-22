import 'package:flutter/material.dart';

class ProfileActionsBar extends StatelessWidget {
  const ProfileActionsBar({
    super.key,
    required this.onBackPressed,
    required this.isMe,
    this.buttonSize = 37.0,
    this.iconSize = 18.0,
    this.iconColor = Colors.white,
    this.buttonBackgroundColor = const Color.fromARGB(157, 0, 0, 0),
    this.buttonBorderRadius = 12.0,
    this.splashColor = const Color.fromARGB(157, 0, 0, 0),
    this.highlightColor = const Color.fromARGB(157, 0, 0, 0),
    this.onEditPressed,
    this.onQrPressed,
    this.onLogoutPressed,
    this.onBlockPressed,
    this.onUnblockPressed,
    this.isSaving = false,
    this.isBlocked = false,
    this.menuBackgroundColor = const Color.fromARGB(255, 0, 0, 0),
    this.menuItemBorderRadius = 0.0,
  });

  final VoidCallback onBackPressed;
  final bool isMe;
  final VoidCallback? onEditPressed;
  final VoidCallback? onQrPressed;
  final VoidCallback? onLogoutPressed;
  final VoidCallback? onBlockPressed;
  final VoidCallback? onUnblockPressed;
  final bool isSaving;
  final bool isBlocked;
  final double buttonSize;
  final Color iconColor;
  final double iconSize;
  final Color menuBackgroundColor;
  final Color splashColor;
  final Color highlightColor;
  final Color buttonBackgroundColor;
  final double buttonBorderRadius;
  final double menuItemBorderRadius;

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ActionMenu(
        onEditPressed: onEditPressed,
        onQrPressed: onQrPressed,
        onLogoutPressed: onLogoutPressed,
        onBlockPressed: onBlockPressed,
        onUnblockPressed: onUnblockPressed,
        isSaving: isSaving,
        isBlocked: isBlocked,
        iconColor: iconColor,
        iconSize: iconSize,
        backgroundColor: menuBackgroundColor,
        splashColor: splashColor,
        highlightColor: highlightColor,
        itemBorderRadius: menuItemBorderRadius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Левая сторона - кнопка назад
          _ActionButton(
            tooltip: 'Назад',
            onPressed: onBackPressed,
            child: Icon(Icons.arrow_back, size: iconSize, color: iconColor),
            size: buttonSize,
            splashColor: splashColor,
            highlightColor: highlightColor,
            backgroundColor: buttonBackgroundColor,
            borderRadius: buttonBorderRadius,
          ),

          // Правая сторона - меню с тремя точками
          _ActionButton(
            tooltip: 'Меню',
            onPressed: () => _showMenu(context),
            child: Icon(Icons.more_vert, size: iconSize, color: iconColor),
            size: buttonSize,
            splashColor: splashColor,
            highlightColor: highlightColor,
            backgroundColor: buttonBackgroundColor,
            borderRadius: buttonBorderRadius,
          ),
        ],
      ),
    );
  }
}

// Компонент меню с действиями
class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.onEditPressed,
    required this.onQrPressed,
    required this.onLogoutPressed,
    required this.onBlockPressed,
    required this.onUnblockPressed,
    required this.isSaving,
    required this.isBlocked,
    required this.iconColor,
    required this.iconSize,
    required this.backgroundColor,
    required this.splashColor,
    required this.highlightColor,
    required this.itemBorderRadius,
  });

  final VoidCallback? onEditPressed;
  final VoidCallback? onQrPressed;
  final VoidCallback? onLogoutPressed;
  final VoidCallback? onBlockPressed;
  final VoidCallback? onUnblockPressed;
  final bool isSaving;
  final bool isBlocked;
  final Color iconColor;
  final double iconSize;
  final Color backgroundColor;
  final Color splashColor;
  final Color highlightColor;
  final double itemBorderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),

          // Кнопка редактирования (только для своего профиля)
          if (onEditPressed != null)
            _MenuItem(
              icon: Icons.edit,
              title: 'Редактировать профиль',
              onTap: () {
                Navigator.pop(context);
                onEditPressed?.call();
              },
              iconColor: iconColor,
              iconSize: iconSize,
              isDisabled: isSaving,
              splashColor: splashColor,
              highlightColor: highlightColor,
              borderRadius: itemBorderRadius,
            ),

          // QR код (для всех)
          if (onQrPressed != null)
            _MenuItem(
              icon: Icons.qr_code,
              title: 'QR код профиля',
              onTap: () {
                Navigator.pop(context);
                onQrPressed?.call();
              },
              iconColor: iconColor,
              iconSize: iconSize,
              isDisabled: isSaving,
              splashColor: splashColor,
              highlightColor: highlightColor,
              borderRadius: itemBorderRadius,
            ),

          // Блокировка/разблокировка (только для чужих профилей)
          if (onBlockPressed != null || onUnblockPressed != null) ...[
            const Divider(height: 1, color: Color.fromARGB(179, 41, 41, 41)),
            if (!isBlocked && onBlockPressed != null)
              _MenuItem(
                icon: Icons.block,
                title: 'Заблокировать',
                onTap: () {
                  Navigator.pop(context);
                  onBlockPressed?.call();
                },
                iconColor: Colors.red, // Красный цвет для иконки блокировки
                iconSize: iconSize,
                isDisabled: isSaving,
                isDestructive: true, // Красный текст
                splashColor: splashColor,
                highlightColor: highlightColor,
                borderRadius: itemBorderRadius,
              ),
            if (isBlocked && onUnblockPressed != null)
              _MenuItem(
                icon: Icons.block_flipped,
                title: 'Разблокировать',
                onTap: () {
                  Navigator.pop(context);
                  onUnblockPressed?.call();
                },
                iconColor: iconColor, // Белый цвет для иконки
                iconSize: iconSize,
                isDisabled: isSaving,
                isDestructive: false, // Белый текст
                splashColor: splashColor,
                highlightColor: highlightColor,
                borderRadius: itemBorderRadius,
              ),
          ],

          // Выход (только для своего профиля)
          if (onLogoutPressed != null) ...[
            const Divider(height: 1, color: Color.fromARGB(179, 41, 41, 41)),
            _MenuItem(
              icon: Icons.logout,
              title: 'Выйти',
              onTap: () {
                Navigator.pop(context);
                onLogoutPressed?.call();
              },
              iconColor: iconColor,
              iconSize: iconSize,
              isDisabled: isSaving,
              isDestructive: true, // Красный текст для выхода
              splashColor: splashColor,
              highlightColor: highlightColor,
              borderRadius: itemBorderRadius,
            ),
          ],
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.iconColor,
    required this.iconSize,
    this.isDisabled = false,
    this.isDestructive = false,
    required this.splashColor,
    required this.highlightColor,
    required this.borderRadius,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;
  final double iconSize;
  final bool isDisabled;
  final bool isDestructive;
  final Color splashColor;
  final Color highlightColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: isDisabled ? null : onTap,
        splashColor: splashColor,
        highlightColor: highlightColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: iconSize,
                color: iconColor, // Используем переданный цвет
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isDestructive ? Colors.red : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isDisabled)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    required this.size,
    required this.splashColor,
    required this.highlightColor,
    required this.backgroundColor,
    required this.borderRadius,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final double size;
  final Color splashColor;
  final Color highlightColor;
  final Color backgroundColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onPressed,
          splashColor: splashColor,
          highlightColor: highlightColor,
          child: Center(child: child),
        ),
      ),
    );
  }
}
