import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/event_message.dart';
import '../../../../services/api_client.dart';
import '../chat_appearance.dart';

class MessageBubbleOther extends StatelessWidget {
  final EventMessage message;
  final DateFormat dateFormat;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isOrganizer;

  /// Действия организатора (удалить и т.д.)
  final ValueChanged<Offset> onOrganizerActionRequested;

  /// Копирование для обычного участника (не организатор)
  final VoidCallback onCopyTap;

  const MessageBubbleOther({
    super.key,
    required this.message,
    required this.dateFormat,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.isOrganizer,
    required this.onOrganizerActionRequested,
    required this.onCopyTap,
  });

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final fullAvatarUrl = ApiClient.getFullImageUrl(message.avatarUrl);
    final showName = isFirstInGroup;
    final showAvatar = isLastInGroup;
    Offset? lastDown;

    final topLeft = isFirstInGroup ? 12.0 : 4.0;
    final bottomLeft = isLastInGroup ? 12.0 : 4.0;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: const Radius.circular(12),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: const Radius.circular(12),
    );

    final bubbleContent = Container(
      constraints: BoxConstraints(
        minWidth: 104,
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: chat.shadowSoft,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
    );

    final onBubbleTap = isOrganizer
        ? () => onOrganizerActionRequested(lastDown ?? Offset.zero)
        : onCopyTap;
    final bubble = Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onBubbleTap,
        onTapDown: (d) => lastDown = d.globalPosition,
        onLongPress: isOrganizer
            ? () => onOrganizerActionRequested(lastDown ?? Offset.zero)
            : onCopyTap,
        borderRadius: borderRadius,
        child: bubbleContent,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar)
          _buildAvatar(context, fullAvatarUrl)
        else
          const SizedBox(width: 42),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [if (showName) _buildName(context), bubble],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, String? avatarUrl) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFABABAB).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
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
                errorWidget: (context, url, error) => Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: const Color(0xFFABABAB),
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: 20,
                color: const Color(0xFFABABAB),
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
