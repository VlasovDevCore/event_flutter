import 'package:flutter/material.dart';

import '../services/api_client.dart';
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
      });
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

  Future<void> _acceptRequest(String requestId) async {
    try {
      await ApiClient.instance.post(
        '/friends/requests/$requestId/accept',
        withAuth: true,
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await ApiClient.instance.post(
        '/friends/requests/$requestId/reject',
        withAuth: true,
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
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
                        'Заявки в друзья',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_requests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Нет новых заявок',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        )
                      else
                        ..._requests.map((r) {
                          final id = r['id'] as String?;
                          final fromEmail = r['from_email'] as String? ?? '—';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(fromEmail),
                              subtitle: const Text('Хочет добавить вас в друзья'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: id != null ? () => _acceptRequest(id) : null,
                                    icon: const Icon(Icons.check),
                                    color: Colors.green,
                                    tooltip: 'Принять',
                                  ),
                                  IconButton(
                                    onPressed: id != null ? () => _rejectRequest(id) : null,
                                    icon: const Icon(Icons.close),
                                    color: Colors.red,
                                    tooltip: 'Отклонить',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
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
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(email),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
