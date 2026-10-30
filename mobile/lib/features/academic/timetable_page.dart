import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'course_form_page.dart';
import 'reminders.dart';
import 'semester_sheet.dart';
import 'timetable_parts.dart';

/// Ders programı (Stitch 43): dönem + .ics satırı, gün hapları, şu an/sıradaki ders, günlük akış, "Derslerim" ızgarası,
/// "Ders ekle" yüzen düğmesi. Çekerek yenilenir; dönem/ders yokken boş durum kartları.
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
    final hasCourses = data != null && data.courses.isNotEmpty;
    return AcademicScaffold(
      title: l.acadTimeTitle,
      floatingActionButton: hasCourses
          ? DecoratedBox(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: context.bu.pr.withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -4)]),
              child: FloatingActionButton.extended(
                heroTag: null,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                tooltip: l.acadTimeAddCourse,
                onPressed: () => _openForm(day: _day),
                icon: const Icon(LucideIcons.plus),
                label: Text(l.acadTimeAddCourse),
              ),
            )
          : null,
      child: Column(children: [
        if (_error != null && data != null) AkadStaleStrip(text: l.acadTimeStale),
        Expanded(child: _body(data)),
      ]),
    );
  }

  Widget _body(TimetableData? data) {
    if (data == null) {
      if (_loading) return const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: TtSkeleton());
      return RefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [_errorCard()]),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 112),
        children: _content(data),
      ),
    );
  }

  Widget _errorCard() {
    final l = context.l10n;
    final e = _error;
    if (e is ApiError && e.status == 503) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AkadNoticeCard(text: e.message.isNotEmpty ? e.message : l.acadMaintenance),
        const SizedBox(height: 12),
        Align(alignment: AlignmentDirectional.centerEnd, child: BuButton(label: l.acadRetry, compact: true, kind: BuButtonKind.soft, onPressed: _load)),
      ]);
    }
    return AkadErrorCard(title: l.p17LoadErrTitle, message: e == null ? null : errorText(e), onRetry: _load, retryLabel: l.acadRetry);
  }

  Widget _pad(Widget w, {double top = 0}) => Padding(padding: EdgeInsetsDirectional.fromSTEB(20, top, 20, 0), child: w);

  List<Widget> _content(TimetableData data) {
    final l = context.l10n;
    final t = context.bu;
    final sem = data.semester;
    final nowWall = istanbulWall(academicClock());
    if (sem == null && data.courses.isEmpty) return [_pad(TtNoSemesterCard(onAdd: _pickSemester))];
    if (data.courses.isEmpty) {
      return [_pad(TtNoCourseCard(semester: sem?.name, onAdd: () => _openForm(day: _day), onPickSemester: _pickSemester))];
    }
    final date = _dateOf(_day, nowWall);
    final inSem = slotsForDay(data.courses, sem, date, nowWall: nowWall);
    final outOfRange = inSem.isEmpty && slotsForDay(data.courses, null, date, nowWall: nowWall).isNotEmpty;
    final list = inSem.isNotEmpty ? inSem : slotsForDay(data.courses, null, date, nowWall: nowWall);
    final todayView = _day == nowWall.weekday;
    final dayName = acadDayName(l, _day);
    final left = todayView ? list.where((s) => s.status != SlotStatus.past).length : 0;
    return [
      _pad(TtTopRow(name: sem?.name ?? l.acadTimePickSemester, onPickSemester: _pickSemester, onExport: _export)),
      const SizedBox(height: 14),
      TtDayPills(selected: _day, todayWeekday: nowWall.weekday, onSelect: (d) => setState(() => _day = d)),
      const SizedBox(height: 14),
      ..._nowAndNext(data, nowWall),
      const SizedBox(height: 22),
      _pad(AkadTitle(l.p17DailyFlow,
          chip: dayName,
          trailing: list.isEmpty
              ? null
              : Text(l.p17DayPlanned(list.length.toString()), textAlign: TextAlign.end, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.mut)))),
      const SizedBox(height: 12),
      if (outOfRange)
        _pad(TtInfoCard(icon: LucideIcons.calendarX, tileBg: t.sf2, tileFg: t.mut, title: l.acadTimeOutOfRange, body: l.p17OutOfRangeBody)),
      if (outOfRange && list.isNotEmpty) const SizedBox(height: 12),
      if (list.isEmpty && !outOfRange) _pad(TtEmptyDay(dayName: dayName, dayOfMonth: date.day, text: l.acadTimeNoClassDay(dayName))),
      if (list.isNotEmpty)
        _pad(BuStaggerScope(
          child: Column(children: [
            for (var i = 0; i < list.length; i++)
              BuStaggerItem(
                index: i,
                child: Padding(
                  padding: EdgeInsets.only(bottom: i == list.length - 1 ? 0 : 12),
                  child: TtSlotCard(slot: list[i], todayView: todayView, onTap: () => _openForm(course: list[i].course)),
                ),
              ),
          ]),
        )),
      if (todayView && list.isNotEmpty) ...[
        const SizedBox(height: 14),
        _pad(left > 0
            ? TtLeftLine(text: l.acadTimeTodayLeft(left.toString()))
            : TtInfoCard(icon: LucideIcons.circleCheck, tileBg: t.tint(1).bg, tileFg: t.tint(1).fg, title: l.acadTimeTodayNone, body: l.p17TodayDoneBody)),
      ],
      const SizedBox(height: 24),
      _pad(AkadTitle(l.p17MyCourses, count: data.courses.length)),
      const SizedBox(height: 12),
      _pad(_courseGrid(data.courses)),
    ];
  }

  Widget _courseGrid(List<Course> courses) {
    final l = context.l10n;
    Widget tile(Course c) {
      final days = {for (final s in c.sessions) '${acadDayShort(l, s.dayOfWeek.clamp(1, 7))} ${s.start}-${s.end}'}.join(' · ');
      return TtCourseTile(course: c, days: days, onTap: () => _openForm(course: c));
    }

    return Column(children: [
      for (var i = 0; i < courses.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: tile(courses[i])),
            const SizedBox(width: 12),
            Expanded(child: i + 1 < courses.length ? tile(courses[i + 1]) : const SizedBox.shrink()),
          ]),
        ),
      ],
    ]);
  }

  /// Süren ders kartı + sıradaki ders kartı (ya da hafta bitti bilgisi).
  List<Widget> _nowAndNext(TimetableData data, DateTime nowWall) {
    final l = context.l10n;
    final t = context.bu;
    final today = slotsForDay(data.courses, data.semester, nowWall, nowWall: nowWall);
    DaySlot? ongoing;
    for (final s in today) {
      if (s.status == SlotStatus.ongoing) ongoing = s;
    }
    final next = nextSlot(data.courses, data.semester, nowWall);
    final out = <Widget>[];
    if (ongoing != null) {
      final nowMin = nowWall.hour * 60 + nowWall.minute;
      final len = ongoing.session.endMin - ongoing.session.startMin;
      out.add(_pad(TtNowCard(
        name: ongoing.course.name,
        minutesLeft: ongoing.session.endMin - nowMin,
        progress: len <= 0 ? 0 : (nowMin - ongoing.session.startMin) / len,
        room: ongoing.session.room,
      )));
    }
    if (next != null) {
      final s = next.slot;
      final isToday = s.date.day == nowWall.day && s.date.month == nowWall.month;
      final when = next.minutesUntil < 60
          ? l.acadTimeWhenMin(next.minutesUntil.toString())
          : isToday
              ? (next.minutesUntil % 60 == 0
                  ? l.acadTimeWhenHours((next.minutesUntil ~/ 60).toString())
                  : l.acadTimeWhenHoursMin((next.minutesUntil ~/ 60).toString(), (next.minutesUntil % 60).toString()))
              : l.acadTimeWhenDay(acadDayName(l, s.date.weekday), s.session.start);
      if (out.isNotEmpty) out.add(const SizedBox(height: 12));
      out.add(_pad(TtInfoCard(
        icon: LucideIcons.clock,
        tileBg: t.tint(1).bg,
        tileFg: t.tint(1).fg,
        label: l.acadTimeNextClass,
        title: s.course.name,
        pill: when,
      )));
    } else if (ongoing == null) {
      out.add(_pad(TtInfoCard(icon: LucideIcons.sofa, tileBg: t.soft, tileFg: t.onSoft, title: l.acadTimeNoMoreWeek, body: l.p17WeekDoneBody)));
    }
    return out;
  }

  /// Haftanın [weekday] gününün tarihi (bu hafta içinde).
  DateTime _dateOf(int weekday, DateTime nowWall) {
    final base = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    return base.add(Duration(days: weekday - nowWall.weekday));
  }
}
