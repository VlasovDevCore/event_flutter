import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/api_client.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_colors.dart';
import 'widgets/auth_error_sheet.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_text_field.dart';

class VerifyEmailCodeScreen extends StatefulWidget {
  const VerifyEmailCodeScreen({super.key});

  @override
  State<VerifyEmailCodeScreen> createState() => _VerifyEmailCodeScreenState();
}

class _VerifyEmailCodeScreenState extends State<VerifyEmailCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sending = false;
  bool _changingEmail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendCode();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.post('/auth/send-verification-code', withAuth: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен на email')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: 'Не удалось отправить код',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: 'Не удалось отправить код',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post(
        '/auth/verify-email-code',
        withAuth: true,
        body: {'code': _code.text.trim()},
      );
      await Hive.box('authBox').put('status', 1);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: 'Не удалось подтвердить',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      await showAuthErrorSheet(
        context,
        title: 'Не удалось подтвердить',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isValidEmail(String email) {
    final e = email.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e);
  }

  Future<bool> _changeEmail() async {
    final next = _email.text.trim();
    if (!_isValidEmail(next)) {
      await showAuthErrorSheet(
        context,
        title: 'Некорректный email',
        message: 'Введите корректный адрес электронной почты.',
      );
      return false;
    }

    setState(() => _changingEmail = true);
    try {
      final res = await ApiClient.instance.post(
        '/auth/change-email',
        withAuth: true,
        body: {'email': next},
      );
      final newEmail = res['email']?.toString() ?? next;
      final token = res['token']?.toString();
      final box = Hive.box('authBox');
      await box.put('email', newEmail);
      await box.put('status', 0);
      if (token != null && token.isNotEmpty) {
        await box.put('token', token);
      }
      if (!mounted) return false;
      setState(() {
        _code.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email изменён. Код отправлен.')),
      );
      // code was already sent by /auth/change-email
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      await showAuthErrorSheet(
        context,
        title: 'Не удалось изменить email',
        message: e.message,
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      await showAuthErrorSheet(
        context,
        title: 'Не удалось изменить email',
        message: e.toString(),
      );
      return false;
    } finally {
      if (mounted) setState(() => _changingEmail = false);
    }
  }

  Future<void> _openChangeEmailSheet() async {
    final box = Hive.box('authBox');
    final current = (box.get('email') as String?) ?? '';
    _email.text = current;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AuthColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const Text(
                'Изменить email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _email,
                label: 'Email',
                hint: 'example@mail.com',
                enabled: !_changingEmail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _changingEmail ? null : _changeEmail(),
                validator: (_) => null,
              ),
              const SizedBox(height: 14),
              AuthPrimaryButton(
                label: 'Сохранить и отправить код',
                loading: _changingEmail,
                onPressed: () async {
                  final ok = await _changeEmail();
                  if (!ctx.mounted) return;
                  if (ok) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF222222)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _changingEmail ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = (Hive.box('authBox').get('email') as String?) ?? 'ваш email';

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
                    title: 'Подтверждение email',
                    subtitle: 'Мы отправили код на $email. Введите 6 цифр ниже.',
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
                            controller: _code,
                            label: 'Код',
                            hint: '000000',
                            enabled: !_loading,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _loading ? null : _verify(),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'Введите код';
                              if (!RegExp(r'^\d{6}$').hasMatch(v)) {
                                return 'Нужен код из 6 цифр';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          AuthPrimaryButton(
                            label: 'Подтвердить',
                            loading: _loading,
                            onPressed: _verify,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: (_loading || _sending) ? null : _sendCode,
                            child: Text(
                              _sending ? 'Отправляем…' : 'Отправить код ещё раз',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                color: AuthColors.subtitle,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: (_loading || _sending || _changingEmail)
                                ? null
                                : _openChangeEmailSheet,
                            child: const Text(
                              'Изменить email',
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
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(false),
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

