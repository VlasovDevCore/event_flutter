import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../auth/auth_screen.dart';
import '../chat/direct_chat_screen.dart';
import 'profile_avatar.dart';
import 'profile_models.dart';
import 'profile_qr_screen.dart';
import 'profile_repository.dart';
import 'profile_social_models.dart';
import 'widgets/achievement_section.dart';
import 'widgets/avatar_crop_dialog.dart';
import 'widgets/birth_date_numeric_sheet.dart';
import 'widgets/profile_edit_sheet_content.dart';
import 'widgets/stat_tile.dart';
import 'profile_achievement.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.userId,
  });

  /// Если `null` — показываем и редактируем мой профиль (`/users/me`).
  /// Если задан — показываем профиль другого пользователя (`/users/:id`) в режиме просмотра.
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ProfileStats> _statsFuture;
  late Future<ProfileMe?> _otherUserFuture;
  late Future<ProfileStats> _otherStatsFuture;
  late Future<ProfileRelationship> _relationshipFuture;
  late Future<ProfileBlockStatus> _blockStatusFuture;
  late Future<List<ProfileAchievement>> _achievementsFuture;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _statsFuture =
        widget.userId == null ? ProfileRepository.fetchMyStats() : Future.value(const ProfileStats.empty());
    _otherUserFuture =
        widget.userId == null ? Future.value(null) : ProfileRepository.fetchUser(widget.userId!);
    _otherStatsFuture = widget.userId == null
        ? Future.value(const ProfileStats.empty())
        : ProfileRepository.fetchUserStats(widget.userId!);
    _relationshipFuture = widget.userId == null
        ? Future.value(const ProfileRelationship.empty())
        : ProfileRepository.fetchRelationship(widget.userId!);
    _blockStatusFuture = widget.userId == null
        ? Future.value(const ProfileBlockStatus.empty())
        : ProfileRepository.fetchBlockStatus(widget.userId!);
    _achievementsFuture = widget.userId == null
        ? ProfileRepository.fetchMyAchievements()
        : ProfileRepository.fetchUserAchievements(widget.userId!);
    if (widget.userId == null) {
      ProfileRepository.fetchMeAndWriteHive();
    }
  }

  String? _email() => Hive.box('authBox').get('email') as String?;
  String? _username() => Hive.box('authBox').get('username') as String?;
  String? _displayName() => Hive.box('authBox').get('displayName') as String?;
  String? _bio() => Hive.box('authBox').get('bio') as String?;
  String? _birthDate() => Hive.box('authBox').get('birthDate') as String?;
  String? _gender() => Hive.box('authBox').get('gender') as String?;
  int? _avatarColorValue() => Hive.box('authBox').get('avatarColorValue') as int?;
  int? _avatarIconCodePoint() => Hive.box('authBox').get('avatarIconCodePoint') as int?;
  String? _avatarUrl() => Hive.box('authBox').get('avatarUrl') as String?;
  bool _allowMessagesFromNonFriends() =>
      (Hive.box('authBox').get('allowMessagesFromNonFriends') as bool?) ?? true;

  Color _avatarColorOrDefault() {
    final v = _avatarColorValue();
    return v == null ? Colors.blue : Color(v);
  }

  Future<void> _openEditSheet() async {
    final box = Hive.box('authBox');

    final usernameController = TextEditingController(text: _username() ?? '');
    final displayNameController = TextEditingController(text: _displayName() ?? '');
    final bioController = TextEditingController(text: _bio() ?? '');

    String? birthDate = _birthDate();
    String? gender = _gender();
    int avatarColorValue = (_avatarColorValue() ?? Colors.blue.toARGB32());
    int avatarIconCodePoint = (_avatarIconCodePoint() ?? Icons.person.codePoint);
    String? avatarUrl = _avatarUrl();
    bool allowMessagesFromNonFriends = _allowMessagesFromNonFriends();

    Timer? debounce;
    bool disposed = false;
    void Function(void Function())? sheetSetState;
    String? lastSaveMessage;
    bool lastSaveOk = true;

    Future<void> persist() async {
      if (disposed) return;
      final username = usernameController.text.trim();
      final displayName = displayNameController.text.trim();
      final bio = bioController.text.trim();

      if (username.isEmpty) {
        lastSaveOk = false;
        lastSaveMessage = 'Никнейм не может быть пустым';
        sheetSetState?.call(() {});
        return;
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        lastSaveOk = false;
        lastSaveMessage = 'Только латиница, цифры и _';
        sheetSetState?.call(() {});
        return;
      }
      if (username.length < 3 || username.length > 24) {
        lastSaveOk = false;
        lastSaveMessage = 'Никнейм: 3–24 символа';
        sheetSetState?.call(() {});
        return;
      }
      if (displayName.isNotEmpty && displayName.length > 40) return;
      if (bio.length > 500) return;

      if (!mounted) return;
      setState(() => _savingProfile = true);
      try {
        final data = await ApiClient.instance.put(
          '/users/me',
          withAuth: true,
          body: {
            'username': username,
            'displayName': displayName.isEmpty ? null : displayName,
            'bio': bio.isEmpty ? null : bio,
            'birthDate': birthDate,
            'gender': gender,
            'avatarColorValue': avatarColorValue,
            'avatarIconCodePoint': avatarIconCodePoint,
            'allowMessagesFromNonFriends': allowMessagesFromNonFriends,
          },
        );
        if (disposed) return;
        final me = ProfileMe.fromApi(data);
        await box.put('username', me.username);
        await box.put('displayName', me.displayName);
        await box.put('bio', me.bio);
        await box.put('birthDate', me.birthDate);
        await box.put('gender', me.gender);
        await box.put('avatarColorValue', me.avatarColorValue);
        await box.put('avatarIconCodePoint', me.avatarIconCodePoint);
        await box.put('avatarUrl', me.avatarUrl);
        await box.put('allowMessagesFromNonFriends', me.allowMessagesFromNonFriends);
        lastSaveOk = true;
        lastSaveMessage = 'Все гуд';
        sheetSetState?.call(() {});
        if (mounted) setState(() {});
      } on ApiException catch (e) {
        if (disposed) return;
        lastSaveOk = false;
        lastSaveMessage = e.statusCode == 409 ? 'Логин занят' : e.message;
        sheetSetState?.call(() {});
      } catch (e) {
        if (disposed) return;
        lastSaveOk = false;
        lastSaveMessage = 'Ошибка: $e';
        sheetSetState?.call(() {});
      } finally {
        if (mounted) setState(() => _savingProfile = false);
      }
    }

    void schedulePersist() {
      if (disposed) return;
      debounce?.cancel();
      lastSaveMessage = null;
      debounce = Timer(const Duration(seconds: 1), () {
        if (disposed) return;
        // ignore: unawaited_futures
        persist();
      });
    }

    void onAnyTextChange() => schedulePersist();

    void disposeControllers() {
      if (disposed) return;
      disposed = true;
      debounce?.cancel();
      usernameController.removeListener(onAnyTextChange);
      displayNameController.removeListener(onAnyTextChange);
      bioController.removeListener(onAnyTextChange);
      usernameController.dispose();
      displayNameController.dispose();
      bioController.dispose();
    }

    usernameController.addListener(onAnyTextChange);
    displayNameController.addListener(onAnyTextChange);
    bioController.addListener(onAnyTextChange);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                sheetSetState = setSheetState;
                return ProfileEditSheetContent(
                  email: _email() ?? '',
                  avatarColorValue: avatarColorValue,
                  avatarUrl: avatarUrl,
                  savingProfile: _savingProfile,
                  lastSaveMessage: lastSaveMessage,
                  lastSaveOk: lastSaveOk,
                  usernameController: usernameController,
                  displayNameController: displayNameController,
                  bioController: bioController,
                  birthDate: birthDate,
                  gender: gender,
                  allowMessagesFromNonFriends: allowMessagesFromNonFriends,
                  scrollController: scrollController,
                  sheetPadding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  onPickAvatar: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                    );
                    if (picked == null) return;
                    try {
                      setState(() => _savingProfile = true);
                      final rawBytes = await picked.readAsBytes();
                      if (!context.mounted) return;
                      final cropped = await showDialog<Uint8List?>(
                        context: context,
                                    builder: (dialogContext) => AvatarCropDialog(bytes: rawBytes),
                      );
                      if (cropped == null) return;

                      final data = await ApiClient.instance.uploadImage(
                        '/users/me/avatar',
                        withAuth: true,
                        bytes: cropped,
                        filename: 'avatar.png',
                      );
                      final me = ProfileMe.fromApi(data);
                      await box.put('avatarUrl', me.avatarUrl);
                      if (mounted) {
                        setState(() {
                          avatarUrl = me.avatarUrl;
                        });
                        setSheetState(() {});
                      }
                    } on ApiException catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.message)),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Ошибка загрузки: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _savingProfile = false);
                    }
                  },
                  onPickBirthDate: () async {
                    final v = await showBirthDateNumericSheet(
                      context,
                      currentBirthDate: birthDate,
                    );
                    if (v == null) return;
                    setSheetState(() => birthDate = v);
                    schedulePersist();
                  },
                  onGenderChanged: (v) {
                    setSheetState(() => gender = v);
                    schedulePersist();
                  },
                  onAllowMessagesFromNonFriendsChanged: (v) {
                    setSheetState(() => allowMessagesFromNonFriends = v);
                    schedulePersist();
                  },
                  onClose: () => Navigator.of(context).pop(),
                );
              },
            );
          },
        );
      },
    );

    disposeControllers();
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await Hive.box('authBox').clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == null;
    final email = _email()?.trim();
    final username = _username()?.trim();
    final displayName = _displayName()?.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Мой профиль' : 'Профиль пользователя'),
        actions: isMe
            ? [
                IconButton(
                  tooltip: 'Изменить профиль',
                  onPressed: _savingProfile ? null : _openEditSheet,
                  icon: _savingProfile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: 'QR код профиля',
                  onPressed: _savingProfile
                      ? null
                      : () {
                          final myId = Hive.box('authBox').get('userId') as String?;
                          if (myId == null || myId.trim().isEmpty) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfileQrScreen(
                                userId: myId.trim(),
                                buildProfileScreen: (scannedId) => ProfileScreen(userId: scannedId),
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.qr_code),
                ),
                IconButton(
                  tooltip: 'Выйти',
                  onPressed: _savingProfile ? null : _confirmSignOut,
                  icon: const Icon(Icons.logout),
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _statsFuture =
                isMe ? ProfileRepository.fetchMyStats() : Future.value(const ProfileStats.empty());
            _achievementsFuture = isMe
                ? ProfileRepository.fetchMyAchievements()
                : ProfileRepository.fetchUserAchievements(widget.userId!);
          });
          if (isMe) {
            await ProfileRepository.fetchMeAndWriteHive();
          } else {
            setState(() {
              _otherUserFuture = ProfileRepository.fetchUser(widget.userId!);
              _otherStatsFuture = ProfileRepository.fetchUserStats(widget.userId!);
              _relationshipFuture = ProfileRepository.fetchRelationship(widget.userId!);
              _blockStatusFuture = ProfileRepository.fetchBlockStatus(widget.userId!);
            });
            await _otherUserFuture;
          }
          await _statsFuture;
          await _achievementsFuture;
        },
        child: isMe
            ? _buildMyProfile(context, email, username, displayName)
            : FutureBuilder<ProfileMe?>(
                future: _otherUserFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              snap.error.toString(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  _otherUserFuture = ProfileRepository.fetchUser(widget.userId!);
                                  _otherStatsFuture = ProfileRepository.fetchUserStats(widget.userId!);
                                  _relationshipFuture = ProfileRepository.fetchRelationship(widget.userId!);
                                  _blockStatusFuture = ProfileRepository.fetchBlockStatus(widget.userId!);
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final u = snap.data;
                  if (u == null) return const SizedBox.shrink();
                  final title = (u.displayName?.isNotEmpty == true)
                      ? u.displayName!
                      : (u.username?.isNotEmpty == true ? '@${u.username}' : 'Профиль');
                  final subtitle = u.username?.isNotEmpty == true ? '@${u.username}' : (u.email ?? '—');
                  final avatarUrl = u.resolvedAvatarUrl();
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: (u.avatarColorValue == null)
                                    ? Colors.blue
                                    : Color(u.avatarColorValue!),
                                backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
                                child: avatarUrl != null
                                    ? null
                                    : Icon(
                                        IconData(
                                          u.avatarIconCodePoint ?? Icons.person.codePoint,
                                          fontFamily: 'MaterialIcons',
                                        ),
                                        color: Colors.white,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 6),
                                    Text(
                                      subtitle,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<ProfileBlockStatus>(
                        future: _blockStatusFuture,
                        builder: (context, blockSnap) {
                          final b = blockSnap.data ?? const ProfileBlockStatus.empty();
                          final blocked = b.isBlocked;
                          final blockedBy = b.isBlockedBy;

                          if (blockedBy) {
                            return Card(
                              elevation: 0,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.block),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Вас заблокировали',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return FutureBuilder<ProfileRelationship>(
                            future: _relationshipFuture,
                            builder: (context, relSnap) {
                              final rel = relSnap.data ?? const ProfileRelationship.empty();
                              final canMessageBase = rel.isFriends || u.allowMessagesFromNonFriends;
                              final canMessage = canMessageBase && !blocked && !blockedBy;
                              final isFollowing = rel.isFollowing;

                              return Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: (blocked || blockedBy)
                                          ? null
                                          : () async {
                                              final messenger = ScaffoldMessenger.of(context);
                                              try {
                                                if (isFollowing) {
                                                  await ApiClient.instance.post(
                                                    '/friends/unsubscribe',
                                                    body: {'toUserId': widget.userId},
                                                    withAuth: true,
                                                  );
                                                } else {
                                                  await ApiClient.instance.post(
                                                    '/friends/subscribe',
                                                    body: {'toUserId': widget.userId},
                                                    withAuth: true,
                                                  );
                                                }
                                                if (!mounted) return;
                                                setState(() {
                                                  _relationshipFuture = ProfileRepository.fetchRelationship(widget.userId!);
                                                  _blockStatusFuture = ProfileRepository.fetchBlockStatus(widget.userId!);
                                                });
                                              } on ApiException catch (e) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(SnackBar(content: Text(e.message)));
                                              } catch (e) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(content: Text('Ошибка: $e')),
                                                );
                                              }
                                            },
                                      child: Text(isFollowing ? 'Отписаться' : 'Подписаться'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton.filledTonal(
                                    tooltip: canMessage ? 'Сообщение' : 'Нельзя написать',
                                    onPressed: canMessage
                                        ? () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => DirectChatScreen(
                                                  userId: widget.userId!,
                                                  title: title,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.message),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    tooltip: 'Действия',
                                    onSelected: (v) async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      try {
                                        if (v == 'block') {
                                          await ApiClient.instance.post(
                                            '/blocks/block',
                                            body: {'userId': widget.userId},
                                            withAuth: true,
                                          );
                                        } else if (v == 'unblock') {
                                          await ApiClient.instance.post(
                                            '/blocks/unblock',
                                            body: {'userId': widget.userId},
                                            withAuth: true,
                                          );
                                        }
                                        if (!mounted) return;
                                        setState(() {
                                          _blockStatusFuture = ProfileRepository.fetchBlockStatus(widget.userId!);
                                          _relationshipFuture = ProfileRepository.fetchRelationship(widget.userId!);
                                        });
                                      } on ApiException catch (e) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(SnackBar(content: Text(e.message)));
                                      } catch (e) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (!blocked)
                                        const PopupMenuItem(
                                          value: 'block',
                                          child: Text('Заблокировать'),
                                        )
                                      else
                                        const PopupMenuItem(
                                          value: 'unblock',
                                          child: Text('Разблокировать'),
                                        ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<ProfileBlockStatus>(
                        future: _blockStatusFuture,
                        builder: (context, bSnap) {
                          final blockedBy = (bSnap.data ?? const ProfileBlockStatus.empty()).isBlockedBy;
                          if (blockedBy) return const SizedBox.shrink();
                          return Column(
                            children: [
                              FutureBuilder<ProfileStats>(
                                future: _otherStatsFuture,
                                builder: (context, statsSnap) {
                                  if (statsSnap.connectionState == ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.only(top: 8, bottom: 8),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  final stats = statsSnap.data ?? const ProfileStats.empty();
                                  return Column(
                                    children: [
                                      StatTile(
                                        title: 'Сколько встреч я создал',
                                        value: stats.createdEventsCount,
                                        icon: Icons.add_box,
                                      ),
                                      const SizedBox(height: 8),
                                      StatTile(
                                        title: 'Сколько пришли суммарно на мои встречи',
                                        value: stats.totalGoingToMyEventsCount,
                                        icon: Icons.groups,
                                      ),
                                      const SizedBox(height: 8),
                                      StatTile(
                                        title: 'На сколько встреч пришёл я',
                                        value: stats.eventsIGoingCount,
                                        icon: Icons.check_circle,
                                      ),
                                      const SizedBox(height: 8),
                                      StatTile(
                                        title: 'Подписчики',
                                        value: stats.followersCount,
                                        icon: Icons.person_add,
                                      ),
                                      const SizedBox(height: 16),
                                      FutureBuilder<List<ProfileAchievement>>(
                                        future: _achievementsFuture,
                                        builder: (context, aSnap) {
                                          if (aSnap.connectionState == ConnectionState.waiting) {
                                            return const AchievementSection(isLoading: true, items: []);
                                          }
                                          if (aSnap.hasError) {
                                            return AchievementSection(
                                              error: aSnap.error,
                                              items: const [],
                                              onRetry: () => setState(() {
                                                _achievementsFuture =
                                                    ProfileRepository.fetchUserAchievements(widget.userId!);
                                              }),
                                            );
                                          }
                                          return AchievementSection(items: aSnap.data ?? const []);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Text('О себе', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  (u.bio?.isNotEmpty == true) ? u.bio! : '—',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildMyProfile(
    BuildContext context,
    String? email,
    String? username,
    String? displayName,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _avatarColorOrDefault(),
                  backgroundImage: resolveAvatarUrl(_avatarUrl()) == null
                      ? null
                      : NetworkImage(resolveAvatarUrl(_avatarUrl())!),
                  child: resolveAvatarUrl(_avatarUrl()) != null
                      ? null
                      : const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName?.isNotEmpty == true
                            ? displayName!
                            : (username?.isNotEmpty == true ? '@$username' : 'Профиль'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email?.isNotEmpty == true ? email! : '—',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<ProfileStats>(
          future: _statsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Не удалось загрузить статистику',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snap.error.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _statsFuture = ProfileRepository.fetchMyStats();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              );
            }

            final stats = snap.data ?? const ProfileStats.empty();
            return Column(
              children: [
                StatTile(
                  title: 'Сколько встреч я создал',
                  value: stats.createdEventsCount,
                  icon: Icons.add_box,
                ),
                const SizedBox(height: 8),
                StatTile(
                  title: 'Сколько пришли суммарно на мои встречи',
                  value: stats.totalGoingToMyEventsCount,
                  icon: Icons.groups,
                ),
                const SizedBox(height: 8),
                StatTile(
                  title: 'На сколько встреч пришёл я',
                  value: stats.eventsIGoingCount,
                  icon: Icons.check_circle,
                ),
                const SizedBox(height: 8),
                StatTile(
                  title: 'Подписчики',
                  value: stats.followersCount,
                  icon: Icons.person_add,
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<ProfileAchievement>>(
                  future: _achievementsFuture,
                  builder: (context, aSnap) {
                    if (aSnap.connectionState == ConnectionState.waiting) {
                      return const AchievementSection(isLoading: true, items: []);
                    }
                    if (aSnap.hasError) {
                      return AchievementSection(
                        error: aSnap.error,
                        items: const [],
                        onRetry: () => setState(() {
                          _achievementsFuture = ProfileRepository.fetchMyAchievements();
                        }),
                      );
                    }
                    return AchievementSection(items: aSnap.data ?? const []);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Потяните вниз, чтобы обновить',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text('О себе', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          (_bio()?.trim().isNotEmpty == true) ? _bio()!.trim() : '—',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Выйти из аккаунта'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

// Helpers moved to separate files:
// - `ProfileMe`, `ProfileStats` in `profile_models.dart`
// - avatar helpers in `profile_avatar.dart`
// - `StatTile` in `widgets/stat_tile.dart`

