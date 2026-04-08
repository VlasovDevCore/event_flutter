import 'package:flutter/material.dart';

import '../bloc/direct_chat_bloc.dart';
import '../chat_appearance.dart';
import 'chat_app_bar.dart';
import 'direct_chat_message_list.dart';
import 'direct_scroll_to_bottom_button.dart';
import 'direct_chat_input.dart';

class DirectChatBody extends StatelessWidget {
  const DirectChatBody({super.key, required this.bloc});

  final DirectChatBloc bloc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: bloc,
      builder: (context, _) {
        if (bloc.loading) {
          final topInset = ChatAppBar.listTopPadding(context);
          return Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Загрузка сообщений…',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (bloc.error != null) {
          final topInset = ChatAppBar.listTopPadding(context);
          return Padding(
            padding: EdgeInsets.only(top: topInset),
            child: _buildErrorWidget(context),
          );
        }

        return Container(
          color: const Color(0xFF161616),
          child: Stack(
            children: [
              DirectChatMessageList(bloc: bloc),
              if (bloc.messages.isEmpty) _EmptyDirectChatHint(bloc: bloc),
              DirectScrollToBottomButton(bloc: bloc),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: chat.errorBannerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error, size: 22),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  bloc.error!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.35,
                    color: chat.onErrorBanner,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDirectChatHint extends StatelessWidget {
  const _EmptyDirectChatHint({required this.bloc});

  final DirectChatBloc bloc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = ChatAppBar.listTopPadding(context);
    final bottomInset =
        DirectChatInput.overlayReserveHeight(context, bloc) + 12;

    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/events/chat-bubble-dynamic-color.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 24),
                Text(
                  'Здесь пока нет сообщений',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Напишите первым, чтобы начать диалог',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
