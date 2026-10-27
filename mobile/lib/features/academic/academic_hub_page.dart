import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'academic_api.dart';
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
  String? _timetableHint;
  String? _examHint;

  @override
  void initState() {
    super.initState();
    _refresh();
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
        setState(() => _timetableHint = tt.courses.isEmpty
            ? 'Derslerini ekle'
            : n == null
                ? 'Bu hafta ders yok'
                : 'Sıradaki: ${n.slot.course.name} ${n.slot.session.start}');
      }
    } catch (_) {}
    try {
      final ex = await _api.upcomingExams(days: 30);
      if (mounted) setState(() => _examHint = ex.isEmpty ? 'Yaklaşan sınav yok' : '${ex.length} yaklaşan sınav');
    } catch (_) {}
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return AcademicScaffold(
      title: 'Akademik',
      actions: [
        BuIconButton(icon: LucideIcons.bellRing, tooltip: 'Hatırlatmalar', onTap: () => _go(ReminderSettingsPage(session: s))),
      ],
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32),
        children: [
          _tile(LucideIcons.calendarDays, 'Ders programı', _timetableHint ?? 'Haftalık ders programın', () => _go(TimetablePage(session: s))),
          _tile(LucideIcons.fileText, 'Sınavlar', _examHint ?? 'Sınav takvimin ve resmi program', () => _go(ExamsPage(session: s))),
          _tile(LucideIcons.calendarRange, 'Akademik takvim', 'Dönem, kayıt ve sınav tarihleri', () => _go(AcademicCalendarPage(session: s))),
          _tile(LucideIcons.megaphone, 'Bölüm duyuruları', 'Bölümüne özel duyurular', () => _go(AnnouncementsPage(session: s)), badge: _unread),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap, {int badge = 0}) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        container: true,
        button: true,
        excludeSemantics: true,
        label: '$title. $sub${badge > 0 ? '. $badge okunmamış' : ''}',
        onTap: onTap,
        child: BuCard(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 21, color: t.pr),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: BuType.heading.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
              ]),
            ),
            if (badge > 0) BuBadge(badge > 99 ? '99+' : '$badge', color: t.pr, onColor: t.onPr),
            const SizedBox(width: 6),
            Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.mut),
          ]),
        ),
      ),
    );
  }
}
