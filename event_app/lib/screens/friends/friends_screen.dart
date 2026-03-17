import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../profile/profile_screen.dart';
import 'add_friend_screen.dart';

/// Экран «Мои друзья»: входящие заявки и кнопка «Добавить в друзья».
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _friends = [];
  final Map<String, Map<String, bool>> _requestRelations = {}; // fromUserId -> rel map
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient.instance;
      final requests = await client.getList('/friends/requests', withAuth: true);
      final friends = await client.getList('/friends', withAuth: true);
      setState(() {
        _requests = requests.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _friends = friends.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _requestRelations.clear();
      });

      // Подгружаем relationship для каждой входящей заявки,
      // чтобы показать кнопку "подписаться в ответ" / "подписан".
      for (final r in _requests) {
        final fromUserId = r['from_user_id'] as String?;
        if (fromUserId == null || fromUserId.isEmpty) continue;
        try {
          final rel = await client.get(
            '/friends/relationship/$fromUserId',
            withAuth: true,
          );
          if (!mounted) return;
          setState(() {
            _requestRelations[fromUserId] = {
              'isFollowing': rel['isFollowing'] == true,
              'isFriends': rel['isFriends'] == true,
            };
          });
        } catch (_) {
          // ignore: relationship is optional for UI
        }
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleSubscribeBack(String toUserId) async {
    try {
      final rel = _requestRelations[toUserId];
      final isFollowing = rel?['isFollowing'] == true;
      if (isFollowing) {
        await ApiClient.instance.post(
          '/friends/unsubscribe',
          body: {'toUserId': toUserId},
          withAuth: true,
        );
      } else {
        await ApiClient.instance.post(
          '/friends/subscribe',
          body: {'toUserId': toUserId},
          withAuth: true,
        );
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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
        title: const Text('Мои друзья'),
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AddFriendScreen(),
                            ),
                          );
                          _load();
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Добавить в друзья'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Друзья',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_friends.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Пока нет друзей',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        )
                      else
                        ..._friends.map((f) {
                          final email = f['email'] as String? ?? '—';
                          final id = f['id'] as String?;
                          final username = (f['username'] as String?)?.trim();
                          final displayName = (f['display_name'] as String?)?.trim();
                          final title = (displayName?.isNotEmpty == true)
                              ? displayName!
                              : (username?.isNotEmpty == true ? '@$username' : email);
                          final subtitle = username?.isNotEmpty == true ? '@$username' : email;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(title),
                              subtitle: Text(subtitle),
                              onTap: id == null
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ProfileScreen(userId: id),
                                        ),
                                      );
                                    },
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      Text(
                        'Новые подписчики',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_requests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Нет новых подписчиков',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        )
                      else
                        ..._requests.map((r) {
                          final fromEmail = r['from_email'] as String? ?? '—';
                          final fromUserId = r['from_user_id'] as String?;
                          final rel = (fromUserId == null) ? null : _requestRelations[fromUserId];
                          final isFollowing = rel?['isFollowing'] == true;
                          final isFriends = rel?['isFriends'] == true;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(fromEmail),
                              subtitle: Text(isFriends ? 'Вы друзья' : 'Подписался на вас'),
                              onTap: fromUserId == null
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ProfileScreen(userId: fromUserId),
                                        ),
                                      );
                                    },
                              trailing: fromUserId == null
                                  ? null
                                  : TextButton(
                                      onPressed: () => _toggleSubscribeBack(fromUserId),
                                      child: Text(isFollowing ? 'Подписан' : 'Подписаться в ответ'),
                                    ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

