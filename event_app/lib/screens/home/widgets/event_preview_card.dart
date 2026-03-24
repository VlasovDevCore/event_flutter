import 'package:flutter/material.dart';

import '../../../config/event_marker_catalog.dart';
import '../../../models/event.dart';
import 'event_preview_participants_row.dart';
import 'preview_participant.dart';

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

  String _hexColor(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
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
                      backgroundColor: isGoing 
                          ? const Color(0xFF2C2C2C)  // Не приду - серый
                          : Colors.white,            // Я приду - белый
                      foregroundColor: isGoing 
                          ? Colors.white             // Не приду - белый текст
                          : Colors.black, // Я приду - синий текст
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => onRsvpToggle(isGoing ? -1 : 1),
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
}