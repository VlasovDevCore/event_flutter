import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../services/api_client.dart';

class DetailAttendeesSection extends StatelessWidget {
  final Event event;
  final String? currentUserEmail;
  final Function(String) onProfileTap;

  const DetailAttendeesSection({
    super.key,
    required this.event,
    required this.currentUserEmail,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final goingCount = event.goingUsers.length;
    final goingProfiles = event.goingUserProfiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Статистика
        Row(
          children: [
            Icon(Icons.people, size: 20, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 8),
            Text(
              'Участники',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$goingCount ${_getDeclension(goingCount)}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Список участников
        if (goingProfiles.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 12,
              runSpacing: 12,
              children: goingProfiles.map((profile) {
                final isMe =
                    currentUserEmail != null &&
                    profile.email == currentUserEmail;
                final isCreator = profile.id == event.creatorId;
                return GestureDetector(
                  onTap: () => onProfileTap(profile.id),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: profile.avatarUrl != null
                                ? NetworkImage(
                                    _resolveAvatarUrl(profile.avatarUrl!),
                                  )
                                : null,
                            child: profile.avatarUrl == null
                                ? Icon(
                                    Icons.person,
                                    color: Colors.white54,
                                    size: 28,
                                  )
                                : null,
                          ),
                          if (isMe)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF2A2A2A),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (isCreator && !isMe)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF2A2A2A),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.star,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          profile.displayName?.split(' ').first ??
                              profile.username ??
                              'User',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // Пустое состояние
        if (goingProfiles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Пока никто не идет 😔\nБудь первым!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getDeclension(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'участник';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20))
      return 'участника';
    return 'участников';
  }

  String _resolveAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return '';
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return avatarUrl;
    }
    if (avatarUrl.startsWith('/uploads')) {
      return '${ApiClient.baseUrl}$avatarUrl';
    }
    return avatarUrl;
  }
}
