import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import '../../core/academic_catalog.dart';

/// Akademik takvim (Stitch 45): ay kartı (noktalar, bugün, seçili gün), ayın önemli tarihleri ve sıradaki önemli tarihler.
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
  String? _semester; // dönem adı (Sıradaki önemli tarihler başlığının sağında)
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
    _api.semesters().then((r) {
      final cur = r.items.where((x) => x.current).firstOrNull ?? r.items.firstOrNull;
      if (mounted && cur != null) setState(() => _semester = cur.name);
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
    final l = context.l10n;
    final err = _error;
    final maintenance = err is ApiError && err.status == 503;
    return AcademicScaffold(
      title: l.acadCalTitle,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (maintenance) ...[AkadNoticeCard(text: err.message.isNotEmpty ? err.message : l.acadMaintenance), const SizedBox(height: 14)],
            _monthCard(),
            const SizedBox(height: 20),
            ..._list(maintenance),
          ],
        ),
      ),
    );
  }

  Widget _navButton(BuTokens t, IconData icon, String tip, VoidCallback onTap) => Semantics(
        button: true,
        label: tip,
        excludeSemantics: true,
        onTap: onTap,
        child: Tooltip(
          message: tip,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Material(
              color: t.sf,
              shape: CircleBorder(side: BorderSide(color: t.bd.withValues(alpha: .7))),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(width: 44, height: 44, child: Icon(buDirIcon(context, icon), size: 20, color: t.ink)),
              ),
            ),
          ),
        ),
      );

  Widget _monthCard() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final today = istanbulWall(academicClock());
    return AkadCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, end: 0, bottom: 10),
          child: Row(children: [
            Icon(LucideIcons.calendarDays, size: 24, color: t.pr),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text('${monthNameL(l, _month.month)} ${_month.year}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              ),
            ),
            _navButton(t, LucideIcons.chevronLeft, l.acadCalPrev, () => _shift(-1)),
            _navButton(t, LucideIcons.chevronRight, l.acadCalNext, () => _shift(1)),
          ]),
        ),
        _grid(t, today),
        const SizedBox(height: 12),
        _legend(t, tx, l, today),
      ]),
    );
  }

  Widget _grid(BuTokens t, DateTime today) {
    final l = context.l10n;
    final lead = _month.weekday - 1;
    final daysIn = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final rows = ((lead + daysIn) / 7).ceil();
    return Column(children: [
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: ExcludeSemantics(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(dayShortL(l, i + 1), style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++) Expanded(child: _cell(t, DateTime.utc(_month.year, _month.month, r * 7 + c - lead + 1), today, c >= 5)),
        ]),
    ]);
  }

  Widget _cell(BuTokens t, DateTime date, DateTime today, bool weekend) {
    final inMonth = date.month == _month.month;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final evs = inMonth ? _events.where((e) => e.coversDay(date)).toList() : const <AcademicEvent>[];
    final isToday = today.year == date.year && today.month == date.month && today.day == date.day;
    final sel = _selected == date;
    final has = evs.isNotEmpty;
    final Color? bg = sel ? t.ink : (isToday ? t.pr : null);
    final Color fg = (sel || isToday)
        ? (sel ? t.bg : t.onPr)
        : !inMonth
            ? t.mut.withValues(alpha: .4)
            : has
                ? t.pr
                : (weekend ? t.mut : t.ink);
    void tap() => setState(() => _selected = sel ? null : date);
    return Semantics(
      button: true,
      selected: sel,
      label: '${date.day} ${monthNameL(l, date.month)}${isToday ? ', ${l.acadCalToday}' : ''}${has ? ', ${l.acadCalEventCount(evs.length.toString())}' : ''}',
      excludeSemantics: true,
      onTap: tap,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: inMonth ? tap : null,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Container(
          width: 46,
          height: 52,
          decoration: BoxDecoration(color: bg, shape: bg == null ? BoxShape.rectangle : BoxShape.rectangle, borderRadius: BorderRadius.circular(23)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.2,
              child: Text('${date.day}', style: tx.titleSmall!.copyWith(fontWeight: sel || isToday || has ? FontWeight.w800 : FontWeight.w500, color: fg)),
            ),
            const SizedBox(height: 3),
            Container(width: 5, height: 5, decoration: BoxDecoration(color: has ? ((sel || isToday) ? t.soft : t.pr) : Colors.transparent, shape: BoxShape.circle)),
          ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(BuTokens t, TextTheme tx, AppLocalizations l, DateTime today) {
    Widget item(Color c, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
        ]);
    final todayText = '${today.day} ${monthNameL(l, today.month)}';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 6,
      children: [
        item(t.pr, l.p20CalToday(todayText)),
        Row(mainAxisSize: MainAxisSize.min, children: [item(t.ink, l.p20CalSelected), const SizedBox(width: 14), item(t.pr, l.p20CalImportant)]),
      ],
    );
  }

  List<Widget> _list(bool maintenance) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    if (_loading && _events.isEmpty) {
      return [
        Semantics(
          label: l.commonLoading,
          liveRegion: true,
          child: const BuSkeletonScope(
            child: Column(children: [
              BuSkeleton(height: 110, radius: 20),
              SizedBox(height: 12),
              BuSkeleton(height: 110, radius: 20),
            ]),
          ),
        ),
      ];
    }
    if (_error != null && _events.isEmpty && !maintenance) {
      return [AkadErrorCard(title: l.sistemuiErrorTitle, message: errorText(_error!), onRetry: _load, retryLabel: l.acadRetry)];
    }
    final sel = _selected;
    final dayEvents = sel == null ? const <AcademicEvent>[] : (_events.where((e) => e.coversDay(sel)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt)));
    final monthEvents = [..._events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final out = <Widget>[];
    if (sel != null) {
      out.add(_dayCard(t, tx, l, sel, dayEvents));
      for (final e in dayEvents) {
        out.add(const SizedBox(height: 12));
        out.add(_eventCard(e));
      }
    } else if (monthEvents.isNotEmpty) {
      out.add(Row(children: [
        Expanded(child: Semantics(header: true, child: Text(l.acadCalMonthHeading(monthNameL(l, _month.month)), style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)))),
        const SizedBox(width: 8),
        AkadPill(l.acadCalEventCount(monthEvents.length.toString()), bg: t.sf2, fg: t.mut),
      ]));
      for (final e in monthEvents) {
        out.add(const SizedBox(height: 12));
        out.add(_eventCard(e));
      }
    }
    if (sel != null || monthEvents.isEmpty) {
      if (_next.isNotEmpty) {
        out
          ..add(const SizedBox(height: 24))
          ..add(Row(children: [
            Expanded(child: Semantics(header: true, child: Text(l.acadCalNextHeading, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)))),
            if (_semester != null) ...[const SizedBox(width: 8), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: Text(_semester!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut)))],
          ]));
        for (final e in _next) {
          out
            ..add(const SizedBox(height: 12))
            ..add(_eventCard(e, nextStyle: true));
        }
      }
      if (sel == null && monthEvents.isEmpty && !_loading) {
        out
          ..add(const SizedBox(height: 20))
          ..add(_emptyMonth(t, tx, l));
      }
    }
    return out;
  }

  Widget _dayCard(BuTokens t, TextTheme tx, AppLocalizations l, DateTime day, List<AcademicEvent> evs) {
    final longDate = DateFormat('d MMMM y, EEEE', Localizations.localeOf(context).toString()).format(day);
    return Semantics(
      container: true,
      child: AkadCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          AkadIconTile(icon: evs.isEmpty ? LucideIcons.calendarX : LucideIcons.calendarDays, bg: t.sf2, fg: t.mut, size: 56, radius: 16, iconSize: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(longDate, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.pr)),
              const SizedBox(height: 2),
              Text(evs.isEmpty ? l.acadCalNoDay : l.acadCalEventCount(evs.length.toString()),
                  style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _emptyMonth(BuTokens t, TextTheme tx, AppLocalizations l) => Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bLg),
          child: Row(children: [
            AkadIconTile(icon: LucideIcons.calendarCheck, bg: t.sf, fg: t.ink, size: 48, radius: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(akadUpper(context, monthNameL(l, _month.month)),
                    style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, letterSpacing: l.localeName == 'ar' ? 0 : .8, color: t.mut)),
                Text(l.acadCalNoMonth, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: t.ink)),
              ]),
            ),
          ]),
        ),
      );

  String _range(AppLocalizations l, AcademicEvent e) {
    final s = e.startDay, en = e.endDay;
    final w = istanbulWall(e.startsAt);
    final midnight = w.hour == 0 && w.minute == 0;
    final startText = e.allDay
        ? fmtWallDateL(l, s)
        : (midnight ? '${fmtWallDateL(l, s)} (${l.p20HalfDay})' : fmtInstantL(l, e.startsAt));
    if (en == s) return startText;
    return '${fmtWallDateL(l, s)} - ${fmtWallDateL(l, en)}';
  }

  IconData _kindIcon(String k) => switch (k) {
        'DONEM_BASLANGIC' => LucideIcons.graduationCap,
        'DERS_KAYIT' => LucideIcons.userCheck,
        'VIZE' || 'FINAL' || 'BUT' => LucideIcons.clipboardList,
        'RESMI_TATIL' => LucideIcons.flag,
        'TATIL' => LucideIcons.sun,
        _ => LucideIcons.calendar,
      };

  /// Önemli tarih kartı: tür etiketi + aralık, başlık, açıklama. [nextStyle]: sağda yalnız tür etiketi + tarih satırı altta.
  Widget _eventCard(AcademicEvent e, {bool nextStyle = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final kind = eventKindLabelL(l, e.kind);
    final range = _range(l, e);
    final color = eventKindColor(e.kind);
    final dark = e.kind == 'DONEM_BASLANGIC';
    final chip = AkadPill(kind, bg: dark ? t.ink : akadTint(context, color), fg: dark ? t.bg : akadOnTint(context, color), icon: _kindIcon(e.kind));
    final days = e.endDay.difference(e.startDay).inDays + 1;
    final span = days <= 1 ? (e.allDay ? l.p20AllDay : l.p20HalfDay) : (days >= 7 ? l.p20RangeWeeks((days / 7).round().toString()) : l.p20RangeDays(days.toString()));
    final note = [if (e.scopeDepartment != null) context.departmentName(e.scopeDepartment), if (e.note != null) e.note!].join(' · ');
    final w = e.startDay;
    final longDay = DateFormat('d MMMM y, EEEE', Localizations.localeOf(context).toString()).format(w);
    return Semantics(
      container: true,
      label: '$kind: ${e.title}. $range',
      excludeSemantics: true,
      child: AkadCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ConstrainedBox(constraints: BoxConstraints(maxWidth: nextStyle ? 220 : 150), child: chip),
            if (nextStyle) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Icon(days > 1 ? LucideIcons.calendarDays : LucideIcons.clock, size: 14, color: t.mut),
                  const SizedBox(width: 6),
                  Flexible(child: Text(span, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut))),
                ]),
              ),
            ],
            if (!nextStyle) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.calendar, size: 14, color: t.pr)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(range, maxLines: 2, textAlign: TextAlign.end, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut))),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Text(e.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
          if (nextStyle)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.endDay == e.startDay ? longDay : range, style: tx.bodyMedium!.copyWith(color: t.mut)))
          else if (note.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(note, style: tx.bodyMedium!.copyWith(color: t.mut))),
        ]),
      ),
    );
  }
}
