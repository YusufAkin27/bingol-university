import '../../core/analytics.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show AcademicLabels, gradeLabelL;
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
import 'alarm_service.dart';
import 'alarm_sheets.dart';
import '../../core/platform/device_alarm.dart';
import 'exam_form_page.dart';
import 'reminders.dart';

/// Sınavlar (Stitch v3 03): geri oku + 28 sp başlık + `pr` "+"; kartsız satırlar (ad, muted "tarih · saat · derslik",
/// sağda kalan süre). Tek içerik: kullanıcının kendi sınavları (okulun resmi sınav programı yoktur).
class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key, required this.session});

  final Session session;

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  String? _filter; // tür süzgeci (null = tümü)

  List<Exam> _mine = [];
  List<Course> _courses = [];
  bool _loadingMine = true;
  Object? _errMine;
  List<PendingExamAlarm> _due = const []; // ertelenmiş, artık Saat uygulamasına kurulabilir sınav alarmları
  bool _settingDue = false;

  @override
  void initState() {
    super.initState();
    _loadMine();
    _loadDue();
  }

  Future<void> _loadDue() async {
    final d = await AlarmService.instance.dueNow();
    if (mounted) setState(() => _due = d);
  }

  Future<void> _setDue() async {
    final l = context.l10n;
    setState(() => _settingDue = true);
    final r = await AlarmService.instance.setDue(l);
    if (!mounted) return;
    setState(() => _settingDue = false);
    academicToast(context, r.failed > 0 ? l.alarmDoneFail(r.failed.toString()) : l.alarmDoneSet(r.set.toString()), kind: r.failed > 0 ? BuToastKind.warning : BuToastKind.success);
    await _loadDue();
  }

  Future<void> _openAlarms() async {
    await showExamAlarmSheet(context, exams: _mine);
    if (mounted) await _loadDue();
  }

  /// Sınavlar başlığının altı: kurulmaya hazır ertelenmiş alarm bandı + "ilk sınav alarmlarını kur" eylemi.
  List<Widget> _alarmEntry() {
    final l = context.l10n;
    final now = academicClock();
    final hasUpcoming = _mine.any((e) => e.startsAt.isAfter(now));
    if (!hasUpcoming && _due.isEmpty) return const [];
    final clock = DeviceAlarmService.instance.usesClockApp;
    return [
      if (_due.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: AcadAmberNote(
            text: l.alarmDueBanner(_due.length.toString()),
            actionLabel: _settingDue ? null : l.alarmDueAction,
            onAction: _settingDue ? null : _setDue,
          ),
        ),
      if (hasUpcoming)
        AcadActionRow(
          icon: clock ? BuIcons.alarmClock : BuIcons.bell,
          title: clock ? l.alarmExamAction : l.alarmExamActionIos,
          onTap: _openAlarms,
        ),
    ];
  }

  Future<void> _loadMine() async {
    setState(() => _loadingMine = true);
    try {
      final r = await Future.wait([_api.exams(), _api.timetable()]);
      if (!mounted) return;
      setState(() {
        _mine = r[0] as List<Exam>;
        final tt = r[1] as TimetableData;
        _courses = tt.courses;
        _errMine = null;
        _loadingMine = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errMine = e;
          _loadingMine = false;
        });
      }
    }
  }

  Future<void> _openForm([Exam? exam]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(settings: const RouteSettings(name: 'exam_form'), builder: (_) => ExamFormPage(session: widget.session, exam: exam, courses: _courses)),
    );
    if (ok == true) {
      await _loadMine();
      unawaited(ReminderService.sync(_api));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final canAdd = !_loadingMine || _mine.isNotEmpty;
    return AcademicScaffold(
      title: l.acadExamsTitle,
      showTitle: false,
      child: RefreshIndicator(
        onRefresh: Analytics.pullRefresh(_loadMine),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(children: [
                  Expanded(child: Semantics(header: true, label: l.acadExamsTitle, child: const SizedBox.shrink())),
                  if (canAdd)
                    Semantics(
                      button: true,
                      label: l.acadExamsAdd,
                      excludeSemantics: true,
                      onTap: () => _openForm(),
                      child: Tooltip(
                        message: l.acadExamsAdd,
                        excludeFromSemantics: true,
                        child: BuPressable(
                          onTap: () => _openForm(),
                          haptic: BuHaptic.selection,
                          scale: .94,
                          child: SizedBox(width: 48, height: 48, child: Center(child: Icon(BuIcons.plus, size: 18, color: t.pr))),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            ..._alarmEntry(),
            ..._mineBody(),
          ],
        ),
      ),
    );
  }

  /// "18 Kasım · 10:30 · B-204" (İstanbul duvar saati; bugünse "Bugün · 10:30").
  String _when(AppLocalizations l, DateTime startsAt, DateTime now, String? room) {
    final w = istanbulWall(startsAt);
    final n = istanbulWall(now);
    final today = w.year == n.year && w.month == n.month && w.day == n.day;
    return [
      today ? l.acadTimeToday : '${w.day} ${monthNameL(l, w.month)}',
      hhmm(w.hour * 60 + w.minute),
      if (room != null && room.isNotEmpty) room,
    ].join(' · ');
  }

  // ---- sınavlarım
  List<Widget> _mineBody() {
    final l = context.l10n;
    final err = _mine.isEmpty ? _errMine : null;
    if (_loadingMine && _mine.isEmpty && err == null) return const [AcadRowsSkeleton(count: 3)];
    if (err != null) return _errorBlock(err, _loadMine);
    final now = academicClock();
    final all = _mine;
    final shown = _filter == null ? all : all.where((e) => e.type == _filter).toList();
    final upcoming = shown.where((e) => (e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = shown.where((e) => !(e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final stale = _errMine != null ? [Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: AcadAmberNote(text: l.acadTimeStale))] : const <Widget>[];
    if (all.isEmpty) {
      return [
        ...stale,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
          child: Row(children: [
            Expanded(child: Text(l.p69NoExams, style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 13, color: context.bu.mut))),
            AcadTextAction(l.acadExamsAdd, onTap: () => _openForm(), size: 15, weight: FontWeight.w400),
          ]),
        ),
      ];
    }
    final types = {for (final e in all) e.type};
    return [
      ...stale,
      if (types.length > 1) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 0, 0), child: _filters(all, types)),
      if (upcoming.isNotEmpty)
        BuStaggerScope(
          child: Column(children: [
            for (var i = 0; i < upcoming.length; i++) BuStaggerItem(index: i, child: _examRow(upcoming[i], now, first: i == 0)),
          ]),
        )
      else
        AcadStateText(text: l.acadExamsNoUpcoming, top: 24),
      if (past.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 0),
          child: Semantics(header: true, child: Text(l.acadExamsPast, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, color: context.bu.mut))),
        ),
        for (final e in past) _examRow(e, now),
      ],
    ];
  }

  List<Widget> _errorBlock(Object err, Future<void> Function() retry) {
    final l = context.l10n;
    if (err is ApiError && err.status == 503) {
      return [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: AcadAmberNote(text: err.message.isNotEmpty ? err.message : l.acadMaintenance)),
        AcadStateText(text: '', actionLabel: l.acadRetry, onAction: retry, top: 0),
      ];
    }
    return [AcadStateText(text: '${l.sistemuiErrorTitle}\n${errorText(err)}', actionLabel: l.acadRetry, onAction: retry)];
  }

  Widget _filters(List<Exam> all, Set<String> types) {
    final l = context.l10n;
    final chips = <(String?, String)>[
      (null, '${l.acadAll} (${all.length})'),
      for (final k in examTypes)
        if (types.contains(k)) (k, examTypeLabelL(l, k)),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(
          child: AkadChip(label: chips[i].$2, selected: _filter == chips[i].$1, onTap: () => setState(() => _filter = chips[i].$1)),
        ),
      ),
    );
  }

  Widget _examRow(Exam e, DateTime now, {bool first = false}) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cd = countdownTextL(l, e.startsAt, now);
    final past = cd == null;
    final typeText = examTypeLabelL(l, e.type);
    final semantic = cd != null
        ? l.acadExamsSemanticCd(typeText, e.title, fmtInstantL(l, e.startsAt), cd)
        : l.acadExamsSemantic(typeText, e.title, fmtInstantL(l, e.startsAt));
    final right = past ? l.akademik2Passed : cd;
    return AcadRow(
      onTap: () => _openForm(e),
      semanticLabel: semantic,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w400, color: past ? t.mut : t.ink)),
            const SizedBox(height: 4),
            Text(_when(l, e.startsAt, now, e.room), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
          ]),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 0,
          child: Text(right, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w400, color: first && !past ? t.prText : t.mut)),
        ),
      ]),
    );
  }
}
