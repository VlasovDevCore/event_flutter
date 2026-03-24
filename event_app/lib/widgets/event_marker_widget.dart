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
    final gradientStart = Color.lerp(color, Colors.white, 0.22) ?? color;
    final gradientEnd = Color.lerp(color, Colors.black, 0.22) ?? color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
            borderRadius: BorderRadius.circular(12),
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

