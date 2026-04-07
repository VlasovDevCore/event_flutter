import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../models/event_message.dart';
import '../../../services/api_client.dart';

/// Логика личного чата: как [ChatBloc], без события и сокета.
class DirectChatBloc extends ChangeNotifier {
  DirectChatBloc({
    required this.peerUserId,
    required String initialPeerTitle,
  }) : _peerDisplayLabel = initialPeerTitle;

  final String peerUserId;

  String _peerDisplayLabel;
  String? _peerEmail;
  String? _peerAvatarUrl;

  void setPeerProfile({
    String? displayName,
    String? email,
    String? avatarUrl,
  }) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      _peerDisplayLabel = displayName.trim();
    }
    _peerEmail = email?.trim();
    _peerAvatarUrl = avatarUrl;

    final me = myId;
    if (me != null) {
      messages = messages.map((m) {
        if (m.userId != me) {
          return m.copyWith(
            userDisplayName: _peerDisplayLabel,
            avatarUrl: _peerAvatarUrl,
            userEmail: _peerEmail ?? m.userEmail,
          );
        }
        return m;
      }).toList();
    }
    notifyListeners();
  }

  List<EventMessage> messages = [];
  bool loading = true;
  String? error;

  bool showScrollToBottom = false;
  int pendingNewMessagesCount = 0;

  final List<EventMessage> _bufferedNewMessages = [];
  String? lastMarkedViewUpToId;

  String? editingMessageId;
  EventMessage? replyingToMessage;

  bool emojiPickerVisible = false;

  final Map<String, bool> sendingStatus = {};
  final Map<String, bool> sentStatus = {};
  final Set<String> tempIds = {};

  String? jumpHighlightedMessageId;
  Timer? _jumpHighlightTimer;

  String? messageActionsMenuOpenForId;

  void setMessageActionsMenuOpen(String? messageId) {
    if (messageActionsMenuOpenForId == messageId) return;
    messageActionsMenuOpenForId = messageId;
    notifyListeners();
  }

  final Map<String, GlobalKey> _messageRowKeys = {};

  GlobalKey keyForMessage(String messageId) =>
      _messageRowKeys.putIfAbsent(messageId, GlobalKey.new);

  void _pruneMessageKeys() {
    final ids = messages.map((m) => m.id).toSet();
    _messageRowKeys.removeWhere((id, _) => !ids.contains(id));
  }

  final TextEditingController textController = TextEditingController();
  final FocusNode inputFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  Function(Offset, EventMessage, bool)? onShowMyMessageActions;
  Function(String)? onShowError;
  Function(Offset anchorGlobalPosition, EventMessage msg)? onShowCopyMenu;

  Timer? _pollTimer;

  static const double scrollToBottomThresholdPx = 140;

  String? get myId {
    final userId = Hive.box('authBox').get('userId') as String?;
    return userId?.trim().isEmpty == true ? null : userId?.trim();
  }

  String? get myEmail {
    final email = Hive.box('authBox').get('email') as String?;
    return email?.trim().isEmpty == true ? null : email?.trim();
  }

  bool get isOrganizer => false;

  Future<void> init() async {
    _setupScrollListener();
    _setupInputListener();
    await loadMessages();
    _startPolling();
  }

  EventMessage _rowToMessage(dynamic e) {
    return EventMessage.fromApi(Map<String, dynamic>.from(e as Map));
  }

  Future<void> loadMessages() async {
    loading = true;
    error = null;
    lastMarkedViewUpToId = null;
    _bufferedNewMessages.clear();
    notifyListeners();

    try {
      final list = await ApiClient.instance.getList(
        '/messages/with/$peerUserId',
        withAuth: true,
      );
      messages = list.map(_rowToMessage).toList();
      _pruneMessageKeys();
      loading = false;
      notifyListeners();
      _scrollToEnd();
    } on ApiException catch (e) {
      error = e.statusCode == 403
          ? 'Пользователь не принимает сообщения'
          : (e.statusCode == 401 ? 'Войдите в аккаунт' : e.message);
      messages = [];
      loading = false;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      messages = [];
      loading = false;
      notifyListeners();
    }
  }

  void clearConversationLocal() {
    messages = [];
    loading = false;
    error = null;
    showScrollToBottom = false;
    pendingNewMessagesCount = 0;
    _bufferedNewMessages.clear();
    lastMarkedViewUpToId = null;
    editingMessageId = null;
    replyingToMessage = null;
    emojiPickerVisible = false;
    sendingStatus.clear();
    sentStatus.clear();
    tempIds.clear();
    jumpHighlightedMessageId = null;
    messageActionsMenuOpenForId = null;
    _pruneMessageKeys();
    notifyListeners();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!scrollController.hasClients) return;
      await scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      _scheduleMarkViewed();
    });
  }

  /// Якорь для POST view: последнее по времени сообщение без temp (иначе чужие
  /// сообщения не отмечаются, пока висит исходящий черновик).
  EventMessage? _anchorMessageForView() {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].id.startsWith('temp_')) return messages[i];
    }
    return null;
  }

  Future<void> markMessagesViewedIfNeeded() async {
    if (messages.isEmpty || myId == null || error != null) return;
    final anchor = _anchorMessageForView();
    if (anchor == null) return;
    if (!isScrolledToBottom()) return;
    if (lastMarkedViewUpToId == anchor.id) return;

    try {
      await ApiClient.instance.post(
        '/messages/with/$peerUserId/view',
        body: {'up_to_id': anchor.id},
        withAuth: true,
      );
      lastMarkedViewUpToId = anchor.id;
      _applyLocalIncomingViewedUpTo(anchor);
      notifyListeners();
    } catch (_) {}
  }

  /// Локально помечаем входящие от собеседника как прочитанные до якоря (после успешного POST view).
  void _applyLocalIncomingViewedUpTo(EventMessage anchor) {
    final me = myId;
    if (me == null) return;
    messages = messages.map((m) {
      if (m.id.startsWith('temp_')) return m;
      if (m.userId == null || m.userId == me) return m;
      if (m.userId != peerUserId) return m;
      if (m.createdAt.isAfter(anchor.createdAt)) return m;
      if (m.isViewed) return m;
      return m.copyWith(
        isViewed: true,
        viewedAt: m.viewedAt ?? DateTime.now(),
      );
    }).toList();
  }

  /// Два кадра после обновления списка (отправка/получение), чтобы позиция скролла была актуальна для POST view.
  void _scheduleMarkViewed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        markMessagesViewedIfNeeded();
      });
    });
  }

  void _flushBufferedIfAtBottom() {
    if (_bufferedNewMessages.isEmpty) return;
    if (!isScrolledToBottom()) return;

    messages = [...messages, ..._bufferedNewMessages];
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _bufferedNewMessages.clear();
    pendingNewMessagesCount = 0;
    notifyListeners();

    _scheduleMarkViewed();
  }

  bool isScrolledToBottom() {
    if (!scrollController.hasClients) return true;
    final p = scrollController.position;
    if (!p.hasPixels) return true;
    if (p.maxScrollExtent <= 0) return true;
    // reverse: true — низ ленты у minScrollExtent; extentBefore = отступ от «дна».
    const tolerancePx = 100.0;
    return p.extentBefore <= tolerancePx;
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      final offset = scrollController.offset;
      final maxExt = scrollController.position.maxScrollExtent;
      final shouldShow = maxExt > 0 && offset > scrollToBottomThresholdPx;

      if (shouldShow != showScrollToBottom) {
        showScrollToBottom = shouldShow;
        notifyListeners();
      }

      _flushBufferedIfAtBottom();

      markMessagesViewedIfNeeded();
    });
  }

  void _setupInputListener() {
    inputFocusNode.addListener(() {
      if (inputFocusNode.hasFocus && emojiPickerVisible) {
        emojiPickerVisible = false;
        notifyListeners();
      }
    });
  }

  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    if (editingMessageId != null) {
      await _updateMessage(text);
      return;
    }

    await _sendNewMessage(text);
  }

  void startReplyTo(EventMessage msg) {
    editingMessageId = null;
    replyingToMessage = msg;
    textController.clear();
    emojiPickerVisible = false;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      inputFocusNode.requestFocus();
    });
  }

  void cancelReply() {
    replyingToMessage = null;
    notifyListeners();
  }

  void startEditingMessage(EventMessage msg) {
    replyingToMessage = null;
    editingMessageId = msg.id;
    textController.text = msg.text;
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: msg.text.length),
    );
    notifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      inputFocusNode.requestFocus();
    });
  }

  void cancelEditing() {
    editingMessageId = null;
    replyingToMessage = null;
    textController.clear();
    emojiPickerVisible = false;
    notifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      inputFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Future<void> _updateMessage(String text) async {
    final editingId = editingMessageId!;
    final idx = messages.indexWhere((m) => m.id == editingId);
    if (idx == -1) {
      cancelEditing();
      return;
    }

    final prev = messages[idx];
    if (text == prev.text) {
      cancelEditing();
      return;
    }

    try {
      final data = await ApiClient.instance.put(
        '/messages/with/$peerUserId/$editingId',
        body: {'text': text},
        withAuth: true,
      );
      final updated = EventMessage.fromApi(Map<String, dynamic>.from(data));
      messages[idx] = updated.copyWith(
        isViewed: prev.isViewed,
        viewedAt: prev.viewedAt,
      );
      cancelEditing();
      notifyListeners();
    } on ApiException catch (e) {
      onShowError?.call(e.message);
    } catch (_) {
      onShowError?.call('Не удалось изменить сообщение');
    }
  }

  Future<void> _sendNewMessage(String text) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    tempIds.add(tempId);

    final replySnap = replyingToMessage;
    final replyToIdForApi =
        replySnap != null && !replySnap.id.startsWith('temp_')
            ? replySnap.id
            : null;

    final tempMessage = EventMessage(
      id: tempId,
      text: text,
      userEmail: myEmail ?? 'me',
      userDisplayName: null,
      createdAt: DateTime.now(),
      userId: myId,
      replyToId: replySnap?.id,
      replyToText: replySnap?.text,
      replyToAuthorName: replySnap?.displayName,
      replyToAuthorEmail:
          replySnap != null && replySnap.userEmail.isNotEmpty
              ? replySnap.userEmail
              : null,
    );

    messages = [...messages, tempMessage];
    sendingStatus[tempId] = true;
    sentStatus[tempId] = false;
    emojiPickerVisible = false;
    replyingToMessage = null;
    textController.clear();
    notifyListeners();

    _scrollToEnd();

    try {
      final body = <String, dynamic>{'text': text};
      if (replyToIdForApi != null) {
        body['reply_to_id'] = replyToIdForApi;
      }

      final data = await ApiClient.instance.post(
        '/messages/with/$peerUserId',
        body: body,
        withAuth: true,
      );
      final real = EventMessage.fromApi(Map<String, dynamic>.from(data));

      final index = messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        messages[index] = real;
      }

      sendingStatus.remove(tempId);
      sentStatus.remove(tempId);
      tempIds.remove(tempId);
      notifyListeners();

      _scrollToEnd();
      unawaited(_pollTick());
    } catch (e) {
      sendingStatus[tempId] = false;
      sentStatus[tempId] = false;
      notifyListeners();

      final errorMsg = e is ApiException && e.statusCode == 403
          ? 'Нельзя написать пользователю'
          : 'Не удалось отправить сообщение';
      onShowError?.call(errorMsg);
      textController.text = text;
      replyingToMessage = replySnap;
    }
  }

  void toggleEmojiPicker() {
    emojiPickerVisible = !emojiPickerVisible;
    if (emojiPickerVisible) {
      inputFocusNode.unfocus();
    }
    notifyListeners();
  }

  void scrollToBottom() {
    if (_bufferedNewMessages.isNotEmpty) {
      messages = [...messages, ..._bufferedNewMessages];
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _bufferedNewMessages.clear();
    }
    pendingNewMessagesCount = 0;
    notifyListeners();
    _scrollToEnd();
  }

  Future<void> deleteMessage(EventMessage msg) async {
    if (msg.id.startsWith('temp_')) {
      messages.removeWhere((m) => m.id == msg.id);
      sendingStatus.remove(msg.id);
      sentStatus.remove(msg.id);
      tempIds.remove(msg.id);
      _bufferedNewMessages.removeWhere((m) => m.id == msg.id);
      if (messageActionsMenuOpenForId == msg.id) {
        messageActionsMenuOpenForId = null;
      }
      if (jumpHighlightedMessageId == msg.id) {
        jumpHighlightedMessageId = null;
      }
      _pruneMessageKeys();
      notifyListeners();
      return;
    }

    try {
      await ApiClient.instance.delete(
        '/messages/with/$peerUserId/${msg.id}',
        withAuth: true,
      );
      messages.removeWhere((m) => m.id == msg.id);
      _bufferedNewMessages.removeWhere((m) => m.id == msg.id);
      if (messageActionsMenuOpenForId == msg.id) {
        messageActionsMenuOpenForId = null;
      }
      if (jumpHighlightedMessageId == msg.id) {
        jumpHighlightedMessageId = null;
      }
      _pruneMessageKeys();
      notifyListeners();
    } on ApiException catch (e) {
      onShowError?.call(e.message);
    } catch (_) {
      onShowError?.call('Не удалось удалить сообщение');
    }
  }

  void showMyMessageActions(Offset anchorGlobalPosition, EventMessage msg) {
    final isSending = sendingStatus[msg.id] ?? false;
    onShowMyMessageActions?.call(anchorGlobalPosition, msg, isSending);
  }

  void showOrganizerMessageActions(Offset anchorGlobalPosition, EventMessage msg) {}

  void showCopyMenuForMessage(Offset anchorGlobalPosition, EventMessage msg) {
    onShowCopyMenu?.call(anchorGlobalPosition, msg);
  }

  Future<void> scrollToRepliedMessage(String? replyToId) async {
    if (replyToId == null || replyToId.isEmpty) return;
    _pruneMessageKeys();
    final ki = messages.indexWhere((m) => m.id == replyToId);
    if (ki == -1) return;

    final key = keyForMessage(replyToId);

    Future<void> tryEnsure() async {
      final ctx = key.currentContext;
      if (ctx == null) return;
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.32,
      );
    }

    await tryEnsure();
    if (key.currentContext != null) {
      _flashJumpHighlight(replyToId);
      return;
    }

    final sc = scrollController;
    if (!sc.hasClients) return;
    final max = sc.position.maxScrollExtent;
    final len = messages.length;
    if (len <= 1) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tryEnsure();
      if (key.currentContext != null) {
        _flashJumpHighlight(replyToId);
      }
      return;
    }

    final t = (len - 1 - ki) / (len - 1);
    await sc.animateTo(
      (max * t).clamp(0.0, max),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await tryEnsure();
    if (key.currentContext != null) {
      _flashJumpHighlight(replyToId);
    }
  }

  void _flashJumpHighlight(String messageId) {
    _jumpHighlightTimer?.cancel();
    jumpHighlightedMessageId = messageId;
    notifyListeners();
    _jumpHighlightTimer = Timer(const Duration(milliseconds: 2000), () {
      jumpHighlightedMessageId = null;
      notifyListeners();
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollTick());
  }

  Future<void> _pollTick() async {
    if (error != null) return;
    try {
      final list = await ApiClient.instance.getList(
        '/messages/with/$peerUserId',
        withAuth: true,
      );
      final incoming = list.map(_rowToMessage).toList();

      if (incoming.isEmpty && messages.isEmpty) return;

      _mergeServerMessages(incoming);
    } catch (_) {}
  }

  void _mergeServerMessages(List<EventMessage> serverList) {
    final me = myId;
    if (me == null) return;

    final serverMap = {for (final s in serverList) s.id: s};

    final updated = <EventMessage>[];
    for (final m in messages) {
      if (m.id.startsWith('temp_')) {
        updated.add(m);
        continue;
      }
      final sv = serverMap[m.id];
      if (sv == null) {
        continue;
      }
      updated.add(sv);
    }

    final haveIds = updated.map((m) => m.id).toSet();
    final bufferedIds = _bufferedNewMessages.map((m) => m.id).toSet();

    final newOnes = serverList.where((s) {
      if (s.id.startsWith('temp_')) return false;
      return !haveIds.contains(s.id) && !bufferedIds.contains(s.id);
    }).toList();

    newOnes.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final n in newOnes) {
      if (n.userId == me) {
        updated.removeWhere((m) => m.id.startsWith('temp_'));
        updated.add(n);
        continue;
      }
      if (isScrolledToBottom()) {
        updated.add(n);
      } else {
        if (!_bufferedNewMessages.any((b) => b.id == n.id)) {
          _bufferedNewMessages.add(n);
        }
      }
    }

    updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    messages = updated;
    pendingNewMessagesCount = _bufferedNewMessages.length;
    _pruneMessageKeys();
    notifyListeners();

    if (isScrolledToBottom()) {
      _scheduleMarkViewed();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _jumpHighlightTimer?.cancel();
    textController.dispose();
    inputFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
