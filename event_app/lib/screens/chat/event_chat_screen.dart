import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/event.dart';
import '../../models/event_message.dart';
import '../../services/api_client.dart';
import '../events/event_details_screen.dart';

/// Чат события. Доступен только участникам (RSVP «приду»).
/// После окончания события чат остаётся.
class EventChatScreen extends StatefulWidget {
  const EventChatScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  List<EventMessage> _messages = [];
  bool _loading = true;
  String? _error;
  io.Socket? _socket;
  bool _showScrollToBottom = false;
  static const double _scrollToBottomThresholdPx = 140;

  /// Новые сообщения, пришедшие пока пользователь не у низа (показ у кнопки «вниз»).
  int _pendingNewMessagesCount = 0;

  // Храним статусы отправки сообщений (локальные)
  final Map<String, bool> _sendingStatus = {}; // id -> isSending
  final Map<String, bool> _sentStatus = {}; // id -> isSent
  final Set<String> _tempIds = {}; // Храним временные ID
  final Set<String> _processedIds = {}; // Храним ID уже обработанных сообщений

  /// Последнее сообщение, до которого уже отправили mark-view на сервер.
  String? _lastMarkedViewUpToId;

  /// Редактирование существующего сообщения (текст в поле ввода).
  String? _editingMessageId;

  bool _emojiPickerVisible = false;

  String? get _myId {
    final userId = Hive.box('authBox').get('userId') as String?;
    return userId?.trim().isEmpty == true ? null : userId?.trim();
  }

  String? get _myEmail {
    final email = Hive.box('authBox').get('email') as String?;
    return email?.trim().isEmpty == true ? null : email?.trim();
  }

  bool get _isOrganizer {
    final c = widget.event.creatorId?.trim();
    final me = _myId;
    return c != null && c.isNotEmpty && me != null && c == me;
  }

  /// Какое сообщение сейчас редактируется (для подсказки над полем ввода).
  String get _editingMessageBannerPreview {
    final id = _editingMessageId;
    if (id == null) return '';
    for (final m in _messages) {
      if (m.id == id) {
        final t = m.text.trim();
        return t.isEmpty ? '…' : t;
      }
    }
    final t = _textController.text.trim();
    return t.isEmpty ? '…' : t;
  }

  /// Один и тот же отправитель (подряд идущие сообщения в списке).
  bool _sameSender(EventMessage a, EventMessage b) {
    final aId = a.userId?.trim();
    final bId = b.userId?.trim();
    if (aId != null &&
        aId.isNotEmpty &&
        bId != null &&
        bId.isNotEmpty) {
      return aId == bId;
    }
    return a.userEmail == b.userEmail;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDayDivider(DateTime day) {
    final label = DateFormat('d MMMM', 'ru').format(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient.instance;
      final list = await client.getList(
        '/events/${widget.event.id}/messages',
        withAuth: true,
      );
      final messages = list
          .map((e) => EventMessage.fromApi(e as Map<String, dynamic>))
          .toList();

      // Добавляем все ID в обработанные
      for (final msg in messages) {
        _processedIds.add(msg.id);
      }

      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToEnd();
      _setupSocket();
      _scheduleMarkViewed();
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 403
            ? 'Вы не участвуете в этом событии'
            : e.statusCode == 401
            ? 'Войдите в аккаунт'
            : e.message;
        _messages = [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _messages = [];
        _loading = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients) return;
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (mounted) _scheduleMarkViewed();
    });
  }

  bool _isScrolledToBottom() {
    if (!_scrollController.hasClients) return true;
    final p = _scrollController.position;
    const edge = 56.0;
    if (p.maxScrollExtent <= 0) return true;
    return p.pixels >= p.maxScrollExtent - edge;
  }

