import 'package:hive_flutter/hive_flutter.dart';

import '../../services/api_client.dart';
import '../../services/push_notifications_service.dart';
import 'profile_achievement.dart';
import 'profile_models.dart';
import 'profile_social_models.dart';

/// Загрузка и кеширование данных профиля (API + Hive для «я»).
class ProfileRepository {
  ProfileRepository._();

  /// Полный выход: очистить кеш авторизации и событий и дождаться записи на диск.
  static Future<void> clearSession() async {
    await PushNotificationsService.instance.unregisterTokenOnLogout();
    final auth = Hive.box('authBox');
    final events = Hive.box('eventsBox');
    await auth.clear();
    await auth.flush();
    await events.clear();
    await events.flush();
  }

  static Future<ProfileMe> fetchMe() async {
    final data = await ApiClient.instance.get('/users/me', withAuth: true);
    return ProfileMe.fromApi(data);
  }

  /// Подтянуть `/users/me` и записать поля в `authBox`.
  static Future<ProfileMe> fetchMeAndWriteHive() async {
    final me = await fetchMe();
    await writeMeToHive(me);
    return me;
  }

  static Future<void> writeMeToHive(ProfileMe me) async {
    final box = Hive.box('authBox');
    await box.put('username', me.username);
    await box.put('email', me.email);
    await box.put('status', me.status);
    await box.put('displayName', me.displayName);
    await box.put('bio', me.bio);
    await box.put('birthDate', me.birthDate);
    await box.put('gender', me.gender);
    await box.put('avatarUrl', me.avatarUrl);
    await box.put('allowMessagesFromNonFriends', me.allowMessagesFromNonFriends);
    if (me.coverGradientColors != null && me.coverGradientColors!.length == 3) {
      await box.put('coverGradientColors', me.coverGradientColors);
    } else {
      await box.delete('coverGradientColors');
    }
    if (me.createdAt != null) {
      await box.put('createdAt', me.createdAt!.toIso8601String());
    }
  }

  static Future<ProfileStats> fetchMyStats() async {
    final data = await ApiClient.instance.get('/users/me/stats', withAuth: true);
    return ProfileStats(
      createdEventsCount: (data['created_events_count'] as num?)?.toInt() ?? 0,
      totalGoingToMyEventsCount: (data['total_going_to_my_events_count'] as num?)?.toInt() ?? 0,
      eventsIGoingCount: (data['events_i_going_count'] as num?)?.toInt() ?? 0,
      eventsIGoingAsGuestCount:
          (data['events_i_going_as_guest_count'] as num?)?.toInt() ?? 0,
      followersCount: (data['followers_count'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<ProfileMe> fetchUser(String userId) async {
    final data = await ApiClient.instance.get('/users/$userId');
    return ProfileMe.fromApi(data);
  }

  static Future<ProfileStats> fetchUserStats(String userId) async {
    final data = await ApiClient.instance.get('/users/$userId/stats');
    return ProfileStats(
      createdEventsCount: (data['created_events_count'] as num?)?.toInt() ?? 0,
      totalGoingToMyEventsCount: (data['total_going_to_my_events_count'] as num?)?.toInt() ?? 0,
      eventsIGoingCount: (data['events_i_going_count'] as num?)?.toInt() ?? 0,
      eventsIGoingAsGuestCount:
          (data['events_i_going_as_guest_count'] as num?)?.toInt() ?? 0,
      followersCount: (data['followers_count'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<ProfileRelationship> fetchRelationship(String userId) async {
    final data =
        await ApiClient.instance.get('/friends/relationship/$userId', withAuth: true);
    return ProfileRelationship.fromApi(data);
  }

  static Future<ProfileBlockStatus> fetchBlockStatus(String userId) async {
    final data = await ApiClient.instance.get('/blocks/status/$userId', withAuth: true);
    return ProfileBlockStatus.fromApi(data);
  }

  static Future<List<ProfileAchievement>> fetchMyAchievements() async {
    final data = await ApiClient.instance.get('/users/me/achievements', withAuth: true);
    return ProfileAchievement.listFromApi(data['achievements']);
  }

  static Future<List<ProfileAchievement>> fetchUserAchievements(String userId) async {
    final data = await ApiClient.instance.get('/users/$userId/achievements');
    return ProfileAchievement.listFromApi(data['achievements']);
  }
}
