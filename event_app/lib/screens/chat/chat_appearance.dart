import 'package:flutter/material.dart';

/// Токены оформления чата события — согласованы с [ThemeData.colorScheme].
class EventChatTheme {
  const EventChatTheme._(this._scheme);
  final ColorScheme _scheme;

  static EventChatTheme of(BuildContext context) =>
      EventChatTheme._(Theme.of(context).colorScheme);

  Color get scaffold => _scheme.surface;

  Color get appBar => _scheme.surface;
  Color get appBarDivider => _scheme.outlineVariant.withValues(alpha: 0.35);

  /// Пузырь своего сообщения
  Color get bubbleMine => _scheme.primaryContainer;
  Color get onBubbleMine => _scheme.onPrimaryContainer;

  /// Пузырь собеседника
  Color get bubbleOther => _scheme.surfaceContainerHighest;
  Color get bubbleOtherBorder => _scheme.outline.withValues(alpha: 0.24);
  Color get onBubbleOther => _scheme.onSurface;

  /// Подпись имени (бирюзовый акцент как в карточках / эмодзи-панели)
  Color get senderName => _scheme.tertiary;

  Color get inputBar => _scheme.surfaceContainerLow;
  Color get inputField => _scheme.surfaceContainerHighest;
  Color get inputDivider => _scheme.outline.withValues(alpha: 0.2);

  Color get dayPillBg => _scheme.surfaceContainerHighest.withValues(alpha: 0.55);
  Color get dayPillBorder => _scheme.outline.withValues(alpha: 0.18);
  Color get metaMuted => _scheme.onSurfaceVariant;

  Color get shadowSoft => Colors.black.withValues(alpha: 0.32);

  Color get sheetBackground => _scheme.surfaceContainerHigh;

  Color get floatingControlFill =>
      _scheme.surfaceContainerHighest.withValues(alpha: 0.94);
  Color get floatingControlBorder => _scheme.outline.withValues(alpha: 0.22);

  Color get errorBannerBg => _scheme.errorContainer.withValues(alpha: 0.35);
  Color get onErrorBanner => _scheme.onErrorContainer;

  Color get editingBannerBg => _scheme.surfaceContainerHigh;
  Color get editingAccent => _scheme.primary;
}
