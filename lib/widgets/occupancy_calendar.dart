// lib/widgets/occupancy_calendar.dart
//
// Widget unificat de calendar — v5.
//
// MODURI:
//   CalendarMode.dateOnly  — selectie interval de zile (tehnica_page)
//   CalendarMode.dateTime  — selectie interval cu ora exacta (comanda_form_sheet)
//
// FUNCTIONALITATI:
//   • Drag-to-select + tap pentru selectie interval
//   • Banda continua (stil Google Calendar)
//   • Time picker cu chip-uri editabile independent
//   • Zile trecute blocate, ore respecta logica zi/interval
//   • Overlap check pe rezervari existente
//   • Tooltip hover/long-press cu detalii rezervare
//   • Legenda dinamica per santier

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/occupancy_period.dart';
import '../approval_theme.dart';

// ── API public ────────────────────────────────────────────────────────────────

enum CalendarMode { dateOnly, dateTime }

const List<Color> kPeriodColors = [
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFE53935),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
  Color(0xFFF4511E),
  Color(0xFF6D4C41),
  Color(0xFF00897B),
];

Color colorForPeriod(int idx) => kPeriodColors[idx % kPeriodColors.length];

Color? _parseHex(String? hex) {
  if (hex == null) return null;
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return null;
  }
}

// ── Pasii de selectie ─────────────────────────────────────────────────────────

enum _Step { startDay, pickTimes, done }
enum _Editing { none, startDay, startTime, endDay, endTime }

// ── Slot de timp predefinit ───────────────────────────────────────────────────

class _TimeSlot {
  final int hour;
  final int minute;
  const _TimeSlot(this.hour, this.minute);

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DateTime on(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  bool isAfter(_TimeSlot other) =>
      hour > other.hour || (hour == other.hour && minute > other.minute);

  @override
  bool operator ==(Object other) =>
      other is _TimeSlot && hour == other.hour && minute == other.minute;

  @override
  int get hashCode => hour * 60 + minute;
}

// Sloturi 07:00–23:30, pas 30 min
List<_TimeSlot> _buildSlots() {
  final slots = <_TimeSlot>[];
  for (int h = 7; h <= 23; h++) {
    slots.add(_TimeSlot(h, 0));
    if (h < 23) slots.add(_TimeSlot(h, 30));
  }
  return slots;
}

final _kSlots = _buildSlots();


// =============================================================================
// OccupancyCalendar
// =============================================================================

class OccupancyCalendar extends StatefulWidget {
  final List<OccupancyPeriod> periods;
  final CalendarMode mode;
  final OccupancyPeriod? editingPeriod;
  final int selectionColorIndex;
  final String? selectionHexColor;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final void Function(DateTime start, DateTime end)? onRangeChanged;
  final bool showActions;
  final bool saving;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final void Function(OccupancyPeriod)? onReservationTap;
  final bool allowNoTime;

  const OccupancyCalendar({
    super.key,
    required this.periods,
    this.mode = CalendarMode.dateOnly,
    this.editingPeriod,
    this.selectionColorIndex = 0,
    this.selectionHexColor,
    this.initialStart,
    this.initialEnd,
    this.onRangeChanged,
    this.showActions = false,
    this.saving = false,
    this.onCancel,
    this.onConfirm,
    this.onReservationTap,
    this.allowNoTime = false,
  });

