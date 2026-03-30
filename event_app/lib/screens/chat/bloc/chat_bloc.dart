import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? editingMessageId;
  bool emojiPickerVisible = false;
  String? lastMarkedViewUpToId;
  final Set<String> processedIds = {};
  final Map<String, bool> sendingStatus = {};
  final Map<String, bool> sentStatus = {};
  final Set<String> tempIds = {};

  final TextEditingController textController = TextEditingController();
  final FocusNode inputFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  // Добавляем колбэки для UI
  Function(EventMessage, bool)? onShowMyMessageActions;
  Function(EventMessage)? onShowOrganizerMessageActions;
  Function(String)? onShowError;

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
    const edge = 56.0;
    if (p.maxScrollExtent <= 0) return true;
    return p.pixels <= edge;
  }

  Future<void> markMessagesViewedIfNeeded() async {
    if (messages.isEmpty || myId == null || error != null) return;
    final last = messages.last;
    if (last.id.startsWith('temp_')) return;
    if (!isScrolledToBottom()) return;
    if (lastMarkedViewUpToId == last.id) return;

    try {
      await _repository.markMessagesViewed(last.id);
      lastMarkedViewUpToId = last.id;
      notifyListeners();
    } catch (_) {}
  }

  void _scheduleMarkViewed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        markMessagesViewedIfNeeded();
      });
    });
  }

  void showMyMessageActions(EventMessage msg) {
    final isSending = sendingStatus[msg.id] ?? false;
    onShowMyMessageActions?.call(msg, isSending);
  }

  void showOrganizerMessageActions(EventMessage msg) {
    onShowOrganizerMessageActions?.call(msg);
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      final offset = scrollController.offset;
      final maxExt = scrollController.position.maxScrollExtent;
      final shouldShow =
          maxExt > 0 && offset > scrollToBottomThresholdPx;

      if (shouldShow != showScrollToBottom) {
        showScrollToBottom = shouldShow;
        notifyListeners();
      }

      if (isScrolledToBottom() && pendingNewMessagesCount > 0) {
        pendingNewMessagesCount = 0;
        notifyListeners();
      }

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

    final tempMessage = EventMessage(
      id: tempId,
      text: text,
      userEmail: myEmail ?? 'me',
      userDisplayName: null,
      createdAt: DateTime.now(),
      userId: myId,
    );

    messages = [...messages, tempMessage];
    sendingStatus[tempId] = true;
    sentStatus[tempId] = false;
    emojiPickerVisible = false;
    textController.clear();
    notifyListeners();

    _scrollToEnd();

    try {
      final realMessage = await _repository.sendMessage(text);
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
    }
  }

  void startEditingMessage(EventMessage msg) {
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
      notifyListeners();
      return;
    }

    try {
      await _repository.deleteMessage(msg.id);
      messages.removeWhere((m) => m.id == msg.id);
      notifyListeners();
    } catch (e) {
      onShowError?.call('Не удалось удалить сообщение');
    }
  }

  void copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    onShowError?.call('Скопировано');
  }

  void toggleEmojiPicker() {
    emojiPickerVisible = !emojiPickerVisible;
    if (emojiPickerVisible) {
      inputFocusNode.unfocus();
    }
    notifyListeners();
  }

  void scrollToBottom() {
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
    if (messages.any((m) => m.id == msg.id)) return;

    final wasAtBottom = isScrolledToBottom();
    messages = [...messages, msg];
    notifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (wasAtBottom) {
        if (pendingNewMessagesCount > 0) {
          pendingNewMessagesCount = 0;
          notifyListeners();
        }
        _scrollToEnd();
        _scheduleMarkViewed();
      } else {
        pendingNewMessagesCount++;
        notifyListeners();
      }
    });
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
      }
    } catch (_) {}
  }

  void _handleMessageDeleted(dynamic data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : null;
    if (map == null) return;

    final id = map['id'] as String?;
    if (id != null) {
      messages.removeWhere((m) => m.id == id);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    socket?.emit('leaveEvent', event.id);
    socket?.disconnect();
    socket?.dispose();
    textController.dispose();
    inputFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
