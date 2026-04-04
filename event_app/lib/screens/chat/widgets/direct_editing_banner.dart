import 'package:flutter/material.dart';

import '../bloc/direct_chat_bloc.dart';
import '../chat_appearance.dart';

class DirectEditingBanner extends StatelessWidget {
  const DirectEditingBanner({super.key, required this.bloc});

  final DirectChatBloc bloc;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: chat.editingBannerBg,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.0,
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
                    color: Colors.white.withValues(alpha: 0.8),
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
                          color: Colors.white.withValues(alpha: 0.9),
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
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 22,
                  ),
                  onPressed: bloc.cancelEditing,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
