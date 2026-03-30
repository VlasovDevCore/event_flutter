import 'package:flutter/material.dart';
import '../bloc/chat_bloc.dart';
import '../chat_appearance.dart';

class ScrollToBottomButton extends StatelessWidget {
  final ChatBloc bloc;

  const ScrollToBottomButton({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bloc,
      builder: (context, _) {
        final visible =
            bloc.showScrollToBottom || bloc.pendingNewMessagesCount > 0;

        return Positioned(
          right: 14,
          bottom: 14,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !visible,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildButton(context),
                  if (bloc.pendingNewMessagesCount > 0) _buildBadge(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: chat.floatingControlFill,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: bloc.scrollToBottom,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: chat.floatingControlBorder),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: scheme.primary,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = bloc.pendingNewMessagesCount;

    return Positioned(
      right: -4,
      top: -6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.surface,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: scheme.onError,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
