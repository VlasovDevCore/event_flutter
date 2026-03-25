import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

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
  final ScrollController _scrollController = ScrollController();
  List<EventMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  io.Socket? _socket;

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
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _textController.clear();

    try {
      final client = ApiClient.instance;
      final data = await client.post(
        '/events/${widget.event.id}/messages',
        body: {'text': text},
        withAuth: true,
      );
      final msg = EventMessage.fromApi(data);
      setState(() {
        _sending = false;
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages = [..._messages, msg];
        }
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.statusCode == 403
                  ? 'Вы не участвуете в этом событии'
                  : e.message,
            ),
          ),
        );
      }
      _textController.text = text;
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
                      final isMe =
                          _myEmail != null &&
                          msg.userEmail == _myEmail; // Исправлено!
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFF2C2E36)
                                : const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMe && msg.displayName != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    msg.displayName!,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8FF5FF),
                                    ),
                                  ),
                                ),
                              Text(
                                msg.text,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFormat.format(msg.createdAt),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.white,
                      ),
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
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_sending && _error == null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _sending || _error != null
                          ? Colors.grey[800]
                          : const Color(0xFFFF5F57),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: _sending || _error != null
                          ? null
                          : _sendMessage,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
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
}
