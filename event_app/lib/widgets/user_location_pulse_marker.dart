import 'package:flutter/material.dart';

/// Маркер «я на карте»: синий кружок и расходящиеся кольца-пульсация.
class UserLocationPulseMarker extends StatefulWidget {
  const UserLocationPulseMarker({super.key});

  static const double size = 88;

  @override
  State<UserLocationPulseMarker> createState() => _UserLocationPulseMarkerState();
}

class _UserLocationPulseMarkerState extends State<UserLocationPulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: UserLocationPulseMarker.size,
      height: UserLocationPulseMarker.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < 3; i++) _pulseRing((t + i / 3) % 1.0),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withOpacity(0.55),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pulseRing(double phase) {
    final eased = Curves.easeOut.transform(phase);
    final diameter = 22.0 + eased * 56.0;
    final opacity = ((1.0 - phase) * 0.55).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2196F3).withOpacity(0.12 * opacity / 0.55),
          border: Border.all(
            color: const Color(0xFF2196F3).withOpacity(opacity),
            width: 2,
          ),
        ),
      ),
    );
  }
}
