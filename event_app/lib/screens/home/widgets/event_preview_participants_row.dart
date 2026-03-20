import 'package:flutter/material.dart';

import '../../profile/profile_avatar.dart';
import 'preview_participant.dart';

class EventPreviewParticipantsRow extends StatefulWidget {
  const EventPreviewParticipantsRow({
    super.key,
    required this.participants,
    required this.totalGoing,
    required this.previewLoading,
    this.color,
  });

  final List<PreviewParticipant> participants;
  final int totalGoing;
  final bool previewLoading;
  final Color? color;

  @override
  State<EventPreviewParticipantsRow> createState() => _EventPreviewParticipantsRowState();
}

class _EventPreviewParticipantsRowState extends State<EventPreviewParticipantsRow> {
  int _lastKnownTotal = 0;
  bool _hasAnimated = false;

  @override
  void didUpdateWidget(EventPreviewParticipantsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Если загрузка закончилась и число изменилось, запускаем анимацию
    if (!widget.previewLoading && oldWidget.previewLoading && widget.totalGoing != _lastKnownTotal) {
      _lastKnownTotal = widget.totalGoing;
      _hasAnimated = true;
      setState(() {});
    }
    
    // Если загрузка закончилась и число не менялось, но анимации не было
    if (!widget.previewLoading && !_hasAnimated && widget.totalGoing != 0) {
      _lastKnownTotal = widget.totalGoing;
      _hasAnimated = true;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? const Color(0xFFB5BBC7);
    
    // Показываем последнее известное значение если загрузка, иначе новое
    final displayCount = widget.previewLoading 
        ? _lastKnownTotal 
        : widget.totalGoing;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_rounded,
              size: 14,
              color: effectiveColor.withOpacity(0.95),
            ),
            const SizedBox(width: 6),
TweenAnimationBuilder<int>(
  key: ValueKey('counter_${widget.totalGoing}_${widget.previewLoading}'), // используем totalGoing
  tween: IntTween(
    begin: _lastKnownTotal,
    end: displayCount,
  ),
  duration: const Duration(milliseconds: 500),
  curve: Curves.easeOutCubic,
  onEnd: () {
    if (!widget.previewLoading && _lastKnownTotal != widget.totalGoing) {
      setState(() {
        _lastKnownTotal = widget.totalGoing;
      });
    }
  },
  builder: (context, value, child) {
    return Text(
      '$value',
      style: TextStyle(
        color: effectiveColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.fade,
    );
  },
),
          ],
        ),
      ],
    );
  }
}