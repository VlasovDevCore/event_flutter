import 'package:flutter/material.dart';
import '../../../../models/event.dart';
import '../../events/event_details_screen.dart';
import '../chat_appearance.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Event event;

  const ChatAppBar({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final chat = EventChatTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      title: Text(
        event.title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      backgroundColor: chat.appBar,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: chat.appBarDivider),
      ),
      actions: [
        _RoundIconButton(
          icon: Icons.info_outline_rounded,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EventDetailsScreen(event: event),
              ),
            );
          },
          tooltip: 'Подробности события',
          alignEnd: true,
        ),
      ],
      leading: _RoundIconButton(
        icon: Icons.arrow_back_rounded,
        onPressed: () => Navigator.of(context).maybePop(),
        alignEnd: false,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.alignEnd = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: alignEnd ? 0 : 8, right: alignEnd ? 8 : 0),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: scheme.onSurface,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
