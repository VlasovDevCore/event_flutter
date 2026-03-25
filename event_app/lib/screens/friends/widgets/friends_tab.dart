import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../profile/profile_screen.dart';
import '../../chat/direct_chat_screen.dart';
import '../../../services/api_client.dart';

class FriendsTab extends StatelessWidget {
  final List<Map<String, dynamic>> friends;

  const FriendsTab({super.key, required this.friends});

  void _shareApp(BuildContext context) async {
    final shareText = '''
Приглашаю тебя в EventApp! 🎉
Создавай события, находи друзей и проводи время вместе!

Скачай приложение: https://play.google.com/store/apps/details?id=com.eventapp
''';

    try {
      await Share.share(shareText);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при открытии шаринга: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFriends = friends.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _shareApp(context),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(255, 65, 129, 231),
                      Color.fromARGB(255, 14, 66, 238),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 152,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Приглашай друзей',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Вместе создавать события и находить компании',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: -45,
                        top: -20,
                        bottom: -20,
                        child: Align(
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/friends/share.png',
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasFriends) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${friends.length}',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
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
        ] else ...[
          const SizedBox(height: 40),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/friends/zoom-dynamic-color.png',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Пока нет друзей',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Пригласи друзей по ссылке выше\nи начинайте общаться!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ],
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
      color: const Color(0xFF141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: const Color.fromARGB(10, 255, 255, 255),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 10, right: 10, bottom: -1),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: avatarUrl.isNotEmpty
              ? Image.network(
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
                )
              : Container(
                  width: 52,
                  height: 52,
                  color: const Color(0xFF2C2C2C),
                  child: const Icon(Icons.person, color: Colors.white70),
                ),
        ),
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
        trailing: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: id == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DirectChatScreen(userId: id!, title: title),
                        ),
                      );
                    },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: const Center(
                child: Icon(Icons.message, color: Colors.black, size: 20),
              ),
            ),
          ),
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
