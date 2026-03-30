import 'package:flutter/material.dart';
import '../bloc/chat_bloc.dart';
import '../chat_appearance.dart';
import 'chat_message_list.dart';
import 'scroll_to_bottom_button.dart';

class ChatBody extends StatelessWidget {
  final ChatBloc bloc;

  const ChatBody({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: bloc,
      builder: (context, _) {
        if (bloc.loading) {
          return Center(
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
          );
        }

        if (bloc.error != null) {
          return _buildErrorWidget(context);
        }

        final chat = EventChatTheme.of(context);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                chat.scaffold,
                Color.lerp(chat.scaffold, scheme.primary, 0.06)!,
              ],
            ),
          ),
          child: Stack(
            children: [
              ChatMessageList(bloc: bloc),
              ScrollToBottomButton(bloc: bloc),
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
            border: Border.all(
              color: scheme.error.withValues(alpha: 0.35),
            ),
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
