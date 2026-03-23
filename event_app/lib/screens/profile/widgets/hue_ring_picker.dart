import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Только кольцо оттенка HSV: без внутреннего SV-квадрата и без маркера в центре
/// (в отличие от [ColorWheelPicker] flex_color_picker при нулевом квадрате).
class HueRingPicker extends StatefulWidget {
  const HueRingPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.wheelWidth = 14,
    this.borderColor = const Color(0x3FFFFFFF),
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final double wheelWidth;
  final Color borderColor;

  @override
  State<HueRingPicker> createState() => _HueRingPickerState();
}

class _HueRingPickerState extends State<HueRingPicker> {
  final GlobalKey _paintKey = GlobalKey();
  late double _hue;
  late double _saturation;
  late double _value;
  bool _onRing = false;

  @override
  void initState() {
    super.initState();
    _syncFromColor(widget.color);
  }

  @override
  void didUpdateWidget(HueRingPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _syncFromColor(widget.color);
    }
  }

  void _syncFromColor(Color c) {
    final hsv = HSVColor.fromColor(c);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  /// Радиус до центра линии обводки кольца (как в flex_color_picker _WheelPainter).
  double _pathRadius(Size size) =>
      math.min(size.width, size.height) / 2 - widget.wheelWidth / 2;

  void _emit() {
    final a = HSVColor.fromColor(widget.color).alpha;
    final c = HSVColor.fromAHSV(a, _hue, _saturation, _value).toColor();
    widget.onChanged(c);
  }

  void _handle(Offset globalPos, {required bool isStart}) {
    final box = _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final center = Offset(size.width / 2, size.height / 2);
    final local = globalPos - origin;
    final v = local - center;
    final len = v.distance;
    final pathR = _pathRadius(size);
    final inner = pathR - widget.wheelWidth / 2;
    final outer = pathR + widget.wheelWidth / 2;

    final onRing = len >= inner - 0.5 && len <= outer + 0.5;

    if (isStart && !onRing) {
      _onRing = false;
      return;
    }
    if (!onRing && !_onRing) return;

    _onRing = true;
    _hue = (((math.atan2(v.dy, v.dx)) * 180.0 / math.pi) + 360.0) % 360.0;
    _emit();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _handle(d.globalPosition, isStart: true),
      onPanUpdate: (d) => _handle(d.globalPosition, isStart: false),
      onPanEnd: (_) => _onRing = false,
      onPanCancel: () => _onRing = false,
      onTapUp: (d) {
        _handle(d.globalPosition, isStart: true);
        _onRing = false;
      },
      child: CustomPaint(
        key: _paintKey,
        painter: _HueRingPainter(
          hue: _hue,
          wheelWidth: widget.wheelWidth,
          borderColor: widget.borderColor,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HueRingPainter extends CustomPainter {
  _HueRingPainter({
    required this.hue,
    required this.wheelWidth,
    required this.borderColor,
  });

  final double hue;
  final double wheelWidth;
  final Color borderColor;

  static double _wheelRadius(Size size, double wheelWidth) =>
      math.min(size.width, size.height) / 2 - wheelWidth / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    final rectCircle = Rect.fromCenter(
      center: center,
      width: shortest - wheelWidth,
      height: shortest - wheelWidth,
    );

    const rads = (2 * math.pi) / 360;
    const step = 1.0;
    const aliasing = 0.5;

    for (int i = 0; i < 360; i++) {
      final sRad = (i - aliasing) * rads;
      final eRad = (i + step) * rads;
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1, i.toDouble(), 1, 1).toColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = wheelWidth;
      canvas.drawArc(rectCircle, sRad, sRad - eRad, false, paint);
    }

    // Одна тонкая обводка по внешнему краю кольца (без второго круга снутри).
    final r = _HueRingPainter._wheelRadius(size, wheelWidth);
    canvas.drawCircle(
      center,
      r + wheelWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = borderColor
        ..strokeWidth = 1,
    );

    // Бегунок на кольце.
    final hr = hue * math.pi / 180.0;
    final thumb = Offset(
      math.cos(hr) * r + center.dx,
      math.sin(hr) * r + center.dy,
    );
    final t = wheelWidth / 2 + 4;
    canvas.drawCircle(
      thumb,
      t,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    canvas.drawCircle(
      thumb,
      t,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.wheelWidth != wheelWidth ||
        oldDelegate.borderColor != borderColor;
  }
}