  @override
  State<OccupancyCalendar> createState() => _OccupancyCalendarState();
}

class _OccupancyCalendarState extends State<OccupancyCalendar>
    with TickerProviderStateMixin {

  late DateTime _month;
  _Step     _step      = _Step.startDay;
  DateTime? _selStart;  // ziua de start (date-only)
  DateTime? _selEnd;    // ziua de end   (date-only)
  DateTime? _start;     // DateTime complet cu ora
  DateTime? _end;       // DateTime complet cu ora
  String?   _overlapError;

  // Drag state
  DateTime? _dragAnchor;
  DateTime? _dragCurrent;
  bool      _isDragging = false;

  // Referinte celule pentru drag hit-test
  final Map<DateTime, GlobalKey> _cellKeys = {};

  // Time picker state
  _TimeSlot? _startSlot;
  _TimeSlot? _endSlot;
  _Editing   _editing = _Editing.none;

  // Panel timp
  late final AnimationController _timeCtrl;
  late final Animation<double>   _timeFade;

  // Tooltip
  OverlayEntry? _tooltip;
  DateTime?     _tooltipDay;

  bool get _isDateTime  => widget.mode == CalendarMode.dateTime;
  bool get _canConfirm  => _start != null && _end != null;
  Color get _selColor   =>
      _parseHex(widget.selectionHexColor) ?? colorForPeriod(widget.selectionColorIndex);

  // Zile efective de selectie (drag in curs sau finalizat)
  DateTime? get _dispStart => _isDragging
      ? (_dragAnchor!.isBefore(_dragCurrent!) ? _dragAnchor : _dragCurrent)
      : _selStart;
  DateTime? get _dispEnd => _isDragging
      ? (_dragAnchor!.isBefore(_dragCurrent!) ? _dragCurrent : _dragAnchor)
      : _selEnd;

  @override
  void initState() {
    super.initState();


    _timeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _timeFade = CurvedAnimation(parent: _timeCtrl, curve: Curves.easeOut);

    _prefill();
  }

  void _prefill() {
    final s = widget.initialStart;
    final e = widget.initialEnd;
    if (s != null) {
      _selStart = _day(s);
      _start    = s;
      _month    = DateTime(s.year, s.month);
      if (_isDateTime) _startSlot = _TimeSlot(s.hour, s.minute);
    } else {
      final now = DateTime.now();
      _month = DateTime(now.year, now.month);
    }
    if (e != null) {
      _selEnd = _day(e);
      _end    = e;
      if (_isDateTime) _endSlot = _TimeSlot(e.hour, e.minute);
    }
    if (_selStart != null && _selEnd != null) {
      _step = _Step.done;
      _editing = _Editing.none;
      if (_isDateTime) _timeCtrl.value = 1.0;
    } else if (_selStart != null) {
      _step = _isDateTime ? _Step.pickTimes : _Step.startDay;
      if (_isDateTime) _timeCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _clearTooltip();
    _timeCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static String _fmtD(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  static String _fmtDT(DateTime d) =>
      '${_fmtD(d)}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  static String _monthName(int m) => const [
    'Ianuarie','Februarie','Martie','Aprilie','Mai','Iunie',
    'Iulie','August','Septembrie','Octombrie','Noiembrie','Decembrie',
  ][m - 1];
  static String _dayAbbr(int w) =>
      const ['Lu','Ma','Mi','Jo','Vi','Sâ','Du'][w - 1];

  // ── Perioade per zi ───────────────────────────────────────────────────────

  List<_Entry> _periodsForDay(DateTime day) {
    final d = _day(day);
    final res = <_Entry>[];
    for (int i = 0; i < widget.periods.length; i++) {
      final p = widget.periods[i];
      if (_isEditing(p)) continue;
      if (!d.isBefore(_day(p.from)) && !d.isAfter(_day(p.to))) {
        res.add(_Entry(i, p));
      }
    }
    return res;
  }


  bool _hasOverlap(DateTime s, DateTime e) {
    for (final p in widget.periods) {
      if (_isEditing(p)) continue;
      if (!s.isAfter(p.to) && !e.isBefore(p.from)) return true;
    }
    return false;
  }

  Color _colorFor(_Entry e) =>
      _parseHex(e.period.santierColor) ?? colorForPeriod(e.idx);

  // ── Logica selectie zile ──────────────────────────────────────────────────

  void _onDayTap(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      _overlapError = null;
      if (_editing == _Editing.startDay) {
        _selStart = day;
        if (_startSlot != null) _start = _startSlot!.on(day);
        if (_selEnd != null && !day.isBefore(_selEnd!)) { _selEnd = null; _endSlot = null; _end = null; }
        _editing = _Editing.none;
        if (_start != null && _end != null) widget.onRangeChanged?.call(_start!, _end!);
        return;
      }
      if (_editing == _Editing.endDay) {
        if (!day.isBefore(_selStart ?? day)) {
          _selEnd = day;
          if (_endSlot != null) _end = _endSlot!.on(day);
          _editing = _Editing.none;
          if (_start != null && _end != null) widget.onRangeChanged?.call(_start!, _end!);
        }
        return;
      }
      if (_step == _Step.done) {
        if (_selStart != null && _same(day, _selStart!)) {
          _editing = _Editing.startTime;
        } else if (_selEnd != null && _same(day, _selEnd!)) {
          _editing = _Editing.endTime;
        } else if (_selStart != null && day.isBefore(_selStart!)) {
          _selStart = day;
          if (_startSlot != null) _start = _startSlot!.on(day);
          _editing = _Editing.none;
          if (_start != null && _end != null) widget.onRangeChanged?.call(_start!, _end!);
        } else {
          _selEnd = day;
          if (_endSlot != null) { _end = _endSlot!.on(day); if (_start != null) widget.onRangeChanged?.call(_start!, _end!); }
          _editing = _Editing.none;
        }
        return;
      }
      if (_step == _Step.startDay || (_selStart != null && _same(day, _selStart!) && _selEnd == null)) {
        _selStart = day; _selEnd = null; _start = null; _end = null; _startSlot = null; _endSlot = null; _editing = _Editing.none;
        if (_isDateTime) { _step = _Step.pickTimes; _timeCtrl.forward(from: 0); }
        else { _step = _Step.startDay; }
      } else if (_selStart != null) {
        final lo = _selStart!.isBefore(day) ? _selStart! : day;
        final hi = _selStart!.isBefore(day) ? day : _selStart!;
        _selStart = lo; _selEnd = hi; _editing = _Editing.none;
        if (_isDateTime) {
          if (_same(lo, hi) && _startSlot != null) {
            final endH = _startSlot!.hour + 1;
            _endSlot = _TimeSlot(endH <= 23 ? endH : 23, _startSlot!.minute);
            _end = _endSlot!.on(hi); _start = _startSlot!.on(lo);
            if (_hasOverlap(_start!, _end!)) { _overlapError = 'Intervalul se suprapune cu o rezervație existentă!'; _resetSelection(); return; }
            _step = _Step.done; widget.onRangeChanged?.call(_start!, _end!);
          } else { _step = _Step.pickTimes; _timeCtrl.forward(); }
        } else {
          if (_hasOverlap(lo, hi.add(const Duration(hours: 23, minutes: 59)))) { _overlapError = 'Intervalul se suprapune cu o rezervație existentă!'; _resetSelection(); return; }
          _start = lo; _end = hi; _step = _Step.done; widget.onRangeChanged?.call(_start!, _end!);
        }
      } else {
        _selStart = day; _selEnd = null; _start = null; _end = null; _startSlot = null; _endSlot = null; _editing = _Editing.none;
        if (_isDateTime) { _step = _Step.pickTimes; _timeCtrl.forward(from: 0); }
        else { _step = _Step.startDay; }
      }
    });
  }

  void _resetSelection() {
    _selStart = null; _selEnd = null;
    _start = null; _end = null;
    _startSlot = null; _endSlot = null;
    _editing = _Editing.none;
    _step = _Step.startDay;
    _timeCtrl.reverse();
  }

  void _reset() {
    setState(() { _resetSelection(); _overlapError = null; });
  }

  // ── Drag-to-select ────────────────────────────────────────────────────────

  // Determina ce zi e la pozitia globala data
  DateTime? _dayAtGlobalPos(Offset global) {
    for (final entry in _cellKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos  = box.localToGlobal(Offset.zero);
      final rect = pos & box.size;
      if (rect.contains(global)) return entry.key;
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    final day = _dayAtGlobalPos(d.globalPosition);
    if (day == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isDragging  = true;
      _dragAnchor  = _day(day);
      _dragCurrent = _day(day);
      _overlapError = null;
      _selStart = null; _selEnd = null;
      _start = null; _end = null;
      _startSlot = null; _endSlot = null;
      _step = _Step.startDay;
      _timeCtrl.reverse();
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    final day = _dayAtGlobalPos(d.globalPosition);
    if (day == null) return;
    final clamped = _day(day);
    if (_dragCurrent != null && _same(_dragCurrent!, clamped)) return;
    HapticFeedback.selectionClick();
    setState(() => _dragCurrent = clamped);
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_isDragging) return;
    final lo = _dispStart!;
    final hi = _dispEnd!;
    setState(() {
      _isDragging = false;
      _selStart = lo; _selEnd = hi;
      _dragAnchor = null; _dragCurrent = null;

      if (_isDateTime) {
        _step = _Step.pickTimes;
        _timeCtrl.forward(from: 0);
      } else {
        if (_hasOverlap(lo, hi.add(const Duration(hours: 23, minutes: 59)))) {
          _overlapError = 'Intervalul se suprapune cu o rezervație existentă!';
          _resetSelection(); return;
        }
        _start = lo; _end = hi;
        _step  = _Step.done;
        widget.onRangeChanged?.call(_start!, _end!);
      }
    });
  }

  // ── Time slot selection ───────────────────────────────────────────────────

  void _onSlotTap(_TimeSlot slot) {
    if (_selStart == null) return;
    setState(() {
      _overlapError = null;

      // ── _editing are prioritate maxima ────────────────────────────────────
      if (_editing == _Editing.startTime) {
        _startSlot = slot; _start = slot.on(_selStart!); _editing = _Editing.none;
        if (_end != null) widget.onRangeChanged?.call(_start!, _end!);
        HapticFeedback.selectionClick();
        return;
      }
      if (_editing == _Editing.endTime) {
        final endDay = _selEnd ?? _selStart!;
        final candidate = slot.on(endDay);
        if (_same(_selStart!, endDay) && _start != null && !candidate.isAfter(_start!)) {
          _overlapError = 'Aceeași zi: ora finală trebuie să fie după ora de start!'; return;
        }
        _endSlot = slot; _end = candidate; _editing = _Editing.none; _step = _Step.done;
        if (_start != null) widget.onRangeChanged?.call(_start!, _end!);
        HapticFeedback.lightImpact();
        return;
      }

      // ── Flux normal ───────────────────────────────────────────────────────
      if (_startSlot == null) {
        _startSlot = slot;
        _start = slot.on(_selStart!);
        HapticFeedback.selectionClick();
      } else if (_endSlot == null) {
        final endDay = _selEnd ?? _selStart!;
        final candidate = slot.on(endDay);
        if (_same(_selStart!, endDay) && !candidate.isAfter(_start!)) {
          _overlapError = 'Aceeași zi: ora de final trebuie să fie după ora de start!'; return;
        }
        if (_hasOverlap(_start!, candidate)) {
          _overlapError = 'Intervalul se suprapune cu o rezervație existentă!';
          _resetSelection(); return;
        }
        _endSlot = slot; _end = candidate; _step = _Step.done;
        HapticFeedback.lightImpact();
        widget.onRangeChanged?.call(_start!, _end!);
      } else {
        // Ambele setate, nicio editare — reseteaza startSlot
        _startSlot = slot; _start = slot.on(_selStart!);
        _endSlot = null; _end = null;
        _step = _Step.pickTimes;
        HapticFeedback.selectionClick();
      }
    });
  }

  void _editStartDay()  => setState(() { _editing = _Editing.startDay;  _overlapError = null; });
  void _editStartTime() => setState(() { _editing = _Editing.startTime; _overlapError = null; });
  void _editEndDay()    => setState(() { _editing = _Editing.endDay;    _overlapError = null; });
  void _editEndTime()   => setState(() { _editing = _Editing.endTime;   _overlapError = null; });
  void _cancelEdit()    => setState(() { _editing = _Editing.none; });

  void _onNoTime() {
    if (_selStart == null) return;
    setState(() {
      _overlapError = null;
      final noTimeSlot = _TimeSlot(0, 0);
      if (_startSlot == null) {
        _startSlot = noTimeSlot; _start = _selStart!;
        HapticFeedback.selectionClick();
      } else if (_endSlot == null) {
        final endDay = _selEnd ?? _selStart!;
        _endSlot = noTimeSlot; _end = endDay;
        if (_selEnd == null) _selEnd = _selStart;
        _step = _Step.done;
        HapticFeedback.lightImpact();
        widget.onRangeChanged?.call(_start!, _end!);
      }
    });
  }

  bool _isEditing(OccupancyPeriod p) {
    final ep = widget.editingPeriod;
    if (ep == null) return false;
    if (ep.comenzaId.isNotEmpty && p.comenzaId.isNotEmpty) return p.comenzaId == ep.comenzaId;
    return p.from == ep.from && p.to == ep.to;
  }

  bool _slotOccupied(_TimeSlot slot) {
    final day = (_editing == _Editing.endTime || (_startSlot != null && _endSlot == null))
        ? (_selEnd ?? _selStart)
        : _selStart;
    if (day == null) return false;

    final s = slot.on(day);
    final e = s.add(const Duration(minutes: 29));
    for (final p in widget.periods) {
      if (_isEditing(p)) continue;
      if (!p.from.isAfter(e) && !p.to.isBefore(s)) return true;
    }
    return false;
  }

  bool _slotDisabled(_TimeSlot slot) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = _selEnd ?? _selStart;
    if (day == null) return false;

    // Zile diferite — nicio restrictie
    if (_selStart != null && _selEnd != null && !_same(_selStart!, _selEnd!)) {
      return false;
    }

    // Aceeasi zi: ore trecute blocate doar daca e azi
    if (_same(day, today) && slot.on(day).isBefore(now)) return true;

    // Aceeasi zi: end trebuie dupa start
    if (_startSlot != null && _endSlot == null) {
      if (!slot.isAfter(_startSlot!)) return true;
    }

    return false;
  }

  // ── Tooltip ───────────────────────────────────────────────────────────────

  void _showTooltip(BuildContext cellCtx, DateTime day, List<_Entry> entries) {
    if (entries.isEmpty) return;
    _clearTooltip();
    _tooltipDay = day;
    final box    = cellCtx.findRenderObject() as RenderBox;
    final pos    = box.localToGlobal(Offset.zero);
    final screen = MediaQuery.of(context).size;
    _tooltip = OverlayEntry(builder: (_) {
      const w = 250.0;
      double l = pos.dx;
      double t = pos.dy + box.size.height + 4;
      if (l + w > screen.width - 8) l = screen.width - w - 8;
      if (l < 8) l = 8;
      return Positioned(
        left: l, top: t,
        child: _TooltipCard(
          entries:  entries,
          colorFor: _colorFor,
          onTap:    widget.onReservationTap,
          onClose:  _clearTooltip,
        ),
      );
    });
    Overlay.of(context, rootOverlay: true).insert(_tooltip!);
  }

  void _clearTooltip() {
    _tooltip?.remove(); _tooltip = null; _tooltipDay = null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary     = Theme.of(context).colorScheme.primary;
    final firstDay    = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startWd     = firstDay.weekday;

    // Legenda
    final mEnd   = DateTime(_month.year, _month.month + 1, 0);
    final legendMap = <String, _Entry>{};
    for (int i = 0; i < widget.periods.length; i++) {
      final p = widget.periods[i];
      if (_isEditing(p)) continue;
      if (!p.from.isAfter(mEnd) && !p.to.isBefore(firstDay)) {
        legendMap.putIfAbsent(p.santierId, () => _Entry(i, p));
      }
    }

    return GestureDetector(
      onTap:         _clearTooltip,
      behavior:      HitTestBehavior.translucent,
      onPanStart:    _onPanStart,
      onPanUpdate:   _onPanUpdate,
      onPanEnd:      _onPanEnd,
      child: Container(
        decoration: BoxDecoration(
          color: ApprovalTheme.surfaceBackground(context),
          borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
          border: Border.all(color: ApprovalTheme.borderColor(context)),
        ),
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Navigare luna ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(children: [
                _NavBtn(icon: Icons.chevron_left, onTap: () => setState(() =>
                _month = DateTime(_month.year, _month.month - 1))),
                Expanded(
                  child: Text('${_monthName(_month.month)} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: ApprovalTheme.textTitle(context)),
                ),
                _NavBtn(icon: Icons.chevron_right, onTap: () => setState(() =>
                _month = DateTime(_month.year, _month.month + 1))),
              ]),
            ),

            const Divider(height: 12),

            // ── Header zile ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: List.generate(7, (i) => Expanded(
                child: Center(child: Text(_dayAbbr(i + 1),
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: i == 6
                          ? Colors.red.withOpacity(0.7)
                          : ApprovalTheme.textSecondary(context),
                    ))),
              ))),
            ),
            const SizedBox(height: 4),

            // ── Grid zile (stil banda continua) ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _CalendarGrid(
                month:         _month,
                daysInMonth:   daysInMonth,
                startWd:       startWd,
                selStart:      _dispStart,
                selEnd:        _dispEnd,
                selColor:      _selColor,
                primaryColor:  primary,
                periodsForDay: _periodsForDay,
                colorFor:      _colorFor,
                onDayTap:      _onDayTap,
                onTooltip:     _showTooltip,
                onClearTooltip: _clearTooltip,
                tooltipDay:    _tooltipDay,
                cellKeys:      _cellKeys,
                today:         _day(DateTime.now()),
              ),
            ),

            // ── Time picker (dateTime mode) ───────────────────────────────
            if (_isDateTime)
              FadeTransition(
                opacity: _timeFade,
                child: SizeTransition(
                  sizeFactor: _timeFade,
                  child: _selStart != null
                      ? _TimePanel(
                    selStart:    _selStart,
                    selEnd:      _selEnd,
                    startSlot:   _startSlot,
                    endSlot:     _endSlot,
                    slots:       _kSlots,
                    selColor:    _selColor,
                    isOccupied:    _slotOccupied,
                    isDisabled:    _slotDisabled,
                    onSlotTap:     _onSlotTap,
                    allowNoTime:   widget.allowNoTime,
                    onNoTime:      _onNoTime,
                    editing:       _editing,
                    onEditStart:   _editStartDay,
                    onEditStartT:  _editStartTime,
                    onEditEnd:     _editEndDay,
                    onEditEndT:    _editEndTime,
                    onCancelEdit:  _cancelEdit,
                  )
                      : const SizedBox.shrink(),
                ),
              ),

            // ── Status / erroare ──────────────────────────────────────────
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: _overlapError != null
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.warning_amber_rounded, size: 14,
                    color: ApprovalTheme.errorColor(context)),
                const SizedBox(width: 6),
                Flexible(child: Text(_overlapError!,
                    style: TextStyle(fontSize: 12,
                        color: ApprovalTheme.errorColor(context),
                        fontWeight: FontWeight.w500))),
              ])
                  : AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(key: ValueKey(_statusTxt), _statusTxt,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _canConfirm ? _selColor
                          : ApprovalTheme.textSecondary(context),
                      fontWeight: _canConfirm
                          ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
            ),

            // ── Legenda ───────────────────────────────────────────────────
            if (legendMap.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Divider(height: 1, color: ApprovalTheme.dividerColor(context)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, runSpacing: 4, children: [
                    _LegendDot(color: Colors.grey, label: 'În așteptare', pending: true),
                    _LegendDot(color: Colors.grey, label: 'Aprobat', pending: false),
                    ...legendMap.values.map((e) => _LegendDot(
                        color: _colorFor(e),
                        label: e.period.rentedBy ?? 'Santier',
                        pending: false)),
                  ]),
                ]),
              ),
            ],

            // ── Actiuni ───────────────────────────────────────────────────
            if (widget.showActions) ...[
              const Divider(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () { _reset(); widget.onCancel?.call(); },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: ApprovalTheme.borderColor(context)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium)),
                    ),
                    child: const Text('Anulează'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(
                    onPressed: (_canConfirm && !widget.saving) ? widget.onConfirm : null,
                    style: ApprovalTheme.primaryButtonStyle(context).copyWith(
                      padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 10)),
                    ),
                    child: widget.saving
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Salvează'),
                  )),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _statusTxt {
    if (_editing == _Editing.startDay)  return 'Apasă pe noua zi de start';
    if (_editing == _Editing.endDay)    return 'Apasă pe noua zi de final';
    if (_editing == _Editing.startTime) return 'Alege ora de start';
    if (_editing == _Editing.endTime)   return 'Alege ora de final';
    if (_step == _Step.startDay && _selStart == null) return 'Apasă sau trage pentru a selecta interval';
    if (_isDateTime) {
      if (_selStart != null && _startSlot == null) return 'Start: ${_fmtD(_selStart!)}  •  alege ora de start';
      if (_startSlot != null && _selEnd == null) return 'Start: ${_startSlot!.label}  •  alege ziua finală';
      if (_startSlot != null && _selEnd != null && _endSlot == null) return 'Final: ${_fmtD(_selEnd!)}  •  alege ora de final';
    } else {
      if (_selStart != null && _selEnd == null) return 'De la: ${_fmtD(_selStart!)}  •  selectează ziua finală';
    }
    if (_start != null && _end != null) {
      return '${_isDateTime ? _fmtDT(_start!) : _fmtD(_start!)}  →  ${_isDateTime ? _fmtDT(_end!) : _fmtD(_end!)}';
    }
    return '';
  }
}

