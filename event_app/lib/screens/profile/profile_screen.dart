import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../chat/direct_chat_screen.dart';
import 'profile_avatar.dart';
import 'profile_models.dart';
import 'profile_qr_screen.dart';
import 'widgets/profile_edit_sheet_content.dart';
import 'widgets/avatar_crop_dialog.dart';
import 'widgets/stat_tile.dart';

class _Relationship {
  const _Relationship({
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isFriends,
  });

  const _Relationship.empty()
      : isFollowing = false,
        isFollowedBy = false,
        isFriends = false;

  final bool isFollowing;
  final bool isFollowedBy;
  final bool isFriends;
}

class _BlockStatus {
  const _BlockStatus({
    required this.isBlocked,
    required this.isBlockedBy,
  });

  const _BlockStatus.empty()
      : isBlocked = false,
        isBlockedBy = false;

  final bool isBlocked;
  final bool isBlockedBy;
}

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
  late Future<_Relationship> _relationshipFuture;
  late Future<_BlockStatus> _blockStatusFuture;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.userId == null ? _loadStats() : Future.value(const ProfileStats.empty());
    _otherUserFuture = widget.userId == null ? Future.value(null) : _loadOtherUser(widget.userId!);
    _otherStatsFuture = widget.userId == null ? Future.value(const ProfileStats.empty()) : _loadUserStats(widget.userId!);
    _relationshipFuture =
        widget.userId == null ? Future.value(const _Relationship.empty()) : _loadRelationship(widget.userId!);
    _blockStatusFuture =
        widget.userId == null ? Future.value(const _BlockStatus.empty()) : _loadBlockStatus(widget.userId!);
    if (widget.userId == null) {
      _loadMe();
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

  Future<ProfileMe> _loadMe() async {
    final data = await ApiClient.instance.get('/users/me', withAuth: true);
    final me = ProfileMe.fromApi(data);

    final box = Hive.box('authBox');
    await box.put('username', me.username);
    await box.put('email', me.email);
    await box.put('status', me.status);
    await box.put('displayName', me.displayName);
    await box.put('bio', me.bio);
    await box.put('birthDate', me.birthDate);
    await box.put('gender', me.gender);
    await box.put('avatarColorValue', me.avatarColorValue);
    await box.put('avatarIconCodePoint', me.avatarIconCodePoint);
    await box.put('avatarUrl', me.avatarUrl);
    await box.put('allowMessagesFromNonFriends', me.allowMessagesFromNonFriends);
    return me;
  }

  Future<ProfileStats> _loadStats() async {
    final data = await ApiClient.instance.get('/users/me/stats', withAuth: true);
    return ProfileStats(
      createdEventsCount: (data['created_events_count'] as num?)?.toInt() ?? 0,
      totalGoingToMyEventsCount: (data['total_going_to_my_events_count'] as num?)?.toInt() ?? 0,
      eventsIGoingCount: (data['events_i_going_count'] as num?)?.toInt() ?? 0,
      followersCount: (data['followers_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ProfileMe> _loadOtherUser(String userId) async {
    final data = await ApiClient.instance.get('/users/$userId');
    return ProfileMe.fromApi(data);
  }

  Future<ProfileStats> _loadUserStats(String userId) async {
    final data = await ApiClient.instance.get('/users/$userId/stats');
    return ProfileStats(
      createdEventsCount: (data['created_events_count'] as num?)?.toInt() ?? 0,
      totalGoingToMyEventsCount: (data['total_going_to_my_events_count'] as num?)?.toInt() ?? 0,
      eventsIGoingCount: (data['events_i_going_count'] as num?)?.toInt() ?? 0,
      followersCount: (data['followers_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<_Relationship> _loadRelationship(String userId) async {
    final data = await ApiClient.instance.get('/friends/relationship/$userId', withAuth: true);
    return _Relationship(
      isFollowing: data['isFollowing'] == true,
      isFollowedBy: data['isFollowedBy'] == true,
      isFriends: data['isFriends'] == true,
    );
  }

  Future<_BlockStatus> _loadBlockStatus(String userId) async {
    final data = await ApiClient.instance.get('/blocks/status/$userId', withAuth: true);
    return _BlockStatus(
      isBlocked: data['isBlocked'] == true,
      isBlockedBy: data['isBlockedBy'] == true,
    );
  }

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

    Future<void> openBirthDateNumericSheet({
      required BuildContext sheetContext,
      required void Function(String?) setBirthDate,
    }) async {
      final current = birthDate;
      final y = (current != null && current.length >= 4) ? current.substring(0, 4) : '';
      final m = (current != null && current.length >= 7) ? current.substring(5, 7) : '';
      final d = (current != null && current.length >= 10) ? current.substring(8, 10) : '';

      final dayCtrl = TextEditingController(text: d);
      final monthCtrl = TextEditingController(text: m);
      final yearCtrl = TextEditingController(text: y);

      final res = await showModalBottomSheet<String?>(
        context: sheetContext,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Дата рождения',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dayCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'День',
                          hintText: '01',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: monthCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Месяц',
                          hintText: '12',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: yearCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Год',
                          hintText: '1999',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    final day = int.tryParse(dayCtrl.text.trim());
                    final month = int.tryParse(monthCtrl.text.trim());
                    final year = int.tryParse(yearCtrl.text.trim());
                    if (day == null || month == null || year == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Введите день, месяц и год')),
                      );
                      return;
                    }
                    if (year < 1900 || year > DateTime.now().year) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Некорректный год')),
                      );
                      return;
                    }
                    if (month < 1 || month > 12) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Некорректный месяц')),
                      );
                      return;
                    }
                    if (day < 1 || day > 31) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Некорректный день')),
                      );
                      return;
                    }
                    final dt = DateTime(year, month, day);
                    if (dt.year != year || dt.month != month || dt.day != day) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Такой даты не существует')),
                      );
                      return;
                    }
                    if (dt.isAfter(DateTime.now())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Дата не может быть в будущем')),
                      );
                      return;
                    }
                    final s =
                        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                    Navigator.of(context).pop(s);
                  },
                  child: const Text('Сохранить'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

      dayCtrl.dispose();
      monthCtrl.dispose();
      yearCtrl.dispose();

      setBirthDate(res);
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
                    await openBirthDateNumericSheet(
                      sheetContext: context,
                      setBirthDate: (v) {
                        if (v == null) return;
                        setSheetState(() => birthDate = v);
                        schedulePersist();
                      },
                    );
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
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _statsFuture = isMe ? _loadStats() : Future.value(const ProfileStats.empty());
          });
          if (isMe) {
            await _loadMe();
          } else {
            setState(() {
              _otherUserFuture = _loadOtherUser(widget.userId!);
              _otherStatsFuture = _loadUserStats(widget.userId!);
              _relationshipFuture = _loadRelationship(widget.userId!);
              _blockStatusFuture = _loadBlockStatus(widget.userId!);
            });
            await _otherUserFuture;
          }
          await _statsFuture;
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
                                  _otherUserFuture = _loadOtherUser(widget.userId!);
                                  _otherStatsFuture = _loadUserStats(widget.userId!);
                                  _relationshipFuture = _loadRelationship(widget.userId!);
                                  _blockStatusFuture = _loadBlockStatus(widget.userId!);
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
                      FutureBuilder<_BlockStatus>(
                        future: _blockStatusFuture,
                        builder: (context, blockSnap) {
                          final b = blockSnap.data ?? const _BlockStatus.empty();
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

                          return FutureBuilder<_Relationship>(
                            future: _relationshipFuture,
                            builder: (context, relSnap) {
                              final rel = relSnap.data ?? const _Relationship.empty();
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
                                                  _relationshipFuture = _loadRelationship(widget.userId!);
                                                  _blockStatusFuture = _loadBlockStatus(widget.userId!);
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
                                          _blockStatusFuture = _loadBlockStatus(widget.userId!);
                                          _relationshipFuture = _loadRelationship(widget.userId!);
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
                      FutureBuilder<_BlockStatus>(
                        future: _blockStatusFuture,
                        builder: (context, bSnap) {
                          final blockedBy = (bSnap.data ?? const _BlockStatus.empty()).isBlockedBy;
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
                          _statsFuture = _loadStats();
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
      ],
    );
  }
}

// Helpers moved to separate files:
// - `ProfileMe`, `ProfileStats` in `profile_models.dart`
// - avatar helpers in `profile_avatar.dart`
// - `StatTile` in `widgets/stat_tile.dart`

