import 'dart:async';

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
  Map<String, DateTime?> _mutedUntilByPeerId = {};
  bool _loading = true;
  String? _error;

  bool _isMutedNow(String peerId) {
    final until = _mutedUntilByPeerId[peerId];
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  Future<DateTime?> _fetchMuteUntil(String peerId) async {
    try {
      final data = await ApiClient.instance.get(
        '/messages/with/$peerId/mute',
        withAuth: true,
      );
      final raw = data['muted_until'];
      if (raw is String && raw.trim().isNotEmpty) {
        return DateTime.tryParse(raw)?.toLocal();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadMuteStatusesForFriends(
    List<Map<String, dynamic>> friends,
  ) async {
    final ids = <String>[];
    for (final f in friends) {
      final id = f['id']?.toString();
      if (id != null && id.trim().isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return;

    final results = await Future.wait<DateTime?>(ids.map(_fetchMuteUntil));
    if (!mounted) return;
    final map = <String, DateTime?>{};
    for (var i = 0; i < ids.length; i++) {
      map[ids[i]] = results[i];
    }
    setState(() => _mutedUntilByPeerId = map);
  }

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
      final friends = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _friends = friends;
        _unreadByPeerId = unread;
        _loading = false;
      });
      unawaited(_loadMuteStatusesForFriends(friends));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 401 ? 'Войдите в аккаунт' : e.message;
        _friends = [];
        _unreadByPeerId = {};
        _mutedUntilByPeerId = {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _friends = [];
        _unreadByPeerId = {};
        _mutedUntilByPeerId = {};
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
    const bg = Color(0xFF161616);
    final topInset = MediaQuery.of(context).padding.top;
    const headerHeight = 0;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          _buildBackgroundGradient(),

          // Контент
          Padding(
            padding: EdgeInsets.only(top: topInset + headerHeight),
            child: _buildBody(),
          ),

          // Градиент сверху (под хедером, но заходит в SafeArea)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100, // Высота градиента, заходит в SafeArea
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0xFF161616), Colors.transparent],
                    stops: const [0, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Хедер поверх градиента
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(bottom: false, child: _buildHeader()),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 0.55,
            colors: [
              const Color.fromARGB(197, 29, 29, 29),
              const Color(0xFF161616),
            ],
            stops: const [0.1, 4.9],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 12),
          Expanded(child: _UnreadTitle(totalUnread: _totalUnread)),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: Container(
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
            onTap: () => Navigator.of(context).maybePop(),
            splashColor: const Color.fromARGB(157, 0, 0, 0),
            highlightColor: const Color.fromARGB(157, 0, 0, 0),
            child: const Center(
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
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
          onTap: _loading ? null : _load,
          splashColor: const Color.fromARGB(157, 0, 0, 0),
          highlightColor: const Color.fromARGB(157, 0, 0, 0),
          child: const Center(
            child: Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ),
      ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFFF5F57),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/events/location-dynamic-color.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              const Text(
                'Нет друзей для переписки',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Добавьте друзей в разделе «Люди»',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFB5BBC7),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.white,
      backgroundColor: const Color(0xFF1F1F1F),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _friends.length + 1,
        separatorBuilder: (context, index) {
          if (index == 0) return const SizedBox.shrink();
          return const SizedBox(height: 10);
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Opacity(
              opacity: 0.0,
              child: _InvisiblePlaceholderCard(),
            );
          }

          final friendIndex = index - 1;
          final f = _friends[friendIndex];
          final email = f['email'] as String? ?? '—';
          final id = f['id'] as String?;
          final username = (f['username'] as String?)?.trim();
          final displayName = (f['display_name'] as String?)?.trim();
          final title = (displayName?.isNotEmpty == true)
              ? displayName!
              : (username?.isNotEmpty == true ? '@$username' : email);
          final subtitle = username?.isNotEmpty == true ? '@$username' : email;
          final avatarUrl = ApiClient.getFullImageUrl(
            f['avatar_url'] as String?,
          );
          final unread = id != null ? (_unreadByPeerId[id] ?? 0) : 0;
          final isMuted = id != null && _isMutedNow(id);

          return _FriendChatCard(
            title: title,
            subtitle: subtitle,
            avatarUrl: avatarUrl,
            unread: unread,
            isMuted: isMuted,
            onTap: id == null
                ? null
                : () {
                    Navigator.of(context)
                        .push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DirectChatScreen(userId: id, title: title),
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

// Невидимая карточка-заглушка
class _InvisiblePlaceholderCard extends StatelessWidget {
  const _InvisiblePlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 5,
          ),
          leading: const SizedBox(width: 50, height: 50),
          title: const SizedBox.shrink(),
          subtitle: const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _UnreadTitle extends StatelessWidget {
  const _UnreadTitle({required this.totalUnread});

  final int totalUnread;

  @override
  Widget build(BuildContext context) {
    if (totalUnread <= 0) {
      return const Text(
        'Написать другу',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: Colors.white,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Написать другу',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _FriendChatCard extends StatelessWidget {
  const _FriendChatCard({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.unread,
    required this.isMuted,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String? avatarUrl;
  final int unread;
  final bool isMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            leading: _FriendAvatar(avatarUrl: avatarUrl, size: 50),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                if (isMuted) ...[
                  const SizedBox(width: 5),
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 14,
                    color: const Color(0xFFB5BBC7).withOpacity(0.9),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFAAABB0),
                fontSize: 12,
              ),
            ),
            trailing: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFF161616),
                      size: 18,
                    ),
                    onPressed: onTap,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF161616),
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.avatarUrl, this.size = 40});

  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Icon(
                    Icons.person,
                    color: scheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  Icons.person,
                  color: scheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
      ),
    );
  }
}
