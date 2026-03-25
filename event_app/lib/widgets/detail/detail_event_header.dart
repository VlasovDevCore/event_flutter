import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailEventHeader extends StatelessWidget {
  const DetailEventHeader({
    super.key,
    required this.title,
    required this.createdAt,
    required this.endsAt,
  });

  final String title;
  final DateTime createdAt;
  final DateTime? endsAt;

  static const Color _text = Color(0xFFDFE3EC);
  static const Color _subtitle = Color(0xFFB5BBC7);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Создано: ${dateFormat.format(createdAt)}',
          style: const TextStyle(
            fontFamily: 'Inter',
            color: _subtitle,
            fontSize: 13,
          ),
        ),
        if (endsAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Актуально до: ${dateFormat.format(endsAt!)}',
            style: const TextStyle(
              fontFamily: 'Inter',
              color: _subtitle,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