  /// Отметить прочитанными чужие сообщения до последнего в списке (когда пользователь внизу).
  Future<void> _markMessagesViewedIfNeeded() async {
    if (_messages.isEmpty || _myId == null || _error != null) return;
    final last = _messages.last;
    if (last.id.startsWith('temp_')) return;
    if (!_isScrolledToBottom()) return;
    if (_lastMarkedViewUpToId == last.id) return;

    try {
      await ApiClient.instance.post(
        '/events/${widget.event.id}/messages/view',
        body: {'up_to_id': last.id},
        withAuth: true,
      );
      if (!mounted) return;
      setState(() => _lastMarkedViewUpToId = last.id);
    } catch (_) {
      // миграция не применена / сеть — повторим при следующем скролле
    }
  }

  void _scheduleMarkViewed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _markMessagesViewedIfNeeded();
      });
    });
  }

  void _showMyMessageActions(EventMessage msg, bool isSending) {
    final isTemp = msg.id.startsWith('temp_');
    final canEdit = !isTemp && !isSending;
    final canDelete = isTemp || (!isTemp && !isSending);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text(
                'Скопировать',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.text));
              },
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.white70),
                title: const Text(
                  'Изменить',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEditingMessage(msg);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text(
                  'Удалить',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMessage(msg);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _startEditingMessage(EventMessage msg) {
    setState(() {
      _editingMessageId = msg.id;
      _textController.text = msg.text;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: msg.text.length),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  void _cancelEditingMessage() {
    setState(() {
      _editingMessageId = null;
      _textController.clear();
      _emojiPickerVisible = false;
    });
  }

  void _showOrganizerOtherMessageActions(EventMessage msg) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text(
                'Скопировать',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.text));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                'Удалить сообщение',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.redAccent,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteMessage(msg);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMessage(EventMessage msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text(
          'Удалить сообщение?',
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Это действие нельзя отменить.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (msg.id.startsWith('temp_')) {
      setState(() {
        _messages.removeWhere((m) => m.id == msg.id);
        _sendingStatus.remove(msg.id);
        _sentStatus.remove(msg.id);
        _tempIds.remove(msg.id);
      });
      return;
    }

    try {
      await ApiClient.instance.delete(
        '/events/${widget.event.id}/messages/${msg.id}',
        withAuth: true,
      );
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == msg.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Не удалось удалить сообщение',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxExt = _scrollController.position.maxScrollExtent;
    final shouldShow = maxExt > 0 &&
        offset < maxExt - _scrollToBottomThresholdPx;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
    if (_isScrolledToBottom() && _pendingNewMessagesCount > 0) {
      setState(() => _pendingNewMessagesCount = 0);
    }
    _markMessagesViewedIfNeeded();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final editingId = _editingMessageId;
    if (editingId != null) {
      final idx = _messages.indexWhere((m) => m.id == editingId);
      if (idx == -1) {
        _cancelEditingMessage();
        return;
      }
      final prev = _messages[idx];
      if (text == prev.text) {
        _cancelEditingMessage();
        return;
      }
      try {
        final data = await ApiClient.instance.put(
          '/events/${widget.event.id}/messages/$editingId',
          body: {'text': text},
          withAuth: true,
        );
        final updated = EventMessage.fromApi(data);
        if (!mounted) return;
        setState(() {
          _messages[idx] = updated.copyWith(
            isViewed: prev.isViewed,
            viewedAt: prev.viewedAt,
          );
          _editingMessageId = null;
          _textController.clear();
          _emojiPickerVisible = false;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Не удалось изменить сообщение',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Создаем временное сообщение с локальным ID
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    _tempIds.add(tempId);

    final tempMessage = EventMessage(
      id: tempId,
      text: text,
      userEmail: _myEmail ?? 'me',
      userDisplayName: null,
      createdAt: DateTime.now(),
      userId: _myId,
    );

    // Добавляем сообщение и устанавливаем статус отправки
    setState(() {
      _messages = [..._messages, tempMessage];
      _sendingStatus[tempId] = true;
      _sentStatus[tempId] = false;
      _emojiPickerVisible = false;
    });
    _textController.clear();
    _scrollToEnd();

    try {
      final client = ApiClient.instance;
      final data = await client.post(
        '/events/${widget.event.id}/messages',
        body: {'text': text},
        withAuth: true,
      );
      final realMessage = EventMessage.fromApi(data);

      // Добавляем реальный ID в обработанные
      _processedIds.add(realMessage.id);

      // Заменяем временное сообщение на реальное
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index] = realMessage;
        }
        _sendingStatus.remove(tempId);
        _sentStatus.remove(tempId);
        _tempIds.remove(tempId);
      });
      _scrollToEnd();
    } catch (e) {
      // При ошибке показываем красный статус
      setState(() {
        _sendingStatus[tempId] = false;
        _sentStatus[tempId] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException && e.statusCode == 403
                  ? 'Вы не участвуете в этом событии'
                  : 'Не удалось отправить сообщение',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      _textController.text = text;
    }
  }

  void _setupSocket() {
    if (_error != null) return;
    try {
      _socket = io.io(
        ApiClient.baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .build(),
      );
      _socket!.connect();
      _socket!.emit('joinEvent', widget.event.id);
      _socket!.on('newMessage', (data) {
        if (!mounted) return;
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final msg = EventMessage.fromApi(map);

        // Игнорируем свои сообщения из сокета (сравниваем по userId)
        if (_myId != null && msg.userId == _myId) {
          return;
        }

        // Проверяем, нет ли уже такого сообщения
        if (_messages.any((m) => m.id == msg.id)) return;

        final wasAtBottom = _isScrolledToBottom();

        setState(() {
          _messages = [..._messages, msg];
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (wasAtBottom) {
            if (_pendingNewMessagesCount > 0) {
              setState(() => _pendingNewMessagesCount = 0);
            }
            _scrollToEnd();
            _scheduleMarkViewed();
          } else {
            setState(() => _pendingNewMessagesCount++);
          }
        });
      });
      _socket!.on('messagesViewed', (data) {
        if (!mounted) return;
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final viewerId = map['user_id'] as String?;
        final upToId = map['up_to_id'] as String?;
        if (viewerId == null || viewerId == _myId) return;
        final anchorIdx = _messages.indexWhere((m) => m.id == upToId);
        if (anchorIdx == -1) return;
        final anchor = _messages[anchorIdx];
        setState(() {
          _messages = _messages.map((m) {
            if (m.userId == _myId && !m.createdAt.isAfter(anchor.createdAt)) {
              return m.copyWith(isViewed: true);
            }
            return m;
          }).toList();
        });
      });
      _socket!.on('messageUpdated', (data) {
        if (!mounted) return;
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
            editedAtNew = DateTime.tryParse(ea);
          }
          setState(() {
            final i = _messages.indexWhere((m) => m.id == idStr);
            if (i == -1) return;
            final prev = _messages[i];
            _messages[i] = prev.copyWith(
              text: textNew,
              editedAt: editedAtNew ?? prev.editedAt,
            );
          });
        } catch (_) {
          // формат сокета может отличаться — не ломаем чат
        }
      });
      _socket!.on('messageDeleted', (data) {
        if (!mounted) return;
        final map = data is Map ? Map<String, dynamic>.from(data) : null;
        if (map == null) return;
        final id = map['id'] as String?;
        if (id == null) return;
        setState(() => _messages.removeWhere((m) => m.id == id));
      });
    } catch (_) {
      // сокет опционален: чат работает и через REST
    }
  }

  void _onInputFocusChanged() {
    if (_inputFocusNode.hasFocus && _emojiPickerVisible) {
      setState(() => _emojiPickerVisible = false);
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _emojiPickerVisible = !_emojiPickerVisible;
      if (_emojiPickerVisible) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onInputFocusChanged);
    _scrollController.addListener(_handleScroll);
    _loadMessages();
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_onInputFocusChanged);
    _scrollController.removeListener(_handleScroll);
    _socket?.emit('leaveEvent', widget.event.id);
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _textController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');
    final renderItems = <Object>[];
    for (var i = 0; i < _messages.length; i++) {
      if (i == 0 || !_sameDay(_messages[i - 1].createdAt, _messages[i].createdAt)) {
        renderItems.add(_messages[i].createdAt);
      }
      renderItems.add(i); // индекс сообщения в _messages (хронологический)
    }

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      appBar: AppBar(
        title: Text(
          widget.event.title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF161616),
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            width: 37,
            height: 37,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(157, 0, 0, 0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.info_outline,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventDetailsScreen(event: widget.event),
                  ),
                );
              },
              tooltip: 'Подробности события',
            ),
          ),
        ],
        leading: Container(
          width: 37,
          height: 37,
          margin: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(157, 0, 0, 0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: renderItems.length,
                        itemBuilder: (context, index) {
                          final item = renderItems[index];

                          if (item is DateTime) {
                            return _buildDayDivider(item);
                          }

                          final msgIndex = item as int;
                          final msg = _messages[msgIndex];
                          final isMe = _myId != null && msg.userId == _myId;
                          final isSending = _sendingStatus[msg.id] ?? false;
                          final isSent = _sentStatus[msg.id] ?? true;

                          final isFirstInGroup = msgIndex == 0 ||
                              !_sameSender(_messages[msgIndex - 1], msg) ||
                              !_sameDay(
                                _messages[msgIndex - 1].createdAt,
                                msg.createdAt,
                              );
                          final isLastInGroup = msgIndex == _messages.length - 1 ||
                              !_sameSender(msg, _messages[msgIndex + 1]) ||
                              !_sameDay(
                                msg.createdAt,
                                _messages[msgIndex + 1].createdAt,
                              );

                          return Container(
                            margin: EdgeInsets.only(
                              bottom: isLastInGroup ? 12 : 4,
                            ),
                            padding: const EdgeInsets.only(bottom: 6),
                            child: isMe
                                ? _buildMyMessage(
                                    msg,
                                    dateFormat,
                                    isSending,
                                    isSent,
                                    isFirstInGroup: isFirstInGroup,
                                    isLastInGroup: isLastInGroup,
                                  )
                                : _buildOtherMessage(
                                    msg,
                                    dateFormat,
                                    isFirstInGroup: isFirstInGroup,
                                    isLastInGroup: isLastInGroup,
                                  ),
                          );
                        },
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: AnimatedOpacity(
                          opacity: (_showScrollToBottom ||
                                  _pendingNewMessagesCount > 0)
                              ? 1
                              : 0,
                          duration: const Duration(milliseconds: 150),
                          child: IgnorePointer(
                            ignoring: !(_showScrollToBottom ||
                                _pendingNewMessagesCount > 0),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(200, 0, 0, 0),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.arrow_downward,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _pendingNewMessagesCount = 0,
                                      );
                                      _scrollToEnd();
                                    },
                                    tooltip: 'Вниз',
                                  ),
                                ),
                                if (_pendingNewMessagesCount > 0)
                                  Positioned(
                                    right: -4,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 18,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5F57),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF161616),
                                          width: 1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _pendingNewMessagesCount > 99
                                            ? '99+'
                                            : '$_pendingNewMessagesCount',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_editingMessageId != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: const Color(0xFF2C2E36),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Color(0xFF8FF5FF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Редактирование',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF8FF5FF),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _editingMessageBannerPreview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Colors.white70,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                onPressed: _cancelEditingMessage,
                                tooltip: 'Отменить редактирование',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        padding: const EdgeInsets.only(bottom: 4),
                        icon: Icon(
                          _emojiPickerVisible
                              ? Icons.keyboard_alt_outlined
                              : Icons.emoji_emotions_outlined,
                          color: Colors.white70,
                          size: 26,
                        ),
                        tooltip: _emojiPickerVisible
                            ? 'Клавиатура'
                            : 'Смайлы',
                        onPressed: _error != null ? null : _toggleEmojiPicker,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _inputFocusNode,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          maxLines: 4,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: _editingMessageId != null
                                ? 'Введите новый текст…'
                                : 'Сообщение...',
                            hintStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            filled: true,
                            fillColor: const Color(0xFF141414),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          enabled: _error == null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _error != null
                              ? Colors.grey[800]
                              : const Color(0xFFFF5F57),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: _error != null ? null : _sendMessage,
                          icon: Icon(
                            _editingMessageId != null
                                ? Icons.check
                                : Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: _editingMessageId != null
                              ? 'Сохранить'
                              : 'Отправить',
                        ),
                      ),
                    ],
                  ),
                  if (_emojiPickerVisible && _error == null)
                    SizedBox(
                      height: 256,
                      child: EmojiPicker(
                        textEditingController: _textController,
                        config: Config(
                          height: 256,
                          locale: const Locale('ru'),
                          checkPlatformCompatibility: true,
                          emojiViewConfig: EmojiViewConfig(
                            backgroundColor: const Color(0xFF1E1E1E),
                            noRecents: const Text(
                              'Нет недавних',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white38,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          categoryViewConfig: const CategoryViewConfig(
                            backgroundColor: Color(0xFF2C2E36),
                            iconColor: Colors.white54,
                            iconColorSelected: Color(0xFF8FF5FF),
                            indicatorColor: Color(0xFF8FF5FF),
                            backspaceColor: Color(0xFF8FF5FF),
                            dividerColor: Color(0xFF3A3D47),
                          ),
                          bottomActionBarConfig: const BottomActionBarConfig(
                            backgroundColor: Color(0xFF2C2E36),
                            buttonColor: Color(0xFF3A3D47),
                            buttonIconColor: Colors.white70,
                          ),
                          searchViewConfig: SearchViewConfig(
                            backgroundColor: const Color(0xFF2C2E36),
                            buttonIconColor: Colors.white54,
                            hintText: 'Поиск',
                            hintTextStyle: TextStyle(
                              color: Colors.grey[600],
                            ),
                            inputTextStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyMessage(
    EventMessage msg,
    DateFormat dateFormat,
    bool isSending,
    bool isSent, {
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
  }) {
    final topRight = isFirstInGroup ? 16.0 : 4.0;
    final bottomRight = isLastInGroup ? 16.0 : 4.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onLongPress: () => _showMyMessageActions(msg, isSending),
              child: Container(
                constraints: const BoxConstraints(minWidth: 104),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2E36),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: Radius.circular(topRight),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: Radius.circular(bottomRight),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 58, bottom: 16),
                      child: Text(
                        msg.text,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dateFormat.format(msg.createdAt),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          if (msg.editedAt != null) ...[
                            const SizedBox(width: 4),
                            const Text(
                              'ред.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          if (isSending)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.grey,
                              ),
                            )
                          else if (isSent && msg.isViewed)
                            const Icon(Icons.done_all, size: 14, color: Colors.green)
                          else if (isSent)
                            const Icon(Icons.check, size: 12, color: Colors.green)
                          else
                            const Icon(Icons.error, size: 12, color: Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherMessage(
    EventMessage msg,
    DateFormat dateFormat, {
    required bool isFirstInGroup,
    required bool isLastInGroup,
  }) {
    // Получаем полный URL аватарки через ApiClient
    final fullAvatarUrl = ApiClient.getFullImageUrl(msg.avatarUrl);

    // Имя — только над первым пузырём; аватар — только у последнего (внизу кластера).
    final showName = isFirstInGroup;
    final showAvatar = isLastInGroup;

    // Верхний левый угол всегда с нормальным скруглением; «хвост» только снизу слева у последнего.
    const topLeft = 10.0;
    final bottomLeft = isLastInGroup ? 4.0 : 16.0;

    Widget bubble = Container(
      constraints: BoxConstraints(
        minWidth: 104,
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8B2020),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topLeft),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(bottomLeft),
          bottomRight: const Radius.circular(16),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 44, bottom: 5),
            child: Text(
              msg.text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateFormat.format(msg.createdAt),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                if (msg.editedAt != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    'ред.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (_isOrganizer) {
      bubble = GestureDetector(
        onLongPress: () => _showOrganizerOtherMessageActions(msg),
        child: bubble,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar)
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2C2E36),
            ),
            child: ClipOval(
              child: fullAvatarUrl != null && fullAvatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: fullAvatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, size: 20, color: Colors.grey),
                    )
                  : const Icon(Icons.person, size: 20, color: Colors.grey),
            ),
          )
        else
          const SizedBox(width: 40),
        // Сообщение
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    msg.displayName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8FF5FF),
                    ),
                  ),
                ),
              bubble,
            ],
          ),
        ),
      ],
    );
  }
}
