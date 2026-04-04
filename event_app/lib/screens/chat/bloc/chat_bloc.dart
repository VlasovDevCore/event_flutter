import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../models/event.dart';
import '../../../models/event_message.dart';
import '../../../services/api_client.dart';
import '../repositories/chat_repository.dart';

// Добавляем класс для событий
enum ChatEvent { editMessage, deleteMessage, copyMessage }

class ChatBloc extends ChangeNotifier {
  final Event event;
  final ChatRepository _repository;

  List<EventMessage> messages = [];
  bool loading = true;
  String? error;
  io.Socket? socket;
  bool showScrollToBottom = false;
  int pendingNewMessagesCount = 0;
  final List<EventMessage> _bufferedNewMessages = [];
  String? editingMessageId;
  /// Сообщение, на которое отвечаем (превью над полем ввода).
  EventMessage? replyingToMessage;
  bool emojiPickerVisible = false;
  String? lastMarkedViewUpToId;
  final Set<String> processedIds = {};
  final Map<String, bool> sendingStatus = {};
  final Map<String, bool> sentStatus = {};
  final Set<String> tempIds = {};

  /// Якоря строк списка для [Scrollable.ensureVisible] (переход к цитируемому сообщению).
  final Map<String, GlobalKey> _messageRowKeys = {};

  GlobalKey keyForMessage(String messageId) =>
      _messageRowKeys.putIfAbsent(messageId, GlobalKey.new);

  void _pruneMessageKeys() {
    final ids = messages.map((m) => m.id).toSet();
    _messageRowKeys.removeWhere((id, _) => !ids.contains(id));
  }

  /// Краткая подсветка сообщения после перехода по цитате ответа.
  String? jumpHighlightedMessageId;
  Timer? _jumpHighlightTimer;

  /// Пузырь, для которого открыто меню действий (копировать, ответить…).
  String? messageActionsMenuOpenForId;

