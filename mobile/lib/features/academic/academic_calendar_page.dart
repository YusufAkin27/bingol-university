import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';

/// Akademik takvim: ay görünümü + o aydaki önemli tarihler; sıradaki önemli tarihler.
class AcademicCalendarPage extends StatefulWidget {
  const AcademicCalendarPage({super.key, required this.session});

  final Session session;

  @override
  State<AcademicCalendarPage> createState() => _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends State<AcademicCalendarPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  late DateTime _month = () {
    final w = istanbulWall(academicClock());
    return DateTime.utc(w.year, w.month);
  }();
  DateTime? _selected;
  List<AcademicEvent> _events = [];
  List<AcademicEvent> _next = [];
  bool _loading = true;
  Object? _error;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _api.nextEvents().then((v) {
      if (mounted) setState(() => _next = v);
    }).catchError((_) {});
  }

  Future<void> _load() async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.calendar(_month.year, _month.month);
      if (!mounted || gen != _gen) return;
      setState(() {
        _events = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _shift(int by) {
    setState(() {
      _month = DateTime.utc(_month.year, _month.month + by);
      _selected = null;
      _events = [];
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AcademicScaffold(
      title: 'Akademik takvim',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
        children: [
          _monthHeader(t),
          const SizedBox(height: 8),
          _grid(t),
          const SizedBox(height: 16),
          ..._list(t),
        ],
      ),
    );
  }

  Widget _monthHeader(BuTokens t) => Row(children: [
        BuIconButton(icon: LucideIcons.chevronLeft, tooltip: 'Önceki ay', onTap: () => _shift(-1), size: 40),
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Text('${monthNames[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink)),
          ),
        ),
        BuIconButton(icon: LucideIcons.chevronRight, tooltip: 'Sonraki ay', onTap: () => _shift(1), size: 40),
      ]);

  Widget _grid(BuTokens t) {
    final first = _month;
    final daysIn = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final rows = ((lead + daysIn) / 7).ceil();
    final today = istanbulWall(academicClock());
    return Column(children: [
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(child: Center(child: ExcludeSemantics(child: Text(dayShort[i], style: BuType.micro.copyWith(color: t.mut))))),
      ]),
      const SizedBox(height: 4),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++) Expanded(child: _cell(t, r * 7 + c - lead + 1, daysIn, today)),
        ]),
    ]);
  }

  Widget _cell(BuTokens t, int day, int daysIn, DateTime today) {
    if (day < 1 || day > daysIn) return const SizedBox(height: 46);
    final date = DateTime.utc(_month.year, _month.month, day);
    final evs = _events.where((e) => e.coversDay(date)).toList();
    final isToday = today.year == date.year && today.month == date.month && today.day == day;
    final sel = _selected == date;
    return Semantics(
      button: true,
      selected: sel,
      label: '$day ${monthNames[date.month - 1]}${isToday ? ', bugün' : ''}${evs.isEmpty ? '' : ', ${evs.length} önemli tarih'}',
      excludeSemantics: true,
      onTap: () => setState(() => _selected = sel ? null : date),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selected = sel ? null : date),
        child: Container(
          height: 46,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: sel ? t.soft : null,
            borderRadius: BorderRadius.circular(12),
            border: isToday ? Border.all(color: t.pr, width: 1.5) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: BuType.bodyStrong.copyWith(color: sel ? t.onSoft : t.ink)),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final e in evs.take(3))
                  Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: eventKindColor(e.kind), shape: BoxShape.circle)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _list(BuTokens t) {
    if (_loading && _events.isEmpty) return [const SizedBox(height: 160, child: LoadingView())];
    if (_error != null && _events.isEmpty) return [SizedBox(height: 260, child: AcademicErrorView(error: _error!, onRetry: _load))];
    final shown = (_selected == null ? _events : _events.where((e) => e.coversDay(_selected!)).toList())
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return [
      Text(_selected == null ? '${monthNames[_month.month - 1]} ayı önemli tarihleri' : fmtWallDate(_selected!),
          style: BuType.heading.copyWith(color: t.ink)),
      const SizedBox(height: 10),
      if (shown.isEmpty)
        Text(_selected == null ? 'Bu ay için kayıtlı önemli tarih yok.' : 'Bu günde önemli tarih yok.', style: BuType.body.copyWith(color: t.mut))
      else
        for (final e in shown) Padding(padding: const EdgeInsets.only(bottom: 8), child: _eventCard(t, e)),
      if (_selected == null && _next.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('Sıradaki önemli tarihler', style: BuType.heading.copyWith(color: t.ink)),
        const SizedBox(height: 10),
        for (final e in _next) Padding(padding: const EdgeInsets.only(bottom: 8), child: _eventCard(t, e)),
      ],
    ];
  }

  String _range(AcademicEvent e) {
    final s = e.startDay, en = e.endDay;
    final startText = e.allDay ? fmtWallDate(s) : fmtInstant(e.startsAt);
    if (en == s) return startText;
    return '${fmtWallDate(s)} - ${fmtWallDate(en)}';
  }

  Widget _eventCard(BuTokens t, AcademicEvent e) => ColorCard(
        color: eventKindColor(e.kind),
        semanticLabel: '${eventKindLabel(e.kind)}: ${e.title}. ${_range(e)}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BuBadge(eventKindLabel(e.kind), color: eventKindColor(e.kind), onColor: Colors.white),
          const SizedBox(height: 6),
          Text(e.title, style: BuType.bodyStrong.copyWith(color: t.ink)),
          MetaLine(LucideIcons.calendarRange, _range(e)),
          if (e.scopeDepartment != null) MetaLine(LucideIcons.graduationCap, e.scopeDepartment!),
          if (e.note != null) MetaLine(LucideIcons.info, e.note!),
        ]),
      );
}
