import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'course_form_page.dart';
import 'reminders.dart';
import 'semester_sheet.dart';
import 'timetable_parts.dart';

/// Ders programı (Ak1): dönem düğmesi + hafta ilerlemesi, sıradaki ders kartı, gün şeridi, zaman çizelgesi,
/// derslerim listesi, "Ders ekle" yüzen düğmesi. Büyük başlık kaydırınca daralır; çekerek yenilenir.
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
  bool _back = false; // gün geçişi yönü (shared axis)
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
      academicToast(context, context.l10n.acadTimeExportNone);
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
      if (mounted) academicToast(context, context.l10n.acadTimeExportCopied, kind: BuToastKind.success);
    }
  }

  void _selectDay(int d) {
    setState(() {
      _back = d < _day;
      _day = d;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = _data;
    final maintenance = _error is ApiError && (_error! as ApiError).status == 503;
    final BuViewState state;
    if (data != null) {
      state = BuViewState.ready;
    } else if (_loading) {
      state = BuViewState.loading;
    } else if (maintenance) {
      state = BuViewState.empty;
    } else {
      state = BuViewState.error;
    }
    return BuPageScaffold(
      title: l.acadTimeTitle,
      state: state,
      loading: const TtSkeleton(),
      error: _error,
      onRetry: _load,
      empty: AcademicErrorView(error: _error ?? 'x', onRetry: _load),
      onRefresh: () => _load(quiet: true),
      actions: [
        BuIconButton(icon: LucideIcons.share, tooltip: l.acadTimeExportTooltip, onTap: data == null ? null : _export),
        const SizedBox(width: 12),
      ],
      banner: _error != null && data != null ? BuOfflineBanner(message: l.acadTimeStale, showCachedHint: false) : null,
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              tooltip: l.acadTimeAddCourse,
              onPressed: () => _openForm(day: _day),
              icon: const Icon(LucideIcons.plus),
              label: Text(data.courses.isEmpty ? l.acadTimeAddFirst : l.acadTimeAddCourse),
            ),
      bottomInset: 104,
      slivers: data == null ? const [] : _slivers(data),
    );
  }

  List<Widget> _slivers(TimetableData data) {
    final l = context.l10n;
    final nowWall = istanbulWall(academicClock());
    final sem = data.semester;
    final week = _weekInfo(sem, nowWall);
    final dates = [for (var d = 1; d <= 7; d++) _dateOf(d, nowWall)];
    final bar = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 14),
      child: TtSemesterBar(
        name: sem?.name ?? l.acadTimePickSemester,
        onTap: _pickSemester,
        week: week?.week,
        weeks: week?.weeks,
        progress: week?.progress,
      ),
    );
    if (data.courses.isEmpty) {
      return [
        SliverToBoxAdapter(child: bar),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            child: BuEmptyState(
              illustration: BuIllustration.calendar,
              title: l.p17NoClassesTitle,
              message: l.acadTimeEmptyText,
            ),
          ),
        ),
      ];
    }
    final hasClass = [
      for (final d in dates) slotsForDay(data.courses, sem, d, nowWall: nowWall).isNotEmpty || slotsForDay(data.courses, null, d, nowWall: nowWall).isNotEmpty
    ];
    return [
      SliverToBoxAdapter(child: bar),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 14),
          child: _nextCard(data, nowWall),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: BuSpace.pageH,
          child: TtDayStrip(selected: _day, todayWeekday: nowWall.weekday, dates: dates, hasClass: hasClass, onSelect: _selectDay),
        ),
      ),
      SliverToBoxAdapter(
        child: BuSharedAxis(
          reverse: _back,
          distance: 24,
          child: Padding(
            key: ValueKey('daybody$_day'),
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
            child: _dayBody(data, nowWall),
          ),
        ),
      ),
      SliverToBoxAdapter(
          child: BuSectionHeader(l.acadTimeMyCourses(data.courses.length.toString()), padding: const EdgeInsetsDirectional.fromSTEB(20, 28, 20, 12))),
      SliverList.builder(
        itemCount: data.courses.length,
        itemBuilder: (c, i) {
          final course = data.courses[i];
          final days = {for (final s in course.sessions) '${acadDayShort(l, s.dayOfWeek.clamp(1, 7))} ${s.start}-${s.end}'}.join(' · ');
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
            child: TtCourseTile(course: course, days: days, onTap: () => _openForm(course: course)),
          );
        },
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
          child: AkadCard(
            shadow: false,
            color: context.bu.sf2,
            borderColor: context.bu.sf2,
            onTap: _export,
            child: Row(children: [
              Icon(LucideIcons.calendarDays, size: 20, color: context.bu.pr),
              const SizedBox(width: 12),
              Expanded(child: Text(l.akademik2ExportLabel, style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700))),
              Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: context.bu.mut),
            ]),
          ),
        ),
      ),
    ];
  }

  /// Dönemin kaçıncı haftası (dönem tarihleri varsa ve bugün aralıktaysa).
  ({int week, int weeks, double progress})? _weekInfo(Semester? s, DateTime nowWall) {
    final a = s?.startDate, b = s?.endDate;
    if (a == null || b == null) return null;
    final total = b.difference(a).inDays + 1;
    if (total <= 0) return null;
    final today = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    final elapsed = today.difference(a).inDays;
    if (elapsed < 0 || elapsed >= total) return null;
    return (week: elapsed ~/ 7 + 1, weeks: (total / 7).ceil(), progress: (elapsed + 1) / total);
  }

  /// Sıradaki / süren ders özeti.
  Widget _nextCard(TimetableData data, DateTime nowWall) {
    final today = slotsForDay(data.courses, data.semester, nowWall, nowWall: nowWall);
    DaySlot? ongoing;
    for (final s in today) {
      if (s.status == SlotStatus.ongoing) ongoing = s;
    }
    final next = nextSlot(data.courses, data.semester, nowWall);
    final l = context.l10n;
    String head;
    String line;
    Color? accent;
    double? progress;
    IconData icon = LucideIcons.clock;
    if (ongoing != null) {
      final nowMin = nowWall.hour * 60 + nowWall.minute;
      final left = ongoing.session.endMin - nowMin;
      final len = ongoing.session.endMin - ongoing.session.startMin;
      head = l.acadTimeNowInClass;
      line = l.acadTimeMinLeft(ongoing.course.name, left.toString());
      accent = courseColor(ongoing.course.color);
      progress = len <= 0 ? null : (nowMin - ongoing.session.startMin) / len;
      icon = LucideIcons.bookOpen;
    } else if (next != null) {
      final s = next.slot;
      final isToday = s.date.day == nowWall.day && s.date.month == nowWall.month;
      final when = next.minutesUntil < 60
          ? l.acadTimeWhenMin(next.minutesUntil.toString())
          : isToday
              ? (next.minutesUntil % 60 == 0
                  ? l.acadTimeWhenHours((next.minutesUntil ~/ 60).toString())
                  : l.acadTimeWhenHoursMin((next.minutesUntil ~/ 60).toString(), (next.minutesUntil % 60).toString()))
              : l.acadTimeWhenDay(acadDayName(l, s.date.weekday), s.session.start);
      head = l.acadTimeNextClass;
      line = '${s.course.name} · $when';
      accent = courseColor(s.course.color);
    } else {
      head = l.acadTimeToday;
      line = l.acadTimeNoMoreWeek;
      icon = LucideIcons.partyPopper;
    }
    return TtNextCard(head: head, line: line, accent: accent, progress: progress, icon: icon);
  }

  /// Haftanın [weekday] gününün tarihi (bu hafta içinde).
  DateTime _dateOf(int weekday, DateTime nowWall) {
    final base = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    return base.add(Duration(days: weekday - nowWall.weekday));
  }

  Widget _dayBody(TimetableData data, DateTime nowWall) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final date = _dateOf(_day, nowWall);
    final slots = slotsForDay(data.courses, data.semester, date, nowWall: nowWall);
    // Dönem aralığı dışındaysa da oturumları göstermek için kısıtsız çek.
    final plain = slots.isEmpty ? slotsForDay(data.courses, null, date, nowWall: nowWall) : const <DaySlot>[];
    final list = slots.isNotEmpty ? slots : plain;
    final name = acadDayName(l, _day);
    final title = _day == nowWall.weekday ? l.akademik2DayHeadingToday(name) : name;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, top: 12, bottom: 14),
        child: Semantics(
          header: true,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: title, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            if (list.isNotEmpty) TextSpan(text: ' · ${l.akademik2CourseCount(list.length.toString())}', style: tx.labelLarge!.copyWith(color: t.mut)),
          ])),
        ),
      ),
      if (list.isEmpty)
        TtEmptyDay(text: l.acadTimeNoClassDay(name))
      else ...[
        if (slots.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: StaleBanner(text: l.acadTimeOutOfRange, icon: LucideIcons.info)),
        BuStaggerScope(
          child: Column(children: [
            for (var i = 0; i < list.length; i++)
              BuStaggerItem(
                index: i,
                child: TtSlotRow(slot: list[i], first: i == 0, last: i == list.length - 1, onTap: () => _openForm(course: list[i].course)),
              ),
          ]),
        ),
      ],
    ]);
  }
}
