import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../academic/acad_ref_widgets.dart';
import '../academic/academic_widgets.dart';
import 'course_widgets.dart';
import 'my_courses_api.dart';
import 'my_courses_models.dart';

/// Ders ayrıntısı (öğrenci): devam durumu ve sınır + dersin duyuruları (ekleriyle, sayfa sayfa).
/// Bildirim dokunuşu yalnız [courseId] ile açar; [course] verilmezse `GET /my-courses` listesinden bulunur.
class MyCourseDetailPage extends StatefulWidget {
  const MyCourseDetailPage({super.key, required this.session, required this.courseId, this.course});

  final Session session;
  final int courseId;
  final MyCourse? course;

  @override
  State<MyCourseDetailPage> createState() => _MyCourseDetailPageState();
}

class _MyCourseDetailPageState extends State<MyCourseDetailPage> {
  late final MyCoursesApi _api = MyCoursesApi(widget.session);
  MyCourse? _course;
  List<CourseNotice>? _notices;
  String? _next;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // Duyurular asıl içeriktir (403: derse kayıtlı değil -> hata); ders özeti yalnız başlık/sayılar içindir.
      final page = await _api.notices(widget.courseId);
      MyCourse? course = _course;
      try {
        // Devam sayıları da yenilenir (yenileme/geri dönüş); alınamazsa eldeki özet korunur.
        for (final c in await _api.courses()) {
          if (c.courseId == widget.courseId) course = c;
        }
      } catch (_) {
        // Özet alınamazsa duyurular yine gösterilir.
      }
      if (!mounted) return;
      setState(() {
        _notices = page.items;
        _next = page.nextCursor;
        _course = course;
      });
    } catch (e) {
      if (!mounted) return;
      if (_notices != null) {
        // Veri zaten var (yenileme): hata geçici bildirimle gösterilir, eski liste korunur.
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      } else {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _next;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.notices(widget.courseId, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _notices = [...?_notices, ...page.items];
        _next = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  List<Widget> _body() {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final c = _course;
    final notices = _notices;
    final List<Widget> section;
    if (notices == null) {
      section = _error != null
          ? [AcadStateText(text: '${l.sistemuiErrorTitle}\n${errorText(_error!)}', actionLabel: l.acadRetry, onAction: _load)]
          : [const AcadRowsSkeleton(count: 3)];
    } else if (notices.isEmpty) {
      section = [AcadStateText(text: l.courseNoticesEmpty, top: 24)];
    } else {
      section = [
        for (final n in notices) NoticeCard(session: widget.session, courseId: widget.courseId, notice: n),
        if (_next != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _loadingMore
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: BuSpinner()))
                : AcadStateText(key: const ValueKey('notices-more'), text: '', actionLabel: l.courseNoticesMore, onAction: _loadMore, top: 0),
          ),
      ];
    }
    return [
      if (c != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text(c.courseName, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
            if (c.academicianName != null)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(c.academicianName!, style: tx.bodyMedium!.copyWith(color: t.mut))),
            const SizedBox(height: 8),
            CourseAttendanceInfo(course: c),
          ]),
        ),
      const AcadRule(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Semantics(header: true, child: Text(l.courseNoticesTitle, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
      ),
      ...section,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AcademicScaffold(
      title: _course?.courseName ?? l.myCoursesTitle,
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
