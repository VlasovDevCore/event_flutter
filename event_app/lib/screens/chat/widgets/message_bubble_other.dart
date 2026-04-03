import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/event_message.dart';
import '../../../../services/api_client.dart';
import '../chat_appearance.dart';
import 'reply_quote.dart';

class MessageBubbleOther extends StatelessWidget {
  final EventMessage message;
  final DateFormat dateFormat;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isOrganizer;

  /// Действия организатора (удалить и т.д.)
  final ValueChanged<Offset> onOrganizerActionRequested;

  /// Копирование для обычного участника (не организатор); [Offset] — низ пузыря в глобальных координатах.
  final ValueChanged<Offset> onCopyTap;
  final VoidCallback? onReplyQuoteTap;
  final bool isJumpHighlighted;

  const MessageBubbleOther({
    super.key,
    required this.message,
    required this.dateFormat,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.isOrganizer,
    required this.onOrganizerActionRequested,
    required this.onCopyTap,
    this.onReplyQuoteTap,
    this.isJumpHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final fullAvatarUrl = ApiClient.getFullImageUrl(message.avatarUrl);
    final showName = isFirstInGroup;
    final showAvatar = isLastInGroup;

    final topLeft = isFirstInGroup ? 12.0 : 4.0;
    final bottomLeft = isLastInGroup ? 12.0 : 4.0;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: const Radius.circular(12),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: const Radius.circular(12),
    );

    const bubbleBase = Color(0xFF1A1A1A);
    final bubbleFill = isJumpHighlighted
        ? Color.lerp(bubbleBase, const Color(0xFF3D3D3D), 0.48)!
        : bubbleBase;

    final bubbleContent = AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      constraints: BoxConstraints(
        minWidth: 104,
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
      decoration: BoxDecoration(
        color: bubbleFill,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: chat.shadowSoft,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToId != null &&
                (message.replyToText != null ||
                    message.replyQuoteAuthorLabel != null))
              ReplyQuote(
                message: message,
                authorColor: chat.senderName,
                textColor: const Color(0xFFFFFFFF),
                borderColor: chat.senderName.withValues(alpha: 0.85),
                onTap: onReplyQuoteTap,
              ),
            // Текст сообщения
            Text(
              message.text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                height: 1.38,
                fontWeight: FontWeight.w500,
                color: Color(0xFFFFFFFF),
              ),
            ),
            const SizedBox(height: 4), // Отступ между текстом и временем
            // Время и статус
            _buildTimeStamp(context),
          ],
        ),
      ),
    );

    final bubble = Builder(
      builder: (bubbleContext) {
        void organizerOpenActions() {
          final box = bubbleContext.findRenderObject() as RenderBox?;
          if (box == null) return;
          onOrganizerActionRequested(
            box.localToGlobal(Offset(0, box.size.height)),
          );
        }

        void participantCopy() {
          final box = bubbleContext.findRenderObject() as RenderBox?;
          if (box == null) return;
          onCopyTap(box.localToGlobal(Offset(0, box.size.height)));
        }

        return Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isOrganizer ? organizerOpenActions : participantCopy,
            onLongPress: isOrganizer ? organizerOpenActions : participantCopy,
            borderRadius: borderRadius,
            child: bubbleContent,
          ),
        );
      },
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar)
          _buildAvatar(context, fullAvatarUrl)
        else
          const SizedBox(width: 50),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showName) _buildName(context),
              Align(
                alignment: Alignment.centerLeft,
                child: bubble,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, String? avatarUrl) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          12,
        ), // должно совпадать со значением выше
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: const Color(0xFFABABAB),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: Color(0xFFABABAB),
                ),
              )
            : const Icon(
                Icons.person_rounded,
                size: 20,
                color: Color(0xFFABABAB),
              ),
      ),
    );
  }

  Widget _buildName(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 5),
      child: Text(
        message.displayName,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFFABABAB),
          letterSpacing: 0.15,
        ),
      ),
    );
  }

  Widget _buildTimeStamp(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateFormat.format(message.createdAt),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: Color(0xFFABABAB),
          ),
        ),
        if (message.editedAt != null) ...[
          const SizedBox(width: 4),
          const Text(
            'ред.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              color: Color(0xFFABABAB),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
