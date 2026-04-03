import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/event_message.dart';

class MessageActionsDialog {
  static Future<String?> _showPopupMenu({
    required BuildContext context,
    required Offset anchorPosition, // Позиция нижней части сообщения
    required List<PopupMenuEntry<String>> items,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final screen = Offset.zero & overlay.size;
    final padding = MediaQuery.paddingOf(context);

    const margin = 10.0;
    final marginTop = margin + padding.top;
    final marginBottom = margin + padding.bottom;

    // Меню на всю ширину с отступами по бокам
    final menuWidth = screen.width - (margin * 2);
    final left = margin;

    // anchor в глобальных координатах → в системе overlay (как у Positioned в диалоге)
    final anchorInOverlay = overlay.globalToLocal(anchorPosition);
    final messageBottom = anchorInOverlay.dy;
    const gapBelowMessage = 8.0;

    // Одна строка иконка+текст, vertical padding 16+16 в InkWell — запас на разные шрифты
    const estimatedMenuHeight = 88.0;

    final maxBottomY = screen.height - marginBottom;
    final topBelow = messageBottom + gapBelowMessage;
    final topAbove = messageBottom - gapBelowMessage - estimatedMenuHeight;

    double top;
    if (topBelow + estimatedMenuHeight <= maxBottomY) {
      top = topBelow;
    } else if (topAbove >= marginTop) {
      // Не помещается снизу — показываем над пузырём
      top = topAbove;
    } else {
      // Ни над, ни под пузырём с отступами — прижимаем к низу safe area
      final pinnedUp = maxBottomY - estimatedMenuHeight;
      top = pinnedUp < marginTop ? marginTop : pinnedUp;
    }

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
                color: const Color(0xFF25262B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    20,
                  ), // Увеличенное скругление
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
                            onTap: () => Navigator.of(
                              ctx,
                            ).pop((items[i] as PopupMenuItem<String>).value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical:
                                    16, // Увеличенный отступ сверху и снизу
                              ),
                              child: (items[i] as PopupMenuItem<String>).child,
                            ),
                          ),
                        )
                      else if (items[i] is PopupMenuDivider)
                        Container(
                          width: 1,
                          height: 40, // Высота разделителя
                          color: Colors.white.withOpacity(0.1),
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Меню для чужого сообщения (не организатор): копировать и ответить.
  static void showParticipantMessageActions(
    BuildContext context,
    Offset messageBottomGlobal,
    EventMessage message,
    VoidCallback onReply,
  ) {
    final scheme = Theme.of(context).colorScheme;

    _showPopupMenu(
      context: context,
      anchorPosition: messageBottomGlobal,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, color: scheme.primary, size: 24),
              const SizedBox(height: 6),
              const Text('Копировать', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'reply',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply_rounded, color: scheme.primary, size: 24),
              const SizedBox(height: 6),
              const Text('Ответить', style: TextStyle(fontSize: 12)),
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
    });
  }

  static void showMyMessageActions(
    BuildContext context,
    Offset messageBottomGlobal,
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

    _showPopupMenu(
      context: context,
      anchorPosition: messageBottomGlobal,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, color: scheme.primary, size: 24),
              const SizedBox(height: 6),
              const Text('Копировать', style: TextStyle(fontSize: 12)),
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
                Icon(Icons.reply_rounded, color: scheme.primary, size: 24),
                const SizedBox(height: 6),
                const Text('Ответить', style: TextStyle(fontSize: 12)),
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
                Icon(Icons.edit_outlined, color: scheme.primary, size: 24),
                const SizedBox(height: 6),
                const Text('Изменить', style: TextStyle(fontSize: 12)),
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
                  color: scheme.error,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  'Удалить',
                  style: TextStyle(color: scheme.error, fontSize: 12),
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
    });
  }

  static void showOrganizerOtherMessageActions(
    BuildContext context,
    Offset messageBottomGlobal,
    EventMessage message,
    VoidCallback onDelete,
    VoidCallback onReply,
  ) {
    final scheme = Theme.of(context).colorScheme;

    _showPopupMenu(
      context: context,
      anchorPosition: messageBottomGlobal,
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, color: scheme.primary, size: 24),
              const SizedBox(height: 6),
              const Text('Копировать', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'reply',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply_rounded, color: scheme.primary, size: 24),
              const SizedBox(height: 6),
              const Text('Ответить', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, color: scheme.error, size: 24),
              const SizedBox(height: 6),
              Text(
                'Удалить',
                style: TextStyle(color: scheme.error, fontSize: 12),
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
        case 'reply':
          onReply();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
