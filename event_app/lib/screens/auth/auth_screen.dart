import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/api_client.dart';
import '../../services/push_notifications_service.dart';
import '../home/home_screen.dart';
import 'auth_profile_setup_screen.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_colors.dart';
import 'widgets/auth_error_sheet.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/auth_toggle.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool? _emailAvailable;
  bool _checkingEmail = false;
  Timer? _emailDebounce;
  bool _passwordObscured = true;
  String _passwordDraft = '';

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final e = email.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e);
  }

  String? _validatePassword(String password) {
    final p = password;
    if (p.length < 8) return 'Минимум 8 символов';
    if (!RegExp(r'^[\x21-\x7E]+$').hasMatch(p)) {
      return 'Только латиница, цифры и символы (без пробелов/кириллицы)';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(p)) return 'Добавьте английскую букву';
    if (!RegExp(r'[0-9]').hasMatch(p)) return 'Добавьте цифру';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(p)) return 'Добавьте спецсимвол';
    return null;
  }

  bool _hasAsciiNoSpace(String s) => RegExp(r'^[\x21-\x7E]+$').hasMatch(s);
  bool _hasLetter(String s) => RegExp(r'[A-Za-z]').hasMatch(s);
  bool _hasDigit(String s) => RegExp(r'[0-9]').hasMatch(s);
  bool _hasSymbol(String s) => RegExp(r'[^A-Za-z0-9]').hasMatch(s);
  bool _hasMinLen(String s) => s.length >= 8;

  void _onEmailChanged(String value) {
    if (_isLogin) return;
    _emailDebounce?.cancel();
    final v = value.trim();
    if (v.isEmpty || !_isValidEmail(v)) {
      setState(() {
        _emailAvailable = null;
        _checkingEmail = false;
      });
      return;
    }
    setState(() => _checkingEmail = true);
    _emailDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        await ApiClient.instance.get('/auth/check-email?email=$v');
        if (!mounted) return;
        setState(() {
          _emailAvailable = true;
          _checkingEmail = false;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _emailAvailable = e.statusCode == 409 ? false : null;
          _checkingEmail = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _emailAvailable = null;
          _checkingEmail = false;
        });
      }
    });
  }

  // Новый метод для загрузки полного профиля пользователя
  Future<void> _loadFullUserProfile() async {
    try {
      final response = await ApiClient.instance.get(
        '/users/me',
        withAuth: true,
      );

      final authBox = Hive.box('authBox');

      // Сохраняем все поля профиля
      await authBox.put('displayName', response['displayName'] as String?);
      await authBox.put('bio', response['bio'] as String?);
      await authBox.put('avatarUrl', response['avatarUrl'] as String?);
      await authBox.put('birthDate', response['birthDate'] as String?);
      await authBox.put('gender', response['gender'] as String?);
      await authBox.put(
        'allowMessagesFromNonFriends',
        response['allowMessagesFromNonFriends'] ?? true,
      );

      // Сохраняем градиент обложки, если есть
      if (response['coverGradientColors'] != null) {
        await authBox.put(
          'coverGradientColors',
          response['coverGradientColors'],
        );
      }

    } catch (e) {
      // Не показываем ошибку пользователю, так как вход уже выполнен успешно
      // Просто логируем
      debugPrint('Error loading full profile: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_isLogin) {
      if (_checkingEmail) return;
      if (_emailAvailable == false) {
        await showAuthErrorSheet(
          context,
          title: 'Этот email занят',
          message: 'Этот email уже зарегистрирован. Попробуйте войти.',
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AuthProfileSetupScreen(email: email, password: password),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final client = ApiClient.instance;
      final path = '/auth/login';
      final response = await client.post(
        path,
        body: {
          'email': email,
          'password': password,
        },
      );

      final authBox = Hive.box('authBox');
      final user = response['user'] as Map<String, dynamic>;
      final token = response['token'] as String;

      // Сохраняем базовые данные
      await authBox.put('userId', user['id'] as String);
      await authBox.put('email', user['email'] as String);
      await authBox.put('username', user['username'] as String?);
      await authBox.put('status', (user['status'] as num?)?.toInt() ?? 1);
      final createdRaw = user['created_at'] ?? user['createdAt'];
      if (createdRaw is String && createdRaw.isNotEmpty) {
        await authBox.put('createdAt', createdRaw);
      }
      await authBox.put('token', token);
      await authBox.put('isLoggedIn', true);

      // Если при регистрации пришли дополнительные данные, сохраняем их
      if (user['displayName'] != null) {
        await authBox.put('displayName', user['displayName']);
      }
      if (user['avatarUrl'] != null) {
        await authBox.put('avatarUrl', user['avatarUrl']);
      }
      if (user['bio'] != null) {
        await authBox.put('bio', user['bio']);
      }

      // Загружаем полный профиль с сервера
      await _loadFullUserProfile();

      await PushNotificationsService.instance.registerTokenAfterLogin();

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: _isLogin ? 'Не удалось войти' : 'Не удалось зарегистрироваться',
        message: e.message,
      );
    } catch (_) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: 'Ошибка сети',
        message: 'Проверьте интернет и попробуйте ещё раз.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
                  AuthHeader(
                    title: _isLogin ? 'Вход' : 'Регистрация',
                    subtitle: _isLogin
                        ? 'Войдите, чтобы создавать встречи и общаться.'
                        : 'Создайте аккаунт, чтобы начать пользоваться приложением.',
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
                          AuthTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'example@mail.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            enabled: !_loading,
                            onChanged: _onEmailChanged,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите email';
                              }
                              if (!_isValidEmail(value)) {
                                return 'Некорректный email';
                              }
                              return null;
                            },
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (_checkingEmail)
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
                                    _emailAvailable == true
                                        ? Icons.check_circle
                                        : _emailAvailable == false
                                            ? Icons.error
                                            : Icons.info_outline,
                                    size: 16,
                                    color: _emailAvailable == true
                                        ? AuthColors.success
                                        : _emailAvailable == false
                                            ? AuthColors.danger
                                            : AuthColors.subtitle,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _checkingEmail
                                        ? 'Проверяем email…'
                                        : _emailAvailable == true
                                            ? 'Email свободен'
                                            : _emailAvailable == false
                                                ? 'Email уже зарегистрирован'
                                                : 'Введите корректный email',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: _emailAvailable == true
                                          ? AuthColors.success
                                          : _emailAvailable == false
                                              ? AuthColors.danger
                                              : AuthColors.subtitle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          AuthTextField(
                            controller: _passwordController,
                            label: 'Пароль',
                            hint: 'Введите пароль',
                            obscureText: _passwordObscured,
                            enabled: !_loading,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _loading ? null : _submit(),
                            onChanged: (v) {
                              if (_isLogin) return;
                              setState(() => _passwordDraft = v);
                            },
                            suffixIcon: IconButton(
                              tooltip:
                                  _passwordObscured ? 'Показать пароль' : 'Скрыть пароль',
                              onPressed: _loading
                                  ? null
                                  : () => setState(
                                        () => _passwordObscured = !_passwordObscured,
                                      ),
                              icon: Icon(
                                _passwordObscured
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white70,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите пароль';
                              }
                              return _isLogin ? null : _validatePassword(value);
                            },
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 10),
                            _PasswordHint(
                              okMinLen: _hasMinLen(_passwordDraft),
                              okAsciiNoSpace: _hasAsciiNoSpace(_passwordDraft),
                              okComplex: _hasLetter(_passwordDraft) &&
                                  _hasDigit(_passwordDraft) &&
                                  _hasSymbol(_passwordDraft),
                            ),
                          ],
                          const SizedBox(height: 16),
                          AuthPrimaryButton(
                            label: _isLogin ? 'Войти' : 'Зарегистрироваться',
                            loading: _loading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AuthToggle(
                    isLogin: _isLogin,
                    disabled: _loading,
                    onToggle: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _emailAvailable = null;
                        _checkingEmail = false;
                        _passwordDraft = '';
                        _passwordController.clear();
                      });
                    },
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

class _PasswordHint extends StatelessWidget {
  const _PasswordHint({
    required this.okMinLen,
    required this.okAsciiNoSpace,
    required this.okComplex,
  });

  final bool okMinLen;
  final bool okAsciiNoSpace;
  final bool okComplex;

  Widget _row(String text, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: ok ? Colors.white70 : const Color(0xFF6A6A6A),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: ok ? Colors.white70 : const Color(0xFF8C8C8C),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Пароль должен содержать:',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFBFC4CE),
            ),
          ),
          const SizedBox(height: 8),
          _row('Минимум 8 символов', okMinLen),
          const SizedBox(height: 6),
          _row('Только латиница/цифры/символы (без пробелов)', okAsciiNoSpace),
          const SizedBox(height: 6),
          _row('Буква + цифра + спецсимвол', okComplex),
        ],
      ),
    );
  }
}
