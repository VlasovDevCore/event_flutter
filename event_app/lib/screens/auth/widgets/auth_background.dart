import 'package:flutter/material.dart';

import 'auth_colors.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 0.75,
                colors: [
                  Color.fromARGB(197, 29, 29, 29),
                  AuthColors.bg,
                ],
                stops: [0.08, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

