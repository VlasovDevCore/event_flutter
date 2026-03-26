import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DetailCreatorCard extends StatelessWidget {
  final String? creatorId;
  final String creatorTitle;
  final String creatorNickname;
  final String? creatorAvatarUrl;
  final VoidCallback? onTap;

  const DetailCreatorCard({
    super.key,
    this.creatorId,
    required this.creatorTitle,
    required this.creatorNickname,
    this.creatorAvatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: creatorAvatarUrl != null && creatorAvatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: creatorAvatarUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.person,
                          color: Colors.white54,
                          size: 28,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.person,
                          color: Colors.white54,
                          size: 28,
                        ),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white54,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creatorTitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    creatorNickname,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Организатор',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
