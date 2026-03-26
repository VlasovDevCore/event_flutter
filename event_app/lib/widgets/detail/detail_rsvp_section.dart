// widgets/detail/detail_rsvp_section.dart
import 'package:flutter/material.dart';
import 'detail_rsvp_button.dart';

class DetailRsvpSection extends StatelessWidget {
  final bool isGoing;
  final VoidCallback onPressed;

  const DetailRsvpSection({
    super.key,
    required this.isGoing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DetailRsvpButton(isGoing: isGoing, onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}
