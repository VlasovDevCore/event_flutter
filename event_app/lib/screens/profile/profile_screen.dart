import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../utils/formatters.dart';
import '../../widgets/profile/stat_badge.dart';
import '../../widgets/profile/stat_card.dart';
import '../../widgets/profile/blocked_card.dart';
import '../../widgets/profile/relationship_buttons.dart';
import '../auth/auth_screen.dart';
import 'profile_models.dart';
import 'profile_qr_screen.dart';
import 'profile_repository.dart';
import 'profile_social_models.dart';
import 'widgets/achievement_section.dart';
import 'widgets/birth_date_numeric_sheet.dart';
import 'profile_cover_gradient.dart';
import 'widgets/profile_avatar_header.dart';
import 'widgets/profile_cover_edit_sheet.dart';
import 'widgets/profile_edit_sheet_content.dart';
import 'profile_achievement.dart';
import 'widgets/profile_actions_bar.dart';
import 'profile_edit_logic.dart';
import 'profile_dialogs.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});

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
  late Future<void> _profileBootstrapFuture;
  bool _savingProfile = false;
  bool _reloadingMeProfileAfterEdit = false;
  bool _isBlocked = false;

  void _assignDataFutures() {
    final isMe = widget.userId == null;
    _statsFuture = isMe
        ? ProfileRepository.fetchMyStats()
        : Future.value(const ProfileStats.empty());
    _otherUserFuture = isMe
        ? Future.value(null)
        : ProfileRepository.fetchUser(widget.userId!);
    _otherStatsFuture = isMe
        ? Future.value(const ProfileStats.empty())
        : ProfileRepository.fetchUserStats(widget.userId!);
    _relationshipFuture = isMe
        ? Future.value(const ProfileRelationship.empty())
        : ProfileRepository.fetchRelationship(widget.userId!);
    _blockStatusFuture = isMe
        ? Future.value(const ProfileBlockStatus.empty())
        : ProfileRepository.fetchBlockStatus(widget.userId!);
    _achievementsFuture = isMe
        ? ProfileRepository.fetchMyAchievements()
        : ProfileRepository.fetchUserAchievements(widget.userId!);
  }

  Future<void> _computeProfileBootstrapFuture() {
    final isMe = widget.userId == null;
    if (isMe) {
      return Future.wait<Object?>([
        _statsFuture,
        _achievementsFuture,
      ]).then((_) {});
    }
    return Future.wait<Object?>([
      _otherUserFuture,
      _otherStatsFuture,
      _relationshipFuture,
      _blockStatusFuture,
      _achievementsFuture,
    ]).then((_) {});
  }

  @override
  void initState() {
    super.initState();
    _assignDataFutures();
    _profileBootstrapFuture = _computeProfileBootstrapFuture();
  }

  String? _email() => Hive.box('authBox').get('email') as String?;
  String? _username() => Hive.box('authBox').get('username') as String?;
  String? _displayName() => Hive.box('authBox').get('displayName') as String?;
  String? _bio() => Hive.box('authBox').get('bio') as String?;
  String? _birthDate() => Hive.box('authBox').get('birthDate') as String?;
  String? _gender() => Hive.box('authBox').get('gender') as String?;
  String? _avatarUrl() => Hive.box('authBox').get('avatarUrl') as String?;
  bool _allowMessagesFromNonFriends() =>
      (Hive.box('authBox').get('allowMessagesFromNonFriends') as bool?) ?? true;

  DateTime? _createdAtFromHive() {
    final raw = Hive.box('authBox').get('createdAt');
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  List<String>? _coverGradientColorsFromHive() {
    final raw = Hive.box('authBox').get('coverGradientColors');
    if (raw is List && raw.length == 3) {
      return raw.map((e) => e.toString()).toList();
    }
    return null;
  }

  ProfileMe _meProfileFromHive() {
    final status = (Hive.box('authBox').get('status') as int?) ?? 1;
    return ProfileMe(
      email: _email(),
      username: _username(),
      status: status,
      displayName: _displayName(),
      bio: _bio(),
      birthDate: _birthDate(),
      gender: _gender(),
      avatarUrl: _avatarUrl(),
      allowMessagesFromNonFriends: _allowMessagesFromNonFriends(),
      coverGradientColors: _coverGradientColorsFromHive(),
      createdAt: _createdAtFromHive(),
    );
  }

  Future<void> _openCoverEditSheet() async {
    final initial = _coverGradientColorsFromHive();
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
          setState(() {});
        } finally {
          if (mounted) setState(() => _savingProfile = false);
        }
      },
    );
  }

  Future<void> _reloadRelationshipData() async {
    if (!mounted) return;
    setState(() {
      _relationshipFuture = ProfileRepository.fetchRelationship(widget.userId!);
      _blockStatusFuture = ProfileRepository.fetchBlockStatus(widget.userId!);
    });
  }

  Future<void> _openEditSheet({
    String? usernameDraft,
    String? displayNameDraft,
    String? bioDraft,
    String? birthDateDraft,
    String? genderDraft,
    String? avatarUrlDraft,
    bool? allowMessagesFromNonFriendsDraft,
  }) async {
    final box = Hive.box('authBox');

    // Оригинальный username
    final String originalUsername = usernameDraft ?? _username() ?? '';

    final usernameController = TextEditingController(text: originalUsername);
    final displayNameController = TextEditingController(
      text: displayNameDraft ?? _displayName() ?? '',
    );
    final bioController = TextEditingController(text: bioDraft ?? _bio() ?? '');

    String? birthDate = birthDateDraft ?? _birthDate();
    String? gender = genderDraft ?? _gender();
    String? avatarUrl = avatarUrlDraft ?? _avatarUrl();
    bool allowMessagesFromNonFriends =
        allowMessagesFromNonFriendsDraft ?? _allowMessagesFromNonFriends();

    // Статусы проверки логина
    bool _isCheckingUsername = false;
    bool?
    _usernameAvailable; // null = не проверен, true = свободен, false = занят
    Timer? _usernameCheckTimer;

    bool disposed = false;
    void Function(void Function())? sheetSetState;
    String? lastSaveMessage;
    bool lastSaveOk = true;

    /// Проверяет доступность логина с дебаунсом
    Future<void> _checkUsernameAvailability() async {
      final username = usernameController.text.trim();

      // Если username равен оригинальному, не показываем иконку и не проверяем
      if (username == originalUsername) {
        sheetSetState?.call(() {
          _usernameAvailable = true;
          _isCheckingUsername = false;
        });
        return;
      }

      // Отменяем предыдущий таймер
      _usernameCheckTimer?.cancel();

      // Устанавливаем таймер для дебаунса (500мс)
      _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () async {
        if (disposed || !mounted) return;

        // Если логин пустой, считаем его валидным
        if (username.isEmpty) {
          sheetSetState?.call(() {
            _usernameAvailable = true;
            _isCheckingUsername = false;
          });
          return;
        }

        sheetSetState?.call(() => _isCheckingUsername = true);

        final available = await ProfileEditLogic.checkUsernameAvailable(
          username,
        );

        if (!disposed && mounted) {
          sheetSetState?.call(() {
            _usernameAvailable = available;
            _isCheckingUsername = false;
          });
        }
      });
    }

    Widget? _getUsernameStatusIcon() {
      final currentUsername = usernameController.text.trim();

      // Не показываем иконку, если ник не изменился
      if (currentUsername == originalUsername) {
        return null;
      }

      if (_isCheckingUsername) {
        return const UnconstrainedBox(
          child: Padding(
            padding: EdgeInsets.only(right: 4),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          ),
        );
      }
      if (_usernameAvailable == true) {
        return const UnconstrainedBox(
          child: Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.check_circle, color: Colors.green, size: 16),
          ),
        );
      }
      if (_usernameAvailable == false) {
        return const UnconstrainedBox(
          child: Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.close, color: Colors.red, size: 16),
          ),
        );
      }
      return null;
    }

    bool validateDraft() {
      final username = usernameController.text.trim();
      final displayName = displayNameController.text.trim();
      final bio = bioController.text.trim();

      // Проверяем, что логин не пустой
      if (username.isEmpty) {
        lastSaveOk = false;
        lastSaveMessage = 'Никнейм не может быть пустым';
        return false;
      }

      // Если username изменился и занят - ошибка
      if (username != originalUsername && _usernameAvailable == false) {
        lastSaveOk = false;
        lastSaveMessage = 'Никнейм уже занят';
        return false;
      }

      final (isValid, errorMsg) = ProfileEditLogic.validateProfile(
        username: username,
        displayName: displayName,
        bio: bio,
      );

      if (!isValid) {
        lastSaveOk = false;
        lastSaveMessage = errorMsg;
        return false;
      }
      lastSaveOk = true;
      lastSaveMessage = null;
      return true;
    }

    // Запоминаем исходные значения, чтобы понять — были ли изменения при
    // закрытии шторки свайпом (sheetResult == null).
    final String originalUsernameValue = usernameController.text.trim();
    final String originalDisplayName = displayNameController.text.trim();
    final String originalBio = bioController.text.trim();
    final String? originalBirthDate = birthDate;
    final String? originalGender = gender;
    final bool originalAllowMessagesFromNonFriends =
        allowMessagesFromNonFriends;

    Future<void> saveDraftToServer() async {
      if (disposed || !mounted) return;
      final username = usernameController.text.trim();
      final displayName = displayNameController.text.trim();
      final bio = bioController.text.trim();

      final messenger = ScaffoldMessenger.of(context);
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
        await box.put('avatarUrl', me.avatarUrl);
        await box.put(
          'allowMessagesFromNonFriends',
          me.allowMessagesFromNonFriends,
        );
        if (me.coverGradientColors != null &&
            me.coverGradientColors!.length == 3) {
          await box.put('coverGradientColors', me.coverGradientColors);
        } else {
          await box.delete('coverGradientColors');
        }
        if (mounted) setState(() {});
      } on ApiException catch (e) {
        if (disposed || !mounted) return;
        if (e.statusCode == 409) {
          // Логин занят - показываем ошибку в UI поля ввода
          lastSaveMessage = 'Логин уже занят';
          lastSaveOk = false;
          sheetSetState?.call(() {});
        } else {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (e) {
        if (disposed || !mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      } finally {
        if (mounted) setState(() => _savingProfile = false);
      }
    }

    void clearValidationHint() {
      if (lastSaveMessage == null) return;
      lastSaveMessage = null;
      lastSaveOk = true;
      sheetSetState?.call(() {});
    }

    /// Снимаем слушатели и ссылку на setState шторки сразу после закрытия модалки,
    /// чтобы IME/фокус не вызывали setState уже размонтированного [StatefulBuilder].
    void detachEditSheetListeners() {
      sheetSetState = null;
      _usernameCheckTimer?.cancel();
      usernameController.removeListener(_checkUsernameAvailability);
      usernameController.removeListener(clearValidationHint);
      displayNameController.removeListener(clearValidationHint);
      bioController.removeListener(clearValidationHint);
    }

    void disposeEditControllers() {
      if (disposed) return;
      disposed = true;
      usernameController.dispose();
      displayNameController.dispose();
      bioController.dispose();
    }

    usernameController.addListener(_checkUsernameAvailability);
    usernameController.addListener(clearValidationHint);
    displayNameController.addListener(clearValidationHint);
    bioController.addListener(clearValidationHint);

    final sheetResult = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        if (!mounted) return const SizedBox.shrink();

        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 1.0,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setSheetState) {
                  sheetSetState = setSheetState;
                  return GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                    },
                    onVerticalDragStart: (_) {
                      FocusScope.of(context).unfocus();
                    },
                    child: ProfileEditSheetContent(
                      email: _email() ?? '',
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
                      usernameStatusIcon: _getUsernameStatusIcon(),
                      isUsernameValid: _usernameAvailable == true,
                      scrollController: scrollController,
                      sheetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      onClose: () => Navigator.of(context).pop(false),
                      onSave: () async {
                        if (!validateDraft()) {
                          sheetSetState?.call(() {});
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
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
                          final croppedBytes =
                              await ProfileEditLogic.autoCropAvatarSquare(
                                rawBytes,
                              );
                          if (croppedBytes == null) return;
                          if (!context.mounted) return;

                          final data = await ApiClient.instance.uploadImage(
                            '/users/me/avatar',
                            withAuth: true,
                            bytes: croppedBytes,
                            filename: 'avatar.png',
                          );
                          final me = ProfileMe.fromApi(data);
                          await box.put('avatarUrl', me.avatarUrl);
                          if (mounted) {
                            setState(() => avatarUrl = me.avatarUrl);
                            sheetSetState?.call(() {});
                          }
                        } on ApiException catch (e) {
                          if (mounted)
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                        } catch (e) {
                          if (mounted)
                            messenger.showSnackBar(
                              SnackBar(content: Text('Ошибка загрузки: $e')),
                            );
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
                        sheetSetState?.call(() {
                          birthDate = v;
                          lastSaveMessage = null;
                        });
                      },
                      onGenderChanged: (v) => sheetSetState?.call(() {
                        gender = v;
                        lastSaveMessage = null;
                      }),
                      onAllowMessagesFromNonFriendsChanged: (v) =>
                          sheetSetState?.call(() {
                            allowMessagesFromNonFriends = v;
                            lastSaveMessage = null;
                          }),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );

    detachEditSheetListeners();

    final draftChanged =
        usernameController.text.trim() != originalUsernameValue ||
        displayNameController.text.trim() != originalDisplayName ||
        bioController.text.trim() != originalBio ||
        birthDate != originalBirthDate ||
        gender != originalGender ||
        allowMessagesFromNonFriends != originalAllowMessagesFromNonFriends;

    // Сохраняем только при явном нажатии кнопки "Сохранить" (sheetResult == true).
    bool willSave = sheetResult == true;
    if (willSave && mounted) {
      setState(() => _reloadingMeProfileAfterEdit = true);
    }
    try {
      if (willSave) {
        await saveDraftToServer();
      }
    } finally {
      if (mounted && _reloadingMeProfileAfterEdit) {
        setState(() => _reloadingMeProfileAfterEdit = false);
      }
      // [TextField] отцепляется от контроллера не мгновенно; dispose сразу после pop
      // даёт assert _dependents.isEmpty на [TextEditingController].
      final done = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        disposeEditControllers();
        if (!done.isCompleted) done.complete();
      });
      await done.future;
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await ProfileDialogs.confirmSignOut(context);
    if (ok != true || !mounted) return;
    await Hive.box('authBox').clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
      (route) => false,
    );
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
      setState(() {
        _isBlocked = true;
      });
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
      setState(() {
        _isBlocked = false;
      });
      await _reloadRelationshipData();
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  /// Тот же полноэкранный индикатор, что при первом открытии профиля (без скачка контента).
  Widget _profileScrollableLoadingBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: h > 0 ? h : 400,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == null;

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: FutureBuilder<void>(
        future: _profileBootstrapFuture,
        builder: (context, bootSnap) {
          if (bootSnap.connectionState != ConnectionState.done) {
            return _profileScrollableLoadingBody();
          }
          if (bootSnap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.85,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            bootSnap.error.toString(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _assignDataFutures();
                                _profileBootstrapFuture =
                                    _computeProfileBootstrapFuture();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return FutureBuilder<ProfileMe?>(
            future: isMe
                ? Future.value(_meProfileFromHive())
                : _otherUserFuture,
            builder: (context, snap) {
              if (isMe && _reloadingMeProfileAfterEdit) {
                return _profileScrollableLoadingBody();
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return _profileScrollableLoadingBody();
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
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            if (!isMe) {
                              setState(() {
                                _otherUserFuture = ProfileRepository.fetchUser(
                                  widget.userId!,
                                );
                                _otherStatsFuture =
                                    ProfileRepository.fetchUserStats(
                                      widget.userId!,
                                    );
                                _relationshipFuture =
                                    ProfileRepository.fetchRelationship(
                                      widget.userId!,
                                    );
                                _blockStatusFuture =
                                    ProfileRepository.fetchBlockStatus(
                                      widget.userId!,
                                    );
                              });
                            }
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
                  : 'Пользователь';
              final subtitle = u.username?.isNotEmpty == true
                  ? '@${u.username}'
                  : (u.email ?? '—');
              final avatarUrl = u.resolvedAvatarUrl();

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ProfileAvatarHeader(
                      headerHeight: 110,
                      avatarUrl: avatarUrl,
                      headerGradientColors: coverGradientColorsFromHex(
                        u.coverGradientColors,
                      ),
                      actionsBar: ProfileActionsBar(
                        onBackPressed: () => Navigator.of(context).pop(),
                        isMe: isMe,
                        onCoverEditPressed: isMe ? _openCoverEditSheet : null,
                        onEditPressed: isMe ? _openEditSheet : null,
                        onQrPressed: () {
                          final myId =
                              Hive.box('authBox').get('userId') as String?;
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
                                    u.coverGradientColors ??
                                    _coverGradientColorsFromHive(),
                                buildProfileScreen: (scannedId) =>
                                    ProfileScreen(userId: scannedId),
                              ),
                            ),
                          );
                        },
                        onLogoutPressed: isMe ? _confirmSignOut : null,
                        onBlockPressed: !isMe ? _handleBlock : null,
                        onUnblockPressed: !isMe ? _handleUnblock : null,
                        isBlocked: _isBlocked,
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
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
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
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey.shade400,
                                      fontFamily: 'Inter',
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<ProfileStats>(
                          future: isMe ? _statsFuture : _otherStatsFuture,
                          builder: (context, statsSnap) {
                            if (statsSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 40,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }

                            final stats =
                                statsSnap.data ?? const ProfileStats.empty();

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(left: 16),
                                  width: 120,
                                  child: StatBadge(
                                    count: stats.followersCount,
                                    label: 'подписчиков',
                                  ),
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
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<ProfileBlockStatus>(
                    future: isMe
                        ? Future.value(const ProfileBlockStatus.empty())
                        : _blockStatusFuture,
                    builder: (context, blockSnap) {
                      final b =
                          blockSnap.data ?? const ProfileBlockStatus.empty();
                      final blocked = b.isBlocked;
                      final blockedBy = b.isBlockedBy;

                      if (blockSnap.hasData && !isMe && mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _isBlocked != blocked) {
                            setState(() {
                              _isBlocked = blocked;
                            });
                          }
                        });
                      }

                      Widget actionsWidget = const SizedBox.shrink();
                      if (!isMe) {
                        if (blockedBy) {
                          actionsWidget = const BlockedCard();
                        } else {
                          actionsWidget = FutureBuilder<ProfileRelationship>(
                            future: _relationshipFuture,
                            builder: (context, relSnap) {
                              final rel =
                                  relSnap.data ??
                                  const ProfileRelationship.empty();
                              final canMessageBase =
                                  rel.isFriends ||
                                  u.allowMessagesFromNonFriends;
                              final canMessage =
                                  canMessageBase && !blocked && !blockedBy;
                              final isFollowing = rel.isFollowing;

                              return RelationshipButtons(
                                userId: widget.userId!,
                                title: title,
                                isFollowing: isFollowing,
                                canMessage: canMessage,
                                isUserBlocked: blocked,
                                onFollowingChanged: _reloadRelationshipData,
                              );
                            },
                          );
                        }
                      }

                      final showStats = isMe || !blockedBy;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                actionsWidget,
                                const SizedBox(height: 16),
                                const Divider(
                                  color: Color.fromARGB(144, 44, 44, 44),
                                  height: 1,
                                  thickness: 1,
                                ),
                                const SizedBox(height: 16),
                                if (!blockedBy) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'О себе',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 19,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      u.bio?.isNotEmpty == true
                                          ? u.bio!
                                          : (isMe
                                                ? 'Вы ещё ничего не рассказали о себе.'
                                                : 'Пользователь ничего не рассказал о себе.'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontFamily: 'Inter',
                                            color: u.bio?.isNotEmpty == true
                                                ? Colors.white
                                                : Colors.grey.shade500,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ),
                          if (showStats) ...[
                            SizedBox(
                              height: 100,
                              child: FutureBuilder<ProfileStats>(
                                future: isMe ? _statsFuture : _otherStatsFuture,
                                builder: (context, statsSnap) {
                                  if (statsSnap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    );
                                  }
                                  final stats =
                                      statsSnap.data ??
                                      const ProfileStats.empty();

                                  return ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: 4,
                                    itemBuilder: (context, index) {
                                      final items = [
                                        StatCard(
                                          value: stats.createdEventsCount,
                                          label: 'Создал встреч',
                                        ),
                                        StatCard(
                                          value:
                                              stats.totalGoingToMyEventsCount,
                                          label: 'Посетителей',
                                        ),
                                        StatCard(
                                          value: stats.eventsIGoingCount,
                                          label: 'Посетил встреч',
                                        ),
                                        StatCard(
                                          value: stats.followersCount,
                                          label: 'Подписчиков',
                                        ),
                                      ];
                                      return StatCard(
                                        value: items[index].value,
                                        label: items[index].label,
                                        isFirst: index == 0,
                                        isLast: index == 3,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: FutureBuilder<List<ProfileAchievement>>(
                                future: _achievementsFuture,
                                builder: (context, aSnap) {
                                  if (aSnap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const AchievementSection(
                                      isLoading: true,
                                      items: [],
                                    );
                                  }
                                  if (aSnap.hasError) {
                                    return AchievementSection(
                                      error: aSnap.error,
                                      items: const [],
                                      onRetry: () => setState(() {
                                        _achievementsFuture = isMe
                                            ? ProfileRepository.fetchMyAchievements()
                                            : ProfileRepository.fetchUserAchievements(
                                                widget.userId!,
                                              );
                                      }),
                                    );
                                  }
                                  return AchievementSection(
                                    items: aSnap.data ?? const [],
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                withUsTenureLine(u.createdAt, isMe),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Color.fromARGB(255, 77, 77, 77),
                                      fontFamily: 'Inter',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
