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
    final topRight = isFirstInGroup ? 12.0 : 4.0; // было 18/6
    final bottomRight = isLastInGroup ? 12.0 : 4.0; // было 18/6
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12), // было 18
      topRight: Radius.circular(topRight),
      bottomLeft: const Radius.circular(12), // было 18
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
                    color: const Color(0xFF00FF7F),
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
                    constraints: const BoxConstraints(minWidth: 74),
                    padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.text,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                height: 1.38,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF00461E),
                              ),
                            ),
                            const SizedBox(height: 16), // Отступ для статуса
                          ],
                        ),
                        Positioned(
                          right: -8,
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

    // Ваши цвета
    const Color textColor = Color(0xFF00461E);
    const Color iconColor = Color(0xFF006633);
    const Color iconReadColor = Color(0xFF008844);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateFormat.format(message.createdAt),
          style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: textColor),
        ),
        if (message.editedAt != null) ...[
          const SizedBox(width: 4),
          Text(
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
          Icon(Icons.done_all_rounded, size: 15, color: iconReadColor)
        else if (isSent)
          Icon(Icons.check_rounded, size: 14, color: iconColor)
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
