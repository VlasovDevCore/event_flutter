import 'package:flutter/material.dart';
import '../bloc/chat_bloc.dart';
import '../chat_appearance.dart';

class EditingBanner extends StatelessWidget {
  final ChatBloc bloc;

  const EditingBanner({super.key, required this.bloc});

  String get _previewText {
    final id = bloc.editingMessageId;
    if (id == null) return '';
    for (final m in bloc.messages) {
      if (m.id == id) {
        final t = m.text.trim();
        return t.isEmpty ? '…' : t;
      }
    }
    final t = bloc.textController.text.trim();
    return t.isEmpty ? '…' : t;
  }

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: chat.editingBannerBg,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: chat.editingAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Редактирование',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: chat.editingAccent,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _previewText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: bloc.cancelEditing,
                  tooltip: 'Отменить редактирование',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
