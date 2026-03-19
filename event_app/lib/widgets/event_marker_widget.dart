import 'package:flutter/material.dart';

class EventMarkerWidget extends StatelessWidget {
  const EventMarkerWidget({
    super.key,
    required this.color,
    required this.icon,
    this.size = 50,
    this.iconSize = 24,
    this.showPinTail = false,
  });

  final Color color;
  final IconData icon;
  final double size;
  final double iconSize;
  final bool showPinTail;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF23262C),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.45),
                blurRadius: 14,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: Colors.white,
            size: iconSize,
          ),
        ),
        if (showPinTail)
          Container(
            width: 4,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

