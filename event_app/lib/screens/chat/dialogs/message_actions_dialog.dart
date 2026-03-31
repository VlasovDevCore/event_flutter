import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/event_message.dart';

class MessageActionsDialog {
  static RelativeRect? _anchorPosition(BuildContext anchorContext) {
    final renderObject = anchorContext.findRenderObject();
    final overlay = Overlay.of(anchorContext).context.findRenderObject();
    if (renderObject is! RenderBox || overlay is! RenderBox) return null;

    final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = topLeft & renderObject.size;
    return RelativeRect.fromRect(rect, Offset.zero & overlay.size);
  }

  static void showMyMessageActions(
    BuildContext context,
    EventMessage message,
    bool isSending,
    VoidCallback onEdit,
    VoidCallback onDelete,
  ) {
    final isTemp = message.id.startsWith('temp_');
    final canEdit = !isTemp && !isSending;
    final canDelete = isTemp || (!isTemp && !isSending);

    final scheme = Theme.of(context).colorScheme;
    final position = _anchorPosition(context);

    showMenu<String>(
      context: context,
      position: position ?? const RelativeRect.fromLTRB(16, 16, 16, 16),
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Скопировать',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
                Text(
                  'Изменить',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: scheme.error,
                    fontWeight: FontWeight.w500,
                  ),
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
    EventMessage message,
    VoidCallback onDelete,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final position = _anchorPosition(context);

    showMenu<String>(
      context: context,
      position: position ?? const RelativeRect.fromLTRB(16, 16, 16, 16),
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Скопировать',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: scheme.error, size: 20),
              const SizedBox(width: 10),
              Text(
                'Удалить сообщение',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: scheme.error,
                  fontWeight: FontWeight.w500,
                ),
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
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text(
          'Удалить сообщение?',
          style: TextStyle(fontFamily: 'Inter', color: Colors.white),
        ),
        content: const Text(
          'Это действие нельзя отменить.',
          style: TextStyle(fontFamily: 'Inter', color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
