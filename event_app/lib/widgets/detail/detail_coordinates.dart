import 'package:flutter/material.dart';

class DetailCoordinates extends StatelessWidget {
  const DetailCoordinates({super.key, required this.lat, required this.lon});

  final double lat;
  final double lon;

  static const Color _text = Color(0xFFDFE3EC);
  static const Color _subtitle = Color(0xFFB5BBC7);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Координаты:',
          style: TextStyle(
            fontFamily: 'Inter',
            color: _text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Широта: ${lat.toStringAsFixed(5)}\nДолгота: ${lon.toStringAsFixed(5)}',
          style: const TextStyle(
            fontFamily: 'Inter',
            color: _subtitle,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
