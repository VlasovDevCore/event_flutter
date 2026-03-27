import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/event.dart';
import '../../models/event_message.dart';
import '../../services/api_client.dart';
import '../events/event_details_screen.dart';
import '../../services/api_client.dart';

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
  final ScrollController _scrollController = ScrollController();
  List<EventMessage> _messages = [];
  bool _loading = true;
  String? _error;
  io.Socket? _socket;

  // Храним статусы отправки сообщений (локальные)
  final Map<String, bool> _sendingStatus = {}; // id -> isSending
  final Map<String, bool> _sentStatus = {}; // id -> isSent
  final Set<String> _tempIds = {}; // Храним временные ID
  final Set<String> _processedIds = {}; // Храним ID уже обработанных сообщений

  String? get _myId {
    final userId = Hive.box('authBox').get('userId') as String?;
    return userId?.trim().isEmpty == true ? null : userId?.trim();
  }

  String? get _myEmail {
    final email = Hive.box('authBox').get('email') as String?;
    return email?.trim().isEmpty == true ? null : email?.trim();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

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

        setState(() {
          _messages = [..._messages, msg];
        });
        _scrollToEnd();
      });
    } catch (_) {
      // сокет опционален: чат работает и через REST
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _socket?.emit('leaveEvent', widget.event.id);
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');

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
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = _myId != null && msg.userId == _myId;
                      final isSending = _sendingStatus[msg.id] ?? false;
                      final isSent = _sentStatus[msg.id] ?? true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: isMe
                            ? _buildMyMessage(
                                msg,
                                dateFormat,
                                isSending,
                                isSent,
                              )
                            : _buildOtherMessage(msg, dateFormat),
                      );
                    },
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
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
                        hintText: 'Сообщение...',
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
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Отправить',
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
    bool isSent,
  ) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2E36),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
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
                else if (isSent)
                  const Icon(Icons.check, size: 12, color: Colors.green)
                else
                  const Icon(Icons.error, size: 12, color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherMessage(EventMessage msg, DateFormat dateFormat) {
    // Получаем полный URL аватарки через ApiClient
    final fullAvatarUrl = ApiClient.getFullImageUrl(msg.avatarUrl);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Аватарка
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
        ),
        // Сообщение
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.displayName != null)
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
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.text,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    // Отладка: выводим путь к аватарке
                    if (msg.avatarUrl != null && msg.avatarUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '🖼️ Avatar: ${msg.avatarUrl}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 8,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '❌ No avatar URL',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 8,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  dateFormat.format(msg.createdAt),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
