import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _BirthDateNumericSheet extends StatefulWidget {
  const _BirthDateNumericSheet({
    required this.currentBirthDate,
  });

  final String? currentBirthDate;

  @override
  State<_BirthDateNumericSheet> createState() => _BirthDateNumericSheetState();
}

class _BirthDateNumericSheetState extends State<_BirthDateNumericSheet> {
  static const fieldBg = Color(0xFF1F1F1F);
  static const fieldBorder = Color(0xFF222222);
  static const popupBg = Color(0xFF151515);

  late final TextEditingController dayCtrl;
  late final TextEditingController monthCtrl;
  late final TextEditingController yearCtrl;

  String errorText = '';

  @override
  void initState() {
    super.initState();
    final current = widget.currentBirthDate;
    final y =
        (current != null && current.length >= 4) ? current.substring(0, 4) : '';
    final m =
        (current != null && current.length >= 7) ? current.substring(5, 7) : '';
    final d =
        (current != null && current.length >= 10) ? current.substring(8, 10) : '';

    dayCtrl = TextEditingController(text: d);
    monthCtrl = TextEditingController(text: m);
    yearCtrl = TextEditingController(text: y);
  }

  @override
  void dispose() {
    dayCtrl.dispose();
    monthCtrl.dispose();
    yearCtrl.dispose();
    super.dispose();
  }

  InputDecoration numericDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: fieldBg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 15,
      ),
      hintStyle: const TextStyle(
        color: Colors.white70,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: fieldBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: fieldBorder),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  void _onSave() {
    final day = int.tryParse(dayCtrl.text.trim());
    final month = int.tryParse(monthCtrl.text.trim());
    final year = int.tryParse(yearCtrl.text.trim());

    if (day == null || month == null || year == null) {
      setState(() {
        errorText = 'Введите день, месяц и год';
      });
      return;
    }
    if (year < 1900 || year > DateTime.now().year) {
      setState(() {
        errorText = 'Некорректный год';
      });
      return;
    }
    if (month < 1 || month > 12) {
      setState(() {
        errorText = 'Некорректный месяц';
      });
      return;
    }
    if (day < 1 || day > 31) {
      setState(() {
        errorText = 'Некорректный день';
      });
      return;
    }

    final dt = DateTime(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) {
      setState(() {
        errorText = 'Такой даты не существует';
      });
      return;
    }
    if (dt.isAfter(DateTime.now())) {
      setState(() {
        errorText = 'Дата не может быть в будущем';
      });
      return;
    }

    final s =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  'Дата рождения',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Мы поздравим вас с днём рождения',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dayCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: numericDecoration(hintText: 'дд'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: monthCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: numericDecoration(hintText: 'мм'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: yearCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: numericDecoration(hintText: 'гггг'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Фиксируем высоту области под ошибку, чтобы контент не "прыгал".
          SizedBox(
            height: 22,
            child: Center(
              child: Opacity(
                opacity: errorText.isNotEmpty ? 1 : 0,
                child: Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
            ),
            onPressed: _onSave,
            child: const Text('Сохранить'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Нижний лист: ввод даты рождения день / месяц / год. Возвращает `YYYY-MM-DD` или `null`.
Future<String?> showBirthDateNumericSheet(
  BuildContext context, {
  String? currentBirthDate,
}) async {
  return await showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: _BirthDateNumericSheetState.popupBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return _BirthDateNumericSheet(
        currentBirthDate: currentBirthDate,
      );
    },
  );
}
