import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../models/event.dart';
import 'event_preview_participants_row.dart';
import 'preview_participant.dart';
import '../../auth/verify_email_code_screen.dart';

class EventPreviewCard extends StatelessWidget {
  const EventPreviewCard({
    super.key,
    required this.event,
    required this.previewLoading,
    required this.remainingLabel,
    required this.iconLabel,
    required this.markerColor,
    required this.participants,
    required this.totalGoing,
    required this.isGoing,
    required this.onRsvpToggle,
    required this.onOpenDetails,
  });

  final Event event;
  final bool previewLoading;
  final String? remainingLabel;
  final String? iconLabel;
  final Color markerColor;
  final List<PreviewParticipant> participants;
  final int totalGoing;
  final bool isGoing;
  final VoidCallback onOpenDetails;
  final void Function(int status) onRsvpToggle;

  @override
  Widget build(BuildContext context) {
    final isVerified = ((Hive.box('authBox').get('status') as int?) ?? 1) != 0;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161616).withOpacity(0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF161616),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: markerColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    iconLabel?.toUpperCase() ?? 'СОБЫТИЕ',
                    style: TextStyle(
                      color: markerColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                if (remainingLabel != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Color(0xFFB5BBC7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        remainingLabel!,
                        style: const TextStyle(
                          color: Color(0xFFB5BBC7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFB5BBC7),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 8),
            EventPreviewParticipantsRow(
              participants: participants,
              totalGoing: totalGoing,
              previewLoading: previewLoading,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isGoing ? const Color(0xFF2C2C2C) : Colors.white,
                      foregroundColor: isGoing ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () async {
                      if (!isVerified) {
                        final nextStatus = isGoing ? -1 : 1;
                        final verified = await _showVerifyEmailGate(context);
                        if (verified == true) {
                          onRsvpToggle(nextStatus);
                        }
                        return;
                      }
                      onRsvpToggle(isGoing ? -1 : 1);
                    },
                    child: Text(isGoing ? 'Не приду' : 'Я приду'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2C),
                      foregroundColor: const Color(0xFFDFE3EC),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onOpenDetails,
                    child: const Icon(Icons.open_in_full_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showVerifyEmailGate(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Center(
                child: Image.asset(
                  'assets/avatar/at-dynamic-color.png',
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Подтвердите email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Чтобы отметить участие, сначала подтвердите почту кодом из письма.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.35,
                  color: Color(0xFFAAABB0),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final ok = await Navigator.of(ctx).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const VerifyEmailCodeScreen(),
                      ),
                    );
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop(ok == true);
                  },
                  child: const Text(
                    'Подтвердить email',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF222222)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
            ],
          ),
        );
      },
    );
  }
}