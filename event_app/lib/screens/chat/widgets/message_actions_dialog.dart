import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/event_message.dart';

class MessageActionsDialog {
  static RelativeRect _positionFromGlobalOffset(
    BuildContext context,
    Offset globalPosition,
  ) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final local = overlay.globalToLocal(globalPosition);
    final rect = Rect.fromLTWH(local.dx, local.dy, 0, 0);
    return RelativeRect.fromRect(rect, Offset.zero & overlay.size);
  }

  static Future<String?> _showPopupMenu({
    required BuildContext context,
    required RelativeRect position,
    required List<PopupMenuEntry<String>> items,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final screen = Offset.zero & overlay.size;

    const menuWidth = 240.0;
    const margin = 10.0;
    const itemExtent = 48.0;
    const dividerExtent = 1.0;

    final left0 = position.left;
    final top0 = position.top;

    final itemCount = items.whereType<PopupMenuItem<String>>().length;
    final dividerCount = items.whereType<PopupMenuDivider>().length;
    final estimatedMenuHeight =
        itemCount * itemExtent + dividerCount * dividerExtent;

    final left = left0.clamp(margin, screen.width - menuWidth - margin);
    final maxTop = (screen.height - estimatedMenuHeight - margin);
    final top = top0.clamp(margin, maxTop < margin ? margin : maxTop);

    return showGeneralDialog<String>(
      context: context,
      barrierLabel: 'dismiss',
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => Navigator.of(ctx).pop(null),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: Material(
                color: scheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in items)
                      if (entry is PopupMenuItem<String>)
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(entry.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: DefaultTextStyle(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              child: IconTheme(
                                data: IconThemeData(
                                  color: scheme.primary,
                                  size: 20,
                                ),
                                child: entry.child ?? const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        )
                      else if (entry is PopupMenuDivider)
                        const Divider(height: 1),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void showMyMessageActions(
    BuildContext context,
    Offset anchorGlobalPosition,
    EventMessage message,
    bool isSending,
    VoidCallback onEdit,
    VoidCallback onDelete,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isTemp = message.id.startsWith('temp_');
    final canEdit = !isTemp && !isSending;
    final canDelete = isTemp || (!isTemp && !isSending);

    final position = _positionFromGlobalOffset(context, anchorGlobalPosition);

    _showPopupMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text('Скопировать'),
            ],
          ),
        ),
        if (canEdit)
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                const Text('Изменить'),
              ],
            ),
          ),
        if (canDelete)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded,
                    color: scheme.error, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Удалить',
                  style: TextStyle(color: scheme.error),
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: message.text));
          break;
        case 'edit':
          onEdit();
          break;
        case 'delete':
          onDelete();
          break;
      }
    });
  }

  static void showOrganizerOtherMessageActions(
    BuildContext context,
    Offset anchorGlobalPosition,
    EventMessage message,
    VoidCallback onDelete,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final position = _positionFromGlobalOffset(context, anchorGlobalPosition);

    _showPopupMenu(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text('Скопировать'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: scheme.error, size: 20),
              const SizedBox(width: 10),
              Text(
                'Удалить сообщение',
                style: TextStyle(color: scheme.error),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: message.text));
          break;
        case 'delete':
          onDelete();
          break;
      }
    });
  }

  static Future<bool?> showDeleteConfirmation(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Удалить сообщение?',
          style: TextStyle(
            fontFamily: 'Inter',
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Это действие нельзя отменить.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: scheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Удалить',
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
