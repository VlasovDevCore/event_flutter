import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';

import '../../../models/event.dart';
import '../../../services/api_client.dart';

import 'event_preview_participants_row.dart';
import 'preview_participant.dart';

class VisibleEventsSheetContent extends StatefulWidget {
  const VisibleEventsSheetContent({
    super.key,
    required this.visibleEvents,
    required this.onEventTap,
    required this.sheetHeight,
  });

  final List<Event> visibleEvents;
  final void Function(Event event) onEventTap;
  final double sheetHeight;

  @override
  State<VisibleEventsSheetContent> createState() => _VisibleEventsSheetContentState();
}

class _ParticipantsData {
  const _ParticipantsData({
    required this.participants,
    required this.totalGoing,
  });

  final List<PreviewParticipant> participants;
  final int totalGoing;
}

class _VisibleEventsSheetContentState extends State<VisibleEventsSheetContent>
    with TickerProviderStateMixin {
  static const int _maxToLoad = 20;

  final Map<String, _ParticipantsData> _participantsByEventId = {};
  bool _loading = false;
  
  late final ScrollController _internalScrollController;
  double _currentSheetHeight = 0;
  
  // Переменные для drag-to-dismiss
  double _dragOffset = 0;
  double _dragStartY = 0;
  bool _isDragging = false;
  bool _isClosing = false;
  
  // Для отслеживания состояния скролла
  bool _isAtTop = true;
  bool _isDraggingToClose = false; // Флаг, что начали закрывать панель
  double _dragStartScrollPosition = 0; // Сохраняем позицию скролла в начале жеста
  
  // Для оптимизации производительности
  final _smoothCurve = Curves.easeInOutCubic;

  // (зарезервировано) Переменные для возможных жестов закрытия.
  double _scrollGestureStartSheetHeight = 0.0;
  bool _scrollGestureActive = false;

  @override
  void initState() {
    super.initState();
    _currentSheetHeight = widget.sheetHeight * 0.6;
    
    _internalScrollController = ScrollController();
    _internalScrollController.addListener(_checkScrollPosition);
    
    _loadParticipants();
  }

  @override
  void dispose() {
    _internalScrollController.removeListener(_checkScrollPosition);
    _internalScrollController.dispose();
    super.dispose();
  }

  void _checkScrollPosition() {
    if (!_internalScrollController.hasClients) return;
    
    final isAtTop = _internalScrollController.position.pixels <= 0;
    if (_isAtTop != isAtTop) {
      setState(() {
        _isAtTop = isAtTop;
        // Если достигли верха и не в процессе закрытия, сбрасываем флаг закрытия
        if (isAtTop && !_isClosing) {
          _isDraggingToClose = false;
        }
      });
    }
    
    // Логика расширения/сворачивания панели
    if (_isClosing || _isDragging) return;
  }

  @override
  void didUpdateWidget(VisibleEventsSheetContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIds = oldWidget.visibleEvents.map((e) => e.id).toList();
    final newIds = widget.visibleEvents.map((e) => e.id).toList();
    if (oldIds.join(',') != newIds.join(',')) {
      _participantsByEventId.clear();
      _loadParticipants();
    }
  }

  Future<void> _loadParticipants() async {
    if (widget.visibleEvents.isEmpty) return;

    final ids = widget.visibleEvents
        .take(_maxToLoad)
        .map((e) => e.id)
        .toList(growable: false);

    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait(ids.map((id) async {
        final data = await ApiClient.instance.get('/events/$id');
        final event = Event.fromApiMap(data);

        final participants = event.goingUserProfiles.isNotEmpty
            ? event.goingUserProfiles
                .map(
                  (p) => PreviewParticipant(
                    label: p.displayName ?? p.username ?? p.email ?? 'U',
                    avatarUrl: p.avatarUrl,
                    status: p.status,
                  ),
                )
                .toList()
            : event.goingUsers
                .map(
                  (email) => PreviewParticipant(
                    label: email,
                    avatarUrl: null,
                    status: 1,
                  ),
                )
                .toList();

        return MapEntry(
          id,
          _ParticipantsData(
            participants: participants,
            totalGoing: event.goingUsers.length,
          ),
        );
      }));

      if (!mounted) return;
      setState(() {
        for (final entry in results) {
          _participantsByEventId[entry.key] = entry.value;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatEventDateTimeLabel(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now().toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(local.year, local.month, local.day);
    final tomorrow = today.add(const Duration(days: 1));

    String dayPart;
    if (dateDay == today) {
      dayPart = 'Сегодня';
    } else if (dateDay == tomorrow) {
      dayPart = 'Завтра';
    } else {
      const weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
      // weekday: 1..7 (Пн..Вс)
      dayPart = weekdays[local.weekday % 7];
    }

    final time = DateFormat('HH:mm').format(local);
    return '$dayPart, $time';
  }

  void _closeSheet() {
    if (_isClosing) return;
    _isClosing = true;

    setState(() {
      _dragOffset = _currentSheetHeight;
    });

    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    if (_isClosing) return;
    
    _dragStartY = details.globalPosition.dy;
    _isDragging = true;
    _isDraggingToClose = false;

    // Защита от микро-дёрганий: на старте считаем, что сдвига еще нет.
    // (в норме _dragOffset уже 0, но это дополнительно гарантирует отсутствие "самозакрытия").
    _dragOffset = 0.0;
    
    // Сохраняем текущую позицию скролла
    if (_internalScrollController.hasClients) {
      _dragStartScrollPosition = _internalScrollController.position.pixels;
    }
  }

  bool _isScrollAtTopNow() {
    if (!_internalScrollController.hasClients) return true;
    return _internalScrollController.position.pixels <= 0.0;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_isClosing) return;
    _dragStartY = event.position.dy;
    _isDragging = true;
    _isDraggingToClose = false;

    // Защита от микро-самозакрытия.
    _dragOffset = 0.0;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isClosing || !_isDragging) return;

    final deltaY = event.position.dy - _dragStartY;

    // Тянем вверх — возвращаем панель.
    if (deltaY <= 0) {
      if (_dragOffset != 0.0) {
        setState(() {
          _dragOffset = 0.0;
          _isDraggingToClose = false;
        });
      }
      return;
    }

    const minDragToAffect = 6.0;
    if (deltaY < minDragToAffect) return;

    // Закрываем/уезжаем панели только если список действительно сверху.
    if (!_isScrollAtTopNow()) return;

    setState(() {
      _isDraggingToClose = true;
      final maxPull = _currentSheetHeight;
      _dragOffset = deltaY.clamp(0.0, maxPull);
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isClosing) return;
    _isDragging = false;

    // Для короткого свайпа: достаточно чуть-чуть опустить панель.
    const minDragToClose = 10.0;
    final isAtTopNow = _isScrollAtTopNow();
    final shouldClose = isAtTopNow && _dragOffset >= minDragToClose;

    if (shouldClose) {
      _closeSheet();
      return;
    }

    if (_dragOffset > 0) {
      setState(() {
        _dragOffset = 0.0;
        _isDraggingToClose = false;
      });
    } else {
      _isDraggingToClose = false;
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isClosing) return;
    
    final deltaY = details.globalPosition.dy - _dragStartY;

    // Игнорируем микро-сдвиги: пользователь должен реально "потянуть" вниз.
    // Иначе из-за конкуренции жестов может срабатывать закрытие.
    const minDragToAffect = 6.0;
    if (deltaY < minDragToAffect) {
      return;
    }
    
    // Если тянем вверх - возвращаем панель
    if (deltaY <= 0) {
      if (_dragOffset != 0) {
        setState(() {
          _dragOffset = 0;
          _isDraggingToClose = false;
        });
      }
      return;
    }
    
    // Разрешаем тянуть панель вниз только когда список в самом верху.
    // Не полагаемся только на флаг (_isAtTop), а проверяем реальную позицию скролла.
    final isAtTopNow = _internalScrollController.hasClients &&
        _internalScrollController.position.pixels <= 0.0;
    if (!isAtTopNow) return;

    if (!_isDraggingToClose) {
      setState(() {
        _isDraggingToClose = true;
      });
    }

    final maxPull = _currentSheetHeight;
    final next = deltaY.clamp(0.0, maxPull);

    if (next == _dragOffset) return;

    setState(() {
      _dragOffset = next;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isClosing) return;
    _isDragging = false;
    
    final isAtTopNow = _internalScrollController.hasClients &&
        _internalScrollController.position.pixels <= 0.0;

    // Закрываем, если тянули достаточно далеко вниз.
    // Порог задаём по dragOffset, а не по высоте видимой части,
    // чтобы работало предсказуемо на схлопнутом состоянии (~60%).
    const minDragToClose = 10.0;
    final shouldClose = isAtTopNow &&
        _dragOffset >= minDragToClose;

    if (shouldClose) {
      _closeSheet();
      return;
    }

    if (_dragOffset > 0) {
      // Возвращаем на место (остаёмся в текущем состоянии 80%/100%).
      setState(() {
        _dragOffset = 0;
        _isDraggingToClose = false;
      });
    } else {
      _isDraggingToClose = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF161616);
    final divider = Colors.white.withOpacity(0.08);
    final subtitleColor = const Color(0xFFB5BBC7);

    final dateFormat = DateFormat('dd.MM.yyyy');
    
    // Расчет прозрачности при закрытии (чем ниже опускаем панель — тем сильнее прячем).
    final opacity = 1.0 - (_dragOffset / _currentSheetHeight).clamp(0.0, 1.0);

    final visibleHeight = (_currentSheetHeight - _dragOffset).clamp(0.0, widget.sheetHeight);
    final heightRatio = (visibleHeight / widget.sheetHeight).clamp(0.0, 1.0);

    // Углы более скругленные на схлопнутом состоянии (60%) и менее — на 100%.
    final cornerRadiusCollapsed = 28.0;
    final cornerRadiusExpanded = 10.0;
    final t = ((heightRatio - 0.6) / 0.4).clamp(0.0, 1.0);
    final cornerRadius = cornerRadiusCollapsed + (cornerRadiusExpanded - cornerRadiusCollapsed) * t;

    // Ползунок исчезает на 100% и появляется на схлопнутом (60%).
    final handleHideT = ((heightRatio - 0.88) / 0.12).clamp(0.0, 1.0);
    final handleScale = (1.0 - handleHideT);
    
    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 340),
      curve: _smoothCurve,
      height: _currentSheetHeight - _dragOffset,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Opacity(
          opacity: opacity,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(cornerRadius)),
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Шапка с индикатором
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: 18 * handleScale,
                          bottom: 4 * handleScale,
                        ),
                        child: Center(
                          child: Container(
                            width: 60 * handleScale,
                            height: 3 * handleScale,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1 * handleScale),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft, // выравнивание по левому краю
                          child: Text(
                            'События рядом',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                Expanded(
                  child: widget.visibleEvents.isEmpty
                      ? Center(
                          child: Text(
                            'На карте событий нет',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: subtitleColor,
                            ),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            // Лист закрывается только drag-down.
                            return false;
                          },
                          child: Stack(
                            children: [
                              ListView.builder(
                                controller: _internalScrollController,
                                padding: const EdgeInsets.only(top: 12),
                                itemCount: widget.visibleEvents.length + 1,
                                physics: _isDraggingToClose
                                    ? const NeverScrollableScrollPhysics() // Блокируем скролл когда начали закрывать
                                    // Блокируем "отскок" сверху: если список в самом верху,
                                    // дальнейший скролл вверх больше не двигает контент.
                                    : const ClampingScrollPhysics(
                                        parent: AlwaysScrollableScrollPhysics(),
                                      ),
                                dragStartBehavior: DragStartBehavior.down,
                                itemBuilder: (context, index) {
                                  if (index == widget.visibleEvents.length) {
                                    return Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                          child: Text(
                                            'Тусить будем?\n${widget.visibleEvents.length} поводов',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF3B3A3A),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(height: 10), // отступ после футера
                                      ],
                                    );
                                  }

                                  final event = widget.visibleEvents[index];
                                  final color = Color(event.markerColorValue);
                                  final icon = IconData(
                                    event.markerIconCodePoint,
                                    fontFamily: 'MaterialIcons',
                                  );

                                  final date = event.endsAt ?? event.createdAt;

                                  final participantsData =
                                      _participantsByEventId[event.id];
                                  final previewLoading =
                                      participantsData == null;
                                  final participants =
                                      participantsData?.participants ?? const [];
                                  final totalGoing =
                                      participantsData?.totalGoing ?? 0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Color(0xFF141414),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        child: InkWell(
                                          splashFactory: NoSplash.splashFactory,
                                          highlightColor: Colors.transparent,
                                          onTap: () =>
                                              widget.onEventTap(event),
                                          child: ListTile(
                                            dense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 15,
                                              vertical: 5,
                                            ),
                                            leading: SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                icon,
                                                size: 20,
                                                color: color,
                                              ),
                                            ),
                                          ),
                                            ),
                                            title: Text(
                                              event.title,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                height: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.fade,
                                            ),
                                            subtitle: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 14,
                                                      color: subtitleColor
                                                          .withOpacity(0.9),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      _formatEventDateTimeLabel(
                                                          date),
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        color:
                                                            const Color(0xFFAAABB0),
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  '•',
                                                  style: TextStyle(
                                                    color: subtitleColor,
                                                    fontSize: 16,
                                                    height: 1,
                                                  ),
                                                ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Align(
                                                        alignment:
                                                            Alignment.centerRight,
                                                        child:
                                                            EventPreviewParticipantsRow(
                                                          participants:
                                                              participants,
                                                          totalGoing: totalGoing,
                                                          previewLoading:
                                                              previewLoading,
                                                          color: const Color(
                                                              0xFF8FF5FF),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Градиентный оверлей: плавно "скрывает" контент под шапкой
                              // и выглядит как блок, а не как тонкая линия.
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 18,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          const Color(0xFF161616).withOpacity(1.0),
                                          const Color(0xFF161616).withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),      
      ),
    );
  }
}