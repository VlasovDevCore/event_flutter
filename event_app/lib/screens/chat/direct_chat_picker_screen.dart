import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/api_client.dart';
import 'direct_chat_screen.dart';

/// Список друзей: по нажатию открывается личный чат с пользователем.
class DirectChatPickerScreen extends StatefulWidget {
  const DirectChatPickerScreen({super.key});

  @override
  State<DirectChatPickerScreen> createState() => _DirectChatPickerScreenState();
}

class _DirectChatPickerScreenState extends State<DirectChatPickerScreen> {
  List<Map<String, dynamic>> _friends = [];
  /// Сколько непрочитанных входящих от каждого друга (ключ — id пользователя).
  Map<String, int> _unreadByPeerId = {};
  bool _loading = true;
  String? _error;

  Future<Map<String, int>> _fetchUnreadByPeerMap() async {
    if (Hive.box('authBox').get('token') == null) return {};
    try {
      final map = await ApiClient.instance.get(
        '/messages/unread-by-peer',
        withAuth: true,
      );
      final raw = map['byPeer'];
      if (raw is! Map) return {};
      final out = <String, int>{};
      for (final e in raw.entries) {
        final v = e.value;
        final n = v is int ? v : int.tryParse('$v') ?? 0;
        if (n > 0) out[e.key.toString()] = n;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _load() async {
    if (Hive.box('authBox').get('token') == null) {
      setState(() {
        _error = 'Войдите в аккаунт, чтобы писать сообщения';
        _friends = [];
        _unreadByPeerId = {};
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batch = await Future.wait<dynamic>([
        ApiClient.instance.getList('/friends', withAuth: true),
        _fetchUnreadByPeerMap(),
      ]);
      final list = batch[0] as List<dynamic>;
      final unread = batch[1] as Map<String, int>;
      if (!mounted) return;
      setState(() {
        _friends = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _unreadByPeerId = unread;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _friends = [];
        _unreadByPeerId = {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _friends = [];
        _unreadByPeerId = {};
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _UnreadTitle(totalUnread: _totalUnread),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : _friends.isEmpty
                  ? Center(
                      child: Text(
                        'Нет друзей для переписки.\nДобавьте друзей в разделе «Люди».',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _friends.length,
                      separatorBuilder: (context, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final f = _friends[index];
                        final email = f['email'] as String? ?? '—';
                        final id = f['id'] as String?;
                        final username = (f['username'] as String?)?.trim();
                        final displayName = (f['display_name'] as String?)?.trim();
                        final title = (displayName?.isNotEmpty == true)
                            ? displayName!
                            : (username?.isNotEmpty == true ? '@$username' : email);
                        final subtitle =
                            username?.isNotEmpty == true ? '@$username' : email;
                        final avatarUrl =
                            ApiClient.getFullImageUrl(f['avatar_url'] as String?);
                        final unread =
                            id != null ? (_unreadByPeerId[id] ?? 0) : 0;

                        return ListTile(
                          leading: _FriendAvatar(avatarUrl: avatarUrl),
                          title: Text(title),
                          subtitle: Text(subtitle),
                          trailing: _ChatTrailing(unread: unread),
                          onTap: id == null
                              ? null
                              : () {
                                  Navigator.of(context)
                                      .push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => DirectChatScreen(
                                        userId: id,
                                        title: title,
                                      ),
                                    ),
                                  )
                                      .then((_) async {
                                    final u = await _fetchUnreadByPeerMap();
                                    if (mounted) {
                                      setState(() => _unreadByPeerId = u);
                                    }
                                  });
                                },
                        );
                      },
                    ),
    );
  }

  int get _totalUnread {
    var s = 0;
    for (final n in _unreadByPeerId.values) {
      s += n;
    }
    return s;
  }
}

class _UnreadTitle extends StatelessWidget {
  const _UnreadTitle({required this.totalUnread});

  final int totalUnread;

  @override
  Widget build(BuildContext context) {
    if (totalUnread <= 0) {
      return const Text('Написать другу');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Написать другу'),
        Text(
          'Непрочитанных: $totalUnread',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }
}

class _ChatTrailing extends StatelessWidget {
  const _ChatTrailing({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.chat_bubble_outline,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (unread <= 0) return icon;
    return Badge(
      label: Text(unread > 99 ? '99+' : '$unread'),
      child: icon,
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 40.0;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: scheme.surfaceContainerHighest,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (context, url) => SizedBox(
              width: size,
              height: size,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Icon(
              Icons.person,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Icon(Icons.person, color: scheme.onSurfaceVariant),
    );
  }
}
