import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../academic/acad_ref_widgets.dart';
import '../academic/academic_widgets.dart';
import 'course_widgets.dart';
import 'my_course_detail_page.dart';
import 'my_courses_api.dart';
import 'my_courses_models.dart';

/// Derslerim (öğrenci): kayıtlı dersler (devam durumu, sınır), yaklaşan sınav/ödev/iptal/derslik değişikliği.
/// Veri: `GET /my-courses` + `GET /my-courses/upcoming` (yaklaşanlar alınamazsa liste yine açılır).
class MyCoursesPage extends StatefulWidget {
  const MyCoursesPage({super.key, required this.session});

  final Session session;

  @override
  State<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends State<MyCoursesPage> {
  late final MyCoursesApi _api = MyCoursesApi(widget.session);
  List<MyCourse>? _courses;
  List<CourseNotice> _upcoming = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final courses = await _api.courses();
      var upcoming = const <CourseNotice>[];
      try {
        upcoming = sortUpcoming(await _api.upcoming());
      } catch (_) {
        // Yaklaşanlar yardımcı bilgidir: alınamazsa ders listesi yine gösterilir.
      }
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _upcoming = upcoming;
      });
    } catch (e) {
      if (!mounted) return;
      if (_courses != null) {
        // Veri zaten var (yenileme): hata geçici bildirimle gösterilir, eski liste korunur.
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      } else {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _openCourse(int courseId, {MyCourse? course}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'my_course_detail'),
      builder: (_) => MyCourseDetailPage(session: widget.session, courseId: courseId, course: course),
    ));
    if (mounted) _load();
  }

  List<Widget> _body() {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final courses = _courses;
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Semantics(header: true, child: Text(l.myCoursesTitle, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
    );
    if (courses == null) {
      if (_error != null) {
        return [head, AcadStateText(text: '${l.sistemuiErrorTitle}\n${errorText(_error!)}', actionLabel: l.acadRetry, onAction: _load)];
      }
      return [head, const AcadRowsSkeleton(count: 3)];
    }
    if (courses.isEmpty) {
      return [
        head,
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: BuEmptyState(
            key: const ValueKey('my-courses-empty'),
            illustration: BuIllustration.calendar,
            title: l.myCoursesEmptyTitle,
            message: l.myCoursesEmptyBody,
            compact: true,
          ),
        ),
      ];
    }
    final shown = _upcoming.take(5).toList();
    return [
      head,
      if (shown.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Semantics(header: true, child: Text(l.myCoursesUpcoming, style: tx.labelMedium!.copyWith(color: t.mut))),
        ),
        for (final n in shown) _upcomingRow(n),
        const SizedBox(height: 12),
      ],
      for (final c in courses) _courseRow(c),
    ];
  }

  Widget _upcomingRow(CourseNotice n) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cid = n.courseId;
    final when = noticeWhenLine(l, n);
    final headline = noticeHeadline(l, n);
    final sub = [
      if (n.title != null) noticeTypeLabel(l, n.type),
      if (n.courseName != null) n.courseName!,
      if (when != null) when,
    ].join(' · ');
    return AcadRow(
      key: ValueKey('upcoming-${n.id}'),
      minHeight: 64,
      onTap: cid == null ? null : () => _openCourse(cid),
      semanticLabel: '$headline. $sub',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w400, color: t.ink)),
        if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
      ]),
    );
  }

  Widget _courseRow(MyCourse c) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final meta = [if (c.code != null) c.code!, if (c.academicianName != null) c.academicianName!].join(' · ');
    return AcadRow(
      key: ValueKey('course-${c.courseId}'),
      minHeight: 88,
      onTap: () => _openCourse(c.courseId, course: c),
      semanticLabel: c.courseName,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(c.courseName, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w500, color: t.ink)),
            if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
            const SizedBox(height: 4),
            CourseAttendanceInfo(course: c),
          ]),
        ),
        const SizedBox(width: 8),
        ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 18, color: t.mut)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AcademicScaffold(
      title: l.myCoursesTitle,
      child: BuRefreshIndicator(
        onRefresh: Analytics.pullRefresh(_load),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: _body(),
        ),
      ),
    );
  }
}
