import 'package:flutter/material.dart';
import '../bloc/chat_bloc.dart';
import '../chat_appearance.dart';
import 'chat_input.dart';

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
        final bottomInset = ChatInput.overlayReserveHeight(context, bloc);

        return Positioned(
          right: 14,
          bottom: 14 + bottomInset,
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

    return Material(
      color: Colors.transparent, // Прозрачный фон
      elevation: 0,
      child: InkWell(
        onTap: bloc.scrollToBottom,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white, // Черная иконка
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    final count = bloc.pendingNewMessagesCount;

    return Positioned(
      right: -4,
      top: -6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
        decoration: BoxDecoration(
          color: Colors.white, // Белый фон
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black, // Черный текст
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
