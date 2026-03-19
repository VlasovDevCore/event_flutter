# Профиль — структура и рефакторинг

## Сейчас в папке

| Файл | Назначение |
|------|------------|
| `profile_screen.dart` | Экран: мой профиль / чужой; тяжёлая логика редактирования и UI |
| `profile_models.dart` | `ProfileMe`, `ProfileStats` + парсинг API |
| `profile_social_models.dart` | `ProfileRelationship`, `ProfileBlockStatus` |
| `profile_repository.dart` | Все `GET` профиля/статистики/друзей/блоков/достижений + запись «я» в Hive |
| `profile_achievement.dart` | Модель достижения (ответ `/users/.../achievements`) |
| `profile_avatar.dart` | `resolveAvatarUrl`, палитра иконок аватара |
| `profile_qr_screen.dart` | QR профиля |
| `widgets/profile_edit_sheet_content.dart` | Контент нижнего листа редактирования |
| `widgets/stat_tile.dart` | Плитка статистики |
| `widgets/achievement_section.dart` | Сетка достижений + иконки по `icon_key` |
| `widgets/avatar_crop_dialog.dart` | Обрезка фото перед загрузкой аватара |
| `widgets/birth_date_numeric_sheet.dart` | Выбор даты рождения (дд/мм/гггг) |

Ничего лишнего не обязано лежать в `profile/`: всё выше используется.

## Уже сделано

- Вынесены соц. модели и HTTP-слой из гигантского `profile_screen`.
- Лист даты рождения — отдельная функция `showBirthDateNumericSheet`.

## Дальше (по желанию)

1. **`profile_edit_controller.dart`** — debounce + `persist()` + контроллеры из `_openEditSheet`, чтобы экран только показывал UI.
2. **`widgets/other_user_profile_view.dart`** — тело списка для `userId != null` (~300 строк из `build`).
3. **`widgets/my_profile_view.dart`** — `_buildMyProfile` как виджет с параметрами/FutureBuilder.
4. **`profile_hive_store.dart`** — чтение полей из `authBox` одним классом вместо десятка `_email()` / `_username()`…

## Правило

Новые фичи профиля — по возможности в `widgets/` или `profile_repository.dart`, а не в конец `profile_screen.dart`.
