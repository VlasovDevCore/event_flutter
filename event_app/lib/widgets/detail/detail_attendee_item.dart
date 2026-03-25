import 'package:flutter/material.dart';
import '../../../services/api_client.dart';

class DetailAttendeeItem extends StatelessWidget {
  const DetailAttendeeItem({
    super.key,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.onTap,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final VoidCallback? onTap;

  static const Color _cardBorder = Color(0xFF23262C);
  static const Color _subtitle = Color(0xFFB5BBC7);
  static const Color _placeholderBg = Color(0xFF2A2E37);

  String? getFullAvatarUrl(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return avatarUrl;
    }
    if (avatarUrl.startsWith('/uploads')) {
      return '${ApiClient.baseUrl}$avatarUrl';
    }
    if (avatarUrl.startsWith('file://')) {
      // Убираем 'file://' и добавляем базовый URL
      final cleanPath = avatarUrl.substring(7); // Убираем 'file://'
      if (cleanPath.startsWith('/uploads')) {
        return '${ApiClient.baseUrl}$cleanPath';
      }
      return '${ApiClient.baseUrl}$cleanPath';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fullAvatarUrl = getFullAvatarUrl(
      avatarUrl,
    ); // <-- ВАЖНО: используем функцию!

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          backgroundColor: _placeholderBg,
          backgroundImage: fullAvatarUrl != null
              ? NetworkImage(fullAvatarUrl)
              : null, // <-- используем fullAvatarUrl
          child: fullAvatarUrl == null
              ? const Icon(Icons.person, color: Colors.white, size: 20)
              : null,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: _subtitle,
                  fontSize: 12,
                ),
              )
            : null,
        onTap: (id.isNotEmpty && onTap != null) ? onTap : null,
      ),
    );
  }
}
