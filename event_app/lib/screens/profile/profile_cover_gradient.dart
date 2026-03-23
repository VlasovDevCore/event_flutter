import 'package:flutter/material.dart';

/// Дефолтный градиент обложки (как в [ProfileAvatarHeader]).
const List<String> kDefaultCoverGradientHex = [
  '#E64444',
  '#FF6E82',
  '#FEBC2F',
];

Color? hexToColor(String s) {
  var hex = s.trim();
  if (!hex.startsWith('#')) return null;
  hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return null;
  return Color(v);
}

int _ch(double x) => (x * 255.0).round().clamp(0, 255);

String colorToHexRgb(Color c) {
  final r = _ch(c.r);
  final g = _ch(c.g);
  final b = _ch(c.b);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

List<Color> coverGradientColorsFromHex(List<String>? hexes) {
  if (hexes == null || hexes.length != 3) {
    return kDefaultCoverGradientHex.map((h) => hexToColor(h)!).toList();
  }
  final out = <Color>[];
  for (final h in hexes) {
    final c = hexToColor(h);
    if (c == null) {
      return kDefaultCoverGradientHex.map((x) => hexToColor(x)!).toList();
    }
    out.add(c);
  }
  return out;
}