// =============================================================================
// _CalendarGrid — gridul de zile cu stil banda continua
// =============================================================================

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final int daysInMonth;
  final int startWd;
  final DateTime? selStart;
  final DateTime? selEnd;
  final Color selColor;
  final Color primaryColor;
  final List<_Entry> Function(DateTime) periodsForDay;
  final Color Function(_Entry) colorFor;
  final void Function(DateTime) onDayTap;
  final void Function(BuildContext, DateTime, List<_Entry>) onTooltip;
  final VoidCallback onClearTooltip;
  final DateTime? tooltipDay;
  final Map<DateTime, GlobalKey> cellKeys;
  final DateTime today;

  const _CalendarGrid({
    required this.month,
    required this.daysInMonth,
    required this.startWd,
    required this.selStart,
    required this.selEnd,
    required this.selColor,
    required this.primaryColor,
    required this.periodsForDay,
    required this.colorFor,
    required this.onDayTap,
    required this.onTooltip,
    required this.onClearTooltip,
    required this.tooltipDay,
    required this.cellKeys,
    required this.today,
  });

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCells = (startWd - 1) + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final idx = row * 7 + col;
            if (idx < startWd - 1 || idx >= (startWd - 1) + daysInMonth) {
              return const Expanded(child: SizedBox(height: 38));
            }
            final num     = idx - (startWd - 1) + 1;
            final day     = DateTime(month.year, month.month, num);
            final entries = periodsForDay(day);
            final isToday = _same(day, today);
            final isWend  = day.weekday >= 6;
            final occupied = entries.isNotEmpty;

            final isStart = selStart != null && _same(day, selStart!);
            final isEnd   = selEnd   != null && _same(day, selEnd!);
            final inRange = selStart != null && selEnd != null &&
                !day.isBefore(selStart!) && !day.isAfter(selEnd!);
            final isSingle = isStart && isEnd;

            final isEndpoint = isStart || isEnd;

            BorderRadius cellRadius;
            if (!inRange) {
              cellRadius = BorderRadius.circular(isEndpoint ? 20 : 6);
            } else if (isSingle) {
              cellRadius = BorderRadius.circular(20);
            } else if (isStart) {
              cellRadius = const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              );
            } else if (isEnd) {
              cellRadius = const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              );
            } else {
              cellRadius = BorderRadius.circular(4);
            }

            Color? bgColor;
            if (isEndpoint) {
              bgColor = selColor;
            } else if (inRange) {
              bgColor = selColor.withOpacity(isDark ? 0.22 : 0.15);
            } else if (occupied) {
              bgColor = colorFor(entries.first).withOpacity(isDark ? 0.18 : 0.12);
            }

            Color textColor;
            if (isEndpoint) {
              textColor = Colors.white;
            } else if (inRange) {
              textColor = selColor;
            } else if (occupied) {
              textColor = colorFor(entries.first);
            } else if (isToday) {
              textColor = primaryColor;
            } else if (isWend) {
              textColor = Colors.red.withOpacity(0.7);
            } else {
              textColor = Theme.of(context).textTheme.bodyMedium?.color
                  ?? ApprovalTheme.textBody(context).color!;
            }

            // Registra chiave per drag hit-test
            cellKeys[day] ??= GlobalKey();

            return Expanded(
              child: Builder(builder: (cellCtx) => MouseRegion(
                onEnter: occupied ? (_) => onTooltip(cellCtx, day, entries) : null,
                onExit:  occupied ? (_) => onClearTooltip() : null,
                child: GestureDetector(
                  key: cellKeys[day],
                  onTap: () => onDayTap(day),
                  onLongPress: occupied
                      ? () => onTooltip(cellCtx, day, entries) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 38,
                    margin: EdgeInsets.symmetric(
                      vertical: 1.5,
                      horizontal: inRange && !isEndpoint ? 0 : 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: cellRadius,
                      border: isEndpoint ? null
                          : isToday
                          ? Border.all(color: primaryColor, width: 2.0)
                          : occupied && !inRange
                          ? Border.all(
                          color: colorFor(entries.first).withOpacity(0.45),
                          width: 1.0)
                          : null,
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      Text('$num',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: (isEndpoint || isToday || occupied)
                                ? FontWeight.bold : FontWeight.normal,
                            color: textColor,
                          )),
                      if (occupied && !isEndpoint && !inRange)
                        Positioned(bottom: 3, left: 0, right: 0,
                            child: _Dots(entries: entries, colorFor: colorFor)),
                    ]),
                  ),
                ),
              )),
            );
          }),
        );
      }),
    );
  }
}

