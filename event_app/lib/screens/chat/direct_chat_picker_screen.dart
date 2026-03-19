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
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    if (Hive.box('authBox').get('token') == null) {
      setState(() {
        _error = 'Войдите в аккаунт, чтобы писать сообщения';
        _friends = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ApiClient.instance.getList('/friends', withAuth: true);
      if (!mounted) return;
      setState(() {
        _friends = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _friends = [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _friends = [];
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
        title: const Text('Написать другу'),
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
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

                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(title),
                          subtitle: Text(subtitle),
                          trailing: const Icon(Icons.chat_bubble_outline),
                          onTap: id == null
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => DirectChatScreen(
                                        userId: id,
                                        title: title,
                                      ),
                                    ),
                                  );
                                },
                        );
                      },
                    ),
    );
  }
}
