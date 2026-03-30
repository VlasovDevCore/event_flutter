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
  final VoidCallback onOrganizerTap;
  /// Копирование для обычного участника (не организатор)
  final VoidCallback onCopyTap;

  const MessageBubbleOther({
    super.key,
    required this.message,
    required this.dateFormat,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.isOrganizer,
    required this.onOrganizerTap,
    required this.onCopyTap,
  });

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final fullAvatarUrl = ApiClient.getFullImageUrl(message.avatarUrl);
    final showName = isFirstInGroup;
    final showAvatar = isLastInGroup;

    final topLeft = isFirstInGroup ? 18.0 : 8.0;
    final bottomLeft = isLastInGroup ? 8.0 : 18.0;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(bottomLeft),
      bottomRight: const Radius.circular(18),
    );

    final bubbleContent = Container(
      constraints: BoxConstraints(
        minWidth: 104,
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
      decoration: BoxDecoration(
        color: chat.bubbleOther,
        borderRadius: borderRadius,
        border: Border.all(color: chat.bubbleOtherBorder),
        boxShadow: [
          BoxShadow(
            color: chat.shadowSoft,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 44, bottom: 5),
            child: Text(
              message.text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                height: 1.38,
                color: chat.onBubbleOther,
              ),
            ),
          ),
          Positioned(right: 0, bottom: 0, child: _buildTimeStamp(context)),
        ],
      ),
    );

    final onBubble = isOrganizer ? onOrganizerTap : onCopyTap;
    final bubble = Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onBubble,
        onLongPress: onBubble,
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
          const SizedBox(width: 40),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showName) _buildName(context),
              bubble,
            ],
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
          color: scheme.primary.withValues(alpha: 0.35),
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
                      color: scheme.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    Icon(Icons.person_rounded, size: 20, color: scheme.onSurfaceVariant),
              )
            : Icon(Icons.person_rounded, size: 20, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildName(BuildContext context) {
    final chat = EventChatTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 5),
      child: Text(
        message.displayName,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: chat.senderName,
          letterSpacing: 0.15,
        ),
      ),
    );
  }

  Widget _buildTimeStamp(BuildContext context) {
    final chat = EventChatTheme.of(context);

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
      ],
    );
  }
}
