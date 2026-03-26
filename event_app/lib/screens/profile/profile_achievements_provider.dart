// profile_achievements_provider.dart
import 'package:flutter/material.dart';
import 'profile_achievement.dart';
import 'profile_repository.dart';

class ProfileAchievementsProvider extends ChangeNotifier {
  List<ProfileAchievement> _achievements = [];
  bool _isLoading = false;
  String? _error;

  List<ProfileAchievement> get achievements => _achievements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ProfileAchievementsProvider() {
    loadAchievements();
  }

  Future<void> loadAchievements() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _achievements = await ProfileRepository.fetchMyAchievements();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadAchievements();
  }
}
