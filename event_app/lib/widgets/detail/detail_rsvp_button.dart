import 'package:flutter/material.dart';

class DetailRsvpButton extends StatelessWidget {
  const DetailRsvpButton({
    super.key,
    required this.isGoing,
    required this.onPressed,
  });

  final bool isGoing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: isGoing
              ? const Color(0xFF2C2C2C) // Темно-серый когда "Не приду"
              : Colors.white, // Белый когда "Я приду"
          foregroundColor: isGoing
              ? Colors
                    .white // Белый текст для "Не приду"
              : Colors.black, // Черный текст для "Я приду"
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 48),
        ),
        onPressed: onPressed,
        child: Text(isGoing ? 'Не приду' : 'Я приду'),
      ),
    );
  }
}
