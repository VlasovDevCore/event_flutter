import 'package:flutter/material.dart';
import '../../../../models/event_message.dart';

/// Превью цитируемого сообщения внутри пузыря.
class ReplyQuote extends StatelessWidget {
  final EventMessage message;
  final Color authorColor;
  final Color textColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const ReplyQuote({
    super.key,
    required this.message,
    required this.authorColor,
    required this.textColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final author = message.replyQuoteAuthorLabel ?? 'Сообщение';
    final raw = message.replyToText?.trim() ?? '';
    final snippet = raw.isEmpty ? '…' : raw;
    final display =
        snippet.length > 160 ? '${snippet.substring(0, 157)}…' : snippet;

    final content = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: borderColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: authorColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            display,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.25,
              color: textColor.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: content,
      ),
    );
  }
}
