import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../models/event_message.dart';
import 'bloc/chat_bloc.dart';
import 'chat_appearance.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_body.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_actions_dialog.dart';

class EventChatScreen extends StatefulWidget {
  const EventChatScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  late ChatBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = ChatBloc(event: widget.event);
    _bloc.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc.onShowMyMessageActions ??= _showMyMessageActions;
    _bloc.onShowOrganizerMessageActions ??= _showOrganizerMessageActions;
    _bloc.onShowError ??= _showToast;
    _bloc.onShowCopyMenu ??= _showCopyMenu;
  }

  void _showCopyMenu(Offset anchorGlobalPosition, EventMessage msg) {
    _bloc.setMessageActionsMenuOpen(msg.id);
    MessageActionsDialog.showParticipantMessageActions(
      context,
      msg,
      () => _bloc.startReplyTo(msg),
    ).whenComplete(() {
      if (mounted) _bloc.setMessageActionsMenuOpen(null);
    });
  }

  void _showMyMessageActions(Offset anchorGlobalPosition, EventMessage msg, bool isSending) {
    _bloc.setMessageActionsMenuOpen(msg.id);
    MessageActionsDialog.showMyMessageActions(
      context,
      msg,
      isSending,
      () => _bloc.startEditingMessage(msg),
      () async {
        final confirmed = await MessageActionsDialog.showDeleteConfirmation(
          context,
        );
        if (confirmed == true && mounted) {
          await _bloc.deleteMessage(msg);
        }
      },
      () => _bloc.startReplyTo(msg),
    ).whenComplete(() {
      if (mounted) _bloc.setMessageActionsMenuOpen(null);
    });
  }

  void _showOrganizerMessageActions(Offset anchorGlobalPosition, EventMessage msg) {
    _bloc.setMessageActionsMenuOpen(msg.id);
    MessageActionsDialog.showOrganizerOtherMessageActions(
      context,
      msg,
      () async {
        final confirmed = await MessageActionsDialog.showDeleteConfirmation(
          context,
        );
        if (confirmed == true && mounted) {
          await _bloc.deleteMessage(msg);
        }
      },
      () => _bloc.startReplyTo(msg),
    ).whenComplete(() {
      if (mounted) _bloc.setMessageActionsMenuOpen(null);
    });
  }

  void _showToast(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        content: Text(
          message,
          style: TextStyle(
            fontFamily: 'Inter',
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    return Scaffold(
      backgroundColor: chat.scaffold,
      extendBodyBehindAppBar: true,
      appBar: ChatAppBar(event: widget.event),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _bloc.inputFocusNode.unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(child: ChatBody(bloc: _bloc)),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: EventChatTheme.appBarTopShadowExtent,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: chat.appBarTopShadowGradient,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: EventChatTheme.inputBottomShadowExtent,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: chat.inputBottomShadowGradient,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ChatInput(bloc: _bloc),
            ),
          ],
        ),
      ),
    );
  }
}
