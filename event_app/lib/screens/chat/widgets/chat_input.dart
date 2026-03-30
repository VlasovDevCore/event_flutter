import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../bloc/chat_bloc.dart';
import '../chat_appearance.dart';
import 'editing_banner.dart';

class ChatInput extends StatelessWidget {
  final ChatBloc bloc;

  const ChatInput({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);

    return ListenableBuilder(
      listenable: bloc,
      builder: (context, _) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(
              color: chat.inputBar,
              border: Border(
                top: BorderSide(color: chat.inputDivider, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bloc.editingMessageId != null) EditingBanner(bloc: bloc),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildEmojiButton(context),
                    const SizedBox(width: 4),
                    Expanded(child: _buildTextField(context)),
                    const SizedBox(width: 8),
                    _buildSendButton(context),
                  ],
                ),

                if (bloc.emojiPickerVisible && bloc.error == null)
                  _buildEmojiPicker(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojiButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = bloc.error != null;

    return IconButton(
      padding: const EdgeInsets.only(bottom: 2),
      icon: Icon(
        bloc.emojiPickerVisible
            ? Icons.keyboard_alt_outlined
            : Icons.emoji_emotions_outlined,
        color: disabled
            ? scheme.onSurface.withValues(alpha: 0.35)
            : scheme.onSurfaceVariant,
        size: 26,
      ),
      tooltip: bloc.emojiPickerVisible ? 'Клавиатура' : 'Смайлы',
      onPressed: disabled ? null : bloc.toggleEmojiPicker,
    );
  }

  Widget _buildTextField(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: bloc.textController,
      focusNode: bloc.inputFocusNode,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        height: 1.35,
        color: scheme.onSurface,
      ),
      maxLines: 4,
      minLines: 1,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      cursorColor: scheme.primary,
      decoration: InputDecoration(
        hintText: bloc.editingMessageId != null
            ? 'Введите новый текст…'
            : 'Сообщение…',
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        filled: true,
        fillColor: chat.inputField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: scheme.outline.withValues(alpha: 0.22),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: scheme.outline.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.65)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
      ),
      onSubmitted: (_) => bloc.sendMessage(),
      enabled: bloc.error == null,
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = bloc.error != null;
    final icon = bloc.editingMessageId != null
        ? Icons.check_rounded
        : Icons.send_rounded;

    return Material(
      color: disabled
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : scheme.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: disabled ? null : bloc.sendMessage,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: disabled
                ? scheme.onSurface.withValues(alpha: 0.35)
                : scheme.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiPicker(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chat = EventChatTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 256,
          child: EmojiPicker(
            textEditingController: bloc.textController,
            config: Config(
              height: 256,
              locale: const Locale('ru'),
              checkPlatformCompatibility: true,
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: chat.inputField,
                noRecents: Text(
                  'Нет недавних',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: scheme.surfaceContainerHigh,
                iconColor: scheme.onSurfaceVariant,
                iconColorSelected: scheme.primary,
                indicatorColor: scheme.primary,
                backspaceColor: scheme.primary,
                dividerColor: scheme.outline.withValues(alpha: 0.35),
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: scheme.surfaceContainerHigh,
                buttonColor: scheme.surfaceContainerHighest,
                buttonIconColor: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
