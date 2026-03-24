import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../profile/profile_screen.dart';
import '../../services/api_client.dart';

/// Поиск пользователей и отправка заявки в друзья.
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _loading = true;
  bool _searching = false;
  String? _error;
  final Map<String, bool> _sending = {};
  Timer? _debounceTimer;

  String? _currentUserId;
  Set<String> _friendIds = {};
  Set<String> _sentRequestIds = {};

  String _getFullAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return '';

    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return avatarUrl;
    }

    final baseUrl = ApiClient.baseUrl;
    final path = avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl';
    return '$baseUrl$path';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = ApiClient.instance;
      final authBox = Hive.box('authBox');
      _currentUserId = authBox.get('userId') as String?;

      try {
        final friends = await client.getList('/friends', withAuth: true);
        _friendIds = friends.map((f) => f['id'] as String).toSet();
      } catch (e) {
        // Игнорируем ошибку
      }

      try {
        final sentRequests = await client.getList(
          '/friends/requests/sent',
          withAuth: true,
        );
        _sentRequestIds = sentRequests
            .map((r) => r['to_user_id'] as String)
            .toSet();
      } catch (e) {
        // Игнорируем ошибку
      }

      final randomUsers = await client.getList(
        '/friends/users',
        withAuth: true,
      );

      if (mounted) {
        setState(() {
          _allUsers = (randomUsers as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where(
                (user) =>
                    user['id'] != _currentUserId &&
                    !_friendIds.contains(user['id']),
              ) // Исключаем себя и друзей
              .map((user) {
                final userId = user['id'] as String;
                user['is_friend'] = _friendIds.contains(userId);
                user['request_sent'] = _sentRequestIds.contains(userId);
                user['full_avatar_url'] = _getFullAvatarUrl(
                  user['avatar_url'] as String?,
                );
                return user;
              })
              .toList();
          _filteredUsers = List.from(_allUsers);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки данных: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _filteredUsers = List.from(_allUsers);
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final client = ApiClient.instance;
      final users = await client.getList(
        '/friends/users',
        query: {'search': query},
        withAuth: true,
      );

      if (mounted) {
        setState(() {
          final searchedUsers = (users as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where(
                (user) =>
                    user['id'] != _currentUserId &&
                    !_friendIds.contains(user['id']),
              ) // Исключаем себя и друзей
              .map((user) {
                final userId = user['id'] as String;
                user['is_friend'] = _friendIds.contains(userId);
                user['request_sent'] = _sentRequestIds.contains(userId);
                user['full_avatar_url'] = _getFullAvatarUrl(
                  user['avatar_url'] as String?,
                );
                return user;
              })
              .toList();

          _filteredUsers = searchedUsers;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка поиска: ${e.toString()}';
          _searching = false;
        });
      }
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
          const SnackBar(
            content: Text('Заявка отправлена'),
            backgroundColor: Color(0xFF2C2C2C),
          ),
        );

        setState(() {
          for (var i = 0; i < _allUsers.length; i++) {
            if (_allUsers[i]['id'] == toUserId) {
              _allUsers[i]['request_sent'] = true;
              break;
            }
          }
          for (var i = 0; i < _filteredUsers.length; i++) {
            if (_filteredUsers[i]['id'] == toUserId) {
              _filteredUsers[i]['request_sent'] = true;
              break;
            }
          }
          _sentRequestIds.add(toUserId);
          _sending.remove(toUserId);
        });
      }
    } on ApiException catch (e) {
      setState(() => _sending[toUserId] = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      setState(() => _sending[toUserId] = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _cancelRequest(String toUserId) async {
    if (_sending[toUserId] == true) return;
    setState(() => _sending[toUserId] = true);

    try {
      await ApiClient.instance.get(
        '/friends/requests/$toUserId',
        withAuth: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка отменена'),
            backgroundColor: Color(0xFF2C2C2C),
          ),
        );

        setState(() {
          for (var i = 0; i < _allUsers.length; i++) {
            if (_allUsers[i]['id'] == toUserId) {
              _allUsers[i]['request_sent'] = false;
              break;
            }
          }
          for (var i = 0; i < _filteredUsers.length; i++) {
            if (_filteredUsers[i]['id'] == toUserId) {
              _filteredUsers[i]['request_sent'] = false;
              break;
            }
          }
          _sentRequestIds.remove(toUserId);
          _sending.remove(toUserId);
        });
      }
    } on ApiException catch (e) {
      setState(() => _sending[toUserId] = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      setState(() => _sending[toUserId] = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.grey, fontFamily: 'Inter'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadData,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Кнопка назад и заголовок
        Row(
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: const Color.fromARGB(157, 0, 0, 0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Добавить в друзья',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Поле поиска
        // Поле поиска
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
          decoration: InputDecoration(
            hintText: 'Найди нового друга',
            hintStyle: const TextStyle(
              color: Color.fromARGB(155, 255, 255, 255),
              fontFamily: 'Inter',
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _filteredUsers = List.from(_allUsers);
                      });
                    },
                  )
                : const Icon(
                    Icons.search,
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white),
            ),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 16),

        // Индикатор поиска (показываем только если идет поиск)
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Поиск...',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_filteredUsers.isEmpty)
          // Пустое состояние
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'Пользователи не найдены'
                        : 'Нет доступных пользователей',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_searchController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Попробуйте изменить запрос',
                      style: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          // Список пользователей
          Column(
            children: [
              ..._filteredUsers.map((user) => _buildUserCard(user)).toList(),
              const SizedBox(height: 16),
              // Рекомендации снизу
              if (_searchController.text.isEmpty && _filteredUsers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      '✨ Введи имя — найдём друзей',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontFamily: "Inter",
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final id = user['id'] as String?;
    final username = user['username'] as String? ?? '—';
    final displayName = user['display_name'] as String?;
    final avatarUrl = user['full_avatar_url'] as String?;
    final isFriend = user['is_friend'] == true;
    final requestSent = user['request_sent'] == true;
    final sending = id != null && _sending[id] == true;

    final title = (displayName?.isNotEmpty == true) ? displayName! : username;
    final subtitle = '@$username';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: const Color.fromARGB(10, 255, 255, 255),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 2),
        leading: _buildAvatar(avatarUrl, displayName, username),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Color.fromARGB(80, 255, 255, 255),
            fontSize: 13,
            fontFamily: 'Inter',
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        trailing: id == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isFriend
                        ? const Color(0xFF2C2C2C)
                        : requestSent
                        ? const Color(0xFF2C2C2C)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (isFriend) {
                        return;
                      } else if (requestSent) {
                        _cancelRequest(id!);
                      } else if (!sending) {
                        _addFriend(id!);
                      }
                    },
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: sending
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              isFriend
                                  ? Icons.check
                                  : requestSent
                                  ? Icons.close
                                  : Icons.person_add,
                              color: isFriend || requestSent
                                  ? Colors.white
                                  : Colors.black,
                              size: 20,
                            ),
                          ),
                  ),
                ),
              ),
        onTap: () {
          if (id != null) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(userId: id),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildAvatar(
    String? avatarUrl,
    String? displayName,
    String? username,
  ) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          avatarUrl,
          width: 55,
          height: 62,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 52,
              height: 52,
              color: const Color(0xFF2C2C2C),
              child: const Icon(Icons.person, color: Colors.white70),
            );
          },
        ),
      );
    }

    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFF2C2C2C),
      child: const Icon(Icons.person, color: Colors.white70),
    );
  }
}
