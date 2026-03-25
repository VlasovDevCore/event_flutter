import 'package:flutter/material.dart';

class DetailDescription extends StatelessWidget {
  const DetailDescription({super.key, required this.description});

  final String description;

  static const Color _subtitle = Color(0xFFB5BBC7);

  @override
  Widget build(BuildContext context) {
    if (description.isEmpty) {
      return const Text(
        'Описание не указано',
        style: TextStyle(fontFamily: 'Inter', color: _subtitle, fontSize: 13),
      );
    }

    return Text(
      description,
      style: const TextStyle(
        fontFamily: 'Inter',
        color: _subtitle,
        fontSize: 13,
      ),
    );
  }
}
