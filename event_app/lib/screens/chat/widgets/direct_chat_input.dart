import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../bloc/direct_chat_bloc.dart';
import '../chat_appearance.dart';
import 'direct_editing_banner.dart';
import 'direct_reply_banner.dart';

/// Поле ввода личного чата — те же стили, что у [ChatInput].
class DirectChatInput extends StatelessWidget {
  const DirectChatInput({super.key, required this.bloc});

  final DirectChatBloc bloc;

  static double overlayReserveHeight(BuildContext context, DirectChatBloc bloc) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    var h = safeBottom + 8 + 10;
    if (bloc.editingMessageId != null) {
      h += 58;
    }
    if (bloc.replyingToMessage != null) {
      h += 58;
    }
    h += 52;
    if (bloc.emojiPickerVisible && bloc.error == null) {
      h += 8 + 256;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: bloc,
      builder: (context, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bloc.editingMessageId != null) DirectEditingBanner(bloc: bloc),
                if (bloc.replyingToMessage != null) DirectReplyBanner(bloc: bloc),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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

  Widget _buildTextField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = bloc.error != null;

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
        fillColor: const Color(0xFF2A2A2A),
        suffixIcon: IconButton(
          icon: Icon(
            bloc.emojiPickerVisible
                ? Icons.keyboard_alt_outlined
                : Icons.emoji_emotions_outlined,
            color: disabled
                ? scheme.onSurface.withValues(alpha: 0.35)
                : scheme.onSurfaceVariant,
            size: 22,
          ),
          onPressed: disabled ? null : bloc.toggleEmojiPicker,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.38)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.85),
            width: 1.5,
          ),
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
    final disabled = bloc.error != null;

    return Material(
      color: disabled ? Colors.white.withValues(alpha: 0.5) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: disabled ? null : bloc.sendMessage,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            bloc.editingMessageId != null
                ? Icons.check_rounded
                : Icons.send_rounded,
            color: disabled
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiPicker(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

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
                showSearchViewButton: false,
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
