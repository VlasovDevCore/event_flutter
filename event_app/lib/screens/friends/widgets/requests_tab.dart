import 'package:flutter/material.dart';
import '../../profile/profile_screen.dart';
import '../../../services/api_client.dart';

class RequestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Map<String, Map<String, bool>> requestRelations;
  final Future<void> Function(String toUserId) onToggleSubscribe;

  const RequestsTab({
    super.key,
    required this.requests,
    required this.requestRelations,
    required this.onToggleSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _RequestCard(
          request: request,
          requestRelations: requestRelations,
          onToggleSubscribe: onToggleSubscribe,
        );
      },
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
              Icons.person_add_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет новых подписчиков',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Когда кто-то подпишется на вас, они появятся здесь',
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

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Map<String, Map<String, bool>> requestRelations;
  final Future<void> Function(String toUserId) onToggleSubscribe;

  const _RequestCard({
    required this.request,
    required this.requestRelations,
    required this.onToggleSubscribe,
  });

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
    final fromUserId = request['from_user_id'] as String?;

    final username = (request['username'] as String?)?.trim();
    final displayName = (request['display_name'] as String?)?.trim();
    final avatarUrl = _getFullAvatarUrl(request['avatar_url'] as String?);

    final title = (displayName?.isNotEmpty == true)
        ? displayName!
        : (username?.isNotEmpty == true ? '@$username' : 'Пользователь');
    final subtitle = username?.isNotEmpty == true ? '@$username' : null;

    final rel = (fromUserId == null) ? null : requestRelations[fromUserId];
    final isFollowing = rel?['isFollowing'] == true;

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
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: Color.fromARGB(80, 255, 255, 255),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )
            : null,
        trailing: fromUserId == null
            ? null
            : _buildSubscribeButton(fromUserId, isFollowing),
        onTap: fromUserId == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(userId: fromUserId),
                  ),
                );
              },
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl, String? displayName, String? username) {
    if (avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12), // Скругление как в FriendCard
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

    // Если нет аватара, показываем иконку как в FriendCard
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFF2C2C2C),
      child: const Icon(Icons.person, color: Colors.white70),
    );
  }

  Widget _buildSubscribeButton(String fromUserId, bool isFollowing) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isFollowing ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onToggleSubscribe(fromUserId),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Center(
            child: Icon(
              isFollowing ? Icons.check : Icons.person_add,
              color: isFollowing ? Colors.white : Colors.black,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
