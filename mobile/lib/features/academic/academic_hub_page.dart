import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu_widgets.dart';
import '../notifications/notif_row.dart';
import 'academic_api.dart';
import 'acadhub_widgets.dart';
import 'academic_calendar_page.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'announcements_page.dart';
import 'exams_page.dart';
import 'reminder_settings_page.dart';
import 'reminders.dart';
import 'timetable_page.dart';

/// Akademik giriş sayfası (Profil > Akademik): ders programı, sınavlar, akademik takvim, bölüm duyuruları.
class AcademicHubPage extends StatefulWidget {
  const AcademicHubPage({super.key, required this.session});

  final Session session;

  @override
  State<AcademicHubPage> createState() => _AcademicHubPageState();
}

class _AcademicHubPageState extends State<AcademicHubPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  int _unread = 0;
  // Özet verisi tutulur, metin build'de dile göre üretilir.
  int? _courseCount;
  ({String name, String start})? _nextClass;
  int? _examCount;
  Exam? _nextExam;
  List<AcademicEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadEvents();
    // Hatırlatmalar sunucudaki güncel veriyle yeniden kurulur (hata sessizce yutulur).
    ReminderService.registerProvider(_api);
    unawaited(ReminderService.sync(_api));
  }

  Future<void> _refresh() async {
    try {
      final c = await _api.unreadCount();
      if (mounted) setState(() => _unread = c);
    } catch (_) {}
    try {
      final tt = await _api.timetable();
      final n = nextSlot(tt.courses, tt.semester, istanbulWall(academicClock()));
      if (mounted) {
        setState(() {
          _courseCount = tt.courses.length;
          _nextClass = n == null ? null : (name: n.slot.course.name, start: n.slot.session.start);
        });
      }
    } catch (_) {}
    try {
      final ex = await _api.upcomingExams(days: 30);
      if (mounted) {
        setState(() {
          _examCount = ex.length;
          _nextExam = ex.isEmpty ? null : ex.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEvents() async {
    try {
      final ev = await _api.nextEvents(limit: 3);
      if (mounted) setState(() => _events = ev);
    } catch (_) {}
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final l = context.l10n;
    final t = context.bu;
    final cc = _courseCount, nc = _nextClass, ec = _examCount;
    final timetableHint = cc == null
        ? l.acadHubTimetableSub
        : cc == 0
            ? l.acadHubAddCourses
            : nc == null
                ? l.acadHubNoClassWeek
                : l.acadHubNext(nc.name, nc.start);
    final examHint = ec == null ? l.acadHubExamsSub : (ec == 0 ? l.acadHubNoExam : l.acadHubExamCount(ec.toString()));
    final ex = _nextExam;
    final cardTitle = ex == null ? (ec == null ? l.acadHubExamsSub : l.acadHubNoExam) : (ex.title.isNotEmpty ? ex.title : (ex.courseName ?? ''));
    final cardSub = ex == null ? null : fmtInstantL(l, ex.startsAt);
    return AcademicScaffold(
      title: l.acadHubTitle,
      actions: [
        BuIconButton(icon: LucideIcons.bellRing, tooltip: l.acadHubReminders, onTap: () => _go(ReminderSettingsPage(session: s))),
      ],
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 32),
        children: [
          AcadhubNextExamCard(
            label: l.acadhubNextExam,
            title: cardTitle,
            subtitle: cardSub,
            onTap: () => _go(ExamsPage(session: s)),
          ),
          const SizedBox(height: 16),
          _grid([
            _tile(LucideIcons.calendarDays, NotifTone.red, l.acadHubTimetable, timetableHint, () => _go(TimetablePage(session: s)),
                key: 'acadhub-timetable'),
            _tile(LucideIcons.fileText, NotifTone.blue, l.acadExamsTitle, examHint, () => _go(ExamsPage(session: s)),
                key: 'acadhub-exams'),
            _tile(LucideIcons.clock, NotifTone.green, l.acadCalTitle, l.acadHubCalendarSub, () => _go(AcademicCalendarPage(session: s)),
                key: 'acadhub-calendar'),
            _tile(LucideIcons.megaphone, NotifTone.amber, l.acadAnnTitle, l.acadHubAnnouncementsSub,
                () => _go(AnnouncementsPage(session: s)),
                badge: _unread, key: 'acadhub-announcements'),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.acadhubUpcoming, style: BuType.title.copyWith(fontSize: 17, color: t.ink)),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _go(AcademicCalendarPage(session: s)),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(l.acadhubCalendarLink,
                      style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: t.pr)),
                ),
              ),
            ]),
          ),
          AcadhubUpcomingCard(
            events: [
              for (var i = 0; i < _events.length; i++)
                AcadhubDate(
                  month: monthNameL(l, istanbulWall(_events[i].startsAt).month),
                  day: istanbulWall(_events[i].startsAt).day,
                  title: _events[i].title,
                  range: _range(l, _events[i]),
                  tone: i.isEven ? NotifTone.red : NotifTone.blue,
                ),
            ],
            emptyText: l.acadhubNoUpcoming,
          ),
        ],
      ),
    );
  }

  String _range(AppLocalizations l, AcademicEvent e) {
    final a = istanbulWall(e.startsAt);
    final end = e.endsAt;
    if (end == null) return fmtInstantL(l, e.startsAt, time: false);
    final b = istanbulWall(end);
    if (a.year == b.year && a.month == b.month && a.day == b.day) return fmtInstantL(l, e.startsAt, time: false);
    if (a.month == b.month && a.year == b.year) return '${a.day} – ${b.day} ${monthNameL(l, a.month)} ${a.year}';
    return '${fmtInstantL(l, e.startsAt, time: false)} – ${fmtInstantL(l, end, time: false)}';
  }

  /// 2 sütunlu karo ızgarası; satır içinde eşit yükseklik (dar ekranda metin uzayabilir).
  Widget _grid(List<Widget> tiles) {
    Widget row(Widget a, Widget b) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ]),
        );
    return Column(children: [
      row(tiles[0], tiles[1]),
      const SizedBox(height: 12),
      row(tiles[2], tiles[3]),
    ]);
  }

  Widget _tile(IconData icon, NotifTone tone, String title, String sub, VoidCallback onTap, {int badge = 0, required String key}) {
    final t = context.bu;
    final l = context.l10n;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: '$title. $sub${badge > 0 ? '. ${l.acadHubUnread(badge.toString())}' : ''}',
      onTap: onTap,
      child: BuCard(
        key: ValueKey(key),
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            NotifIconTile(icon: icon, tone: tone, size: 48, radius: 16),
            const Spacer(),
            if (badge > 0) BuBadge(badge > 99 ? '99+' : '$badge', color: t.pr, onColor: t.onPr),
          ]),
          const SizedBox(height: 12),
          Text(title, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
        ]),
      ),
    );
  }
}
