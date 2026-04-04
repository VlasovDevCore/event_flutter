import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/event_message.dart';
import '../chat_appearance.dart';
import 'reply_quote.dart';

class MessageBubbleMy extends StatelessWidget {
  final EventMessage message;
  final DateFormat dateFormat;
  final bool isSending;
  final bool isSent;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final ValueChanged<Offset> onActionRequested;
  final VoidCallback? onReplyQuoteTap;
  final bool isJumpHighlighted;
  /// Подсветка, пока открыто меню действий по этому сообщению.
  final bool isActionsMenuHighlighted;

  const MessageBubbleMy({
    super.key,
    required this.message,
    required this.dateFormat,
    required this.isSending,
    required this.isSent,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onActionRequested,
    this.onReplyQuoteTap,
    this.isJumpHighlighted = false,
    this.isActionsMenuHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final topRight = isFirstInGroup ? 12.0 : 4.0;
    final bottomRight = isLastInGroup ? 12.0 : 4.0;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: Radius.circular(topRight),
      bottomLeft: const Radius.circular(12),
      bottomRight: Radius.circular(bottomRight),
    );

    const bubbleBase = Color(0xFF00FF7F);
    final bubbleFill = isJumpHighlighted
        ? Color.lerp(bubbleBase, const Color(0xFFD4FFF0), 0.42)!
        : isActionsMenuHighlighted
            ? Color.lerp(bubbleBase, const Color(0xFFD4FFF0), 0.26)!
            : bubbleBase;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (bubbleContext) {
                void openActions() {
                  final box = bubbleContext.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  onActionRequested(
                    box.localToGlobal(Offset(0, box.size.height)),
                  );
                }

                return Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: borderRadius,
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: bubbleFill,
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: chat.shadowSoft,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: openActions,
                        onLongPress: openActions,
                        borderRadius: borderRadius,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.replyToId != null &&
                                  (message.replyToText != null ||
                                      message.replyQuoteAuthorLabel != null))
                                ReplyQuote(
                                  message: message,
                                  authorColor: const Color(0xFF006633),
                                  textColor: const Color(0xFF00461E),
                                  borderColor: const Color(0xFF008844),
                                  onTap: onReplyQuoteTap,
                                ),
                              Text(
                                message.text,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  height: 1.38,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF00461E),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildStatusIndicator(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    const Color textColor = Color(0xFF00461E);
    const Color iconColor = Color(0xFF006633);
    const Color iconReadColor = Color(0xFF008844);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateFormat.format(message.createdAt),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: textColor,
          ),
        ),
        if (message.editedAt != null) ...[
          const SizedBox(width: 4),
          const Text(
            'ред.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              color: textColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(width: 6),
        if (isSending)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: iconColor,
            ),
          )
        else if (isSent && message.isViewed)
          const Icon(Icons.done_all_rounded, size: 15, color: iconReadColor)
        else if (isSent)
          const Icon(Icons.check_rounded, size: 14, color: iconColor)
        else
          Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: Colors.red.shade400,
          ),
      ],
    );
  }
}
