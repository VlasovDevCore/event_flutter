import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/event_message.dart';
import '../chat_appearance.dart';

class MessageBubbleMy extends StatelessWidget {
  final EventMessage message;
  final DateFormat dateFormat;
  final bool isSending;
  final bool isSent;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final ValueChanged<Offset> onActionRequested;

  const MessageBubbleMy({
    super.key,
    required this.message,
    required this.dateFormat,
    required this.isSending,
    required this.isSent,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.onActionRequested,
  });

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    Offset? lastDown;
    final topRight = isFirstInGroup ? 18.0 : 6.0;
    final bottomRight = isLastInGroup ? 18.0 : 6.0;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: Radius.circular(topRight),
      bottomLeft: const Radius.circular(18),
      bottomRight: Radius.circular(bottomRight),
    );

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
            Material(
              color: Colors.transparent,
              borderRadius: borderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTapDown: (d) => lastDown = d.globalPosition,
                onTap: () => onActionRequested(lastDown ?? Offset.zero),
                onLongPress: () => onActionRequested(lastDown ?? Offset.zero),
                borderRadius: borderRadius,
                child: Ink(
                  decoration: BoxDecoration(
                    color: chat.bubbleMine,
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
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 104),
                    padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 58, bottom: 16),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              height: 1.38,
                              color: chat.onBubbleMine,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -6,
                          child: _buildStatusIndicator(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateFormat.format(message.createdAt),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: chat.metaMuted,
          ),
        ),
        if (message.editedAt != null) ...[
          const SizedBox(width: 4),
          Text(
            'ред.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              color: chat.metaMuted,
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
              color: scheme.primary,
            ),
          )
        else if (isSent && message.isViewed)
          Icon(Icons.done_all_rounded, size: 15, color: scheme.tertiary)
        else if (isSent)
          Icon(Icons.check_rounded, size: 14, color: scheme.primary)
        else
          Icon(Icons.error_outline_rounded, size: 14, color: scheme.error),
      ],
    );
  }
}
