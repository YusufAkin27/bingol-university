import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'course_form_page.dart';
import 'reminders.dart';
import 'semester_sheet.dart';

/// Ders programı: bugün/sıradaki ders, gün sekmeleri + zaman çizelgesi, tüm dersler, dönem seçimi, .ics paylaşımı.
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
      backgroundColor: context.bu.sf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
      academicToast(context, 'Dışa aktarılacak ders yok.');
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
      if (mounted) academicToast(context, 'Takvim (.ics) metni panoya kopyalandı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return AcademicScaffold(
      title: 'Ders programı',
      actions: [
        BuIconButton(icon: LucideIcons.share, tooltip: 'Takvime aktar (.ics)', onTap: data == null ? null : _export),
        BuIconButton(icon: LucideIcons.plus, tooltip: 'Ders ekle', filled: true, onTap: data == null ? null : () => _openForm(day: _day)),
      ],
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
        padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32),
        children: [
          if (_error != null)
            const Padding(padding: EdgeInsets.only(bottom: 8), child: StaleBanner(text: 'Güncellenemedi, son veriler gösteriliyor.')),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              button: true,
              label: 'Dönem seç',
              child: ActionChip(
                avatar: Icon(LucideIcons.graduationCap, size: 15, color: t.pr),
                label: Text(sem?.name ?? 'Dönem seç', style: BuType.label.copyWith(color: t.ink)),
                backgroundColor: t.sf,
                side: BorderSide(color: t.bd),
                onPressed: _pickSemester,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (data.courses.isEmpty)
            _emptyState(t)
          else ...[
            _todayCard(t, data, nowWall),
            const SizedBox(height: 16),
            _dayTabs(t, nowWall),
            const SizedBox(height: 12),
            _timeline(t, data, nowWall),
            const SizedBox(height: 22),
            Text('Derslerim (${data.courses.length})', style: BuType.heading.copyWith(color: t.ink)),
            const SizedBox(height: 10),
            for (final c in data.courses) Padding(padding: const EdgeInsets.only(bottom: 8), child: _courseTile(t, c)),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(BuTokens t) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(children: [
          const EmptyView(icon: LucideIcons.calendarDays, text: 'Henüz ders eklemedin.\nHaftalık programını oluşturmak için derslerini ekle.'),
          BuButton(label: 'İlk dersini ekle', icon: LucideIcons.plus, onPressed: () => _openForm(day: _day)),
        ]),
      );

  Widget _todayCard(BuTokens t, TimetableData data, DateTime nowWall) {
    final today = slotsForDay(data.courses, data.semester, nowWall, nowWall: nowWall);
    DaySlot? ongoing;
    for (final s in today) {
      if (s.status == SlotStatus.ongoing) ongoing = s;
    }
    final next = nextSlot(data.courses, data.semester, nowWall);
    final todayLeft = today.where((s) => s.status != SlotStatus.past).length;

    String head;
    String line;
    Color? accent;
    if (ongoing != null) {
      final left = ongoing.session.endMin - (nowWall.hour * 60 + nowWall.minute);
      head = 'Şu an derste';
      line = '${ongoing.course.name} · $left dk kaldı';
      accent = courseColor(ongoing.course.color);
    } else if (next != null) {
      final s = next.slot;
      final isToday = s.date.day == nowWall.day && s.date.month == nowWall.month;
      final when = next.minutesUntil < 60
          ? '${next.minutesUntil} dk sonra'
          : isToday
              ? '${next.minutesUntil ~/ 60} sa${next.minutesUntil % 60 == 0 ? '' : ' ${next.minutesUntil % 60} dk'} sonra'
              : '${dayNames[s.date.weekday - 1]} ${s.session.start}';
      head = 'Sıradaki ders';
      line = '${s.course.name} · $when';
      accent = courseColor(s.course.color);
    } else {
      head = 'Bugün';
      line = 'Bu hafta başka dersin yok.';
    }
    return Semantics(
      container: true,
      label: '$head. $line',
      child: BuHeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (accent != null) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(head, style: BuType.label.copyWith(color: Colors.white.withValues(alpha: .85)))),
            Text(longDate(nowWall), style: BuType.caption.copyWith(color: Colors.white.withValues(alpha: .85))),
          ]),
          const SizedBox(height: 8),
          Text(line, maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(todayLeft == 0 ? 'Bugün kalan ders yok' : 'Bugün $todayLeft ders kaldı',
              style: BuType.caption.copyWith(color: Colors.white.withValues(alpha: .85))),
        ]),
      ),
    );
  }

  Widget _dayTabs(BuTokens t, DateTime nowWall) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var d = 1; d <= 7; d++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Semantics(
                label: d == nowWall.weekday ? '${dayNames[d - 1]}, bugün' : dayNames[d - 1],
                child: BuChip(label: dayShort[d - 1], selected: _day == d, onTap: () => setState(() => _day = d)),
              ),
            ),
        ]),
      );

  Widget _timeline(BuTokens t, TimetableData data, DateTime nowWall) {
    // Seçili haftanın günü: dönem kısıtı için bu hafta içindeki tarihi al.
    final base = DateTime.utc(nowWall.year, nowWall.month, nowWall.day);
    final date = base.add(Duration(days: _day - nowWall.weekday));
    final slots = slotsForDay(data.courses, data.semester, date, nowWall: nowWall);
    final plain = <DaySlot>[];
    if (slots.isEmpty) {
      // Dönem aralığı dışındaysa da oturumları göstermek için kısıtsız çek.
      plain.addAll(slotsForDay(data.courses, null, date, nowWall: nowWall));
    }
    if (slots.isEmpty && plain.isEmpty) {
      return BuCard(
        child: Row(children: [
          Icon(LucideIcons.coffee, size: 18, color: t.mut),
          const SizedBox(width: 10),
          Expanded(child: Text('${dayNames[_day - 1]} günü dersin yok.', style: BuType.body.copyWith(color: t.mut))),
        ]),
      );
    }
    final list = slots.isNotEmpty ? slots : plain;
    return Column(children: [
      if (slots.isEmpty && plain.isNotEmpty)
        const Padding(padding: EdgeInsets.only(bottom: 8), child: StaleBanner(text: 'Bu tarih dönem aralığı dışında.')),
      for (final s in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _slotRow(t, s)),
    ]);
  }

  Widget _slotRow(BuTokens t, DaySlot s) {
    final c = s.course;
    final color = courseColor(c.color);
    final status = switch (s.status) {
      SlotStatus.ongoing => 'Şu an',
      SlotStatus.past => 'Bitti',
      SlotStatus.upcoming => null,
    };
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 48,
        child: Column(children: [
          Text(s.session.start, style: BuType.bodyStrong.copyWith(color: t.ink)),
          Text(s.session.end, style: BuType.caption.copyWith(color: t.mut)),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Opacity(
          opacity: s.status == SlotStatus.past ? .6 : 1,
          child: ColorCard(
            color: color,
            onTap: () => _openForm(course: c),
            semanticLabel:
                '${c.name}, ${dayNames[s.session.dayOfWeek - 1]} ${s.session.start} ile ${s.session.end} arası${s.session.room != null ? ', ${s.session.room}' : ''}${status != null ? ', $status' : ''}',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink))),
                if (status != null) BuBadge(status, color: s.status == SlotStatus.ongoing ? t.ok : t.sf2, onColor: s.status == SlotStatus.ongoing ? Colors.white : t.mut),
              ]),
              if (c.code != null) MetaLine(LucideIcons.hash, c.code!),
              if (c.instructor != null) MetaLine(LucideIcons.user, c.instructor!),
              if (s.session.room != null) MetaLine(LucideIcons.mapPin, s.session.room!),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _courseTile(BuTokens t, Course c) {
    final days = {for (final s in c.sessions) '${dayShort[(s.dayOfWeek - 1).clamp(0, 6)]} ${s.start}-${s.end}'}.join(' · ');
    return ColorCard(
      color: courseColor(c.color),
      onTap: () => _openForm(course: c),
      semanticLabel: '${c.name}. $days. Düzenlemek için dokun.',
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
            if (c.instructor != null) MetaLine(LucideIcons.user, c.instructor!),
            MetaLine(LucideIcons.clock, days.isEmpty ? 'Oturum yok' : days),
          ]),
        ),
        Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
      ]),
    );
  }
}
