import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../auth/auth_screen.dart';
import '../chat/direct_chat_screen.dart';
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

String _formatNumber(int number) {
  if (number >= 1_000_000) {
    final millions = number / 1_000_000;
    if (millions == millions.roundToDouble()) {
      return '${millions.round()} млн';
    } else {
      return '${millions.toStringAsFixed(1)} млн';
    }
  } else {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]} ',
    );
  }
}

String _dneyRu(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 19) return 'дней';
  switch (n % 10) {
    case 1:
      return 'день';
    case 2:
    case 3:
    case 4:
      return 'дня';
    default:
      return 'дней';
  }
}

String _nedelRu(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 19) return 'недель';
  switch (n % 10) {
    case 1:
      return 'неделю';
    case 2:
    case 3:
    case 4:
      return 'недели';
    default:
      return 'недель';
  }
}

String _mesyacevRu(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 19) return 'месяцев';
  switch (n % 10) {
    case 1:
      return 'месяц';
    case 2:
    case 3:
    case 4:
      return 'месяца';
    default:
      return 'месяцев';
  }
}

String _letRu(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 19) return 'лет';
  switch (n % 10) {
    case 1:
      return 'год';
    case 2:
    case 3:
    case 4:
      return 'года';
    default:
      return 'лет';
  }
}