  void setMessageActionsMenuOpen(String? messageId) {
    if (messageActionsMenuOpenForId == messageId) return;
    messageActionsMenuOpenForId = messageId;
    notifyListeners();
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

  void _clearJumpHighlightIfMessageRemoved(String messageId) {
    if (jumpHighlightedMessageId == messageId) {
      _jumpHighlightTimer?.cancel();
      jumpHighlightedMessageId = null;
      notifyListeners();
    }
  }

  void _clearMessageActionsMenuIfMessageRemoved(String messageId) {
    if (messageActionsMenuOpenForId == messageId) {
      messageActionsMenuOpenForId = null;
    }
  }

  final TextEditingController textController = TextEditingController();
  final FocusNode inputFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  // Добавляем колбэки для UI
  Function(Offset, EventMessage, bool)? onShowMyMessageActions;
  Function(Offset, EventMessage)? onShowOrganizerMessageActions;
  Function(String)? onShowError;
  /// Меню «Копировать» для чужих сообщений (якорь — низ пузыря в глобальных координатах).
  Function(Offset anchorGlobalPosition, EventMessage msg)? onShowCopyMenu;

  static const double scrollToBottomThresholdPx = 140;

  String? get myId {
    final userId = Hive.box('authBox').get('userId') as String?;
    return userId?.trim().isEmpty == true ? null : userId?.trim();
  }

  String? get myEmail {
    final email = Hive.box('authBox').get('email') as String?;
    return email?.trim().isEmpty == true ? null : email?.trim();
  }

  bool get isOrganizer {
    final c = event.creatorId?.trim();
    final me = myId;
    return c != null && c.isNotEmpty && me != null && c == me;
  }

  ChatBloc({required this.event}) : _repository = ChatRepository(event.id);

  Future<void> init() async {
    await loadMessages();
    _setupScrollListener();
    _setupInputListener();
  }

  Future<void> loadMessages() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final list = await _repository.getMessages();
      messages = list;

      for (final msg in messages) {
        processedIds.add(msg.id);
      }

      _pruneMessageKeys();

      loading = false;
      notifyListeners();

      _setupSocket();
      _scheduleMarkViewed();
    } on ApiException catch (e) {
      error = _getErrorMessage(e);
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

  String _getErrorMessage(ApiException e) {
    if (e.statusCode == 403) return 'Вы не участвуете в этом событии';
    if (e.statusCode == 401) return 'Войдите в аккаунт';
    return e.message;
  }

  /// Список [ListView.reverse] = true: «низ» чата — offset 0.
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

  bool isScrolledToBottom() {
    if (!scrollController.hasClients) return true;
    final p = scrollController.position;
    if (!p.hasPixels) return true;
    if (p.maxScrollExtent <= 0) return true;
    const tolerancePx = 100.0;
    return p.extentBefore <= tolerancePx;
  }

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
      await _repository.markMessagesViewed(anchor.id);
      lastMarkedViewUpToId = anchor.id;
      notifyListeners();
    } catch (_) {}
  }

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
    _bufferedNewMessages.clear();
    pendingNewMessagesCount = 0;
    notifyListeners();

    _scheduleMarkViewed();
  }

  void showMyMessageActions(Offset anchorGlobalPosition, EventMessage msg) {
    final isSending = sendingStatus[msg.id] ?? false;
    onShowMyMessageActions?.call(anchorGlobalPosition, msg, isSending);
  }

  void showOrganizerMessageActions(
    Offset anchorGlobalPosition,
    EventMessage msg,
  ) {
    onShowOrganizerMessageActions?.call(anchorGlobalPosition, msg);
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

  // Методы для работы с сообщениями
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
      final updated = await _repository.updateMessage(editingId, text);
      messages[idx] = updated.copyWith(
        isViewed: prev.isViewed,
        viewedAt: prev.viewedAt,
      );
      cancelEditing();
      notifyListeners();
    } catch (e) {
      onShowError?.call('Не удалось изменить сообщение');
    }
  }

  Future<void> _sendNewMessage(String text) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    tempIds.add(tempId);

    final replySnap = replyingToMessage;
    final replyToIdForApi = replySnap != null && !replySnap.id.startsWith('temp_')
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
      final realMessage = await _repository.sendMessage(
        text,
        replyToId: replyToIdForApi,
      );
      processedIds.add(realMessage.id);

      final index = messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        messages[index] = realMessage;
      }

      sendingStatus.remove(tempId);
      sentStatus.remove(tempId);
      tempIds.remove(tempId);
      notifyListeners();

      _scrollToEnd();
    } catch (e) {
      sendingStatus[tempId] = false;
      sentStatus[tempId] = false;
      notifyListeners();

      final errorMsg = e is ApiException && e.statusCode == 403
          ? 'Вы не участвуете в этом событии'
          : 'Не удалось отправить сообщение';
      onShowError?.call(errorMsg);
      textController.text = text;
      replyingToMessage = replySnap;
    }
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

    // После снятия баннера фокус с IconButton «Отмена» переходит на TextField —
    // снимаем фокус на следующем кадре, чтобы клавиатура не открывалась.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      inputFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Future<void> deleteMessage(EventMessage msg) async {
    if (msg.id.startsWith('temp_')) {
      messages.removeWhere((m) => m.id == msg.id);
      sendingStatus.remove(msg.id);
      sentStatus.remove(msg.id);
      tempIds.remove(msg.id);
      _clearJumpHighlightIfMessageRemoved(msg.id);
      _clearMessageActionsMenuIfMessageRemoved(msg.id);
      _pruneMessageKeys();
      notifyListeners();
      return;
    }

    try {
      await _repository.deleteMessage(msg.id);
      messages.removeWhere((m) => m.id == msg.id);
      _clearJumpHighlightIfMessageRemoved(msg.id);
      _clearMessageActionsMenuIfMessageRemoved(msg.id);
      _pruneMessageKeys();
      notifyListeners();
    } catch (e) {
      onShowError?.call('Не удалось удалить сообщение');
    }
  }

  void showCopyMenuForMessage(
    Offset anchorGlobalPosition,
    EventMessage msg,
  ) {
    onShowCopyMenu?.call(anchorGlobalPosition, msg);
  }

  /// Прокрутка к исходному сообщению по тапу на превью ответа.
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
      return;
    }

    await sc.animateTo(
      (max * (t * 0.92 + 0.04)).clamp(0.0, max),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await tryEnsure();
    if (key.currentContext != null) {
      _flashJumpHighlight(replyToId);
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
    // Если пользователь явно нажал «вниз», сразу показываем накопленные сообщения
    // (и одновременно сбрасываем счётчик).
    if (_bufferedNewMessages.isNotEmpty) {
      messages = [...messages, ..._bufferedNewMessages];
      _bufferedNewMessages.clear();
    }
    pendingNewMessagesCount = 0;
    notifyListeners();
    _scrollToEnd();
  }

  void _setupSocket() {
    if (error != null) return;

    try {
      socket = io.io(
        ApiClient.baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .build(),
      );

      socket!.connect();
      socket!.emit('joinEvent', event.id);

      socket!.on('newMessage', (data) => _handleNewMessage(data));
      socket!.on('messagesViewed', (data) => _handleMessagesViewed(data));
      socket!.on('messageUpdated', (data) => _handleMessageUpdated(data));
      socket!.on('messageDeleted', (data) => _handleMessageDeleted(data));
    } catch (_) {}
  }

  void _handleNewMessage(dynamic data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : null;
    if (map == null) return;

    final msg = EventMessage.fromApi(map);
    if (myId != null && msg.userId == myId) return;
    if (messages.any((m) => m.id == msg.id) ||
        _bufferedNewMessages.any((m) => m.id == msg.id)) {
      return;
    }

    final wasAtBottom = isScrolledToBottom();

    // Если пользователь не внизу — копим, но не показываем.
    if (!wasAtBottom) {
      _bufferedNewMessages.add(msg);
      pendingNewMessagesCount = _bufferedNewMessages.length;
      notifyListeners();
      return;
    }

    // Пользователь внизу — добавляем и показываем сразу.
    messages = [...messages, msg];
    notifyListeners();

    // Если пользователь был внизу - прокручиваем к новому сообщению
    if (wasAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          // Плавно прокручиваем вниз
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
          _scheduleMarkViewed();
        }
      });
    }
  }

  void _handleMessagesViewed(dynamic data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : null;
    if (map == null) return;

    final viewerId = map['user_id'] as String?;
    final upToId = map['up_to_id'] as String?;
    if (viewerId == null || viewerId == myId) return;

    final anchorIdx = messages.indexWhere((m) => m.id == upToId);
    if (anchorIdx == -1) return;

    final anchor = messages[anchorIdx];
    messages = messages.map((m) {
      if (m.userId == myId && !m.createdAt.isAfter(anchor.createdAt)) {
        return m.copyWith(isViewed: true);
      }
      return m;
    }).toList();

    notifyListeners();
  }

  void _handleMessageUpdated(dynamic data) {
    try {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;

      final idStr = map['id']?.toString();
      if (idStr == null || idStr.isEmpty) return;

      final textNew = map['text']?.toString();
      if (textNew == null) return;

      DateTime? editedAtNew;
      final ea = map['edited_at'];
      if (ea is String && ea.isNotEmpty) {
        editedAtNew = EventMessage.tryParseDateTimeFromApi(ea);
      }

      final i = messages.indexWhere((m) => m.id == idStr);
      if (i != -1) {
        final prev = messages[i];
        messages[i] = prev.copyWith(
          text: textNew,
          editedAt: editedAtNew ?? prev.editedAt,
        );
        notifyListeners();
        return;
      }

      final j = _bufferedNewMessages.indexWhere((m) => m.id == idStr);
      if (j != -1) {
        final prev = _bufferedNewMessages[j];
        _bufferedNewMessages[j] = prev.copyWith(
          text: textNew,
          editedAt: editedAtNew ?? prev.editedAt,
        );
      }
    } catch (_) {}
  }

  void _handleMessageDeleted(dynamic data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : null;
    if (map == null) return;

    final id = map['id'] as String?;
    if (id != null) {
      _clearJumpHighlightIfMessageRemoved(id);
      messages.removeWhere((m) => m.id == id);
      final before = _bufferedNewMessages.length;
      _bufferedNewMessages.removeWhere((m) => m.id == id);
      if (_bufferedNewMessages.length != before) {
        pendingNewMessagesCount = _bufferedNewMessages.length;
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _jumpHighlightTimer?.cancel();
    socket?.emit('leaveEvent', event.id);
    socket?.disconnect();
    socket?.dispose();
    textController.dispose();
    inputFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
