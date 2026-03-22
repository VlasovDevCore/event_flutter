import 'package:flutter/material.dart';

import '../profile_avatar.dart';

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
    required this.scrollController,
    required this.sheetPadding,
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
  final ScrollController scrollController;
  final EdgeInsets sheetPadding;

  @override
  Widget build(BuildContext context) {
    const placeholderBg = Color(0xFF252525);
    final fullAvatarUrl = resolveAvatarUrl(avatarUrl);
    final statusColor = savingProfile
        ? Colors.grey
        : (lastSaveMessage == null
            ? Colors.grey
            : (lastSaveOk ? Colors.green : Theme.of(context).colorScheme.error));

    return ListView(
      controller: scrollController,
      padding: sheetPadding,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: placeholderBg,
              backgroundImage: fullAvatarUrl == null ? null : NetworkImage(fullAvatarUrl),
              child: fullAvatarUrl != null ? null : const Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Редактирование профиля',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    savingProfile
                        ? 'Сохраняю...'
                        : (lastSaveMessage ?? 'Изменения сохранятся при закрытии'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Аватар', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: savingProfile ? null : () { onPickAvatar(); },
            icon: const Icon(Icons.photo),
            label: const Text('Загрузить фото'),
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 16),
        TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: 'Никнейм (username)',
            hintText: 'ivan_123',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: displayNameController,
          decoration: const InputDecoration(
            labelText: 'Имя',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bioController,
          decoration: const InputDecoration(
            labelText: 'О себе',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () { onPickBirthDate(); },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Дата рождения',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(birthDate ?? 'Не указано'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: (gender == null || gender!.isEmpty) ? null : gender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Мужской')),
                  DropdownMenuItem(value: 'female', child: Text('Женский')),
                  DropdownMenuItem(value: 'other', child: Text('Другое')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Пол',
                  border: OutlineInputBorder(),
                ),
                onChanged: onGenderChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: email.isEmpty ? '—' : email,
            border: const OutlineInputBorder(),
            hintStyle: const TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Разрешать сообщения не друзьям'),
          value: allowMessagesFromNonFriends,
          onChanged: savingProfile ? null : onAllowMessagesFromNonFriendsChanged,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onClose,
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

