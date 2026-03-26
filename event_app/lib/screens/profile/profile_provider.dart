// profile_provider.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'profile_models.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileMe? _profile;

  ProfileMe? get profile => _profile;

  ProfileProvider() {
    _loadProfile();
    // Слушаем изменения в Hive
    Hive.box('authBox').watch().listen((event) {
      _loadProfile();
      notifyListeners();
    });
  }

  void _loadProfile() {
    final box = Hive.box('authBox');
    final status = (box.get('status') as int?) ?? 1;
    _profile = ProfileMe(
      email: box.get('email') as String?,
      username: box.get('username') as String?,
      status: status,
      displayName: box.get('displayName') as String?,
      bio: box.get('bio') as String?,
      birthDate: box.get('birthDate') as String?,
      gender: box.get('gender') as String?,
      avatarUrl: box.get('avatarUrl') as String?,
      allowMessagesFromNonFriends:
          (box.get('allowMessagesFromNonFriends') as bool?) ?? true,
      coverGradientColors: _getCoverGradientColors(box),
      createdAt: _getCreatedAt(box),
    );
  }

  void updateProfile(ProfileMe updatedProfile) {
    _profile = updatedProfile;
    notifyListeners();
  }

  void refresh() {
    _loadProfile();
    notifyListeners();
  }

  List<String>? _getCoverGradientColors(Box box) {
    final raw = box.get('coverGradientColors');
    if (raw is List && raw.length == 3) {
      return raw.map((e) => e.toString()).toList();
    }
    return null;
  }

  DateTime? _getCreatedAt(Box box) {
    final raw = box.get('createdAt');
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}
