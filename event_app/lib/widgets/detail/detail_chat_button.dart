import 'package:flutter/material.dart';

class DetailChatButton extends StatelessWidget {
  const DetailChatButton({
    super.key,
    required this.onPressed,
    this.onMapPressed,
  });

  final VoidCallback onPressed;
  final VoidCallback? onMapPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
            label: const Text(
              'Открыть чат события',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ),
        if (onMapPressed != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF8604A), // Цвет Яндекс.Карт
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onMapPressed,
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text(
                'Открыть в Яндекс.Картах',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
