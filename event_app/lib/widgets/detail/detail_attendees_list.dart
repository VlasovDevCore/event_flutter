import 'package:flutter/material.dart';
import '../../models/event.dart';
import 'detail_attendee_item.dart';
import '../../../services/api_client.dart';

class DetailAttendeesList extends StatelessWidget {
  const DetailAttendeesList({
    super.key,
    required this.goingUsers,
    required this.goingUserProfiles,
    required this.currentUserEmail,
    required this.onProfileTap,
  });

  final List<String> goingUsers;
  final List<EventUserProfile> goingUserProfiles;
  final String? currentUserEmail;
  final Function(String userId) onProfileTap;

  static const Color _subtitle = Color(0xFFB5BBC7);
  static const Color _cardBorder = Color(0xFF23262C);

  String? getFullAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return avatarUrl;
    }
    if (avatarUrl.startsWith('/uploads')) {
      return '${ApiClient.baseUrl}$avatarUrl';
    }
    if (avatarUrl.startsWith('file://')) {
      return avatarUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (goingUsers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Кто придёт:',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Пока никто не отметил "Я приду"',
            style: TextStyle(
              fontFamily: 'Inter',
              color: _subtitle,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Кто придёт:',
          style: TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...(goingUserProfiles.isNotEmpty
            ? goingUserProfiles.map((u) {
                final title = (u.displayName?.isNotEmpty == true)
                    ? u.displayName!
                    : (u.username?.isNotEmpty == true
                          ? u.username!
                          : 'Пользователь');
                final subtitle = (u.username?.isNotEmpty == true)
                    ? '@${u.username}'
                    : '—';
                final resolvedAvatar = _resolveAvatarUrl(u.avatarUrl);

                return DetailAttendeeItem(
                  id: u.id,
                  title: title,
                  subtitle: subtitle,
                  avatarUrl: resolvedAvatar,
                  onTap: u.id.isNotEmpty ? () => onProfileTap(u.id) : null,
                );
              })
            : goingUsers.map((email) {
                final raw = email.trim();
                final isMe =
                    currentUserEmail != null && raw == currentUserEmail;
                final hasAt = raw.contains('@');
                final localPart = hasAt ? raw.split('@').first.trim() : raw;
                final displayName = localPart.isNotEmpty
                    ? localPart
                    : 'Пользователь';
                final nickname = hasAt && localPart.isNotEmpty
                    ? '@$localPart'
                    : '—';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder, width: 1),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: const Icon(Icons.person, color: Colors.white),
                    title: Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isMe ? 'Это вы' : nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: _subtitle,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              })),
      ],
    );
  }

  String? _resolveAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    // Если URL уже полный, возвращаем как есть
    if (avatarUrl.startsWith('http')) return avatarUrl;
    // Иначе предполагаем, что это путь к файлу
    return avatarUrl;
  }
}
