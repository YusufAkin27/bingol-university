import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'acad_ref_widgets.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import '../../core/academic_catalog.dart';

/// Akademik takvim (Stitch v3 05): "DÖNEM YARIYILI" + "Güne dön", ay gezgini (< Ay Yıl >), kartsız ay ızgarası (önemli
/// günlerde nokta, seçili gün `soft` daire) ve "Akademik olaylar" satırları (tarih + gün adı solda, olay adı sağda).
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
  int _monthDir = 1; // ay geçişi yönü (+1 ileri / -1 geri)
  List<AcademicEvent> _events = [];
  List<AcademicEvent> _next = [];
  String? _semester; // dönem adı (üstteki "DÖNEM YARIYILI" etiketi)
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

  void _shift(int by) => _goMonth(DateTime.utc(_month.year, _month.month + by), by >= 0 ? 1 : -1);

  void _goMonth(DateTime m, int dir, {DateTime? select}) {
    final same = m.year == _month.year && m.month == _month.month;
    setState(() {
      _monthDir = dir;
      _month = DateTime.utc(m.year, m.month);
      _selected = select;
      if (!same) _events = [];
    });
    if (!same) _load();
  }

  /// "Güne dön": bugünün ayına geçer ve bugünü seçer.
  void _goToday() {
    final w = istanbulWall(academicClock());
    final m = DateTime.utc(w.year, w.month);
    final dir = m.isBefore(_month) ? -1 : 1;
    _goMonth(m, dir, select: DateTime.utc(w.year, w.month, w.day));
  }

  /// Ay adına dokununca: tarih seçici ile istenen aya geç.
  Future<void> _pickMonth() async {
    final l = context.l10n;
    final d = await pickAcadDate(context,
        initial: DateTime(_month.year, _month.month), first: DateTime(_month.year - 3), last: DateTime(_month.year + 3), help: l.acadCalTitle);
    if (d == null || !mounted) return;
    final m = DateTime.utc(d.year, d.month);
    _goMonth(m, m.isBefore(_month) ? -1 : 1, select: DateTime.utc(d.year, d.month, d.day));
  }

  bool _isExam(String kind) => kind == 'VIZE' || kind == 'FINAL' || kind == 'BUT';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final err = _error;
    final maintenance = err is ApiError && err.status == 503;
    return AcademicScaffold(
      title: l.acadCalTitle,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (maintenance) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: AcadAmberNote(text: err.message.isNotEmpty ? err.message : l.acadMaintenance)),
            // Üst satır: dönem etiketi + "Güne dön" (dokunma alanı 48 dp, metin üste hizalı).
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 20, end: 20),
              child: SizedBox(
                height: 48,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: _semester == null
                          ? const SizedBox.shrink()
                          : Text(akadUpper(context, l.p69SemesterTerm(_semester!)),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: l.localeName == 'ar' ? 0 : .6, color: t.mut)),
                    ),
                  ),
                  AcadTextAction(l.p69TodayJump, onTap: _goToday, top: true),
                ]),
              ),
            ),
            _monthNav(t, tx, l),
            _grid(t, istanbulWall(academicClock())),
            const SizedBox(height: 10),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: AcadRule()),
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
          excludeFromSemantics: true,
          child: BuPressable(
            onTap: onTap,
            haptic: BuHaptic.selection,
            scale: .92,
            child: SizedBox(width: 48, height: 48, child: Center(child: Icon(buDirIcon(context, icon), size: 22, color: t.ink))),
          ),
        ),
      );

  Widget _monthNav(BuTokens t, TextTheme tx, AppLocalizations l) {
    final title = '${monthNameL(l, _month.month)} ${_month.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        _navButton(t, LucideIcons.chevronLeft, l.acadCalPrev, () => _shift(-1)),
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            button: true,
            label: title,
            excludeSemantics: true,
            onTap: _pickMonth,
            child: BuPressable(
              onTap: _pickMonth,
              scale: .98,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: BuFadeThrough(
                  duration: BuMotion.short,
                  child: Row(
                    key: ValueKey('${_month.year}-${_month.month}'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronDown, size: 16, color: t.ink),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _navButton(t, LucideIcons.chevronRight, l.acadCalNext, () => _shift(1)),
      ]),
    );
  }

  Widget _grid(BuTokens t, DateTime today) {
    final l = context.l10n;
    final lead = _month.weekday - 1;
    final daysIn = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final rows = ((lead + daysIn) / 7).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 13),
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(dayShortL(l, i + 1), style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: i >= 5 ? t.mut.withValues(alpha: .75) : t.mut)),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        // Ay değişince ızgara yatay kayarak yer değiştirir (RTL'de aynalanır).
        BuSharedAxis(
          reverse: _monthDir < 0,
          distance: 24,
          child: KeyedSubtree(
            key: ValueKey('grid-${_month.year}-${_month.month}'),
            child: Column(children: [
              for (var r = 0; r < rows; r++)
                Row(children: [
                  for (var c = 0; c < 7; c++) Expanded(child: _cell(t, DateTime.utc(_month.year, _month.month, r * 7 + c - lead + 1), today, c >= 5)),
                ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _cell(BuTokens t, DateTime date, DateTime today, bool weekend) {
    final inMonth = date.month == _month.month;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final evs = inMonth ? _events.where((e) => e.coversDay(date)).toList() : const <AcademicEvent>[];
    final isToday = today.year == date.year && today.month == date.month && today.day == date.day;
    final sel = _selected == date;
    final has = evs.isNotEmpty;
    final exam = evs.any((e) => _isExam(e.kind));
    final Color fg = sel || (isToday && inMonth)
        ? t.pr
        : !inMonth
            ? t.mut.withValues(alpha: .4)
            : (weekend ? t.mut : t.ink);
    void tap() => setState(() => _selected = sel ? null : date);
    return Semantics(
      button: true,
      selected: sel,
      label: '${date.day} ${monthNameL(l, date.month)}${isToday ? ', ${l.acadCalToday}' : ''}${has ? ', ${l.acadCalEventCount(evs.length.toString())}' : ''}',
      excludeSemantics: true,
      onTap: inMonth ? tap : null,
      child: BuPressable(
        scale: .94,
        onTap: inMonth
            ? () {
                buHaptic(BuHaptic.selection);
                tap();
              }
            : null,
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              curve: BuMotion.standard,
              width: 34,
              height: 38,
              decoration: BoxDecoration(color: sel ? t.soft : Colors.transparent, borderRadius: BorderRadius.circular(19)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.2,
                  child: AnimatedDefaultTextStyle(
                    duration: BuMotion.of(context, BuMotion.short),
                    style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: sel || (isToday && inMonth) ? FontWeight.w700 : FontWeight.w500, color: fg),
                    child: Text('${date.day}'),
                  ),
                ),
                const SizedBox(height: 2),
                // Önemli gün noktası: belirirken 0 -> 1 ölçeklenir (sınav `pr`, diğerleri `ink`).
                AnimatedScale(
                  scale: has ? 1 : 0,
                  duration: BuMotion.of(context, BuMotion.short),
                  curve: BuMotion.emphasizedDecelerate,
                  child: Container(width: 5, height: 5, decoration: BoxDecoration(color: exam ? t.pr : t.ink, shape: BoxShape.circle)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _list(bool maintenance) {
    final l = context.l10n;
    if (_loading && _events.isEmpty) return const [AcadRowsSkeleton(count: 3)];
    if (_error != null && _events.isEmpty && !maintenance) {
      return [AcadStateText(text: '${l.sistemuiErrorTitle}\n${errorText(_error!)}', actionLabel: l.acadRetry, onAction: _load)];
    }
    final sel = _selected;
    final monthEvents = [..._events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final dayHas = sel != null && _events.any((e) => e.coversDay(sel));
    final out = <Widget>[const SizedBox(height: 19)];
    if (monthEvents.isNotEmpty) {
      out.add(_listHeader(l.p69Events, l.p69Records(monthEvents.length.toString())));
      if (sel != null && !dayHas) out.add(AcadStateText(text: l.acadCalNoDay, top: 4));
      for (final e in monthEvents) {
        out.add(_eventRow(e));
      }
    } else if (sel != null) {
      out.add(AcadStateText(text: l.acadCalNoDay, top: 8));
    }
    if (monthEvents.isEmpty && _next.isNotEmpty) {
      out.add(const SizedBox(height: 8));
      out.add(_listHeader(l.acadCalNextHeading, _semester));
      for (final e in _next) {
        out.add(_eventRow(e));
      }
    }
    if (sel == null && monthEvents.isEmpty && !_loading) {
      out.add(AcadStateText(text: l.acadCalNoMonth, top: 12));
    }
    if (_error != null && maintenance) out.add(AcadStateText(text: '', actionLabel: l.acadRetry, onAction: _load, top: 0));
    return out;
  }

  Widget _listHeader(String title, String? trailing) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Semantics(header: true, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)))),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(flex: 0, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: Text(trailing, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)))),
        ],
      ]),
    );
  }

  String _range(AppLocalizations l, AcademicEvent e) {
    final s = e.startDay, en = e.endDay;
    final w = istanbulWall(e.startsAt);
    final midnight = w.hour == 0 && w.minute == 0;
    final startText = e.allDay ? fmtWallDateL(l, s) : (midnight ? '${fmtWallDateL(l, s)} (${l.p20HalfDay})' : fmtInstantL(l, e.startsAt));
    if (en == s) return startText;
    return '${fmtWallDateL(l, s)} - ${fmtWallDateL(l, en)}';
  }

  /// Olay satırı: solda "18 Kasım" (sınavda `pr`) + gün adı, sağda olay adı; dokununca o güne gider.
  Widget _eventRow(AcademicEvent e) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final loc = Localizations.localeOf(context).toString();
    final exam = _isExam(e.kind);
    final color = exam ? t.pr : t.ink;
    final d = e.startDay;
    final dayName = DateFormat('EEEE', loc).format(d);
    final multi = e.endDay != e.startDay;
    final note = [
      if (multi) _range(l, e),
      if (e.scopeDepartment != null) context.departmentName(e.scopeDepartment),
      if (e.note != null) e.note!,
    ].join(' · ');
    final kind = eventKindLabelL(l, e.kind);
    return AcadRow(
      minHeight: 73,
      semanticLabel: '$kind: ${e.title}. ${_range(l, e)}',
      onTap: () => _goMonth(DateTime.utc(d.year, d.month), d.isBefore(_month) ? -1 : 1, select: DateTime.utc(d.year, d.month, d.day)),
      child: Row(children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${d.day} ${monthNameL(l, d.month)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(dayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(e.title, maxLines: 2, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
            if (note.isNotEmpty) Text(note, maxLines: 2, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut)),
          ]),
        ),
        const SizedBox(width: 8),
        ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
      ]),
    );
  }
}
