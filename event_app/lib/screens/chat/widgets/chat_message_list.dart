import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/event_message.dart';
import '../bloc/chat_bloc.dart';
import '../chat_appearance.dart';
import 'chat_input.dart';
import 'message_bubble_my.dart';
import 'message_bubble_other.dart';

class ChatMessageList extends StatelessWidget {
  final ChatBloc bloc;

  /// Визуальный зазор между последними сообщениями и низом экрана (над панелью ввода).
  static const double messageBottomGap = 12;

  const ChatMessageList({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final messages = bloc.messages;
    final renderItems = _buildRenderItems(messages);
    final dateFormat = DateFormat('HH:mm');

    final n = renderItems.length;

    return ListenableBuilder(
      listenable: bloc,
      builder: (context, _) {
        final inputAreaHeight =
            ChatInput.overlayReserveHeight(context, bloc) + messageBottomGap;

        return ListView.builder(
          controller: bloc.scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: n + 1,
          itemBuilder: (context, index) {
            // При reverse: index 0 — у нижнего края, под ним «виртуальное» место под панель ввода.
            if (index == 0) {
              return SizedBox(
                key: const ValueKey('chat_input_area_spacer'),
                height: inputAreaHeight,
                width: double.infinity,
              );
            }

            final item = renderItems[n - index];

            if (item is DateTime) {
              return _buildDayDivider(item);
            }

            final msgIndex = item as int;
            final msg = messages[msgIndex];
            final isMe = bloc.myId != null && msg.userId == bloc.myId;

            // При reverse: первое в группе по времени — сверху визуально → отступ сверху
            final gapTop = _isFirstInGroup(messages, msgIndex) ? 10.0 : 4.0;
            Widget bubble;
            final jumpHl = bloc.jumpHighlightedMessageId == msg.id;

            if (isMe) {
              bubble = MessageBubbleMy(
                message: msg,
                dateFormat: dateFormat,
                isSending: bloc.sendingStatus[msg.id] ?? false,
                isSent: bloc.sentStatus[msg.id] ?? true,
                isFirstInGroup: _isFirstInGroup(messages, msgIndex),
                isLastInGroup: _isLastInGroup(messages, msgIndex),
                onActionRequested: (pos) => bloc.showMyMessageActions(pos, msg),
                onReplyQuoteTap: msg.replyToId != null
                    ? () => bloc.scrollToRepliedMessage(msg.replyToId)
                    : null,
                isJumpHighlighted: jumpHl,
              );
            } else {
              bubble = MessageBubbleOther(
                message: msg,
                dateFormat: dateFormat,
                isFirstInGroup: _isFirstInGroup(messages, msgIndex),
                isLastInGroup: _isLastInGroup(messages, msgIndex),
                isOrganizer: bloc.isOrganizer,
                onOrganizerActionRequested: (pos) =>
                    bloc.showOrganizerMessageActions(pos, msg),
                onCopyTap: (anchor) => bloc.showCopyMenuForMessage(anchor, msg),
                onReplyQuoteTap: msg.replyToId != null
                    ? () => bloc.scrollToRepliedMessage(msg.replyToId)
                    : null,
                isJumpHighlighted: jumpHl,
              );
            }

            return Padding(
              key: bloc.keyForMessage(msg.id),
              padding: EdgeInsets.only(top: gapTop),
              child: bubble,
            );
          },
        );
      },
    );
  }

  List<Object> _buildRenderItems(List<EventMessage> messages) {
    final renderItems = <Object>[];
    for (var i = 0; i < messages.length; i++) {
      if (i == 0 ||
          !_sameDay(messages[i - 1].createdAt, messages[i].createdAt)) {
        renderItems.add(messages[i].createdAt);
      }
      renderItems.add(i);
    }
    return renderItems;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isFirstInGroup(List<EventMessage> messages, int index) {
    if (index == 0) return true;
    return !_sameSender(messages[index - 1], messages[index]) ||
        !_sameDay(messages[index - 1].createdAt, messages[index].createdAt);
  }

  bool _isLastInGroup(List<EventMessage> messages, int index) {
    if (index == messages.length - 1) return true;
    return !_sameSender(messages[index], messages[index + 1]) ||
        !_sameDay(messages[index].createdAt, messages[index + 1].createdAt);
  }

  bool _sameSender(EventMessage a, EventMessage b) {
    final aId = a.userId?.trim();
    final bId = b.userId?.trim();
    if (aId != null && aId.isNotEmpty && bId != null && bId.isNotEmpty) {
      return aId == bId;
    }
    return a.userEmail == b.userEmail;
  }

  Widget _buildDayDivider(DateTime day) {
    final label = DateFormat('d MMMM', 'ru').format(day);
    return Builder(
      builder: (context) {
        final chat = EventChatTheme.of(context);
        final scheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: chat.dayPillBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: chat.dayPillBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
