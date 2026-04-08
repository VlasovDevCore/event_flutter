import 'package:flutter/material.dart';

import '../bloc/direct_chat_bloc.dart';
import 'direct_chat_input.dart';

class DirectScrollToBottomButton extends StatelessWidget {
  const DirectScrollToBottomButton({super.key, required this.bloc});

  final DirectChatBloc bloc;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bloc,
      builder: (context, _) {
        final visible =
            bloc.showScrollToBottom || bloc.pendingNewMessagesCount > 0;
        final bottomInset = DirectChatInput.overlayReserveHeight(context, bloc);

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
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: bloc.scrollToBottom,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    final count = bloc.pendingNewMessagesCount;
    final text = count > 99 ? '99+' : '$count';

    // Рассчитываем ширину в зависимости от текста
    final isTwoDigits = text.length >= 2;
    final width = isTwoDigits ? 24.0 : 20.0;

    return Positioned(
      right: -4,
      top: -6,
      child: Container(
        width: width, // фиксированная ширина
        height: 20, // фиксированная высота
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle, // 👈 ИДЕАЛЬНЫЙ КРУГ
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
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
