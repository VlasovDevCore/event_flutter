import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/api_client.dart';
import '../../utils/formatters.dart';
import '../../widgets/profile/blocked_card.dart';
import '../../widgets/profile/relationship_buttons.dart';
import '../../widgets/profile/stat_badge.dart';
import '../../widgets/profile/stat_card.dart';
import '../auth/auth_screen.dart';
import 'profile_models.dart';
import 'profile_qr_screen.dart';
import 'profile_repository.dart';
import 'profile_social_models.dart';
import 'widgets/achievement_section.dart';
import 'profile_cover_gradient.dart';
import 'widgets/profile_avatar_header.dart';
import 'widgets/profile_cover_edit_sheet.dart';
import 'profile_achievement.dart';
import 'widgets/profile_actions_bar.dart';
import 'profile_edit_screen.dart';
import 'profile_dialogs.dart';
import 'profile_provider.dart';
import 'profile_stats_provider.dart';
import 'profile_achievements_provider.dart';
import 'widgets/report_user_sheet.dart';
import 'widgets/profile_active_events_section.dart';
import '../events/event_details_screen.dart';
import '../../models/event.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Для чужого профиля
  late Future<ProfileMe?> _otherUserFuture;
  late Future<ProfileStats> _otherStatsFuture;
  late Future<ProfileRelationship> _relationshipFuture;
  late Future<ProfileBlockStatus> _blockStatusFuture;
  late Future<List<ProfileAchievement>> _otherAchievementsFuture;
  late Future<List<Event>> _otherActiveEventsFuture;
  /// Один общий future для [FutureBuilder] — нельзя создавать [Future.wait] в [build],
  /// иначе при любом [setState] виджет сбрасывается в loading.
  late Future<List<dynamic>> _otherProfileCombinedFuture;

  // Для своего профиля - провайдеры
  ProfileProvider? _profileProvider;
  ProfileStatsProvider? _statsProvider;
  ProfileAchievementsProvider? _achievementsProvider;
  Future<List<Event>>? _myActiveEventsFuture;

  bool _savingProfile = false;

  bool _isLoggedIn() =>
      Hive.box('authBox').get('token') != null;

  @override
  void initState() {
    super.initState();

    final isMe = widget.userId == null;

    if (isMe) {
      // Для своего профиля используем провайдеры
      _profileProvider = ProfileProvider();
      _statsProvider = ProfileStatsProvider();
      _achievementsProvider = ProfileAchievementsProvider();
      final myId = Hive.box('authBox').get('userId')?.toString().trim();
      if (myId != null && myId.isNotEmpty) {
        _myActiveEventsFuture = ProfileRepository.fetchUserActiveEvents(myId);
      }
    } else {
      // Для чужого профиля используем Future
      _loadOtherProfileData();
    }
  }

  void _loadOtherProfileData() {
    _otherUserFuture = ProfileRepository.fetchUser(widget.userId!);
    _otherStatsFuture = ProfileRepository.fetchUserStats(widget.userId!);
    _relationshipFuture = ProfileRepository.fetchRelationship(widget.userId!);
    _blockStatusFuture = ProfileRepository.fetchBlockStatus(widget.userId!);
    _otherAchievementsFuture = ProfileRepository.fetchUserAchievements(
      widget.userId!,
    );
    _otherActiveEventsFuture = ProfileRepository.fetchUserActiveEvents(
      widget.userId!,
    );
    _otherProfileCombinedFuture = Future.wait([
      _otherUserFuture,
      _otherStatsFuture,
      _relationshipFuture,
      _blockStatusFuture,
      _otherAchievementsFuture,
      _otherActiveEventsFuture,
    ]);
  }

  @override
  void dispose() {
    _profileProvider?.dispose();
    _statsProvider?.dispose();
    _achievementsProvider?.dispose();
    super.dispose();
  }

  Future<void> _openCoverEditSheet() async {
    final initial = _getCoverGradientColors();
    final initialHex = List<String>.from(
      initial != null && initial.length == 3
          ? initial
          : kDefaultCoverGradientHex,
    );

    await showProfileCoverEditSheet(
      context,
      initialHexColors: initialHex,
      onSave: (colors) async {
        setState(() => _savingProfile = true);
        try {
          final data = await ApiClient.instance.put(
            '/users/me',
            withAuth: true,
            body: {'coverGradientColors': colors},
          );
          if (!mounted) return;
          final me = ProfileMe.fromApi(data);
          await ProfileRepository.writeMeToHive(me);
          // Обновляем провайдер
          _profileProvider?.refresh();
        } finally {
          if (mounted) setState(() => _savingProfile = false);
        }
      },
    );
  }

  List<String>? _getCoverGradientColors() {
    final raw = Hive.box('authBox').get('coverGradientColors');
    if (raw is List && raw.length == 3) {
      return raw.map((e) => e.toString()).toList();
    }
    return null;
  }

  Future<void> _reloadRelationshipData() async {
    if (!mounted || widget.userId == null) return;
    final id = widget.userId!;
    setState(() {
      _relationshipFuture = ProfileRepository.fetchRelationship(id);
      _blockStatusFuture = ProfileRepository.fetchBlockStatus(id);
      _otherStatsFuture = ProfileRepository.fetchUserStats(id);
      _otherActiveEventsFuture = ProfileRepository.fetchUserActiveEvents(id);
      _otherProfileCombinedFuture = Future.wait([
        _otherUserFuture,
        _otherStatsFuture,
        _relationshipFuture,
        _blockStatusFuture,
        _otherAchievementsFuture,
        _otherActiveEventsFuture,
      ]);
    });
  }

  Future<void> _openEditScreen() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ProfileEditScreen()));

    if (result == true && mounted) {
      // Обновляем провайдеры - они сами уведомят UI
      _profileProvider?.refresh();
      _statsProvider?.refresh();
      _achievementsProvider?.refresh();
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await ProfileDialogs.confirmSignOut(context);
    if (ok != true || !mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      (route) => false,
    );

    try {
      await ProfileRepository.clearSession();
    } catch (_) {
      try {
        await Hive.box('authBox').clear();
        await Hive.box('eventsBox').clear();
      } catch (_) {}
    }
  }

  Future<void> _handleBlock() async {
    if (widget.userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance.post(
        '/blocks/block',
        body: {'userId': widget.userId},
        withAuth: true,
      );
      if (!mounted) return;
      await _reloadRelationshipData();
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _handleUnblock() async {
    if (widget.userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance.post(
        '/blocks/unblock',
        body: {'userId': widget.userId},
        withAuth: true,
      );
      if (!mounted) return;
      await _reloadRelationshipData();
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == null;

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: isMe ? _buildMyProfile() : _buildOtherProfile(),
    );
  }

  Widget _buildMyProfile() {
    if (_profileProvider == null ||
        _statsProvider == null ||
        _achievementsProvider == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        _profileProvider!,
        _statsProvider!,
        _achievementsProvider!,
      ]),
      builder: (context, child) {
        final profile = _profileProvider!.profile;
        final stats = _statsProvider!.stats;
        final achievements = _achievementsProvider!.achievements;

        if (profile == null || stats == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final myActiveFuture = _myActiveEventsFuture;
        if (myActiveFuture == null) {
          return _buildProfileContent(
            profile: profile,
            stats: stats,
            achievements: achievements,
            isMe: true,
            isLoadingStats: _statsProvider!.isLoading,
            isLoadingAchievements: _achievementsProvider!.isLoading,
            relationship: null,
            blockStatus: null,
            activeEvents: const [],
          );
        }

        return FutureBuilder<List<Event>>(
          future: myActiveFuture,
          builder: (context, snapshot) {
            final activeEvents = snapshot.data ?? const <Event>[];
            return _buildProfileContent(
              profile: profile,
              stats: stats,
              achievements: achievements,
              isMe: true,
              isLoadingStats: _statsProvider!.isLoading,
              isLoadingAchievements: _achievementsProvider!.isLoading,
              relationship: null,
              blockStatus: null,
              activeEvents: activeEvents,
            );
          },
        );
      },
    );
  }

  Widget _buildOtherProfile() {
    return FutureBuilder<List<dynamic>>(
      future: _otherProfileCombinedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loadOtherProfileData();
                    });
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        final results = snapshot.data as List<dynamic>;

        // Правильные индексы:
        // 0 - _otherUserFuture
        // 1 - _otherStatsFuture
        // 2 - _relationshipFuture
        // 3 - _blockStatusFuture
        // 4 - _otherAchievementsFuture
        // 5 - _otherActiveEventsFuture

        final profile = results[0] as ProfileMe?;
        final stats = results[1] as ProfileStats;
        final relationship = results[2] as ProfileRelationship;
        final blockStatus = results[3] as ProfileBlockStatus;
        final achievements = results[4] as List<ProfileAchievement>;
        final activeEvents = results[5] as List<Event>;

        if (profile == null) {
          return const Center(
            child: Text(
              'Пользователь не найден',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return _buildProfileContent(
          profile: profile,
          stats: stats,
          achievements: achievements,
          isMe: false,
          isLoadingStats: false,
          isLoadingAchievements: false,
          relationship: relationship,
          blockStatus: blockStatus,
          activeEvents: activeEvents,
        );
      },
    );
  }

  Widget _buildProfileContent({
    required ProfileMe profile,
    required ProfileStats stats,
    required List<ProfileAchievement> achievements,
    required bool isMe,
    required bool isLoadingStats,
    required bool isLoadingAchievements,
    ProfileRelationship? relationship,
    ProfileBlockStatus? blockStatus,
    List<Event>? activeEvents,
  }) {
    final title = (profile.displayName?.isNotEmpty == true)
        ? profile.displayName!
        : 'Пользователь';
    final subtitle = profile.username?.isNotEmpty == true
        ? '@${profile.username}'
        : (profile.email ?? '—');
    final avatarUrl = profile.resolvedAvatarUrl();
    final isBlockedView = !isMe &&
        blockStatus != null &&
        (blockStatus.isBlocked || blockStatus.isBlockedBy);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ProfileAvatarHeader(
            headerHeight: 110,
            avatarUrl: avatarUrl,
            headerGradientColors: coverGradientColorsFromHex(
              profile.coverGradientColors,
            ),
            actionsBar: ProfileActionsBar(
              onBackPressed: () => Navigator.of(context).pop(),
              isMe: isMe,
              onCoverEditPressed: isMe ? _openCoverEditSheet : null,
              onEditPressed: isMe ? _openEditScreen : null,
              onQrPressed: () {
                final myId = Hive.box('authBox').get('userId') as String?;
                if (myId == null || myId.trim().isEmpty) return;
                final box = Hive.box('authBox');
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileQrScreen(
                      userId: myId.trim(),
                      displayName: box.get('displayName') as String?,
                      username: box.get('username') as String?,
                      avatarUrl: box.get('avatarUrl') as String?,
                      coverGradientColors:
                          profile.coverGradientColors ??
                          _getCoverGradientColors(),
                      buildProfileScreen: (scannedId) =>
                          ProfileScreen(userId: scannedId),
                    ),
                  ),
                );
              },
              onLogoutPressed: isMe ? _confirmSignOut : null,
              onBlockPressed: !isMe ? _handleBlock : null,
              onUnblockPressed: !isMe ? _handleUnblock : null,
              onReportPressed: !isMe && widget.userId != null && _isLoggedIn()
                  ? () {
                      final title = (profile.displayName?.isNotEmpty == true)
                          ? profile.displayName!
                          : (profile.username?.isNotEmpty == true
                              ? '@${profile.username}'
                              : 'Пользователь');
                      showReportUserSheet(
                        context,
                        reportedUserId: widget.userId!,
                        reportedUserTitle: title,
                      );
                    }
                  : null,
              isBlocked: blockStatus?.isBlocked ?? false,
              isSaving: _savingProfile,
            ),
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 37,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade400,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMe &&
                  relationship != null &&
                  blockStatus != null &&
                  _isLoggedIn() &&
                  widget.userId != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RelationshipButtons(
                    userId: widget.userId!,
                    title: title,
                    isFollowing: relationship.isFollowing,
                    canMessage:
                        (relationship.isFriends ||
                            profile.allowMessagesFromNonFriends) &&
                        !blockStatus.isBlocked &&
                        !blockStatus.isBlockedBy,
                    isUserBlocked: blockStatus.isBlocked || blockStatus.isBlockedBy,
                    onFollowingChanged: () {
                      unawaited(_reloadRelationshipData());
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildStatsRow(stats, isLoadingStats),
            ],
          ),
        ),
        if (isBlockedView) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BlockedCard(
              isBlocked: blockStatus.isBlocked,
              isBlockedBy: blockStatus.isBlockedBy,
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 16),
          if (activeEvents != null && activeEvents.isNotEmpty)
            ProfileActiveEventsSection(
              events: activeEvents,
              onEventTap: (event) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventDetailsScreen(event: event),
                  ),
                );
              },
            ),
          _buildBioSection(profile, isMe),
          const SizedBox(height: 16),
          _buildStatsCards(stats, isLoadingStats),
          const SizedBox(height: 16),
          _buildAchievementsSection(achievements, isLoadingAchievements, isMe),
        ],
        if (!isBlockedView) ...[
          const SizedBox(height: 16),
          _buildTenureLine(profile.createdAt, isMe),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildStatsRow(ProfileStats stats, bool isLoading) {
    if (isLoading) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: const EdgeInsets.only(left: 16),
          width: 120,
          child: StatBadge(count: stats.followersCount, label: 'подписчиков'),
        ),
        Container(
          width: 1,
          height: 40,
          color: const Color.fromARGB(255, 44, 44, 44),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          width: 120,
          child: StatBadge(
            count: stats.createdEventsCount,
            label: 'встреч создал',
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection(ProfileMe profile, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(
            color: Color.fromARGB(144, 44, 44, 44),
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 16),
          const Text(
            'О себе',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 19,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.bio?.isNotEmpty == true
                ? profile.bio!
                : (isMe
                      ? 'Вы ещё ничего не рассказали о себе.'
                      : 'Пользователь ничего не рассказал о себе.'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: profile.bio?.isNotEmpty == true
                  ? Colors.white
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(ProfileStats stats, bool isLoading) {
    if (isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final items = [
      StatCard(value: stats.createdEventsCount, label: 'Создал встреч'),
      StatCard(value: stats.totalGoingToMyEventsCount, label: 'Посетителей'),
      StatCard(value: stats.eventsIGoingCount, label: 'Посетил встреч'),
      StatCard(value: stats.followersCount, label: 'Подписчиков'),
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, index) {
          return StatCard(
            value: items[index].value,
            label: items[index].label,
            isFirst: index == 0,
            isLast: index == items.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildAchievementsSection(
    List<ProfileAchievement> achievements,
    bool isLoading,
    bool isMe,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AchievementSection(
        items: achievements,
        isLoading: isLoading,
        onRetry: isMe ? () => _achievementsProvider?.refresh() : null,
      ),
    );
  }

  Widget _buildTenureLine(DateTime? createdAt, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        withUsTenureLine(createdAt, isMe),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: Color.fromARGB(255, 77, 77, 77),
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}