// =============================================================================
// _TimePanel — selector sloturi ora (single-step, sub calendar)
// =============================================================================

class _TimePanel extends StatelessWidget {
  final DateTime? selStart;
  final DateTime? selEnd;
  final _TimeSlot? startSlot;
  final _TimeSlot? endSlot;
  final List<_TimeSlot> slots;
  final Color selColor;
  final bool Function(_TimeSlot) isOccupied;
  final bool Function(_TimeSlot) isDisabled;
  final void Function(_TimeSlot) onSlotTap;
  final bool allowNoTime;
  final VoidCallback onNoTime;
  final _Editing editing;
  final VoidCallback onEditStart;
  final VoidCallback onEditStartT;
  final VoidCallback onEditEnd;
  final VoidCallback onEditEndT;
  final VoidCallback onCancelEdit;

  const _TimePanel({
    required this.selStart,
    required this.selEnd,
    required this.startSlot,
    required this.endSlot,
    required this.slots,
    required this.selColor,
    required this.isOccupied,
    required this.isDisabled,
    required this.onSlotTap,
    this.allowNoTime = false,
    required this.onNoTime,
    this.editing = _Editing.none,
    required this.onEditStart,
    required this.onEditStartT,
    required this.onEditEnd,
    required this.onEditEndT,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool pickingStart = startSlot == null;
    final bool pickingEnd   = startSlot != null && endSlot == null;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : selColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        border: Border.all(
            color: selColor.withOpacity(0.20), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header cu editare selectiva ──────────────────────────────────
        Row(children: [
          _EditableChip(
            icon: Icons.calendar_today_outlined,
            label: selStart != null ? '${selStart!.day.toString().padLeft(2, "0")}.${selStart!.month.toString().padLeft(2, "0")}' : 'Zi',
            color: selColor, isActive: editing == _Editing.startDay, isFilled: selStart != null,
            onTap: editing == _Editing.startDay ? onCancelEdit : onEditStart,
          ),
          const SizedBox(width: 3),
          _EditableChip(
            icon: Icons.access_time_outlined,
            label: startSlot != null ? startSlot!.label : '--:--',
            color: selColor, isActive: editing == _Editing.startTime || pickingStart, isFilled: startSlot != null,
            onTap: editing == _Editing.startTime ? onCancelEdit : onEditStartT,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded, size: 13, color: ApprovalTheme.textSecondary(context)),
          ),
          _EditableChip(
            icon: Icons.calendar_today_outlined,
            label: selEnd != null ? '${selEnd!.day.toString().padLeft(2, "0")}.${selEnd!.month.toString().padLeft(2, "0")}' : 'Zi',
            color: selColor, isActive: editing == _Editing.endDay, isFilled: selEnd != null,
            onTap: editing == _Editing.endDay ? onCancelEdit : onEditEnd,
          ),
          const SizedBox(width: 3),
          _EditableChip(
            icon: Icons.access_time_outlined,
            label: endSlot != null ? endSlot!.label : '--:--',
            color: selColor, isActive: editing == _Editing.endTime || pickingEnd, isFilled: endSlot != null,
            onTap: editing == _Editing.endTime ? onCancelEdit : onEditEndT,
          ),
        ]),

        const SizedBox(height: 10),

        // ── Grid sloturi ─────────────────────────────────────────────────
        Wrap(
          spacing: 4, runSpacing: 4,
          children: slots.map((slot) {
            final occ      = isOccupied(slot);
            final disabled = isDisabled(slot) || occ;
            final isSelStart = slot == startSlot;
            final isSelEnd   = slot == endSlot;
            final isSelected = isSelStart || isSelEnd;

            Color bg, fg;
            Color? border;

            if (occ) {
              final occColor = isDark
                  ? Colors.red.withOpacity(0.25)
                  : Colors.red.withOpacity(0.10);
              bg = occColor;
              fg = Colors.red.withOpacity(0.5);
              border = Colors.red.withOpacity(0.3);
            } else if (isSelected) {
              bg = selColor;
              fg = Colors.white;
            } else if (disabled) {
              bg = isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.04);
              fg = ApprovalTheme.textSecondary(context).withOpacity(0.3);
            } else {
              // Slot disponibil — verde subtil
              bg = isDark
                  ? Colors.green.shade900.withOpacity(0.35)
                  : const Color(0xFFE8F5E9);
              fg = isDark ? Colors.green.shade300 : Colors.green.shade800;
            }

            return GestureDetector(
              onTap: disabled ? null : () => onSlotTap(slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 62, height: 30,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                  border: border != null
                      ? Border.all(color: border, width: 1)
                      : isSelected ? null
                      : Border.all(
                      color: fg.withOpacity(0.25), width: 0.8),
                  boxShadow: isSelected
                      ? [BoxShadow(color: selColor.withOpacity(0.35),
                      blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(slot.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    )),
              ),
            );
          }).toList(),
        ),

        if (allowNoTime) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onNoTime,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selColor.withOpacity(0.35))),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_outlined, size: 13, color: selColor.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text('Fără oră exactă', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selColor.withOpacity(0.7))),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// =============================================================================
