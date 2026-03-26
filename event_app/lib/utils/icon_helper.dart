import 'package:flutter/material.dart';

class IconConstants {
  // Предопределенные константы для часто используемых иконок
  static const IconData eventDefault = IconData(
    0xe800,
    fontFamily: 'MaterialIcons',
  );
  static const IconData eventLocation = IconData(
    0xe801,
    fontFamily: 'MaterialIcons',
  );
  static const IconData eventMeeting = IconData(
    0xe802,
    fontFamily: 'MaterialIcons',
  );
  static const IconData eventParty = IconData(
    0xe803,
    fontFamily: 'MaterialIcons',
  );
  static const IconData eventSport = IconData(
    0xe804,
    fontFamily: 'MaterialIcons',
  );
  static const IconData eventMusic = IconData(
    0xe805,
    fontFamily: 'MaterialIcons',
  );
  static const IconData eventFood = IconData(
    0xe806,
    fontFamily: 'MaterialIcons',
  );
  static const IconData eventWork = IconData(
    0xe807,
    fontFamily: 'MaterialIcons',
  );
  static const IconData eventTravel = IconData(
    0xe808,
    fontFamily: 'MaterialIcons',
  );

  // Маппинг codePoint -> константная иконка
  static const Map<int, IconData> _iconMap = {
    0xe800: eventDefault,
    0xe801: eventLocation,
    0xe802: eventMeeting,
    0xe803: eventParty,
    0xe804: eventSport,
    0xe805: eventMusic,
    0xe806: eventFood,
    0xe807: eventWork,
    0xe808: eventTravel,
  };

  static IconData getIcon(int codePoint) {
    // Возвращаем предопределенную константу или иконку по умолчанию
    return _iconMap[codePoint] ?? eventDefault;
  }
}
