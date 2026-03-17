import 'package:flutter/material.dart';

import '../../services/api_client.dart';

/// Поиск пользователей и отправка заявки в друзья.
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _searching = false;
  String? _error;
  final Map<String, bool> _sending = {};

  Future<void> _search() async {
    final q = _searchController.text.trim();
    setState(() {
      _searching = true;
      _error = null;
      _users = [];
    });
    try {
      final client = ApiClient.instance;
      final list = await client.getList(
        '/users/search',
        query: q.isEmpty ? null : {'q': q},
        withAuth: true,
      );
      setState(() {
        _users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _searching = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  Future<void> _addFriend(String toUserId) async {
    if (_sending[toUserId] == true) return;
    setState(() => _sending[toUserId] = true);
    try {
      await ApiClient.instance.post(
        '/friends/requests',
        body: {'toUserId': toUserId},
        withAuth: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка отправлена')),
        );
        setState(() {
          _users.removeWhere((u) => u['id'] == toUserId);
          _sending[toUserId] = false;
        });
      }
    } on ApiException catch (e) {
      setState(() => _sending[toUserId] = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      setState(() => _sending[toUserId] = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить в друзья'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по email...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Найти'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _users.isEmpty && !_searching
                ? Center(
                    child: Text(
                      'Введите email и нажмите «Найти»',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final u = _users[index];
                      final id = u['id'] as String?;
                      final email = u['email'] as String? ?? '—';
                      final sending = id != null && _sending[id] == true;
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(email),
                        trailing: id == null
                            ? null
                            : FilledButton(
                                onPressed: sending ? null : () => _addFriend(id),
                                child: sending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Добавить'),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

