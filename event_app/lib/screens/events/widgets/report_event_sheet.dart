import 'package:flutter/material.dart';

import '../../../services/api_client.dart';

Future<String?> _showCategorySelectSheet(
  BuildContext context, {
  required List<String> items,
  required String selected,
  bool isDisabled = false,
}) async {
  if (isDisabled) return null;

  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Text(
              'Причина жалобы',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final v = items[index];
                  final isSelected = v == selected;
                  return Material(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(ctx).pop(v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white24
                                : const Color(0xFF222222),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                v,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFDBDBDB),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.chevron_right,
                              size: 18,
                              color: isSelected
                                  ? Colors.white70
                                  : const Color(0xFF6A6A6A),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF222222)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showReportEventSheet(
  BuildContext context, {
  required String eventId,
  required String eventTitle,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  const categories = <String>[
    'Спам',
    'Неприемлемый контент',
    'Мошенничество',
    'Опасное мероприятие',
    'Другое',
  ];

  String category = categories.first;
  final controller = TextEditingController();
  bool isSending = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final canSend = !isSending &&
              controller.text.trim().isNotEmpty &&
              controller.text.trim().length >= 10;

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Жалоба',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Опишите проблему с событием “$eventTitle”.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFAAABB0),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Причина',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isSending
                        ? null
                        : () async {
                            final picked = await _showCategorySelectSheet(
                              ctx,
                              items: categories,
                              selected: category,
                              isDisabled: isSending,
                            );
                            if (picked == null) return;
                            setState(() => category = picked);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF222222)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: isSending
                                ? const Color(0xFF4A4A4A)
                                : Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Описание',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  enabled: !isSending,
                  minLines: 4,
                  maxLines: 8,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Что случилось? (минимум 10 символов)',
                    hintStyle: const TextStyle(color: Color(0xFF5E5E5E)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F0F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF222222)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF222222)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: canSend
                      ? () async {
                          setState(() => isSending = true);
                          try {
                            await ApiClient.instance.post(
                              '/reports/event',
                              withAuth: true,
                              body: {
                                'eventId': eventId,
                                'category': category,
                                'message': controller.text.trim(),
                              },
                            );
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Жалоба отправлена')),
                            );
                          } on ApiException catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')),
                            );
                          } finally {
                            if (ctx.mounted) setState(() => isSending = false);
                          }
                        }
                      : null,
                  child: isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : const Text('Отправить'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF222222)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSending ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

