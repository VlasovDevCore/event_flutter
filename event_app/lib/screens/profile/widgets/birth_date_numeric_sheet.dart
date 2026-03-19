import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Нижний лист: ввод даты рождения день / месяц / год. Возвращает `YYYY-MM-DD` или `null`.
Future<String?> showBirthDateNumericSheet(
  BuildContext context, {
  String? currentBirthDate,
}) async {
  final current = currentBirthDate;
  final y = (current != null && current.length >= 4) ? current.substring(0, 4) : '';
  final m = (current != null && current.length >= 7) ? current.substring(5, 7) : '';
  final d = (current != null && current.length >= 10) ? current.substring(8, 10) : '';

  final dayCtrl = TextEditingController(text: d);
  final monthCtrl = TextEditingController(text: m);
  final yearCtrl = TextEditingController(text: y);

  try {
    return await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Дата рождения',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dayCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'День',
                        hintText: '01',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: monthCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Месяц',
                        hintText: '12',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: yearCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Год',
                        hintText: '1999',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final day = int.tryParse(dayCtrl.text.trim());
                  final month = int.tryParse(monthCtrl.text.trim());
                  final year = int.tryParse(yearCtrl.text.trim());
                  if (day == null || month == null || year == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите день, месяц и год')),
                    );
                    return;
                  }
                  if (year < 1900 || year > DateTime.now().year) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Некорректный год')),
                    );
                    return;
                  }
                  if (month < 1 || month > 12) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Некорректный месяц')),
                    );
                    return;
                  }
                  if (day < 1 || day > 31) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Некорректный день')),
                    );
                    return;
                  }
                  final dt = DateTime(year, month, day);
                  if (dt.year != year || dt.month != month || dt.day != day) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Такой даты не существует')),
                    );
                    return;
                  }
                  if (dt.isAfter(DateTime.now())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Дата не может быть в будущем')),
                    );
                    return;
                  }
                  final s =
                      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  Navigator.of(context).pop(s);
                },
                child: const Text('Сохранить'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  } finally {
    dayCtrl.dispose();
    monthCtrl.dispose();
    yearCtrl.dispose();
  }
}