// _EditableChip
// =============================================================================

class _EditableChip extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  final bool isActive; final bool isFilled; final VoidCallback onTap;
  const _EditableChip({required this.icon, required this.label, required this.color,
    required this.isActive, required this.isFilled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    if (isActive) { bg = color.withOpacity(0.15); fg = color; border = color; }
    else if (isFilled) { bg = color; fg = Colors.white; border = color; }
    else { bg = Colors.transparent; fg = ApprovalTheme.textSecondary(context); border = ApprovalTheme.borderColor(context); }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: isActive ? 1.5 : 1),
            boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6)] : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          if (isFilled && !isActive) ...[const SizedBox(width: 3), Icon(Icons.edit_outlined, size: 9, color: fg.withOpacity(0.7))],
        ]),
      ),
    );
  }
}


// =============================================================================
// _Entry
// =============================================================================

class _Entry {
  final int idx;
  final OccupancyPeriod period;
  const _Entry(this.idx, this.period);
}

// =============================================================================
// _Dots
// =============================================================================

class _Dots extends StatelessWidget {
  final List<_Entry> entries;
  final Color Function(_Entry) colorFor;
  const _Dots({required this.entries, required this.colorFor});

  @override
  Widget build(BuildContext context) {
    const max = 3;
    final vis = entries.take(max).toList();
    final ovf = entries.length - max;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      ...vis.map((e) {
        final c       = colorFor(e);
        final pending = e.period.isPending;
        return Container(
          width: 5, height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:  pending ? c.withOpacity(0.6) : c,
            border: pending ? Border.all(color: c, width: 0.8) : null,
          ),
        );
      }),
      if (ovf > 0)
        Padding(
          padding: const EdgeInsets.only(left: 1),
          child: Text('+$ovf',
              style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold,
                  color: ApprovalTheme.textSecondary(context))),
        ),
    ]);
  }
}

