import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../profile_cover_gradient.dart';
import 'hue_ring_picker.dart';

/// Размер квадратов выбора цвета (меньше — компактнее шторка).
const double _kCoverColorSquareSize = 44;

/// Кольцо оттенка без внутреннего SV-квадрата: padding ≈ радиус − wheelWidth.
const double _kWheelSize = 180;
const double _kWheelWidth = 14;

/// Шторка: три цвета градиента обложки и превью.
Future<void> showProfileCoverEditSheet(
  BuildContext context, {
  required List<String> initialHexColors,
  required Future<void> Function(List<String> hexColors) onSave,
}) async {
  final c1 = hexToColor(initialHexColors[0]) ?? hexToColor(kDefaultCoverGradientHex[0])!;
  final c2 = hexToColor(initialHexColors[1]) ?? hexToColor(kDefaultCoverGradientHex[1])!;
  final c3 = hexToColor(initialHexColors[2]) ?? hexToColor(kDefaultCoverGradientHex[2])!;

  var color1 = c1;
  var color2 = c2;
  var color3 = c3;
  var saving = false;
  String? errorText;

  Future<void> pickColor(
    BuildContext sheetContext,
    void Function(void Function()) setSheetState,
    Color current,
    BuildContext anchorContext,
    void Function(Color) onLiveColor,
  ) async {
    await _showWheelPickerOverlayAtAnchor(
      sheetContext: sheetContext,
      anchorContext: anchorContext,
      initialColor: current,
      onColorChanged: (c) {
        onLiveColor(c);
        setSheetState(() {});
      },
    );
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 2, 16, 14),
                    child: Text(
                      'Градиент обложки',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 100,
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [color1, color2, color3],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: _kCoverColorSquareSize,
                          height: _kCoverColorSquareSize,
                          child: _CoverColorSquare(
                            color: color1,
                            onTap: saving
                                ? null
                                : (anchorCtx) async {
                                    await pickColor(
                                      sheetContext,
                                      setSheetState,
                                      color1,
                                      anchorCtx,
                                      (c) => setSheetState(() {
                                        color1 = c;
                                        errorText = null;
                                      }),
                                    );
                                  },
                          ),
                        ),
                        SizedBox(
                          width: _kCoverColorSquareSize,
                          height: _kCoverColorSquareSize,
                          child: _CoverColorSquare(
                            color: color2,
                            onTap: saving
                                ? null
                                : (anchorCtx) async {
                                    await pickColor(
                                      sheetContext,
                                      setSheetState,
                                      color2,
                                      anchorCtx,
                                      (c) => setSheetState(() {
                                        color2 = c;
                                        errorText = null;
                                      }),
                                    );
                                  },
                          ),
                        ),
                        SizedBox(
                          width: _kCoverColorSquareSize,
                          height: _kCoverColorSquareSize,
                          child: _CoverColorSquare(
                            color: color3,
                            onTap: saving
                                ? null
                                : (anchorCtx) async {
                                    await pickColor(
                                      sheetContext,
                                      setSheetState,
                                      color3,
                                      anchorCtx,
                                      (c) => setSheetState(() {
                                        color3 = c;
                                        errorText = null;
                                      }),
                                    );
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        errorText!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setSheetState(() {
                                  saving = true;
                                  errorText = null;
                                });
                                try {
                                  await onSave([
                                    colorToHexRgb(color1),
                                    colorToHexRgb(color2),
                                    colorToHexRgb(color3),
                                  ]);
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                } on ApiException catch (e) {
                                  setSheetState(() {
                                    saving = false;
                                    errorText = e.message;
                                  });
                                } catch (e) {
                                  setSheetState(() {
                                    saving = false;
                                    errorText = e.toString();
                                  });
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Сохранить'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

/// Колесо цвета во всплывающем окне рядом с [anchorContext].
Future<void> _showWheelPickerOverlayAtAnchor({
  required BuildContext sheetContext,
  required BuildContext anchorContext,
  required Color initialColor,
  required ValueChanged<Color> onColorChanged,
}) async {
  final overlay = Overlay.maybeOf(sheetContext, rootOverlay: true) ?? Overlay.of(sheetContext);
  final box = anchorContext.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    await showDialog<void>(
      context: sheetContext,
      barrierDismissible: true,
      barrierColor: const Color(0x66000000),
      builder: (ctx) {
        Color draft = initialColor;
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Center(
              child: Material(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: _kWheelSize,
                    height: _kWheelSize,
                    child: HueRingPicker(
                      color: draft,
                      wheelWidth: _kWheelWidth,
                      borderColor: Colors.white24,
                      onChanged: (c) {
                        draft = c;
                        onColorChanged(c);
                        setLocal(() {});
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return;
  }

  final origin = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);

  final completer = Completer<void>();
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _WheelPickerOverlay(
      anchorRect: anchorRect,
      initialColor: initialColor,
      onColorChanged: onColorChanged,
      onDismissed: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _WheelPickerOverlay extends StatefulWidget {
  const _WheelPickerOverlay({
    required this.anchorRect,
    required this.initialColor,
    required this.onColorChanged,
    required this.onDismissed,
  });

  final Rect anchorRect;
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onDismissed;

  @override
  State<_WheelPickerOverlay> createState() => _WheelPickerOverlayState();
}

class _WheelPickerOverlayState extends State<_WheelPickerOverlay>
    with SingleTickerProviderStateMixin {
  late Color _draft;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<double> _scale;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialColor;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _fade = curved;
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _anim.reverse().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final pad = media.padding;
    const popupW = _kWheelSize + 24;
    const popupH = _kWheelSize + 24;
    const gap = 8.0;

    final minTop = pad.top + gap;
    final maxTop = screen.height -
        pad.bottom -
        media.viewInsets.bottom -
        popupH -
        gap;

    double left = widget.anchorRect.center.dx - popupW / 2;
    double top = widget.anchorRect.top - gap - popupH;

    if (left < pad.left + gap) left = pad.left + gap;
    if (left + popupW > screen.width - pad.right - gap) {
      left = screen.width - pad.right - gap - popupW;
    }

    if (top < minTop) {
      top = widget.anchorRect.bottom + gap;
    }
    if (top > maxTop) {
      top = maxTop;
    }
    if (top < minTop) {
      top = minTop;
    }

    return FadeTransition(
      opacity: _fade,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: popupW,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.center,
              child: Material(
                elevation: 12,
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: _kWheelSize,
                    height: _kWheelSize,
                    child: HueRingPicker(
                      color: _draft,
                      wheelWidth: _kWheelWidth,
                      borderColor: Colors.white24,
                      onChanged: (c) {
                        setState(() => _draft = c);
                        widget.onColorChanged(c);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Один квадрат цвета (размер задаёт родитель [SizedBox]).
class _CoverColorSquare extends StatelessWidget {
  const _CoverColorSquare({
    required this.color,
    required this.onTap,
  });

  final Color color;
  final Future<void> Function(BuildContext anchorContext)? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(context),
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
