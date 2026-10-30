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
import 'akad_widgets.dart';
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
  List<AcademicEvent>? _events;
  bool _maintenance = false;
  bool _noDept = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadEvents();
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

  Future<void> _loadEvents() async {
    try {
      final ev = await _api.nextEvents(limit: 3);
      if (mounted) setState(() => _events = ev);
    } catch (e) {
      _note(e);
    }
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
    final ev = _events;
    return AcademicScaffold(
      title: l.acadHubTitle,
      actions: [
        Semantics(
          button: true,
          label: l.acadHubReminders,
          excludeSemantics: true,
          onTap: () => _go(ReminderSettingsPage(session: s)),
          child: BuPressable(
            onTap: () => _go(ReminderSettingsPage(session: s)),
            haptic: BuHaptic.selection,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.bellRing, size: 16, color: t.pr),
                  const SizedBox(width: 6),
                  Text(l.acadHubReminders, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: t.pr)),
                ]),
              ),
            ),
          ),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          await _refresh();
          await _loadEvents();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (_semester != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(_semester!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.mut))),
                ]),
              ),
            if (_maintenance) ...[AkadNoticeCard(text: l.acadMaintenance), const SizedBox(height: 14)],
            if (_noDept) ...[_noDeptCard(l, t, tx), const SizedBox(height: 14)],
            if (ex != null) ...[
              AcadhubNextExamCard(
                label: l.acadhubNextExam,
                title: ex.title.isNotEmpty ? ex.title : (ex.courseName ?? ''),
                subtitle: ex.title.isNotEmpty ? ex.courseName : null,
                countdown: countdownTextL(l, ex.startsAt, academicClock()),
                dateLabel: l.p20HubDateTime,
                dateText: _examWhen(l, ex),
                roomLabel: l.acadFormRoom,
                room: ex.room,
                planLabel: l.p20HubExamPlan,
                onTap: () => _go(ExamsPage(session: s)),
              ),
              const SizedBox(height: 20),
            ],
            if (ev != null && ev.isNotEmpty) ...[
              Row(children: [
                Expanded(child: Semantics(header: true, child: Text(l.acadhubUpcoming, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)))),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48)),
                  onPressed: () => _go(AcademicCalendarPage(session: s)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(l.acadhubCalendarLink, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: t.pr)),
                    Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.pr),
                  ]),
                ),
              ]),
              const SizedBox(height: 4),
              AcadhubDateStrip(
                dates: [
                  for (var i = 0; i < ev.length; i++) AcadhubDate(day: _short(l, ev[i]), title: ev[i].title, primary: i == 0),
                ],
                onTap: () => _go(AcademicCalendarPage(session: s)),
              ),
              const SizedBox(height: 20),
            ],
            // 1) Ders programı
            if (cc == 0)
              AcadhubEmptyCard(
                key: const ValueKey('acadhub-timetable'),
                icon: LucideIcons.calendar,
                title: l.acadHubTimetable,
                badge: _semester,
                emptyIcon: LucideIcons.calendarX,
                emptyTitle: l.acadHubNoClassWeek,
                emptyBody: l.p20HubTimetableEmptyBody,
                actionLabel: l.acadHubAddCourses,
                onAction: () => _go(TimetablePage(session: s)),
                onTap: () => _go(TimetablePage(session: s)),
              )
            else
              AcadhubTile(
                key: const ValueKey('acadhub-timetable'),
                icon: LucideIcons.clock,
                tileBg: t.tint(1).bg,
                tileFg: t.tint(1).fg,
                title: l.acadHubTimetable,
                sub: l.acadHubTimetableSub,
                chip: cc == null ? null : (nc == null ? l.acadHubNoClassWeek : l.acadHubNext(nc.name, nc.start)),
                onTap: () => _go(TimetablePage(session: s)),
              ),
            const SizedBox(height: 14),
            // 2) Sınavlar
            if (ec == 0)
              AcadhubEmptyCard(
                key: const ValueKey('acadhub-exams'),
                icon: LucideIcons.clipboardList,
                iconBg: t.soft,
                iconFg: t.onSoft,
                title: l.acadExamsTitle,
                badge: l.p20HubExamBadge,
                emptyIcon: LucideIcons.clipboardCheck,
                emptyTitle: l.acadHubNoExam,
                emptyBody: l.p20HubExamEmptyBody,
                onTap: () => _go(ExamsPage(session: s)),
              )
            else
              AcadhubTile(
                key: const ValueKey('acadhub-exams'),
                icon: LucideIcons.clipboardList,
                tileBg: t.soft,
                tileFg: t.onSoft,
                title: l.acadExamsTitle,
                sub: l.acadHubExamsSub,
                chip: ec == null ? null : l.acadHubExamCount(ec.toString()),
                chipTone: AcadhubChipTone.soft,
                onTap: () => _go(ExamsPage(session: s)),
              ),
            const SizedBox(height: 14),
            // 3) Akademik takvim
            if (ev != null && ev.isEmpty)
              AcadhubEmptyCard(
                key: const ValueKey('acadhub-calendar'),
                icon: LucideIcons.calendarDays,
                iconBg: t.sf2,
                iconFg: t.ink,
                title: l.acadCalTitle,
                sub: l.acadHubCalendarSub,
                emptyIcon: LucideIcons.calendarCheck,
                emptyTitle: l.acadhubNoUpcoming,
                emptyBody: l.p20HubCalEmptySub,
                rowStyle: true,
                onTap: () => _go(AcademicCalendarPage(session: s)),
              )
            else
              AcadhubTile(
                key: const ValueKey('acadhub-calendar'),
                icon: LucideIcons.calendarDays,
                tileBg: t.sf2,
                tileFg: t.ink,
                title: l.acadCalTitle,
                sub: l.acadHubCalendarSub,
                onTap: () => _go(AcademicCalendarPage(session: s)),
              ),
            const SizedBox(height: 14),
            // 4) Bölüm duyuruları
            if (un == 0)
              AcadhubEmptyCard(
                key: const ValueKey('acadhub-announcements'),
                icon: LucideIcons.megaphone,
                title: l.acadAnnTitle,
                sub: l.acadHubAnnouncementsSub,
                emptyIcon: LucideIcons.mailCheck,
                emptyTitle: l.p20HubAnnEmptyTitle,
                emptyBody: l.p20HubAnnEmptyBody,
                onTap: () => _go(AnnouncementsPage(session: s)),
              )
            else
              AcadhubTile(
                key: const ValueKey('acadhub-announcements'),
                icon: LucideIcons.megaphone,
                tileBg: t.tint(1).bg,
                tileFg: t.tint(1).fg,
                title: l.acadAnnTitle,
                sub: l.acadHubAnnouncementsSub,
                chip: un == null ? null : l.acadHubUnread(un.toString()),
                chipTone: AcadhubChipTone.solid,
                onTap: () => _go(AnnouncementsPage(session: s)),
              ),
          ],
        ),
      ),
    );
  }

  /// "18 Kasım • 10:30" (İstanbul duvar saati).
  String _examWhen(AppLocalizations l, Exam e) {
    final w = istanbulWall(e.startsAt);
    return '${w.day} ${monthNameL(l, w.month)} • ${hhmm(w.hour * 60 + w.minute)}';
  }

  /// "18 Kasım" (kısa tarih çipi).
  String _short(AppLocalizations l, AcademicEvent e) {
    final w = istanbulWall(e.startsAt);
    return '${w.day} ${monthNameL(l, w.month)}';
  }

  Widget _noDeptCard(AppLocalizations l, BuTokens t, TextTheme tx) => Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bLg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle),
              child: ExcludeSemantics(child: Icon(LucideIcons.idCard, size: 18, color: t.pr)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.p20HubNoDeptTitle, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                const SizedBox(height: 2),
                Text(l.p20HubNoDeptBody, style: tx.bodySmall!.copyWith(color: t.onSoft)),
                const SizedBox(height: 10),
                BuButton(label: l.p20EditProfile, icon: LucideIcons.arrowRight, compact: true, onPressed: () => openEditProfile(context, widget.session)),
              ]),
            ),
          ]),
        ),
      );
}
