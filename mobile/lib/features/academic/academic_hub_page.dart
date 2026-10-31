import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_calendar_page.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'acadhub_widgets.dart';
import 'acad_ref_widgets.dart';
import 'announcements_page.dart';
import 'exams_page.dart';
import 'reminder_settings_page.dart';
import 'reminders.dart';
import 'timetable_page.dart';

/// Akademik giriş sayfası (Profil > Akademik; Stitch 43): sıradaki sınav, yaklaşan tarihler, ders programı, sınavlar,
/// akademik takvim ve bölüm duyuruları kartları. Verisi olmayan kart boş durum kutusuna dönüşür.
class AcademicHubPage extends StatefulWidget {
  const AcademicHubPage({super.key, required this.session});

  final Session session;

  @override
  State<AcademicHubPage> createState() => _AcademicHubPageState();
}

class _AcademicHubPageState extends State<AcademicHubPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  int? _unread;
  // Özet verisi tutulur, metin build'de dile göre üretilir.
  int? _courseCount;
  ({String name, String start})? _nextClass;
  String? _semester;
  int? _examCount;
  Exam? _nextExam;
  bool _maintenance = false;
  bool _noDept = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Hatırlatmalar sunucudaki güncel veriyle yeniden kurulur (hata sessizce yutulur).
    ReminderService.registerProvider(_api);
    unawaited(ReminderService.sync(_api));
  }

  void _note(Object e) {
    if (e is ApiError && e.status == 503 && mounted) setState(() => _maintenance = true);
  }

  Future<void> _refresh() async {
    try {
      final c = await _api.unreadCount();
      if (mounted) setState(() => _unread = c);
    } catch (e) {
      _note(e);
    }
    try {
      final tt = await _api.timetable();
      final n = nextSlot(tt.courses, tt.semester, istanbulWall(academicClock()));
      if (mounted) {
        setState(() {
          _courseCount = tt.courses.length;
          _semester = tt.semester?.name;
          _nextClass = n == null ? null : (name: n.slot.course.name, start: n.slot.session.start);
        });
      }
    } catch (e) {
      _note(e);
    }
    try {
      final ex = await _api.upcomingExams(days: 30);
      if (mounted) {
        setState(() {
          _examCount = ex.length;
          _nextExam = ex.isEmpty ? null : ex.first;
        });
      }
    } catch (e) {
      _note(e);
    }
    try {
      final o = await _api.officialExams();
      if (mounted) setState(() => _noDept = !o.profileComplete);
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
    final tx = Theme.of(context).textTheme;
    final cc = _courseCount, nc = _nextClass, ec = _examCount, un = _unread;
    final ex = _nextExam;
    final timetableSub = cc == null
        ? l.acadHubTimetableSub
        : (cc == 0 ? l.acadHubAddCourses : (nc == null ? l.acadHubNoClassWeek : l.acadHubNext(nc.name, nc.start)));
    final examsSub = ec == null ? l.acadHubExamsSub : (ec == 0 ? l.acadHubNoExam : l.acadHubExamCount(ec.toString()));
    final annSub = (un == null || un == 0) ? l.acadHubAnnouncementsSub : l.acadHubUnread(un.toString());
    return AcademicScaffold(
      title: l.acadHubTitle,
      actions: [AcadTextAction(l.acadHubReminders, onTap: () => _go(ReminderSettingsPage(session: s)), size: 14)],
      child: RefreshIndicator(
        onRefresh: () async {
          await _refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (_maintenance) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: AcadAmberNote(text: l.acadMaintenance)),
            if (_noDept)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: AcadAmberNote(text: '${l.p20HubNoDeptTitle}. ${l.p20HubNoDeptBody}', actionLabel: l.p20EditProfile, onAction: () => openEditProfile(context, s)),
              ),
            if (_semester != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 1, 20, 0),
                child: Text(_semester!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
              ),
            if (ex != null) ...[
              const SizedBox(height: 17),
              AcadhubNextExam(
                key: const ValueKey('acadhub-next-exam'),
                label: l.acadhubNextExam,
                title: ex.title.isNotEmpty ? ex.title : (ex.courseName ?? ''),
                detail: _examWhen(l, ex),
                countdown: countdownTextL(l, ex.startsAt, academicClock()),
                onTap: () => _go(ExamsPage(session: s)),
              ),
              const SizedBox(height: 22),
            ] else
              const SizedBox(height: 14),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: AcadRule()),
            AcadhubNavRow(key: const ValueKey('acadhub-timetable'), title: l.acadHubTimetable, sub: timetableSub, onTap: () => _go(TimetablePage(session: s))),
            AcadhubNavRow(key: const ValueKey('acadhub-exams'), title: l.acadExamsTitle, sub: examsSub, onTap: () => _go(ExamsPage(session: s))),
            AcadhubNavRow(
              key: const ValueKey('acadhub-calendar'),
              title: l.acadCalTitle,
              sub: l.acadHubCalendarSub,
              onTap: () => _go(AcademicCalendarPage(session: s)),
            ),
            AcadhubNavRow(key: const ValueKey('acadhub-announcements'), title: l.acadAnnTitle, sub: annSub, onTap: () => _go(AnnouncementsPage(session: s))),
          ],
        ),
      ),
    );
  }

  /// "18 Kasım · 10:30 · B-204" (İstanbul duvar saati; derslik varsa).
  String _examWhen(AppLocalizations l, Exam e) {
    final w = istanbulWall(e.startsAt);
    return [
      '${w.day} ${monthNameL(l, w.month)}',
      hhmm(w.hour * 60 + w.minute),
      if (e.room != null && e.room!.isNotEmpty) e.room!,
    ].join(' · ');
  }

}
