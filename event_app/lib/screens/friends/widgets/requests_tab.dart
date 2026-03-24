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

    // Получаем данные напрямую из request
    final username = (request['username'] as String?)?.trim();
    final displayName = (request['display_name'] as String?)?.trim();
    final avatarUrl = _getFullAvatarUrl(request['avatar_url'] as String?);

    // Заголовок: displayName или username
    final title = (displayName?.isNotEmpty == true)
        ? displayName!
        : (username?.isNotEmpty == true ? username! : 'Пользователь');

    // Подзаголовок: всегда показываем username если есть
    final subtitle = username?.isNotEmpty == true ? '@$username' : null;

    final rel = (fromUserId == null) ? null : requestRelations[fromUserId];
    final isFollowing = rel?['isFollowing'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _buildAvatar(avatarUrl, displayName, username),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Inter',
                ),
              )
            : null,
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
            : _buildSubscribeButton(fromUserId, isFollowing),
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl, String? displayName, String? username) {
    // Если есть URL аватара
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: const Color(0xFF2C2C2C),
        radius: 24,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    // Если нет аватара, показываем инициалы
    String initials = '';
    if (displayName != null && displayName.isNotEmpty) {
      initials = displayName[0].toUpperCase();
    } else if (username != null && username.isNotEmpty) {
      initials = username[0].toUpperCase();
    } else {
      initials = '?';
    }

    return CircleAvatar(
      backgroundColor: const Color(0xFF2C2C2C),
      radius: 24,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(String fromUserId, bool isFollowing) {
    return TextButton(
      onPressed: () => onToggleSubscribe(fromUserId),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        isFollowing ? 'Подписан' : 'Подписаться в ответ',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
