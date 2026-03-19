import 'package:flutter/material.dart';

class EventCategoryOption {
  const EventCategoryOption({
    required this.icon,
    required this.label,
    this.minUserStatus = 1,
  });

  final IconData icon;
  final String label;
  final int minUserStatus;
}

class EventMarkerCatalog {
  static const Color defaultIconColor = Color(0xFFFFFFFF);

  static final List<Color> availableColors = <Color>[
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  static const List<EventCategoryOption> categories = <EventCategoryOption>[
    EventCategoryOption(icon: Icons.flutter_dash, label: 'Встреча с друзьями'),
    EventCategoryOption(icon: Icons.music_note, label: 'Музыка / концерт'),
    EventCategoryOption(icon: Icons.sports_soccer, label: 'Спорт / активность'),
    EventCategoryOption(icon: Icons.restaurant, label: 'Поход в ресторан'),
    EventCategoryOption(icon: Icons.coffee, label: 'Кофе и разговоры'),
    EventCategoryOption(icon: Icons.movie, label: 'Кино / просмотр фильма'),
    EventCategoryOption(icon: Icons.celebration, label: 'Вечеринка / праздник'),
    EventCategoryOption(icon: Icons.hiking, label: 'Прогулка в парке'),
    EventCategoryOption(icon: Icons.beach_access, label: 'Пляж / природа'),
    EventCategoryOption(icon: Icons.pets, label: 'Прогулка с питомцами'),
    EventCategoryOption(
      icon: Icons.local_fire_department,
      label: 'Интенсив / челлендж',
      minUserStatus: 2,
    ),
    EventCategoryOption(
      icon: Icons.nightlife,
      label: 'Ночной ивент',
      minUserStatus: 2,
    ),
    EventCategoryOption(
      icon: Icons.auto_awesome,
      label: 'Премиум активность',
      minUserStatus: 2,
    ),
  ];

  static List<EventCategoryOption> categoriesForUserStatus(int userStatus) {
    return categories.where((c) => c.minUserStatus <= userStatus).toList(growable: false);
  }

  static List<IconData> availableIconsForUserStatus(int userStatus) {
    return categoriesForUserStatus(userStatus).map((c) => c.icon).toList(growable: false);
  }

  static List<IconData> get availableIcons {
    return availableIconsForUserStatus(1);
  }

  static String? categoryLabelForCodePoint(int codePoint) {
    for (final category in categories) {
      if (category.icon.codePoint == codePoint) return category.label;
    }
    return null;
  }
}
