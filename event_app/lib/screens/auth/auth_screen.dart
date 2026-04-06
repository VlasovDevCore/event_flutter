import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/api_client.dart';
import '../../services/push_notifications_service.dart';
import '../home/home_screen.dart';

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
  final _usernameController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
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

      print(
        'Profile loaded successfully: displayName=${response['displayName']}, avatarUrl=${response['avatarUrl']}',
      );
    } catch (e) {
      print('Error loading full profile: $e');
      // Не показываем ошибку пользователю, так как вход уже выполнен успешно
      // Просто логируем
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    setState(() {
      _loading = true;
    });

    try {
      final client = ApiClient.instance;
      final path = _isLogin ? '/auth/login' : '/auth/register';
      final response = await client.post(
        path,
        body: {
          'email': email,
          'password': password,
          if (!_isLogin && username.isNotEmpty) 'username': username,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ошибка сети')));
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLogin ? 'Вход' : 'Регистрация',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите email';
                              }
                              if (!value.contains('@')) {
                                return 'Некорректный email';
                              }
                              return null;
                            },
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Логин (username)',
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (_isLogin) return null;
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Введите логин';
                                if (v.length < 3) return 'Минимум 3 символа';
                                if (v.length > 24) return 'Максимум 24 символа';
                                final ok = RegExp(
                                  r'^[a-zA-Z0-9_]+$',
                                ).hasMatch(v);
                                if (!ok) return 'Только латиница, цифры и _';
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Пароль',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите пароль';
                              }
                              if (value.length < 6) {
                                return 'Минимум 6 символов';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isLogin ? 'Войти' : 'Зарегистрироваться',
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _usernameController.clear();
                              });
                            },
                            child: Text(
                              _isLogin
                                  ? 'Нет аккаунта? Зарегистрируйтесь'
                                  : 'Уже есть аккаунт? Войти',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
