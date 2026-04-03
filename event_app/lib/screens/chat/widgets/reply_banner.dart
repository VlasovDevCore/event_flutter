import 'package:flutter/material.dart';
import '../bloc/chat_bloc.dart';
import '../chat_appearance.dart';

class ReplyBanner extends StatelessWidget {
  final ChatBloc bloc;

  const ReplyBanner({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final target = bloc.replyingToMessage;
    if (target == null) return const SizedBox.shrink();

    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final preview = target.text.trim().isEmpty ? '…' : target.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: chat.editingBannerBg,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.reply_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ответ ${target.displayName}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.9),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
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
                  onPressed: bloc.cancelReply,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
