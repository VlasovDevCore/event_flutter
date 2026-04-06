import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/event_message.dart';
import '../../services/api_client.dart';
import '../../services/chat_presence_tracker.dart';
import '../profile/profile_avatar.dart';
import 'bloc/direct_chat_bloc.dart';
import 'chat_appearance.dart';
import 'widgets/direct_chat_app_bar.dart';
import 'widgets/direct_chat_body.dart';
import 'widgets/direct_chat_input.dart';
import 'widgets/message_actions_dialog.dart';

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.userId,
    required this.title,
  });

  final String userId;
  final String title;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  late DirectChatBloc _bloc;

  String? _peerHeaderName;
  String? _peerAvatarResolved;
  String? _peerUsername;

  String get _titleForAppBar {
    final n = _peerHeaderName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return widget.title;
  }

  String _initialLetter(String text) {
    final t = text.trim();
    if (t.isEmpty) return '?';
    return String.fromCharCode(t.runes.first).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    ChatPresenceTracker.instance.setDirectPeer(widget.userId);
    _bloc = DirectChatBloc(
      peerUserId: widget.userId,
      initialPeerTitle: widget.title,
    );
    _bloc.onShowMyMessageActions = _showMyMessageActions;
    _bloc.onShowCopyMenu = _showCopyMenu;
    _bloc.onShowError = _showToast;
    unawaited(_bloc.init());
    _loadPeerProfile();
  }

  Future<void> _loadPeerProfile() async {
    try {
      final data = await ApiClient.instance.get('/users/${widget.userId}');
      final displayName =
          (data['display_name'] ?? data['displayName'])?.toString().trim();
      final email = data['email']?.toString().trim();
      final username = data['username']?.toString().trim();
      final rawAvatar = (data['avatar_url'] ?? data['avatarUrl'])?.toString();

      String? headerName;
      if (displayName != null && displayName.isNotEmpty) {
        headerName = displayName;
      } else if (email != null && email.isNotEmpty) {
        headerName = email;
      } else if (username != null && username.isNotEmpty) {
        headerName = '@$username';
      }

      if (!mounted) return;
      setState(() {
        _peerHeaderName = headerName;
        _peerUsername = username;
        _peerAvatarResolved = resolveAvatarUrl(rawAvatar);
      });
      _bloc.setPeerProfile(
        displayName: headerName,
        email: email,
        avatarUrl: _peerAvatarResolved,
      );
    } catch (_) {}
  }

  void _showMyMessageActions(
    Offset anchorGlobalPosition,
    EventMessage msg,
    bool isSending,
  ) {
    _bloc.setMessageActionsMenuOpen(msg.id);
    MessageActionsDialog.showDirectMyMessageActions(
      context,
      msg,
      isSending,
      () => _bloc.startEditingMessage(msg),
      () => _bloc.startReplyTo(msg),
      () async {
        final ok = await MessageActionsDialog.showDeleteConfirmation(context);
        if (ok == true && mounted) {
          await _bloc.deleteMessage(msg);
        }
      },
    ).whenComplete(() {
      if (mounted) _bloc.setMessageActionsMenuOpen(null);
    });
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
    ChatPresenceTracker.instance.setDirectPeer(null);
    _bloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final subtitle = (_peerUsername != null && _peerUsername!.isNotEmpty)
        ? '@${_peerUsername!}'
        : null;

    return Scaffold(
      backgroundColor: chat.scaffold,
      extendBodyBehindAppBar: true,
      appBar: DirectChatAppBar(
        peerUserId: widget.userId,
        title: _titleForAppBar,
        subtitle: subtitle,
        avatarUrl: _peerAvatarResolved,
        titleLetter: _initialLetter(_titleForAppBar),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _bloc.inputFocusNode.unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(child: DirectChatBody(bloc: _bloc)),
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
              child: DirectChatInput(bloc: _bloc),
            ),
          ],
        ),
      ),
    );
  }
}
