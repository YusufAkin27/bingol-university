import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';

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
      title: context.l10n.acadCalTitle,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
        children: [
          AkadCard(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(children: [
              _monthHeader(t),
              _grid(t),
            ]),
          ),
          const SizedBox(height: 14),
          ..._list(t),
        ],
      ),
    );
  }

  Widget _monthHeader(BuTokens t) {
    final l = context.l10n;
    Widget nav(IconData icon, String tip, VoidCallback onTap) => Semantics(
          button: true,
          label: tip,
          child: Tooltip(
            message: tip,
            excludeFromSemantics: true,
            child: Material(
              color: t.bg,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(width: 44, height: 44, child: Icon(buDirIcon(context, icon), size: 18, color: t.ink)),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        nav(LucideIcons.chevronLeft, l.acadCalPrev, () => _shift(-1)),
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Text('${monthNameL(l, _month.month)} ${_month.year}',
                textAlign: TextAlign.center, style: BuType.heading.copyWith(fontSize: 16, fontWeight: FontWeight.w800, color: t.ink)),
          ),
        ),
        nav(LucideIcons.chevronRight, l.acadCalNext, () => _shift(1)),
      ]),
    );
  }

  Widget _grid(BuTokens t) {
    final first = _month;
    final daysIn = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final rows = ((lead + daysIn) / 7).ceil();
    final today = istanbulWall(academicClock());
    final l = context.l10n;
    return Column(children: [
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: ExcludeSemantics(
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(dayShortL(l, i + 1), style: BuType.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: t.mut))),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      for (var r = 0; r < rows; r++)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(children: [
            for (var c = 0; c < 7; c++) ...[
              if (c > 0) const SizedBox(width: 2),
              Expanded(child: _cell(t, r * 7 + c - lead + 1, daysIn, today)),
            ],
          ]),
        ),
    ]);
  }

  Widget _cell(BuTokens t, int day, int daysIn, DateTime today) {
    if (day < 1 || day > daysIn) return const SizedBox(height: 44);
    final date = DateTime.utc(_month.year, _month.month, day);
    final evs = _events.where((e) => e.coversDay(date)).toList();
    // Çok günlü aralıklar (sınav haftası, tatil) gün zeminini boyar; tek günlükler nokta olur.
    final ranges = evs.where((e) => e.endDay.isAfter(e.startDay)).toList();
    final dots = evs.where((e) => !e.endDay.isAfter(e.startDay)).take(3).toList();
    final isToday = today.year == date.year && today.month == date.month && today.day == day;
    final sel = _selected == date;
    final l = context.l10n;
    final rangeColor = ranges.isEmpty ? null : eventKindColor(ranges.first.kind);
    final bg = sel ? t.pr : (rangeColor != null ? akadTint(context, rangeColor) : null);
    final fg = sel ? t.onPr : (rangeColor != null ? akadOnTint(context, rangeColor) : t.ink);
    return Semantics(
      button: true,
      selected: sel,
      label: '$day ${monthNameL(l, date.month)}${isToday ? ', ${l.acadCalToday}' : ''}${evs.isEmpty ? '' : ', ${l.acadCalEventCount(evs.length.toString())}'}',
      excludeSemantics: true,
      onTap: () => setState(() => _selected = sel ? null : date),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selected = sel ? null : date),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: isToday ? Border.all(color: t.pr, width: 1.5) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: BuType.bodyStrong.copyWith(fontSize: 14, fontWeight: rangeColor != null || sel ? FontWeight.w700 : FontWeight.w600, color: fg)),
            SizedBox(
              height: 6,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final e in dots)
                  Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(color: sel ? t.onPr : akadOnTint(context, eventKindColor(e.kind)), shape: BoxShape.circle)),
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
    final l = context.l10n;
    final shown = (_selected == null ? _events : _events.where((e) => e.coversDay(_selected!)).toList())
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return [
      AkadSection(_selected == null ? l.acadCalMonthHeading(monthNameL(l, _month.month)) : fmtWallDateL(l, _selected!)),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6),
          child: Text(_selected == null ? l.acadCalNoMonth : l.acadCalNoDay, style: BuType.body.copyWith(color: t.mut)),
        )
      else
        _eventGroup(t, shown),
      if (_selected == null && _next.isNotEmpty) ...[
        const SizedBox(height: 14),
        AkadSection(l.acadCalNextHeading),
        _eventGroup(t, _next),
      ],
    ];
  }

  String _range(AppLocalizations l, AcademicEvent e) {
    final s = e.startDay, en = e.endDay;
    final startText = e.allDay ? fmtWallDateL(l, s) : fmtInstantL(l, e.startsAt);
    if (en == s) return startText;
    return '${fmtWallDateL(l, s)} - ${fmtWallDateL(l, en)}';
  }

  Widget _eventGroup(BuTokens t, List<AcademicEvent> events) => AkadCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) const AkadDivider(),
            _eventRow(t, events[i]),
          ],
        ]),
      );

  Widget _eventRow(BuTokens t, AcademicEvent e) {
    final l = context.l10n;
    final kind = eventKindLabelL(l, e.kind);
    final range = _range(l, e);
    final color = eventKindColor(e.kind);
    final tint = akadTint(context, color);
    final on = akadOnTint(context, color);
    final sd = e.startDay;
    Widget sub(String s) => Text(s, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.mut));
    return Semantics(
      container: true,
      label: '$kind: ${e.title}. $range',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          AkadDateTile(month: monthNameL(l, sd.month), day: sd.day, bg: tint, fg: on, width: 50, height: 50, daySize: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)),
              sub(range),
              if (e.scopeDepartment != null) sub(e.scopeDepartment!),
              if (e.note != null) sub(e.note!),
            ]),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 104), child: AkadPill(kind, bg: tint, fg: on)),
        ]),
      ),
    );
  }
}
