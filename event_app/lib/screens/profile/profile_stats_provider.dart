// profile_stats_provider.dart
import 'package:flutter/material.dart';
import 'profile_models.dart';
import 'profile_repository.dart';

class ProfileStatsProvider extends ChangeNotifier {
  ProfileStats? _stats;
  bool _isLoading = false;
  String? _error;

  ProfileStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ProfileStatsProvider() {
    loadStats();
  }

  Future<void> loadStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await ProfileRepository.fetchMyStats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadStats();
  }
}
