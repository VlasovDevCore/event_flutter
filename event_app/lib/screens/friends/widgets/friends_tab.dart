import 'package:flutter/material.dart';
import '../../profile/profile_screen.dart';
import '../../chat/direct_chat_screen.dart';
import '../../../services/api_client.dart';

class FriendsTab extends StatelessWidget {
  final List<Map<String, dynamic>> friends;

  const FriendsTab({super.key, required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Синий скруглённый блок
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_alt, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Друзья',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Общайтесь с друзьями в чате и встречайтесь',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontFamily: 'Inter',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Text(
                'Все друзья',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${friends.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return FriendCard(friend: friend);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'Пока нет друзей',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите на кнопку "+" вверху, чтобы добавить друга',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FriendCard extends StatelessWidget {
  final Map<String, dynamic> friend;

  const FriendCard({super.key, required this.friend});

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
  Widget build(BuildContext context) {
    final email = friend['email'] as String? ?? '—';
    final id = friend['id'] as String?;
    final username = (friend['username'] as String?)?.trim();
    final displayName = (friend['display_name'] as String?)?.trim();
    final avatarUrl = _getFullAvatarUrl(friend['avatar_url'] as String?);

    final title = (displayName?.isNotEmpty == true)
        ? displayName!
        : (username?.isNotEmpty == true ? '@$username' : email);
    final subtitle = username?.isNotEmpty == true ? '@$username' : email;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFF2C2C2C),
                      child: const Icon(Icons.person, color: Colors.white70),
                    );
                  },
                )
              : Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFF2C2C2C),
                  child: const Icon(Icons.person, color: Colors.white70),
                ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontFamily: 'Inter'),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.message, color: Colors.white70, size: 20),
          onPressed: id == null
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DirectChatScreen(userId: id!, title: title),
                    ),
                  );
                },
        ),
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
  }
}
