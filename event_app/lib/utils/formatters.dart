/// Форматирует число с разделением пробелами для тысяч
String formatNumber(int number) {
  if (number >= 1_000_000) {
    final millions = number / 1_000_000;
    if (millions == millions.roundToDouble()) {
      return '${millions.round()} млн';
    } else {
      return '${millions.toStringAsFixed(1)} млн';
    }
  } else {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]} ',
    );
  }
}

/// Русское склонение для дней
String daysRu(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 19) return 'дней';
  switch (n % 10) {
    case 1:
      return 'день';
    case 2:
    case 3:
    case 4:
      return 'дня';
    default:
      return 'дней';
  }
}

/// Русское склонение для недель
String weeksRu(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 19) return 'недель';
  switch (n % 10) {
    case 1:
      return 'неделю';
    case 2:
    case 3:
    case 4:
      return 'недели';
    default:
      return 'недель';
  }
}

/// Русское склонение для месяцев
String monthsRu(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 19) return 'месяцев';
  switch (n % 10) {
    case 1:
      return 'месяц';
    case 2:
    case 3:
    case 4:
      return 'месяца';
    default:
      return 'месяцев';
  }
}

/// Русское склонение для лет
String yearsRu(int n) {
  final m = n % 100;
  if (m >= 11 && m <= 19) return 'лет';
  switch (n % 10) {
    case 1:
      return 'год';
    case 2:
    case 3:
    case 4:
      return 'года';
    default:
      return 'лет';
  }
}

/// «Вы с нами уже …» по [createdAt] регистрации.
String withUsTenureLine(DateTime? createdAt, bool isMe) {
  if (createdAt == null) {
    return 'Дата регистрации неизвестна';
  }
  final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(start).inDays;
  if (days <= 0) {
    return isMe ? 'Вы с нами с сегодняшнего дня' : 'С нами с сегодняшнего дня';
  }
  String wrap(String s) {
    if (isMe) return 'Вы $s';
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  if (days < 7) {
    final d = formatNumber(days);
    return wrap('с нами уже $d ${daysRu(days)}');
  }
  if (days < 30) {
    final w = days ~/ 7;
    final ws = formatNumber(w);
    return wrap('с нами уже $ws ${weeksRu(w)}');
  }
  if (days < 365) {
    final m = days ~/ 30;
    final ms = formatNumber(m);
    if (m < 1) {
      final w = days ~/ 7;
      return wrap('с нами уже ${formatNumber(w)} ${weeksRu(w)}');
    }
    return wrap('с нами уже $ms ${monthsRu(m)}');
  }
  final y = days ~/ 365;
  final ys = formatNumber(y);
  return wrap('с нами уже $ys ${yearsRu(y)}');
}
