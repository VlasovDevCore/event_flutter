import 'package:flutter/material.dart';

import '../../profile/profile_avatar.dart';
import 'preview_participant.dart';

class EventPreviewParticipantsRow extends StatelessWidget {
  const EventPreviewParticipantsRow({
    super.key,
    required this.participants,
    required this.totalGoing,
    required this.previewLoading,
  });

  final List<PreviewParticipant> participants;
  final int totalGoing;
  final bool previewLoading;

  IconData _statusIconForUser(int status) {
    if (status == -1) return Icons.close_rounded;
    if (status == 0) return Icons.schedule_rounded;
    return Icons.check_rounded;
  }

  Color _statusColorForUser(int status) {
    if (status == -1) return const Color(0xFFFF8A8A);
    if (status == 0) return const Color(0xFFF6C85A);
    return const Color(0xFF4ADE80);
  }

  @override
  Widget build(BuildContext context) {
    final displayParticipants = previewLoading
        ? List<PreviewParticipant>.generate(
            3,
            (i) => const PreviewParticipant(
              label: '',
              avatarUrl: null,
              status: 1,
            ),
          )
        : participants;

    return Row(
      children: [
        SizedBox(
          width: 4 * 22 + 14,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < displayParticipants.length && i < 3; i++)
                Positioned(
                  left: i * 22,
                  child: Builder(
                    builder: (context) {
                      final resolved = resolveAvatarUrl(displayParticipants[i].avatarUrl);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF101319),
                            child: CircleAvatar(
                              radius: 15,
                              backgroundImage:
                                  resolved != null ? NetworkImage(resolved) : null,
                              child: resolved == null
                                  ? (previewLoading
                                      ? Container(
                                          width: 18,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF23262C),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        )
                                      : Text(
                                          displayParticipants[i]
                                              .label
                                              .characters
                                              .take(1)
                                              .toString()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ))
                                  : null,
                            ),
                          ),
                          if (!previewLoading)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: _statusColorForUser(displayParticipants[i].status),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF0E1118),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  _statusIconForUser(displayParticipants[i].status),
                                  size: 9,
                                  color: const Color(0xFF0E1118),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              if (previewLoading || totalGoing > 3)
                Positioned(
                  left: 3 * 22,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF101319),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(0xFF23262C),
                      child: Text(
                        previewLoading ? '…' : '+${totalGoing - 3}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Участники: ${previewLoading ? '…' : totalGoing}',
          style: const TextStyle(
            color: Color(0xFFB5BBC7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

