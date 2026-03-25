import 'package:flutter/material.dart';

import '../profile_avatar.dart';

const Color _fieldBg = Color(0xFF1F1F1F);
const Color _fieldBorder = Color(0xFF222222);

String? _formatBirthDate(String? birthDate) {
  if (birthDate == null) return null;
  final v = birthDate.trim();
  if (v.isEmpty) return null;

  // Ожидаем ISO: YYYY-MM-DD -> DD/MM/YYYY
  if (v.length >= 10 && v.contains('-')) {
    final y = v.substring(0, 4);
    final m = v.substring(5, 7);
    final d = v.substring(8, 10);
    return '$d/$m/$y';
  }

  return v;
}

class _BirthDateField extends StatefulWidget {
  const _BirthDateField({
    required this.birthDate,
    required this.onPickBirthDate,
  });

  final String? birthDate;
  final Future<void> Function() onPickBirthDate;

  @override
  State<_BirthDateField> createState() => _BirthDateFieldState();
}

class _BirthDateFieldState extends State<_BirthDateField> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final formatted = _formatBirthDate(widget.birthDate);
    final text = formatted ?? 'дд/мм/гггг';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Дата рождения',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async => widget.onPickBirthDate(),
          onHighlightChanged: (value) => setState(() => isPressed = value),
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            isFocused: isPressed,
            decoration: InputDecoration(
              filled: true,
              fillColor: _fieldBg,
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _fieldBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: _fieldBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: formatted == null ? Colors.white54 : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StyledTextField extends StatefulWidget {
  const _StyledTextField({
    required this.labelText,
    required this.controller,
    this.hintText,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.labelTrailing,
    this.statusIcon,
  });

  final String labelText;
  final TextEditingController controller;
  final String? hintText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final Widget? labelTrailing;
  final Widget? statusIcon;

  @override
  State<_StyledTextField> createState() => _StyledTextFieldState();
}

class _StyledTextFieldState extends State<_StyledTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) return;

    // Добавляем проверку на mounted
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Проверяем mounted и hasFocus перед выполнением
      if (!mounted || !_focusNode.hasFocus) return;

      final ctx = _focusNode.context;
      if (ctx == null) return;

      try {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      } catch (e) {
        // Игнорируем ошибки при сворачивании
        debugPrint('Scroll error: $e');
      }
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Добавляем try-catch для MediaQuery
    double scrollPadBottom = 24;
    try {
      final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;
      scrollPadBottom = keyboardBottom + 24;
    } catch (e) {
      // Если ошибка, используем значение по умолчанию
      scrollPadBottom = 24;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.labelText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.labelTrailing != null) widget.labelTrailing!,
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          focusNode: _focusNode,
          enabled: widget.enabled,
          controller: widget.controller,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) {
                return const SizedBox.shrink();
              },
          textAlign: TextAlign.start,
          textAlignVertical: widget.maxLines > 1
              ? TextAlignVertical.top
              : TextAlignVertical.center,
          scrollPadding: EdgeInsets.fromLTRB(16, 24, 16, scrollPadBottom),
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: _fieldBg,
            hintStyle: const TextStyle(color: Colors.white54),
            suffixIcon: widget.statusIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: widget.statusIcon,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _fieldBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white, width: 2),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            border: OutlineInputBorder(
              borderSide: const BorderSide(color: _fieldBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GenderDropdownField extends StatefulWidget {
  const _GenderDropdownField({
    required this.gender,
    required this.onGenderChanged,
    required this.enabled,
  });

  final String? gender;
  final ValueChanged<String?> onGenderChanged;
  final bool enabled;

  @override
  State<_GenderDropdownField> createState() => _GenderDropdownFieldState();
}

class _GenderDropdownFieldState extends State<_GenderDropdownField> {
  OverlayEntry? _entry;
  final LayerLink _layerLink = LayerLink();

  bool _isOpen = false;

  double _fieldWidth = 0;
  double _fieldHeight = 0;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  String? _displayGender(String? v) {
    if (v == null || v.isEmpty) return null;
    switch (v) {
      case 'male':
        return 'Мужской';
      case 'female':
        return 'Женский';
      case 'other':
        return 'Другое';
      default:
        return v;
    }
  }

  Future<void> _openMenu() async {
    if (!widget.enabled) return;
    if (_entry != null) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _fieldWidth = renderBox.size.width;
    _fieldHeight = renderBox.size.height;
    const radius = 12.0;

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _entry?.remove();
                  _entry = null;
                  if (mounted) setState(() => _isOpen = false);
                },
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              offset: Offset(0, _fieldHeight + 6),
              showWhenUnlinked: false,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: _fieldWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(color: const Color(0xFF222222)),
                      ),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          _MenuItem(
                            text: 'Мужской',
                            onTap: () {
                              _entry?.remove();
                              _entry = null;
                              widget.onGenderChanged('male');
                              if (mounted) setState(() => _isOpen = false);
                            },
                          ),
                          _MenuItem(
                            text: 'Женский',
                            onTap: () {
                              _entry?.remove();
                              _entry = null;
                              widget.onGenderChanged('female');
                              if (mounted) setState(() => _isOpen = false);
                            },
                          ),
                          _MenuItem(
                            text: 'Другое',
                            onTap: () {
                              _entry?.remove();
                              _entry = null;
                              widget.onGenderChanged('other');
                              if (mounted) setState(() => _isOpen = false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
    if (mounted) setState(() => _isOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final text = _displayGender(widget.gender) ?? 'Не выбрано';
    final isHint = widget.gender == null || widget.gender!.isEmpty;
    const arrowColor = Colors.white54;

    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
          onTap: _openMenu,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _fieldBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isHint ? Colors.white54 : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  turns: _isOpen ? 0.5 : 0.0,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: arrowColor,
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

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ProfileEditSheetContent extends StatelessWidget {
  const ProfileEditSheetContent({
    super.key,
    required this.email,
    required this.avatarUrl,
    required this.savingProfile,
    required this.lastSaveMessage,
    required this.lastSaveOk,
    required this.usernameController,
    required this.displayNameController,
    required this.bioController,
    required this.birthDate,
    required this.gender,
    required this.allowMessagesFromNonFriends,
    required this.onPickAvatar,
    required this.onPickBirthDate,
    required this.onGenderChanged,
    required this.onAllowMessagesFromNonFriendsChanged,
    required this.onClose,
    required this.onSave,
    required this.scrollController,
    required this.sheetPadding,
    this.usernameStatusIcon,
    this.isUsernameValid = true,
  });

  final String email;
  final String? avatarUrl;
  final bool savingProfile;
  final String? lastSaveMessage;
  final bool lastSaveOk;

  final TextEditingController usernameController;
  final TextEditingController displayNameController;
  final TextEditingController bioController;

  final String? birthDate;
  final String? gender;
  final bool allowMessagesFromNonFriends;

  final Future<void> Function() onPickAvatar;
  final Future<void> Function() onPickBirthDate;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<bool> onAllowMessagesFromNonFriendsChanged;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final ScrollController scrollController;
  final EdgeInsets sheetPadding;
  final Widget? usernameStatusIcon;
  final bool isUsernameValid;

  @override
  Widget build(BuildContext context) {
    const usernameMaxLen = 20;
    const bioMaxLen = 280;
    const placeholderBg = Color(0xFF252525);
    final fullAvatarUrl = resolveAvatarUrl(avatarUrl);
    final statusColor = savingProfile
        ? Colors.grey
        : (lastSaveMessage == null
              ? Colors.grey
              : (lastSaveOk
                    ? Colors.green
                    : Theme.of(context).colorScheme.error));

    return GestureDetector(
      onTap: () {
        // Закрываем клавиатуру при тапе на пустое место
        FocusScope.of(context).unfocus();
      },
      child: ListView(
        controller: scrollController,
        padding: sheetPadding,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: savingProfile ? null : onPickAvatar,
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: fullAvatarUrl == null
                              ? Container(
                                  color: placeholderBg,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                )
                              : Image.network(fullAvatarUrl, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: savingProfile
                            ? null
                            : () {
                                onPickAvatar();
                              },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.photo,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Редактирование профиля',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  savingProfile
                      ? 'Сохраняю...'
                      : (lastSaveMessage ??
                            'Нажмите Сохранить для сохранения изменений'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StyledTextField(
                labelText: 'Никнейм',
                controller: usernameController,
                hintText: 'ivan_123',
                maxLength: usernameMaxLen,
                statusIcon: usernameStatusIcon,
                labelTrailing: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: usernameController,
                  builder: (context, value, _) {
                    final len = value.text.trim().length;
                    return Text(
                      '$len/$usernameMaxLen',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StyledTextField(
            labelText: 'Имя',
            controller: displayNameController,
            hintText: 'Как Вас зовут?',
          ),
          const SizedBox(height: 12),
          _StyledTextField(
            labelText: 'О себе',
            controller: bioController,
            maxLines: 4,
            hintText: 'Расскажите немного о себе',
            maxLength: bioMaxLen,
            labelTrailing: ValueListenableBuilder<TextEditingValue>(
              valueListenable: bioController,
              builder: (context, value, _) {
                final len = value.text.length;
                return Text(
                  '$len/$bioMaxLen',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BirthDateField(
                  birthDate: birthDate,
                  onPickBirthDate: onPickBirthDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пол',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _GenderDropdownField(
                      gender: gender,
                      enabled: !savingProfile,
                      onGenderChanged: onGenderChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                enabled: false,
                decoration: InputDecoration(
                  hintText: email.isEmpty ? 'email@example.com' : email,
                  filled: true,
                  fillColor: _fieldBg,
                  hintStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: _fieldBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: _fieldBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Разрешать сообщения не друзьям',
              style: TextStyle(color: Colors.white),
            ),
            value: allowMessagesFromNonFriends,
            activeColor: Colors.white,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: const Color(0xFF222222),
            onChanged: savingProfile
                ? null
                : onAllowMessagesFromNonFriendsChanged,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                  ),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                  ),
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
