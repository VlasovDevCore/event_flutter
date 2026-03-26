import 'package:flutter/material.dart';

class DetailDescription extends StatelessWidget {
  const DetailDescription({super.key, required this.description});

  final String description;

  static const Color _subtitle = Color.fromARGB(255, 255, 255, 255);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Описание:',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        if (description.isEmpty)
          Text(
            'Описание не указано',
            style: TextStyle(
              fontFamily: 'Inter',
              color: _subtitle.withOpacity(0.6),
              fontSize: 13,
            ),
          )
        else
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: _subtitle,
              fontSize: 15,
              height: 1.5,
            ),
          ),
      ],
    );
  }
}
