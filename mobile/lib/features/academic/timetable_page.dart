import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'acad_ref_widgets.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'course_form_page.dart';
import 'exams_page.dart';
import 'reminders.dart';
import 'semester_sheet.dart';
import 'timetable_parts.dart';

/// Ders programı (Stitch v3 02): hafta + dönem + "+" satırı, gün şeridi, kartsız zaman çizelgesi ("Şimdi" çizgisi), özet.
/// Çekerek yenilenir; dönem/ders yokken ortalı boş durum.
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key, required this.session});

  final Session session;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  TimetableData? _data;
  Object? _error;
  bool _loading = true;
  int? _semesterId;
  int _day = istanbulWall(academicClock()).weekday;
  int _dayDir = 1; // gün şeridi geçişinin yönü: içerik o yöne kayar
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final d = await _api.timetable(semesterId: _semesterId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Course? course, int? day}) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => CourseFormPage(
        session: widget.session,
        course: course,
        allCourses: _data?.courses ?? const [],
        semesterId: _semesterId ?? _data?.semester?.id,
        initialDay: day,
      ),
    ));
    if (changed == true) {
      await _load(quiet: true);
      unawaited(ReminderService.sync(_api));
    }
  }

  Future<void> _pickSemester() async {
    final r = await BuSheet.show<SemesterAction>(
      context,
      scrollable: false,
      padding: EdgeInsets.zero,
      builder: (_) => SemesterSheet(api: _api, activeId: _semesterId ?? _data?.semester?.id),
    );
    if (r == null || !mounted) return;
    if (r.changed || r.semesterId != null) {
      _semesterId = r.semesterId;
      await _load();
      unawaited(ReminderService.sync(_api));
    }
  }

  Future<void> _export() async {
    final d = _data;
    if (d == null || d.courses.isEmpty) {
      academicToast(context, context.l10n.acadTimeExportNone, kind: BuToastKind.warning);
      return;
    }
    final l = context.l10n;
    var exams = <Exam>[];
    try {
      exams = await _api.exams();
    } catch (_) {}
    final ics = buildIcs(d.courses, d.semester, exams, l: l);
    final shared = await ReminderService.platform.shareText(ics, 'bu-ders-programi.ics');
    if (!shared) {
      await Clipboard.setData(ClipboardData(text: ics));
      if (mounted) academicToast(context, isolateIcs(context.l10n.acadTimeExportCopied), kind: BuToastKind.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = _data;
    return AcademicScaffold(
      title: l.acadTimeTitle,
      child: Column(children: [
        if (_error != null && data != null) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: AcadAmberNote(text: l.acadTimeStale)),
        Expanded(child: _body(data)),
      ]),
    );
  }

  Widget _body(TimetableData? data) {
    if (data == null) {
      if (_loading) return const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: TtSkeleton());
      return RefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 32), children: [_errorBlock()]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: _content(data),
      ),
    );
  }

  Widget _errorBlock() {
    final l = context.l10n;
    final e = _error;
    if (e is ApiError && e.status == 503) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: AcadAmberNote(text: e.message.isNotEmpty ? e.message : l.acadMaintenance)),
        AcadStateText(text: '', actionLabel: l.acadRetry, onAction: _load, top: 0),
      ]);
    }
    return AcadStateText(text: e == null ? l.p17LoadErrTitle : '${l.p17LoadErrTitle}\n${errorText(e)}', actionLabel: l.acadRetry, onAction: _load);
  }

  /// Yarıyılın kaçıncı haftasındayız (1'den); dönem tarihi yoksa ya da dışındaysak null.
  int? _weekOf(Semester? sem, DateTime nowWall) {
    final st = sem?.startDate;
    if (st == null) return null;
    final today = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    final monday = DateTime.utc(st.year, st.month, st.day).subtract(Duration(days: st.weekday - 1));
    final w = today.difference(monday).inDays ~/ 7 + 1;
    if (w < 1) return null;
    final end = sem?.endDate;
    if (end != null && today.isAfter(end)) return null;
    return w;
  }

  /// Gün şeridinde gösterilecek günler: hafta içi 5 gün; Cmt/Paz yalnız dersi varsa ya da seçiliyse.
  List<int> _stripDays(List<Course> courses) => [
        for (var d = 1; d <= 7; d++)
          if (d <= 5 || d == _day || courses.any((c) => c.sessions.any((s) => s.dayOfWeek == d))) d,
      ];

  String _ago(AppLocalizations l, int minutesUntil) {
    if (minutesUntil < 60) return l.acadTimeWhenMin(minutesUntil.toString());
    return minutesUntil % 60 == 0
        ? l.acadTimeWhenHours((minutesUntil ~/ 60).toString())
        : l.acadTimeWhenHoursMin((minutesUntil ~/ 60).toString(), (minutesUntil % 60).toString());
  }

  List<Widget> _content(TimetableData data) {
    final l = context.l10n;
    final t = context.bu;
    final sem = data.semester;
    final nowWall = istanbulWall(academicClock());
    if (sem == null && data.courses.isEmpty) {
      return [TtEmpty(title: l.p17NoSemesterTitle, body: l.p17NoSemesterBody, actionLabel: l.acadTimeAddSemester, onAction: _pickSemester)];
    }
    if (data.courses.isEmpty) {
      return [
        TtEmpty(
          title: l.p17NoCourseTitle,
          body: l.p17NoCourseBody,
          actionLabel: l.acadTimeAddFirst,
          onAction: () => _openForm(day: _day),
          semesterLabel: sem?.name,
          onPickSemester: _pickSemester,
        ),
      ];
    }
    final date = _dateOf(_day, nowWall);
    final inSem = slotsForDay(data.courses, sem, date, nowWall: nowWall);
    final outOfRange = inSem.isEmpty && slotsForDay(data.courses, null, date, nowWall: nowWall).isNotEmpty;
    final list = inSem.isNotEmpty ? inSem : slotsForDay(data.courses, null, date, nowWall: nowWall);
    final todayView = _day == nowWall.weekday;
    final dayName = acadDayName(l, _day);
    final nowMin = nowWall.hour * 60 + nowWall.minute;
    final nowTime = hhmm(nowMin);
    var nowIdx = list.indexWhere((s) => s.status != SlotStatus.past);
    if (nowIdx < 0) nowIdx = list.length; // hepsi bitti: çizgi en sonda
    var totalMin = 0;
    for (final s in list) {
      final d = s.session.endMin - s.session.startMin;
      if (d > 0) totalMin += d;
    }
    String? trailingOf(int i) {
      final s = list[i];
      if (todayView) {
        switch (s.status) {
          case SlotStatus.past:
            return l.p69Done;
          case SlotStatus.ongoing:
            return l.acadCountdownMinutes((s.session.endMin - nowMin).toString());
          case SlotStatus.upcoming:
            return i == list.length - 1 ? l.p69LastSession : _ago(l, s.session.startMin - nowMin);
        }
      }
      return i == list.length - 1 && list.length > 1 ? l.p69LastSession : null;
    }

    final rows = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      if (todayView && i == nowIdx) rows.add(TtNowLine(time: nowTime));
      rows.add(BuStaggerItem(
        index: i,
        child: TtSlotCard(slot: list[i], todayView: todayView, trailing: trailingOf(i), onTap: () => _openForm(course: list[i].course)),
      ));
      final nextIsNow = todayView && i + 1 == nowIdx;
      if (i < list.length - 1 && !nextIsNow) rows.add(const Padding(padding: EdgeInsetsDirectional.only(start: 85), child: AcadRule()));
    }
    if (todayView && nowIdx == list.length && list.isNotEmpty) rows.add(TtNowLine(time: nowTime));
    return [
      TtTopRow(semester: sem?.name ?? l.acadTimePickSemester, week: _weekOf(sem, nowWall), onPickSemester: _pickSemester, onAdd: () => _openForm(day: _day)),
      const SizedBox(height: 6),
      TtDayStrip(
        selected: _day,
        todayWeekday: nowWall.weekday,
        days: _stripDays(data.courses),
        dates: {for (var d = 1; d <= 7; d++) d: _dateOf(d, nowWall)},
        onSelect: (d) => setState(() {
          _dayDir = d >= _day ? 1 : -1;
          _day = d;
        }),
      ),
      const SizedBox(height: 17),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: AcadRule()),
      const SizedBox(height: 12),
      // Gün değişince akış yatay kayarak yer değiştirir (ileri gün: sola, geri: sağa).
      BuSharedAxis(
        reverse: _dayDir < 0,
        distance: 24,
        child: KeyedSubtree(
          key: ValueKey<int>(_day),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (outOfRange) AcadStateText(text: l.acadTimeOutOfRange, top: 4),
            if (list.isEmpty && !outOfRange) AcadStateText(text: l.acadTimeNoClassDay(dayName), top: 18),
            if (list.isNotEmpty) BuStaggerScope(child: Column(children: rows)),
          ]),
        ),
      ),
      if (list.isNotEmpty) ...[
        const SizedBox(height: 20),
        TtSummary(
          text: todayView ? l.p69TodayTotal(list.length.toString(), ttHoursText(context, totalMin)) : l.p17DayPlanned(list.length.toString()),
          actionLabel: l.p69ExamCalendar,
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamsPage(session: widget.session))),
        ),
      ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 20),
          child: AcadTextAction(isolateIcs(l.acadTimeExportTooltip), onTap: _export, size: 13, color: t.mut, semanticLabel: l.acadTimeExportTooltip),
        ),
      ),
    ];
  }

  /// Haftanın [weekday] gününün tarihi (bu hafta içinde).
  DateTime _dateOf(int weekday, DateTime nowWall) {
    final base = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    return base.add(Duration(days: weekday - nowWall.weekday));
  }
}
