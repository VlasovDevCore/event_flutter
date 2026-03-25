import 'package:flutter/material.dart';

class DetailCreatorCard extends StatelessWidget {
  const DetailCreatorCard({
    super.key,
    required this.creatorId,
    required this.creatorTitle,
    required this.creatorNickname,
    required this.creatorAvatarUrl,
    required this.onTap,
  });

  final String? creatorId;
  final String creatorTitle;
  final String creatorNickname;
  final String? creatorAvatarUrl;
  final VoidCallback? onTap;

  static const Color _cardBorder = Color(0xFF23262C);
  static const Color _subtitle = Color(0xFFB5BBC7);
  static const Color _creatorPlaceholderBg = Color(0xFF2A2E37);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: _creatorPlaceholderBg,
          backgroundImage: creatorAvatarUrl != null
              ? NetworkImage(creatorAvatarUrl!)
              : null,
          child: creatorAvatarUrl != null
              ? null
              : const Icon(Icons.person, color: Colors.white, size: 20),
        ),
        title: Text(
          creatorTitle,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          creatorNickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: _subtitle,
            fontSize: 12,
          ),
        ),
        onTap: (creatorId != null && creatorId!.isNotEmpty && onTap != null)
            ? onTap
            : null,
      ),
    );
  }
}