/// «Вы с нами уже …» по [createdAt] регистрации.
String _withUsTenureLine(DateTime? createdAt, bool isMe) {
  if (createdAt == null) {
    return 'Дата регистрации неизвестна';
  }
  final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(start).inDays;
  if (days <= 0) {
    return isMe ? 'Вы с нами с сегодняшнего дня' : 'С нами с сегодняшнего дня';
  }
  String wrap(String s) {
    if (isMe) return 'Вы $s';
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }
  if (days < 7) {
    final d = _formatNumber(days);
    return wrap('с нами уже $d ${_dneyRu(days)}');
  }
  if (days < 30) {
    final w = days ~/ 7;
    final ws = _formatNumber(w);
    return wrap('с нами уже $ws ${_nedelRu(w)}');
  }
  if (days < 365) {
    final m = days ~/ 30;
    final ms = _formatNumber(m);
    if (m < 1) {
      final w = days ~/ 7;
      return wrap('с нами уже ${_formatNumber(w)} ${_nedelRu(w)}');
    }
    return wrap('с нами уже $ms ${_mesyacevRu(m)}');
  }
  final y = days ~/ 365;
  final ys = _formatNumber(y);
  return wrap('с нами уже $ys ${_letRu(y)}');
}

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
        ProfileRepository.fetchMeAndWriteHive(),
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
      initial != null && initial.length == 3 ? initial : kDefaultCoverGradientHex,
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

    Future<Uint8List?> autoCropAvatarSquare(Uint8List bytes) async {
      final decodedCompleter = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) => decodedCompleter.complete(img));
      final img = await decodedCompleter.future;

      final minSide = (img.width < img.height ? img.width : img.height).toDouble();
      final srcLeft = (img.width.toDouble() - minSide) / 2.0;
      final srcTop = (img.height.toDouble() - minSide) / 2.0;

      const outputPx = 512;
      final src = ui.Rect.fromLTWH(srcLeft, srcTop, minSide, minSide);
      final dst = ui.Rect.fromLTWH(0, 0, outputPx.toDouble(), outputPx.toDouble());

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..isAntiAlias = true;

      canvas.save();
      // Просто квадратный crop по центру. Закругления будут только на UI.
      canvas.drawImageRect(img, src, dst, paint);
      canvas.restore();

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(outputPx, outputPx);
      final data = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    }

    final usernameController = TextEditingController(
      text: usernameDraft ?? _username() ?? '',
    );
    final displayNameController = TextEditingController(
      text: displayNameDraft ?? _displayName() ?? '',
    );
    final bioController = TextEditingController(text: bioDraft ?? _bio() ?? '');

    String? birthDate = birthDateDraft ?? _birthDate();
    String? gender = genderDraft ?? _gender();
    String? avatarUrl = avatarUrlDraft ?? _avatarUrl();
    bool allowMessagesFromNonFriends =
        allowMessagesFromNonFriendsDraft ?? _allowMessagesFromNonFriends();

    bool disposed = false;
    void Function(void Function())? sheetSetState;
    String? lastSaveMessage;
    bool lastSaveOk = true;

    bool validateDraft() {
      final username = usernameController.text.trim();
      final displayName = displayNameController.text.trim();
      final bio = bioController.text.trim();

      if (username.isEmpty) {
        lastSaveOk = false;
        lastSaveMessage = 'Никнейм не может быть пустым';
        return false;
      }
      // Разрешаем: латиница, цифры, '.' и '_'.
      // Русские буквы и прочие символы запрещены.
      if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
        lastSaveOk = false;
        lastSaveMessage = 'Только латиница, цифры и символы . или _';
        return false;
      }
      if (username.length < 3 || username.length > 20) {
        lastSaveOk = false;
        lastSaveMessage = 'Никнейм: 3–20 символов';
        return false;
      }
      if (displayName.isNotEmpty && displayName.length > 40) {
        lastSaveOk = false;
        lastSaveMessage = 'Имя: не больше 40 символов';
        return false;
      }
      if (bio.length > 280) {
        lastSaveOk = false;
        lastSaveMessage = 'О себе: не больше 280 символов';
        return false;
      }
      lastSaveOk = true;
      lastSaveMessage = null;
      return true;
    }

    // Запоминаем исходные значения, чтобы понять — были ли изменения при
    // закрытии шторки свайпом (sheetResult == null).
    final String originalUsername = usernameController.text.trim();
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
        if (me.coverGradientColors != null && me.coverGradientColors!.length == 3) {
          await box.put('coverGradientColors', me.coverGradientColors);
        } else {
          await box.delete('coverGradientColors');
        }
        if (mounted) setState(() {});
      } on ApiException catch (e) {
        if (disposed || !mounted) return;
        if (e.statusCode == 409) {
          final usernameValue = usernameController.text.trim();
          final displayNameValue = displayNameController.text.trim();
          final bioValue = bioController.text.trim();

          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: const Color(0xFF161616),
            showDragHandle: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (sheetContext) {
              final theme = Theme.of(sheetContext);
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Не удалось сохранить',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Логин занят',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          if (!mounted) return;
                          await _openEditSheet(
                            usernameDraft: usernameValue,
                            displayNameDraft: displayNameValue,
                            bioDraft: bioValue,
                            birthDateDraft: birthDate,
                            genderDraft: gender,
                            avatarUrlDraft: avatarUrl,
                            allowMessagesFromNonFriendsDraft:
                                allowMessagesFromNonFriends,
                          );
                        },
                        child: const Text('Вернуться обратно'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF222222)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Закрыть'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(e.message)),
          );
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
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
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
                  return ProfileEditSheetContent(
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
                    scrollController: scrollController,
                    sheetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                      final croppedBytes = await autoCropAvatarSquare(rawBytes);
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
                    setSheetState(() {
                      birthDate = v;
                      lastSaveMessage = null;
                    });
                  },
                  onGenderChanged: (v) {
                    setSheetState(() {
                      gender = v;
                      lastSaveMessage = null;
                    });
                  },
                  onAllowMessagesFromNonFriendsChanged: (v) {
                    setSheetState(() {
                      allowMessagesFromNonFriends = v;
                      lastSaveMessage = null;
                    });
                  },
                  onClose: () {
                    if (!validateDraft()) {
                      sheetSetState?.call(() {});
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                );
              },
            );
          },
        ),
        );
      },
    );

    detachEditSheetListeners();

    final draftChanged = usernameController.text.trim() != originalUsername ||
        displayNameController.text.trim() != originalDisplayName ||
        bioController.text.trim() != originalBio ||
        birthDate != originalBirthDate ||
        gender != originalGender ||
        allowMessagesFromNonFriends != originalAllowMessagesFromNonFriends;

    // Сохраняем:
    // - при явном закрытии кнопкой (sheetResult == true)
    // - при свайпе вниз (sheetResult == null) только если были реальные изменения
    //   (иначе профиль не должен "дергаться").
    bool willSave = false;
    if (sheetResult == true) {
      willSave = true;
    } else if (sheetResult == null && draftChanged) {
      willSave = validateDraft();
    }
    try {
      if (willSave) {
        await saveDraftToServer();
      } else if (mounted && sheetResult == false) {
        final msg = lastSaveMessage ?? 'Проверьте поля профиля';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
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
        _blockStatusFuture = ProfileRepository.fetchBlockStatus(widget.userId!);
        _relationshipFuture = ProfileRepository.fetchRelationship(
          widget.userId!,
        );
      });
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
        _blockStatusFuture = ProfileRepository.fetchBlockStatus(widget.userId!);
        _relationshipFuture = ProfileRepository.fetchRelationship(
          widget.userId!,
        );
      });
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
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
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
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _statsFuture = isMe
                ? ProfileRepository.fetchMyStats()
                : Future.value(const ProfileStats.empty());
            _achievementsFuture = isMe
                ? ProfileRepository.fetchMyAchievements()
                : ProfileRepository.fetchUserAchievements(widget.userId!);
          });
          if (isMe) {
            await ProfileRepository.fetchMeAndWriteHive();
          } else {
            setState(() {
              _otherUserFuture = ProfileRepository.fetchUser(widget.userId!);
              _otherStatsFuture = ProfileRepository.fetchUserStats(
                widget.userId!,
              );
              _relationshipFuture = ProfileRepository.fetchRelationship(
                widget.userId!,
              );
              _blockStatusFuture = ProfileRepository.fetchBlockStatus(
                widget.userId!,
              );
            });
            await _otherUserFuture;
          }
          await _statsFuture;
          await _achievementsFuture;
        },
        child: FutureBuilder<void>(
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
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white70,
                                  ),
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
              future: isMe ? Future.value(_meProfileFromHive()) : _otherUserFuture,
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                                  u.coverGradientColors ?? _coverGradientColorsFromHive(),
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
                                child: _StatBadge(
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
                                child: _StatBadge(
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
                        actionsWidget = Card(
                          elevation: 0,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.block),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Вас заблокировали',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        actionsWidget = FutureBuilder<ProfileRelationship>(
                          future: _relationshipFuture,
                          builder: (context, relSnap) {
                            final rel =
                                relSnap.data ??
                                const ProfileRelationship.empty();
                            final canMessageBase =
                                rel.isFriends || u.allowMessagesFromNonFriends;
                            final canMessage =
                                canMessageBase && !blocked && !blockedBy;
                            final isFollowing = rel.isFollowing;

                            // Определяем, заблокирован ли пользователь
                            final isUserBlocked = blocked;

                            return Row(
                              children: [
                                Expanded(
                                  child: Opacity(
                                    opacity: isUserBlocked ? 0.5 : 1.0,
                                    child: FilledButton(
                                      onPressed: (blocked || blockedBy)
                                          ? null
                                          : () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              try {
                                                if (isFollowing) {
                                                  await ApiClient.instance.post(
                                                    '/friends/unsubscribe',
                                                    body: {
                                                      'toUserId': widget.userId,
                                                    },
                                                    withAuth: true,
                                                  );
                                                } else {
                                                  await ApiClient.instance.post(
                                                    '/friends/subscribe',
                                                    body: {
                                                      'toUserId': widget.userId,
                                                    },
                                                    withAuth: true,
                                                  );
                                                }
                                                if (!mounted) return;
                                                setState(() {
                                                  _relationshipFuture =
                                                      ProfileRepository.fetchRelationship(
                                                        widget.userId!,
                                                      );
                                                  _blockStatusFuture =
                                                      ProfileRepository.fetchBlockStatus(
                                                        widget.userId!,
                                                      );
                                                });
                                              } on ApiException catch (e) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(e.message),
                                                  ),
                                                );
                                              } catch (e) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text('Ошибка: $e'),
                                                  ),
                                                );
                                              }
                                            },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: isFollowing
                                            ? const Color.fromARGB(
                                                255,
                                                44,
                                                44,
                                                44,
                                              )
                                            : const Color.fromARGB(
                                                255,
                                                0,
                                                122,
                                                255,
                                              ),
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: Colors
                                            .white, // Белый текст при disabled
                                        disabledBackgroundColor: isFollowing
                                            ? const Color.fromARGB(
                                                255,
                                                44,
                                                44,
                                                44,
                                              )
                                            : const Color.fromARGB(
                                                255,
                                                0,
                                                122,
                                                255,
                                              ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isFollowing
                                                ? Icons.person_remove
                                                : Icons.person_add,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isFollowing
                                                ? 'Отписаться'
                                                : 'Подписаться',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Opacity(
                                    opacity: isUserBlocked ? 0.5 : 1.0,
                                    child: FilledButton(
                                      onPressed: canMessage
                                          ? () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      DirectChatScreen(
                                                        userId: widget.userId!,
                                                        title: title,
                                                      ),
                                                ),
                                              );
                                            }
                                          : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(
                                          255,
                                          44,
                                          44,
                                          44,
                                        ),
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor: Colors
                                            .white, // Белый текст при disabled
                                        disabledBackgroundColor:
                                            const Color.fromARGB(
                                              255,
                                              44,
                                              44,
                                              44,
                                            ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.message, size: 18),
                                          SizedBox(width: 8),
                                          Text('Сообщение'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                                      _StatCard(
                                        value: stats.createdEventsCount,
                                        label: 'Создал встреч',
                                      ),
                                      _StatCard(
                                        value: stats.totalGoingToMyEventsCount,
                                        label: 'Посетителей',
                                      ),
                                      _StatCard(
                                        value: stats.eventsIGoingCount,
                                        label: 'Посетил встреч',
                                      ),
                                      _StatCard(
                                        value: stats.followersCount,
                                        label: 'Подписчиков',
                                      ),
                                    ];
                                    return _StatCard(
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _withUsTenureLine(u.createdAt, isMe),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
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
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _formatNumber(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.isFirst = false,
    this.isLast = false,
  });

  final int value;
  final String label;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: EdgeInsets.only(left: isFirst ? 16 : 0, right: isLast ? 16 : 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 28, 28, 28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatNumber(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
