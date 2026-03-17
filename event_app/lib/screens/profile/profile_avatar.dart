import 'package:flutter/material.dart';

import '../../services/api_client.dart';

String? resolveAvatarUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final v = raw.trim();
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  if (v.startsWith('/')) return '${ApiClient.baseUrl}$v';
  return '${ApiClient.baseUrl}/$v';
}

const avatarPalette = <Color>[
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFF4511E),
  Color(0xFF8E24AA),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
  Color(0xFFFDD835),
  Color(0xFFE53935),
];

const avatarIcons = <IconData>[
  Icons.person,
  Icons.face,
  Icons.pets,
  Icons.sports_esports,
  Icons.music_note,
  Icons.directions_run,
  Icons.star,
  Icons.flutter_dash,
];

