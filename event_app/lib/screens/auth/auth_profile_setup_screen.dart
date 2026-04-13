import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

import '../../services/api_client.dart';
import '../../services/push_notifications_service.dart';
import '../home/home_screen.dart';
import '../profile/profile_repository.dart';
import '../profile/profile_edit_logic.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_colors.dart';
import 'widgets/auth_error_sheet.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_text_field.dart';

class AuthProfileSetupScreen extends StatefulWidget {
  const AuthProfileSetupScreen({
    super.key,
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  State<AuthProfileSetupScreen> createState() => _AuthProfileSetupScreenState();
}

class _AuthProfileSetupScreenState extends State<AuthProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  bool _saving = false;
  bool _picking = false;
  String? _avatarUrl;
  Uint8List? _localAvatarBytes;
  bool? _usernameAvailable;
  bool _checkingUsername = false;
  Timer? _usernameDebounce;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final v = value.trim();
    if (v.isEmpty) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }
    // quick local validation first
    if (v.length < 3 ||
        v.length > 24 ||
        !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        await ApiClient.instance.get(
          '/users/check-username',
          query: {'username': v},
          withAuth: false,
        );
        if (!mounted) return;
        setState(() {
          _usernameAvailable = true;
          _checkingUsername = false;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _usernameAvailable = e.statusCode == 409 ? false : null;
          _checkingUsername = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _usernameAvailable = null;
          _checkingUsername = false;
        });
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_checkingUsername) return;
    if (_usernameAvailable == false) {
      await showAuthErrorSheet(
        context,
        title: 'Логин занят',
        message: 'Этот логин уже занят. Выберите другой.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await ApiClient.instance.post(
        '/auth/register',
        body: {
          'email': widget.email.trim(),
          'password': widget.password,
          'username': _username.text.trim(),
          'displayName': _displayName.text.trim(),
        },
      );

      final authBox = Hive.box('authBox');
      final user = response['user'] as Map<String, dynamic>;
      final token = response['token'] as String;

      await authBox.put('userId', user['id'] as String);
      await authBox.put('email', user['email'] as String);
      await authBox.put('username', user['username'] as String?);
      await authBox.put('status', (user['status'] as num?)?.toInt() ?? 0);
      final createdRaw = user['created_at'] ?? user['createdAt'];
      if (createdRaw is String && createdRaw.isNotEmpty) {
        await authBox.put('createdAt', createdRaw);
      }
      await authBox.put('token', token);
      await authBox.put('isLoggedIn', true);

      if (_localAvatarBytes != null) {
        try {
          await ApiClient.instance.uploadImage(
            '/users/me/avatar',
            withAuth: true,
            bytes: _localAvatarBytes!,
            filename: 'avatar.png',
          );
        } catch (_) {}
      }

      await ProfileRepository.fetchMeAndWriteHive();
      await PushNotificationsService.instance.registerTokenAfterLogin();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (r) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = () {
        if (e.statusCode == 409) {
          final m = e.message.toLowerCase();
          if (m.contains('email')) return 'Этот email уже зарегистрирован. Попробуйте войти.';
          if (m.contains('логин') || m.contains('username')) return 'Этот логин уже занят. Выберите другой.';
          return 'Аккаунт с такими данными уже существует.';
        }
        return e.message;
      }();
      await showAuthErrorSheet(
        context,
        title: 'Не удалось зарегистрироваться',
        message: msg,
      );
    } catch (e) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: 'Ошибка',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  Future<void> _pickAvatar() async {
    if (_saving || _picking) return;
    setState(() => _picking = true);
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) {
        if (mounted) setState(() => _picking = false);
        return;
      }

      final rawBytes = await picked.readAsBytes();
      final croppedBytes = await ProfileEditLogic.autoCropAvatarSquare(rawBytes);
      if (croppedBytes == null) {
        if (mounted) setState(() => _picking = false);
        return;
      }
      if (!mounted) return;
      setState(() => _localAvatarBytes = croppedBytes);
      // Upload happens after step 2 completes (we need JWT).
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: 'Не удалось загрузить аватар',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: 'Не удалось загрузить аватар',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.bg,
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AuthHeader(
                    title: 'Профиль',
                    subtitle: 'Заполните основные данные — можно пропустить и сделать позже.',
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: AuthColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1E1E1E)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: (_saving || _picking) ? null : _pickAvatar,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F0F0F),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AuthColors.border),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: () {
                                    if (_localAvatarBytes != null) {
                                      return Image.memory(
                                        _localAvatarBytes!,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    final full = ApiClient.getFullImageUrl(_avatarUrl);
                                    if (full != null && full.trim().isNotEmpty) {
                                      return Image.network(
                                        full,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.person, color: Colors.white54),
                                      );
                                    }
                                    return const Icon(Icons.person, color: Colors.white54);
                                  }(),
                                ),
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: _picking
                                        ? const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.black,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Colors.black,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          AuthTextField(
                            controller: _username,
                            label: 'Логин',
                            hint: 'username',
                            enabled: !_saving,
                            textInputAction: TextInputAction.next,
                            onChanged: _onUsernameChanged,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'Введите логин';
                              if (v.length < 3) return 'Минимум 3 символа';
                              if (v.length > 24) return 'Максимум 24 символа';
                              final ok = RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v);
                              if (!ok) return 'Только латиница, цифры и _';
                              if (_usernameAvailable == false) return 'Логин уже занят';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (_checkingUsername)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                )
                              else
                                Icon(
                                  _usernameAvailable == true
                                      ? Icons.check_circle
                                      : _usernameAvailable == false
                                          ? Icons.error
                                          : Icons.info_outline,
                                  size: 16,
                                  color: _usernameAvailable == true
                                      ? AuthColors.success
                                      : _usernameAvailable == false
                                          ? AuthColors.danger
                                          : AuthColors.subtitle,
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _checkingUsername
                                      ? 'Проверяем логин…'
                                      : _usernameAvailable == true
                                          ? 'Логин свободен'
                                          : _usernameAvailable == false
                                              ? 'Логин уже занят'
                                              : 'Латиница, цифры и _ (3–24)',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: _usernameAvailable == true
                                        ? AuthColors.success
                                        : _usernameAvailable == false
                                            ? AuthColors.danger
                                            : AuthColors.subtitle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AuthTextField(
                            controller: _displayName,
                            label: 'Имя',
                            hint: 'Как показывать другим',
                            enabled: !_saving,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _saving ? null : _save(),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'Введите имя';
                              if (v.length > 40) return 'Максимум 40 символов';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AuthPrimaryButton(
                            label: 'Сохранить',
                            loading: _saving,
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _saving ? null : _goBack,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Назад',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: AuthColors.subtitle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

