import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_screen.dart';

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.createdAt,
  });

  factory DirectMessage.fromApi(Map<String, dynamic> map) {
    return DirectMessage(
      id: map['id'].toString(),
      fromUserId: map['from_user_id'].toString(),
      toUserId: map['to_user_id'].toString(),
      text: (map['text'] as String?) ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final String id;
  final String fromUserId;
  final String toUserId;
  final String text;
  final DateTime createdAt;
}

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
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<DirectMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;

  /// Имя для шапки: display_name, иначе email, иначе переданный title.
  String? _peerHeaderName;
  String? _peerAvatarResolved;

  String? get _myUserId {
    final id = Hive.box('authBox').get('userId') as String?;
    return id?.trim().isEmpty == true ? null : id?.trim();
  }

  String get _titleForAppBar {
    final n = _peerHeaderName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return widget.title;
  }

  String _initialLetter(String text) {
    final t = text.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
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
        _peerAvatarResolved = resolveAvatarUrl(rawAvatar);
      });
    } catch (_) {
      // оставляем widget.title и без аватара
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient.instance.getList(
        '/messages/with/${widget.userId}',
        withAuth: true,
      );
      final msgs =
          list.map((e) => DirectMessage.fromApi(e as Map<String, dynamic>)).toList(growable: false);
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _messages = [];
        _error = e.statusCode == 403 ? 'Пользователь не принимает сообщения' : e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _messages = [];
        _error = e.toString();
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    _textController.clear();
    setState(() => _sending = true);
    try {
      final data = await ApiClient.instance.post(
        '/messages/with/${widget.userId}',
        body: {'text': text},
        withAuth: true,
      );
      final msg = DirectMessage.fromApi(data);
      setState(() {
        _sending = false;
        _messages = [..._messages, msg];
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.statusCode == 403 ? 'Нельзя написать пользователю' : e.message)),
        );
      }
      _textController.text = text;
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
      _textController.text = text;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final list = await ApiClient.instance.getList(
          '/messages/with/${widget.userId}',
          withAuth: true,
        );
        final msgs = list
            .map((e) => DirectMessage.fromApi(e as Map<String, dynamic>))
            .toList(growable: false);
        if (!mounted) return;
        if (msgs.isNotEmpty && (_messages.isEmpty || msgs.last.id != _messages.last.id)) {
          setState(() => _messages = msgs);
          _scrollToEnd();
        }
      } catch (_) {
        // ignore polling errors
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPeerProfile();
    _loadMessages().then((_) => _startPolling());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = _myUserId;
    final df = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              backgroundImage: _peerAvatarResolved != null
                  ? NetworkImage(_peerAvatarResolved!)
                  : null,
              child: _peerAvatarResolved == null
                  ? Text(
                      _initialLetter(_titleForAppBar),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _titleForAppBar,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Профиль',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(userId: widget.userId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final mine = myId != null && m.fromUserId == myId;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              constraints: const BoxConstraints(maxWidth: 320),
                              decoration: BoxDecoration(
                                color: mine ? Theme.of(context).colorScheme.primaryContainer : null,
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(m.text),
                                  const SizedBox(height: 4),
                                  Text(
                                    df.format(m.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Сообщение…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Отпр.'),
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

