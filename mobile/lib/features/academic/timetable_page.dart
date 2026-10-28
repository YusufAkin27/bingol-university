import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'course_form_page.dart';
import 'reminders.dart';
import 'semester_sheet.dart';

/// Ders programı (Ak1): dönem düğmesi, gün şeridi, renkli ders blokları, alt eylem çubuğu.
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
    final r = await showModalBottomSheet<SemesterAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bu.bg,
      barrierColor: const Color(0x73171E33),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
    var exams = <Exam>[];
    try {
      exams = await _api.exams();
    } catch (_) {}
    final ics = buildIcs(d.courses, d.semester, exams);
    final shared = await ReminderService.platform.shareText(ics, 'bu-ders-programi.ics');
    if (!shared) {
      await Clipboard.setData(ClipboardData(text: ics));
      if (mounted) academicToast(context, context.l10n.acadTimeExportCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final l = context.l10n;
    return AcademicScaffold(
      title: l.acadTimeTitle,
      actions: [
        BuIconButton(icon: LucideIcons.share, tooltip: l.acadTimeExportTooltip, onTap: data == null ? null : _export),
      ],
      bottomBar: data == null
          ? null
          : AkadBottomBar(children: [
              if (data.courses.isNotEmpty)
                AkadButton(label: l.akademik2ExportLabel, icon: LucideIcons.calendarDays, outlined: true, onPressed: _export),
              AkadButton(
                label: data.courses.isEmpty ? l.acadTimeAddFirst : l.acadTimeAddCourse,
                icon: LucideIcons.plus,
                tooltip: l.acadTimeAddCourse,
                onPressed: () => _openForm(day: _day),
              ),
            ]),
      child: _body(data),
    );
  }

  Widget _body(TimetableData? data) {
    if (_loading && data == null) return const LoadingView();
    if (data == null) return AcademicErrorView(error: _error ?? 'x', onRetry: _load);
    final t = context.bu;
    final nowWall = istanbulWall(academicClock());
    final sem = data.semester;
    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, AkadBottomBar.reserve),
        children: [
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: StaleBanner(text: context.l10n.acadTimeStale)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              button: true,
              label: context.l10n.acadTimePickSemester,
              excludeSemantics: true,
              onTap: _pickSemester,
              child: Material(
                color: t.sf,
                shape: StadiumBorder(side: BorderSide(color: t.bd, width: 1.5)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _pickSemester,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(sem?.name ?? context.l10n.acadTimePickSemester,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
                        ),
                        const SizedBox(width: 8),
                        Icon(LucideIcons.chevronDown, size: 16, color: t.mut),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (data.courses.isEmpty)
            _emptyState(t)
          else ...[
            _nextCard(t, data, nowWall),
            const SizedBox(height: 14),
            _dayTabs(t, nowWall),
            _dayHeading(t, data, nowWall),
            const SizedBox(height: 12),
            _timeline(t, data, nowWall),
            const SizedBox(height: 22),
            Text(context.l10n.acadTimeMyCourses(data.courses.length.toString()),
                style: BuType.heading.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: t.ink)),
            const SizedBox(height: 10),
            for (final c in data.courses) Padding(padding: const EdgeInsets.only(bottom: 8), child: _courseTile(t, c)),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(BuTokens t) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: EmptyView(icon: LucideIcons.calendarDays, text: context.l10n.acadTimeEmptyText),
      );

  /// Sıradaki / süren ders özeti (kompakt).
  Widget _nextCard(BuTokens t, TimetableData data, DateTime nowWall) {
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
    if (ongoing != null) {
      final left = ongoing.session.endMin - (nowWall.hour * 60 + nowWall.minute);
      head = l.acadTimeNowInClass;
      line = l.acadTimeMinLeft(ongoing.course.name, left.toString());
      accent = courseColor(ongoing.course.color);
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
    }
    return Semantics(
      container: true,
      label: '$head. $line',
      excludeSemantics: true,
      child: AkadCard(
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: accent ?? t.mut, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(head, style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: t.mut)),
              const SizedBox(height: 2),
              Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
            ]),
          ),
        ]),
      ),
    );
  }

  /// Haftanın [weekday] gününün tarihi (bu hafta içinde).
  DateTime _dateOf(int weekday, DateTime nowWall) {
    final base = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    return base.add(Duration(days: weekday - nowWall.weekday));
  }

  Widget _dayTabs(BuTokens t, DateTime nowWall) => Row(children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) const SizedBox(width: 6),
          Expanded(child: _dayCell(t, d, nowWall)),
        ],
      ]);

  Widget _dayCell(BuTokens t, int d, DateTime nowWall) {
    final l = context.l10n;
    final sel = _day == d;
    final date = _dateOf(d, nowWall);
    final name = acadDayName(l, d);
    return Semantics(
      button: true,
      selected: sel,
      label: '${d == nowWall.weekday ? l.acadTimeDayToday(name) : name} ${date.day}',
      excludeSemantics: true,
      onTap: () => setState(() => _day = d),
      child: Material(
        color: sel ? t.pr : t.sf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: sel ? t.pr : t.bd, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _day = d),
          child: SizedBox(
            height: 60,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(acadDayShort(l, d), style: BuType.label.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? t.onPr : t.mut)),
              ),
              const SizedBox(height: 2),
              Text('${date.day}', style: BuType.heading.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: sel ? t.onPr : t.ink)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dayHeading(BuTokens t, TimetableData data, DateTime nowWall) {
    final l = context.l10n;
    final date = _dateOf(_day, nowWall);
    var count = slotsForDay(data.courses, data.semester, date, nowWall: nowWall).length;
    if (count == 0) count = slotsForDay(data.courses, null, date, nowWall: nowWall).length;
    final name = acadDayName(l, _day);
    final title = _day == nowWall.weekday ? l.akademik2DayHeadingToday(name) : name;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 16),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: title, style: BuType.heading.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: t.ink)),
          if (count > 0)
            TextSpan(text: ' · ${l.akademik2CourseCount(count.toString())}', style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: t.mut)),
        ]),
      ),
    );
  }

  Widget _timeline(BuTokens t, TimetableData data, DateTime nowWall) {
    // Seçili haftanın günü: dönem kısıtı için bu hafta içindeki tarihi al.
    final date = _dateOf(_day, nowWall);
    final slots = slotsForDay(data.courses, data.semester, date, nowWall: nowWall);
    final plain = <DaySlot>[];
    if (slots.isEmpty) {
      // Dönem aralığı dışındaysa da oturumları göstermek için kısıtsız çek.
      plain.addAll(slotsForDay(data.courses, null, date, nowWall: nowWall));
    }
    if (slots.isEmpty && plain.isEmpty) {
      return AkadCard(
        child: Row(children: [
          Icon(LucideIcons.coffee, size: 18, color: t.mut),
          const SizedBox(width: 10),
          Expanded(child: Text(context.l10n.acadTimeNoClassDay(acadDayName(context.l10n, _day)), style: BuType.body.copyWith(color: t.mut))),
        ]),
      );
    }
    final list = slots.isNotEmpty ? slots : plain;
    return Column(children: [
      if (slots.isEmpty && plain.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: StaleBanner(text: context.l10n.acadTimeOutOfRange)),
      for (final s in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: _slotRow(t, s)),
    ]);
  }

  Widget _slotRow(BuTokens t, DaySlot s) {
    final c = s.course;
    final color = courseColor(c.color);
    final onTint = akadOnTint(context, color);
    final status = switch (s.status) {
      SlotStatus.ongoing => context.l10n.acadTimeStatusNow,
      SlotStatus.past => context.l10n.acadTimeStatusDone,
      SlotStatus.upcoming => null,
    };
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 44,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(s.session.start, style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: t.mut))),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(s.session.end, style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.mut))),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Opacity(
          opacity: s.status == SlotStatus.past ? .6 : 1,
          child: ColorCard(
            color: color,
            onTap: () => _openForm(course: c),
            semanticLabel:
                '${context.l10n.acadTimeSlotSemantic(c.name, acadDayName(context.l10n, s.session.dayOfWeek.clamp(1, 7)), s.session.start, s.session.end)}${s.session.room != null ? ', ${s.session.room}' : ''}${status != null ? ', $status' : ''}',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink))),
                if (status != null) BuBadge(status, color: s.status == SlotStatus.ongoing ? t.ok : t.sf2, onColor: s.status == SlotStatus.ongoing ? Colors.white : t.mut),
              ]),
              if (s.session.room != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    ExcludeSemantics(child: Icon(LucideIcons.mapPin, size: 14, color: onTint)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.session.room!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: t.ink))),
                  ]),
                ),
              if (c.code != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(c.code!, style: BuType.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.mut))),
              if (c.instructor != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(c.instructor!, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.mut))),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _courseTile(BuTokens t, Course c) {
    final days = {for (final s in c.sessions) '${acadDayShort(context.l10n, s.dayOfWeek.clamp(1, 7))} ${s.start}-${s.end}'}.join(' · ');
    return ColorCard(
      color: courseColor(c.color),
      onTap: () => _openForm(course: c),
      semanticLabel: context.l10n.acadTimeCourseSemantic(c.name, days),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink)),
            if (c.instructor != null) MetaLine(LucideIcons.user, c.instructor!),
            MetaLine(LucideIcons.clock, days.isEmpty ? context.l10n.acadTimeNoSessions : days),
          ]),
        ),
        Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
      ]),
    );
  }
}
