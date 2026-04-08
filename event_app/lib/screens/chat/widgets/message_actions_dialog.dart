import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/event_message.dart';

class MessageActionsDialog {
  static Future<String?> _showPopupMenu({
    required BuildContext context,
    required List<PopupMenuEntry<String>> items,
  }) async {
    final padding = MediaQuery.paddingOf(context);

    const margin = 10.0;
    final marginBottom = margin + padding.bottom;

    return showGeneralDialog<String>(
      context: context,
      barrierLabel: 'dismiss',
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim1, anim2) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => Navigator.of(ctx).pop(null),
              ),
            ),
            Positioned(
              left: margin,
              right: margin,
              bottom: marginBottom,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(
                  opacity: curved,
                  child: Material(
                    color: const Color(0xFF25262B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int i = 0; i < items.length; i++)
                          if (items[i] is PopupMenuItem<String>)
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.of(ctx).pop(
                                  (items[i] as PopupMenuItem<String>).value,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 16,
                                  ),
                                  child:
                                      (items[i] as PopupMenuItem<String>).child,
                                ),
                              ),
                            )
                          else if (items[i] is PopupMenuDivider)
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Меню для чужого сообщения (не организатор): копировать и ответить.
  static Future<String?> showParticipantMessageActions(
    BuildContext context,
    EventMessage message,
    VoidCallback onReply,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return _showPopupMenu(
      context: context,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                'Копировать',
                style: const TextStyle(fontSize: 12),
                softWrap: false,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'reply',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply_rounded, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                'Ответить',
                style: const TextStyle(fontSize: 12),
                softWrap: false,
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: message.text));
      } else if (value == 'reply') {
        onReply();
      }
      return value;
    });
  }

  /// Личный чат: копировать, ответить, изменить, удалить.
  static Future<String?> showDirectMyMessageActions(
    BuildContext context,
    EventMessage message,
    bool isSending,
    VoidCallback onEdit,
    VoidCallback onReply,
    VoidCallback onDelete,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isTemp = message.id.startsWith('temp_');
    final canEdit = !isTemp && !isSending;
    final canDelete = isTemp || (!isTemp && !isSending);

    return _showPopupMenu(
      context: context,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                'Копировать',
                style: const TextStyle(fontSize: 12),
                softWrap: false,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (!isTemp) ...[
          PopupMenuItem<String>(
            value: 'reply',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply_rounded, color: Colors.white, size: 24),
                const SizedBox(height: 6),
                Text(
                  'Ответить',
                  style: const TextStyle(fontSize: 12),
                  softWrap: false,
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        if (canEdit) ...[
          PopupMenuItem<String>(
            value: 'edit',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, color: Colors.white, size: 24),
                const SizedBox(height: 6),
                Text(
                  'Изменить',
                  style: const TextStyle(fontSize: 12),
                  softWrap: false,
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        if (canDelete)
          PopupMenuItem<String>(
            value: 'delete',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: const Color(0xFFE34438),
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  'Удалить',
                  style: TextStyle(
                    color: const Color(0xFFE34438),
                    fontSize: 12,
                  ),
                  softWrap: false,
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'copy':
            Clipboard.setData(ClipboardData(text: message.text));
            break;
          case 'reply':
            onReply();
            break;
          case 'edit':
            onEdit();
            break;
          case 'delete':
            onDelete();
            break;
        }
      }
      return value;
    });
  }

  static Future<String?> showMyMessageActions(
    BuildContext context,
    EventMessage message,
    bool isSending,
    VoidCallback onEdit,
    VoidCallback onDelete,
    VoidCallback onReply,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isTemp = message.id.startsWith('temp_');
    final canEdit = !isTemp && !isSending;
    final canDelete = isTemp || (!isTemp && !isSending);

    return _showPopupMenu(
      context: context,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                'Копировать',
                style: const TextStyle(fontSize: 12),
                softWrap: false,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (!isTemp) ...[
          PopupMenuItem<String>(
            value: 'reply',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply_rounded, color: Colors.white, size: 24),
                const SizedBox(height: 6),
                Text(
                  'Ответить',
                  style: const TextStyle(fontSize: 12),
                  softWrap: false,
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        if (canEdit) ...[
          PopupMenuItem<String>(
            value: 'edit',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, color: Colors.white, size: 24),
                const SizedBox(height: 6),
                Text(
                  'Изменить',
                  style: const TextStyle(fontSize: 12),
                  softWrap: false,
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        if (canDelete)
          PopupMenuItem<String>(
            value: 'delete',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: const Color(0xFFE34438),
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  'Удалить',
                  style: TextStyle(
                    color: const Color(0xFFE34438),
                    fontSize: 12,
                  ),
                  softWrap: false,
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'copy':
            Clipboard.setData(ClipboardData(text: message.text));
            break;
          case 'reply':
            onReply();
            break;
          case 'edit':
            onEdit();
            break;
          case 'delete':
            onDelete();
            break;
        }
      }
      return value;
    });
  }

  static Future<String?> showOrganizerOtherMessageActions(
    BuildContext context,
    EventMessage message,
    VoidCallback onDelete,
    VoidCallback onReply,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return _showPopupMenu(
      context: context,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                'Копировать',
                style: const TextStyle(fontSize: 12),
                softWrap: false,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'reply',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply_rounded, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                'Ответить',
                style: const TextStyle(fontSize: 12),
                softWrap: false,
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: const Color(0xFFE34438),
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                'Удалить',
                style: TextStyle(color: const Color(0xFFE34438), fontSize: 12),
                softWrap: false,
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'copy':
            Clipboard.setData(ClipboardData(text: message.text));
            break;
          case 'reply':
            onReply();
            break;
          case 'delete':
            onDelete();
            break;
        }
      }
      return value;
    });
  }

  static Future<bool?> showDeleteConfirmation(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        title: const Text(
          'Удалить сообщение?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        content: const Text(
          'Это действие нельзя отменить.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.35,
            color: Color(0xFFAAABB0),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Удалить',
                style: TextStyle(
                  color: const Color(0xFFFC5B4C),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Отмена',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
