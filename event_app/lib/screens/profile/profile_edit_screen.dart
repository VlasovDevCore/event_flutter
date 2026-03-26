// profile_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import 'profile_edit_logic.dart';
import 'profile_models.dart';
import 'profile_repository.dart';
import 'widgets/birth_date_numeric_sheet.dart';

// Функция для формирования URL аватара
String? resolveAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
    return avatarUrl;
  }
  if (avatarUrl.startsWith('/uploads')) {
    return '${ApiClient.baseUrl}$avatarUrl';
  }
  if (avatarUrl.startsWith('file://')) {
    return avatarUrl;
  }
  return null;
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;

  String? _avatarUrl;
  String? _birthDate;
  String? _gender;
  bool _allowMessagesFromNonFriends = true;
  bool _saving = false;
  bool _isPickingImage = false;
  String? _error;

  bool _isCheckingUsername = false;
  bool? _usernameAvailable;
  final String _originalUsername =
      Hive.box('authBox').get('username') as String? ?? '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _loadProfileData() {
    final box = Hive.box('authBox');
    _usernameController = TextEditingController(
      text: box.get('username') as String? ?? '',
    );
    _displayNameController = TextEditingController(
      text: box.get('displayName') as String? ?? '',
    );
    _bioController = TextEditingController(
      text: box.get('bio') as String? ?? '',
    );
    _avatarUrl = box.get('avatarUrl') as String?;
    _birthDate = box.get('birthDate') as String?;
    _gender = box.get('gender') as String?;
    _allowMessagesFromNonFriends =
        (box.get('allowMessagesFromNonFriends') as bool?) ?? true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim();
    if (username == _originalUsername) {
      if (mounted) {
        setState(() {
          _usernameAvailable = true;
          _isCheckingUsername = false;
        });
      }
      return;
    }

    if (username.isEmpty) {
      if (mounted) {
        setState(() {
          _usernameAvailable = true;
          _isCheckingUsername = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isCheckingUsername = true);
    }

    final available = await ProfileEditLogic.checkUsernameAvailable(username);

    if (mounted) {
      setState(() {
        _usernameAvailable = available;
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    if (_isPickingImage || _saving) return;

    _isPickingImage = true;
    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null) {
        _isPickingImage = false;
        return;
      }

      if (mounted) {
        setState(() => _saving = true);
      }

      try {
        final rawBytes = await picked.readAsBytes();
        final croppedBytes = await ProfileEditLogic.autoCropAvatarSquare(
          rawBytes,
        );
        if (croppedBytes == null) {
          _isPickingImage = false;
          return;
        }

        final data = await ApiClient.instance.uploadImage(
          '/users/me/avatar',
          withAuth: true,
          bytes: croppedBytes,
          filename: 'avatar.png',
        );
        final me = ProfileMe.fromApi(data);
        await Hive.box('authBox').put('avatarUrl', me.avatarUrl);
        if (mounted) {
          setState(() => _avatarUrl = me.avatarUrl);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _saving = false);
        }
        _isPickingImage = false;
      }
    } catch (e) {
      _isPickingImage = false;
      if (e.toString().contains('already_active')) {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора изображения: $e')),
        );
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final v = await showBirthDateNumericSheet(
      context,
      currentBirthDate: _birthDate,
    );
    if (v != null && mounted) {
      setState(() => _birthDate = v);
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();

    if (username.isEmpty) {
      setState(() => _error = 'Никнейм не может быть пустым');
      return;
    }

    if (username != _originalUsername && _usernameAvailable == false) {
      setState(() => _error = 'Никнейм уже занят');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final data = await ApiClient.instance.put(
        '/users/me',
        withAuth: true,
        body: {
          'username': username,
          'displayName': displayName.isEmpty ? null : displayName,
          'bio': bio.isEmpty ? null : bio,
          'birthDate': _birthDate,
          'gender': _gender,
          'allowMessagesFromNonFriends': _allowMessagesFromNonFriends,
        },
      );

      final me = ProfileMe.fromApi(data);
      final box = Hive.box('authBox');

      await box.put('username', me.username);
      await box.put('displayName', me.displayName);
      await box.put('bio', me.bio);
      await box.put('birthDate', me.birthDate);
      await box.put('gender', me.gender);
      await box.put(
        'allowMessagesFromNonFriends',
        me.allowMessagesFromNonFriends,
      );

      if (me.avatarUrl != null) {
        await box.put('avatarUrl', me.avatarUrl);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        setState(() => _saving = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Ошибка: $e');
        setState(() => _saving = false);
      }
    }
  }

  Widget? _getUsernameStatusIcon() {
    final username = _usernameController.text.trim();
    if (username == _originalUsername) return null;
    if (_isCheckingUsername) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }
    if (_usernameAvailable == true) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 16);
    }
    if (_usernameAvailable == false) {
      return const Icon(Icons.close, color: Colors.red, size: 16);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fullAvatarUrl = resolveAvatarUrl(_avatarUrl);
    const fieldBg = Color(0xFF1F1F1F);
    const fieldBorder = Color(0xFF222222);

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Stack(
        children: [
          _buildBackgroundGradient(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Заголовок как sliver
                SliverToBoxAdapter(child: _buildHeader()),
                // Контент
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Аватар (скругленный вариант)
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Аватар
                            GestureDetector(
                              onTap: _saving ? null : _pickAvatar,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: const Color(0xFF252525),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: fullAvatarUrl == null
                                      ? const Center(
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 48,
                                          ),
                                        )
                                      : Image.network(
                                          fullAvatarUrl,
                                          fit: BoxFit.cover,
                                          width: 96,
                                          height: 96,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: const Color(
                                                    0xFF252525,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                    size: 48,
                                                  ),
                                                );
                                              },
                                        ),
                                ),
                              ),
                            ),
                            // Иконка камеры
                            Positioned(
                              right: -5,
                              bottom: -5,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF161616),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ошибка
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Поля ввода
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            // Никнейм
                            _buildTextField(
                              label: 'Никнейм',
                              controller: _usernameController,
                              hint: 'ivan_123',
                              maxLength: 20,
                              statusIcon: _getUsernameStatusIcon(),
                              onChanged: (_) => _checkUsernameAvailability(),
                            ),
                            const SizedBox(height: 16),

                            // Имя
                            _buildTextField(
                              label: 'Имя',
                              controller: _displayNameController,
                              hint: 'Как Вас зовут?',
                            ),
                            const SizedBox(height: 16),

                            // О себе
                            _buildTextField(
                              label: 'О себе',
                              controller: _bioController,
                              hint: 'Расскажите немного о себе',
                              maxLines: 4,
                              maxLength: 280,
                            ),
                            const SizedBox(height: 16),

                            // Дата рождения и Пол
                            Row(
                              children: [
                                Expanded(child: _buildBirthDateField()),
                                const SizedBox(width: 12),
                                Expanded(child: _buildGenderField()),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Email (только для чтения)
                            _buildReadOnlyField(
                              label: 'Email',
                              value:
                                  Hive.box('authBox').get('email') as String? ??
                                  '',
                            ),
                            const SizedBox(height: 16),

                            // Разрешать сообщения не друзьям
                            _buildSwitchField(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Кнопки снизу как sliver
                SliverToBoxAdapter(child: _buildBottomButtons()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 0.55,
            colors: [
              const Color.fromARGB(197, 29, 29, 29),
              const Color(0xFF161616),
            ],
            stops: const [0.1, 4.9],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Редактирование профиля',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Tooltip(
      message: 'Назад',
      child: Container(
        width: 37,
        height: 37,
        decoration: BoxDecoration(
          color: const Color.fromARGB(157, 0, 0, 0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(),
            splashColor: const Color.fromARGB(157, 0, 0, 0),
            highlightColor: const Color.fromARGB(157, 0, 0, 0),
            child: const Center(
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Отмена',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _saveProfile,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Сохранить',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int? maxLines,
    int? maxLength,
    Widget? statusIcon,
    void Function(String)? onChanged,
  }) {
    const fieldBg = Color(0xFF1F1F1F);
    const fieldBorder = Color(0xFF222222);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines ?? 1,
          maxLength: maxLength,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: fieldBg,
            hintStyle: const TextStyle(color: Colors.white54),
            counterText: '',
            suffixIcon: statusIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: statusIcon,
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: fieldBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    const fieldBg = Color(0xFF1F1F1F);
    const fieldBorder = Color(0xFF222222);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fieldBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? 'email@example.com' : value,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBirthDateField() {
    const fieldBg = Color(0xFF1F1F1F);
    const fieldBorder = Color(0xFF222222);

    String? formattedDate;
    if (_birthDate != null && _birthDate!.isNotEmpty) {
      final v = _birthDate!.trim();
      if (v.length >= 10 && v.contains('-')) {
        final y = v.substring(0, 4);
        final m = v.substring(5, 7);
        final d = v.substring(8, 10);
        formattedDate = '$d/$m/$y';
      } else {
        formattedDate = v;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Дата рождения',
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickBirthDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: fieldBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formattedDate ?? 'дд/мм/гггг',
                    style: TextStyle(
                      color: formattedDate == null
                          ? Colors.white54
                          : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    const fieldBg = Color(0xFF1F1F1F);
    const fieldBorder = Color(0xFF222222);

    String? displayGender;
    if (_gender != null) {
      switch (_gender) {
        case 'male':
          displayGender = 'Мужской';
          break;
        case 'female':
          displayGender = 'Женский';
          break;
        case 'other':
          displayGender = 'Другое';
          break;
        default:
          displayGender = _gender;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Пол',
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (mounted) {
              setState(() => _gender = value);
            }
          },
          offset: const Offset(0, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: const Color(0xFF252525),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: fieldBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayGender ?? 'Не выбрано',
                    style: TextStyle(
                      color: displayGender == null
                          ? Colors.white54
                          : Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white54),
              ],
            ),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'male', child: Text('Мужской')),
            const PopupMenuItem(value: 'female', child: Text('Женский')),
            const PopupMenuItem(value: 'other', child: Text('Другое')),
          ],
        ),
      ],
    );
  }

  Widget _buildSwitchField() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Разрешать сообщения не друзьям',
        style: TextStyle(color: Colors.white, fontSize: 15),
      ),
      value: _allowMessagesFromNonFriends,
      activeColor: Colors.white,
      inactiveThumbColor: Colors.white54,
      inactiveTrackColor: const Color(0xFF222222),
      onChanged: _saving
          ? null
          : (v) {
              if (mounted) {
                setState(() => _allowMessagesFromNonFriends = v);
              }
            },
    );
  }
}
