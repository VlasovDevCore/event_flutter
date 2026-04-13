import 'package:flutter/material.dart';

import 'auth_colors.dart';

class AuthToggle extends StatelessWidget {
  const AuthToggle({
    super.key,
    required this.isLogin,
    required this.onToggle,
    this.disabled = false,
  });

  final bool isLogin;
  final VoidCallback onToggle;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final label = isLogin
        ? 'Нет аккаунта? Зарегистрируйтесь'
        : 'Уже есть аккаунт? Войти';

    return TextButton(
      onPressed: disabled ? null : onToggle,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          color: AuthColors.subtitle,
        ),
      ),
    );
  }
}

