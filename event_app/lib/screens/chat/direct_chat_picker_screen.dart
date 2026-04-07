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
    // Height of header row area (excluding SafeArea top).
    const headerHeight =
        37.0 + 8 + 12; // button + top/bottom paddings inside header
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.2,
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Content goes "under" the header overlay.
          Padding(
            padding: EdgeInsets.only(top: topInset + headerHeight),
            child: _buildBody(),
          ),
          // Header overlay (position: fixed, transparent).
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Нет друзей для переписки.\nДобавьте друзей в разделе «Люди».',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFFB5BBC7),
              fontSize: 14,
              height: 1.35,
            ),
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
        itemCount: _friends.length,
        separatorBuilder: (context, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final f = _friends[index];
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
            color: Colors.white,
          ),
        ),
        Text(
          'Непрочитанных: $totalUnread',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFFF5F57),
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
    final trailing = _ChatTrailing(unread: unread);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              _FriendAvatar(avatarUrl: avatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isMuted) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFFB5BBC7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
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
    final r = BorderRadius.circular(10);
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: r,
        child: Container(
          width: size,
          height: size,
          color: scheme.surfaceContainerHighest,
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
            errorWidget: (context, url, error) => Center(
              child: Icon(Icons.person, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: r,
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.person, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ChatTrailing extends StatelessWidget {
  const _ChatTrailing({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.chat_bubble_outline,
        color: Colors.black,
        size: 20,
      ),
    );
    if (unread <= 0) return icon;
    return Badge(
      label: Text(
        unread > 99 ? '99+' : '$unread',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
      child: icon,
    );
  }
}
