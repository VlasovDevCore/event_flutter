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

  void _showAllAttendees(
    BuildContext context,
    List<EventUserProfile> allProfiles,
    String? currentUserEmail,
  ) {
    final totalCount = allProfiles.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Заголовок
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.people,
                            color: Colors.white70,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Все участники',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalCount',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Список участников
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: allProfiles.length,
                    itemBuilder: (context, index) {
                      final profile = allProfiles[index];
                      final isMe =
                          currentUserEmail != null &&
                          profile.email == currentUserEmail;
                      final isCreator = profile.id == event.creatorId;

                      // Получаем отображаемое имя (приоритет: displayName > username > 'Пользователь')
                      final displayName =
                          profile.displayName?.isNotEmpty == true
                          ? profile.displayName!
                          : (profile.username?.isNotEmpty == true
                                ? profile.username!
                                : 'Пользователь');

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          onProfileTap(profile.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.05),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Аватар
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: profile.avatarUrl != null
                                        ? Image.network(
                                            _resolveAvatarUrl(
                                              profile.avatarUrl!,
                                            ),
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: Colors.grey[800],
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors.white54,
                                                      size: 24,
                                                    ),
                                                  );
                                                },
                                          )
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            color: Colors.grey[800],
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white54,
                                              size: 24,
                                            ),
                                          ),
                                  ),
                                  if (isMe)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF1E1E1E),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF1E1E1E),
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
                              const SizedBox(width: 12),
                              // Информация
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (isMe)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Вы',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 10,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        if (isCreator && !isMe)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Организатор',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 10,
                                                color: Colors.amber,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    // Показываем никнейм вместо email
                                    if (profile.username != null &&
                                        profile.username!.isNotEmpty)
                                      Text(
                                        '@${profile.username}',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goingProfiles = event.goingUserProfiles;
    final goingCount = goingProfiles.length;

    // Показываем только первых 12 участников
    final displayProfiles = goingProfiles.take(12).toList();
    final hasMore = goingProfiles.length > 12;

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
        if (displayProfiles.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const itemWidth = 70.0;
                final availableWidth = constraints.maxWidth;
                final itemsPerRow = (availableWidth / itemWidth).floor().clamp(
                  4,
                  8,
                );

                return Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: itemsPerRow,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: displayProfiles.length,
                      itemBuilder: (context, index) {
                        final profile = displayProfiles[index];
                        final isMe =
                            currentUserEmail != null &&
                            profile.email == currentUserEmail;
                        final isCreator = profile.id == event.creatorId;

                        return GestureDetector(
                          onTap: () => onProfileTap(profile.id),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      15,
                                    ), // Полукруглые углы
                                    child: profile.avatarUrl != null
                                        ? Image.network(
                                            _resolveAvatarUrl(
                                              profile.avatarUrl!,
                                            ),
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    width: 56,
                                                    height: 56,
                                                    color: Colors.grey[800],
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: Colors.white54,
                                                      size: 28,
                                                    ),
                                                  );
                                                },
                                          )
                                        : Container(
                                            width: 56,
                                            height: 56,
                                            color: Colors.grey[800],
                                            child: const Icon(
                                              Icons.person,
                                              color: Colors.white54,
                                              size: 28,
                                            ),
                                          ),
                                  ),
                                  if (isMe)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                              const SizedBox(height: 6),
                              Text(
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
                            ],
                          ),
                        );
                      },
                    ),
                    // Кнопка "Показать всех"
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: InkWell(
                          onTap: () => _showAllAttendees(
                            context,
                            goingProfiles,
                            currentUserEmail,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Показать всех участников',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+${goingProfiles.length - 12}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Colors.white54,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

        // Пустое состояние
        if (displayProfiles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/events/tick-dynamic-color.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  'Пока никто не идет',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Будь первым!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
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
