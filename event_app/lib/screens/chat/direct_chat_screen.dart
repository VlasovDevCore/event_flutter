import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/event_message.dart';
import '../../services/api_client.dart';
import '../../services/chat_presence_tracker.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_screen.dart';
import '../profile/profile_repository.dart';
import '../../widgets/profile/blocked_card.dart';
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
    this.initialIsBlocked,
    this.initialIsBlockedBy,
    this.initialCanWrite,
  });

  final String userId;
  final String title;
  final bool? initialIsBlocked;
  final bool? initialIsBlockedBy;
  final bool? initialCanWrite;

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  late DirectChatBloc _bloc;

  String? _peerHeaderName;
  String? _peerAvatarResolved;
  String? _peerUsername;
  bool _peerAllowMessagesFromNonFriends = true;
  bool _isFriends = false;
  bool? _canWriteKnown;
  DateTime? _mutedUntil;
  bool _isBlocked = false;
  bool _isBlockedBy = false;

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

    // Чтобы не было "мигания": если статус блокировки уже известен из списка,
    // применяем его до первого кадра.
    final initBlocked = widget.initialIsBlocked == true;
    final initBlockedBy = widget.initialIsBlockedBy == true;
    if (initBlocked || initBlockedBy) {
      _isBlocked = initBlocked;
      _isBlockedBy = initBlockedBy;
      _bloc.setMessageActionsEnabled(false);
    }
    _canWriteKnown = (initBlocked || initBlockedBy)
        ? false
        : widget.initialCanWrite;

    unawaited(_bloc.init());
    _loadPeerProfile();
    _loadRelationship();
    _loadMuteStatus();
    _loadBlockStatus();
  }

  bool get _canWriteToPeer {
    if (_isBlocked || _isBlockedBy) return false;
    return _isFriends || _peerAllowMessagesFromNonFriends;
  }

  void _syncMessageActionsEnabled() {
    _bloc.setMessageActionsEnabled(_canWriteKnown == true);
  }

  Future<void> _loadRelationship() async {
    try {
      final rel = await ProfileRepository.fetchRelationship(widget.userId);
      if (!mounted) return;
      setState(() {
        _isFriends = rel.isFriends;
        _canWriteKnown = _canWriteToPeer;
      });
      _syncMessageActionsEnabled();
    } catch (_) {}
  }

  bool get _isMutedNow {
    final u = _mutedUntil;
    if (u == null) return false;
    return u.isAfter(DateTime.now());
  }

  Future<void> _loadMuteStatus() async {
    try {
      final data = await ApiClient.instance.get(
        '/messages/with/${widget.userId}/mute',
        withAuth: true,
      );
      final raw = data['muted_until'];
      DateTime? parsed;
      if (raw is String && raw.trim().isNotEmpty) {
        parsed = DateTime.tryParse(raw)?.toLocal();
      }
      if (!mounted) return;
      setState(() => _mutedUntil = parsed);
    } catch (_) {}
  }

  Future<void> _loadBlockStatus() async {
    try {
      final status = await ProfileRepository.fetchBlockStatus(widget.userId);
      if (!mounted) return;
      setState(() {
        _isBlocked = status.isBlocked;
        _isBlockedBy = status.isBlockedBy;
        _canWriteKnown = _canWriteToPeer;
      });
      _syncMessageActionsEnabled();
    } catch (_) {}
  }

  Future<void> _setMuteFor(Duration duration) async {
    final untilUtc = DateTime.now().add(duration).toUtc();
    try {
      final data = await ApiClient.instance.post(
        '/messages/with/${widget.userId}/mute',
        body: {'muted_until': untilUtc.toIso8601String()},
        withAuth: true,
      );
      final raw = data['muted_until'];
      final parsed = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
      if (!mounted) return;
      setState(() => _mutedUntil = parsed);
      _showToast('Уведомления отключены');
    } on ApiException catch (e) {
      _showToast(e.statusCode == 401 ? 'Войдите в аккаунт' : e.message);
    } catch (_) {
      _showToast('Не удалось изменить уведомления');
    }
  }

  Future<void> _unmute() async {
    try {
      await ApiClient.instance.post(
        '/messages/with/${widget.userId}/mute',
        body: {'muted_until': null},
        withAuth: true,
      );
      if (!mounted) return;
      setState(() => _mutedUntil = null);
      _showToast('Уведомления включены');
    } on ApiException catch (e) {
      _showToast(e.statusCode == 401 ? 'Войдите в аккаунт' : e.message);
    } catch (_) {
      _showToast('Не удалось изменить уведомления');
    }
  }

  Future<void> _confirmAndClearChat() async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        title: const Text(
          'Очистить чат?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        content: const Text(
          'Вся история переписки будет удалена. Действие нельзя отменить.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.35,
            color: Color(0xFFAAABB0),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Очистить',
                style: TextStyle(
                  color: const Color(0xFFFC5B4C),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiClient.instance.delete(
        '/messages/with/${widget.userId}',
        withAuth: true,
      );
      if (!mounted) return;
      _bloc.clearConversationLocal();
    } on ApiException catch (e) {
    } catch (_) {
      _showToast('Не удалось очистить чат');
    }
  }

  Future<void> _confirmAndToggleBlockUser() async {
    final scheme = Theme.of(context).colorScheme;
    final willBlock = !_isBlocked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          willBlock
              ? 'Заблокировать пользователя?'
              : 'Разблокировать пользователя?',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        content: Text(
          willBlock
              ? 'Вы больше не сможете переписываться и видеть сообщения друг друга.'
              : 'Пользователь снова сможет писать вам и видеть переписку.',
          style: TextStyle(fontFamily: 'Inter', height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: scheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              willBlock ? 'Заблокировать' : 'Разблокировать',
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (willBlock) {
        await ApiClient.instance.post(
          '/blocks/block',
          body: {'userId': widget.userId},
          withAuth: true,
        );
      } else {
        await ApiClient.instance.post(
          '/blocks/unblock',
          body: {'userId': widget.userId},
          withAuth: true,
        );
      }
      if (!mounted) return;
      setState(() => _isBlocked = willBlock);
      _showToast(
        willBlock ? 'Пользователь заблокирован' : 'Пользователь разблокирован',
      );
      if (willBlock) {
        Navigator.of(context).maybePop();
      }
    } on ApiException catch (e) {
      _showToast(e.statusCode == 401 ? 'Войдите в аккаунт' : e.message);
    } catch (_) {
      _showToast(
        willBlock
            ? 'Не удалось заблокировать пользователя'
            : 'Не удалось разблокировать пользователя',
      );
    }
  }

  Future<void> _loadPeerProfile() async {
    try {
      final data = await ApiClient.instance.get('/users/${widget.userId}');
      final displayName = (data['display_name'] ?? data['displayName'])
          ?.toString()
          .trim();
      final email = data['email']?.toString().trim();
      final username = data['username']?.toString().trim();
      final rawAvatar = (data['avatar_url'] ?? data['avatarUrl'])?.toString();
      final allowNonFriends = data['allow_messages_from_non_friends'] ??
          data['allowMessagesFromNonFriends'];
      final allow =
          allowNonFriends is bool ? allowNonFriends : true;

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
        _peerAllowMessagesFromNonFriends = allow;
        _canWriteKnown = _canWriteToPeer;
      });
      _syncMessageActionsEnabled();
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
          style: TextStyle(fontFamily: 'Inter', color: scheme.onSurface),
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
    return ListenableBuilder(
      listenable: _bloc,
      builder: (context, _) {
        final chat = EventChatTheme.of(context);
        final subtitle = (_peerUsername != null && _peerUsername!.isNotEmpty)
            ? '@${_peerUsername!}'
            : null;
        final blockedView = _isBlocked || _isBlockedBy;
        final canWriteResolved = _canWriteKnown ?? true;

        return Scaffold(
          backgroundColor: chat.scaffold,
          extendBodyBehindAppBar: true,
          appBar: DirectChatAppBar(
            peerUserId: widget.userId,
            title: _titleForAppBar,
            subtitle: subtitle,
            avatarUrl: _peerAvatarResolved,
            titleLetter: _initialLetter(_titleForAppBar),
            isMuted: _isMutedNow,
            isBlocked: _isBlocked,
            canClearChat: _bloc.messages.isNotEmpty,
            onMuteFor: _setMuteFor,
            onUnmute: _unmute,
            onOpenProfile: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(userId: widget.userId),
                ),
              );
            },
            onDeleteChat: _confirmAndClearChat,
            onToggleBlockUser: _confirmAndToggleBlockUser,
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
                  child: (canWriteResolved == true)
                      ? DirectChatInput(bloc: _bloc)
                      : SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            child: blockedView
                                ? BlockedCard(
                                    isBlocked: _isBlocked,
                                    isBlockedBy: _isBlockedBy,
                                  )
                                : Card(
                                    elevation: 0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/friends/lock-dynamic-color.png',
                                            width: 34,
                                            height: 34,
                                          ),
                                          const SizedBox(width: 12),
                                          const Flexible(
                                            child: Text(
                                              'Пользователь не принимает сообщения от не друзей',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