// =============================================================================
// _TooltipCard
// =============================================================================

class _TooltipCard extends StatelessWidget {
  final List<_Entry>                   entries;
  final Color Function(_Entry)         colorFor;
  final void Function(OccupancyPeriod)? onTap;
  final VoidCallback                   onClose;

  const _TooltipCard({
    required this.entries,
    required this.colorFor,
    required this.onTap,
    required this.onClose,
  });

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} '
          '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      width: 250,
      decoration: BoxDecoration(
        color: ApprovalTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(ApprovalTheme.radiusMedium),
        border: Border.all(color: ApprovalTheme.borderColor(context)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 13,
                color: ApprovalTheme.primaryAccent(context)),
            const SizedBox(width: 6),
            Expanded(child: Text('Rezervări (${entries.length})',
                style: ApprovalTheme.textSmall(context)
                    .copyWith(fontWeight: FontWeight.bold))),
            GestureDetector(onTap: onClose,
                child: Icon(Icons.close, size: 15,
                    color: ApprovalTheme.textSecondary(context))),
          ]),
        ),
        Divider(height: 1, color: ApprovalTheme.dividerColor(context)),
        ...entries.map((e) {
          final p = e.period; final c = colorFor(e);
          return GestureDetector(
            onTap: onTap != null ? () => onTap!(p) : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(
                  color: ApprovalTheme.dividerColor(context), width: 0.5))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 9, height: 9,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: p.isPending ? c.withOpacity(0.65) : c)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p.rentedBy ?? 'Rezervat',
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600, color: c))),
                  _Badge(pending: p.isPending),
                ]),
                const SizedBox(height: 3),
                _TRow(icon: Icons.access_time_outlined,
                    text: '${_fmt(p.from)} – ${_fmt(p.to)}'),
              ]),
            ),
          );
        }),
      ]),
    ),
  );
}

class _TRow extends StatelessWidget {
  final IconData icon; final String text;
  const _TRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 10, color: ApprovalTheme.textSecondary(context)),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: ApprovalTheme.textTiny(context),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
    ],
  );
}

class _Badge extends StatelessWidget {
  final bool pending;
  const _Badge({required this.pending});
  @override
  Widget build(BuildContext context) {
    final c = pending
        ? ApprovalTheme.warningColor(context)
        : ApprovalTheme.successColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(pending ? 'Așteptare' : 'Aprobat',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c)),
    );
  }
}

// =============================================================================
// _LegendDot
// =============================================================================

class _LegendDot extends StatelessWidget {
  final Color color; final String label; final bool pending;
  const _LegendDot({required this.color, required this.label, required this.pending});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 9, height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:  pending ? color.withOpacity(0.65) : color,
            border: pending ? Border.all(color: color, width: 1.2) : null,
          )),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10,
          color: ApprovalTheme.textSecondary(context))),
    ],
  );
}

// =============================================================================
// _NavBtn
// =============================================================================

class _NavBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Icon(icon, size: 20, color: ApprovalTheme.textSecondary(context)),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
  );
}