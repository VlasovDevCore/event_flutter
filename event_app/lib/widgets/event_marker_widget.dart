import 'package:flutter/material.dart';

class EventMarkerWidget extends StatelessWidget {
  const EventMarkerWidget({
    super.key,
    required this.color,
    required this.icon,
    this.size = 32,
    this.iconSize = 18,
    this.showPinTail = true,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
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

