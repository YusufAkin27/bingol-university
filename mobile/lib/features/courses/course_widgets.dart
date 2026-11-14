import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../academic/acad_ref_widgets.dart';
import '../academic/academic_models.dart';
import 'my_courses_api.dart';
import 'my_courses_models.dart';

/// "18 Kasım · 10:30" (İstanbul duvar saati).
String noticeWhenText(AppLocalizations l, DateTime instant) {
  final w = istanbulWall(instant);
  return '${w.day} ${monthNameL(l, w.month)} · ${hhmm(w.hour * 60 + w.minute)}';
}

/// Türün kısa adı; bilinmeyen tür için "Duyuru".
String noticeTypeLabel(AppLocalizations l, String type) => switch (type) {
      NoticeType.lessonStarted => l.noticeTypeLessonStarted,
      NoticeType.attendanceStarted => l.noticeTypeAttendanceStarted,
      NoticeType.exam => l.noticeTypeExam,
      NoticeType.assignment => l.noticeTypeAssignment,
      NoticeType.material => l.noticeTypeMaterial,
      NoticeType.lessonCancelled => l.noticeTypeLessonCancelled,
      NoticeType.roomChanged => l.noticeTypeRoomChanged,
      _ => l.noticeTypeOther,
    };

/// Satır başlığı: derslik değişiminde yeni derslik, diğerlerinde başlık; başlık yoksa tür adı. Bilinmeyen tür çökmez.
String noticeHeadline(AppLocalizations l, CourseNotice n) {
  final title = n.title;
  if (n.type == NoticeType.roomChanged && title != null) return l.noticeRoomChanged(title);
  return title ?? noticeTypeLabel(l, n.type);
}

/// Tarih satırı (varsa): sınav zamanı / son teslim / ders zamanı; diğer türlerde (ör. bilinmeyen) yalnız tarih.
String? noticeWhenLine(AppLocalizations l, CourseNotice n) {
  final at = n.eventAt;
  if (at == null) return null;
  final when = noticeWhenText(l, at);
  return switch (n.type) {
    NoticeType.exam => l.noticeExamWhen(when),
    NoticeType.assignment => l.noticeDueWhen(when),
    NoticeType.lessonCancelled || NoticeType.roomChanged => l.noticeLessonWhen(when),
    _ => when,
  };
}

/// Devam sayıları, sınır ve durum (sınıra yakın / sınır aşıldı). Durum rengi tek başına anlam taşımaz: metin de vardır.
class CourseAttendanceInfo extends StatelessWidget {
  const CourseAttendanceInfo({super.key, required this.course});

  final MyCourse course;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final limit = course.limit;
    final limitText = limit == null ? null : (limit.isPercent ? l.myCoursesLimitPercent(limit.value) : l.myCoursesLimitCount(limit.value));
    final status = course.overLimit ? l.myCoursesOverLimit : (course.atRisk ? l.myCoursesAtRisk : null);
    final statusColor = course.overLimit ? t.danger : t.warn;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(l.myCoursesCounts(course.presentCount, course.absentCount), style: tx.bodySmall!.copyWith(color: t.mut)),
      if (limitText != null) Text(limitText, style: tx.bodySmall!.copyWith(color: t.mut)),
      if (status != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ExcludeSemantics(child: Icon(course.overLimit ? BuIcons.circleAlert : BuIcons.triangleAlert, size: 16, color: statusColor)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(status, key: const ValueKey('course-status'), style: tx.bodySmall!.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
    ]);
  }
}

IconData _fileIcon(NoticeFile f) {
  final ct = f.contentType.toLowerCase();
  final n = f.name.toLowerCase();
  if (ct.startsWith('image/') || n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg')) return BuIcons.image;
  return BuIcons.fileText;
}

/// Ek satırı: dosya simgesi, ad, okunur boyut; dokununca indirir ve açma/kaydetme sayfasını açar.
class NoticeFileRow extends StatefulWidget {
  const NoticeFileRow({super.key, required this.session, required this.courseId, required this.noticeId, required this.file});

  final Session session;
  final int courseId;
  final int noticeId;
  final NoticeFile file;

  @override
  State<NoticeFileRow> createState() => _NoticeFileRowState();
}

class _NoticeFileRowState extends State<NoticeFileRow> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await openNoticeFile(widget.session, widget.courseId, widget.noticeId, widget.file, title: l.noticeFileShareTitle);
    } catch (e) {
      if (mounted) BuToast.show(context, e is ApiError ? errorText(e) : l.noticeFileFailed, kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final f = widget.file;
    final size = humanSize(f.sizeBytes);
    return AcadRow(
      key: ValueKey('notice-file-${f.id}'),
      rule: false,
      minHeight: 56,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      semanticLabel: '${f.name}, $size',
      onTap: _busy ? null : _open,
      child: Row(children: [
        ExcludeSemantics(child: Icon(_fileIcon(f), size: 22, color: t.ink)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.ink)),
            Text(_busy ? l.noticeFileDownloading : size, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
        ),
        const SizedBox(width: 8),
        if (_busy) const BuSpinner(size: 18) else ExcludeSemantics(child: Icon(BuIcons.download, size: 18, color: t.mut)),
      ]),
    );
  }
}

/// Tek duyuru: tür, başlık, not, tarih satırı ve ekler.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.session, required this.courseId, required this.notice});

  final Session session;
  final int courseId;
  final CourseNotice notice;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final n = notice;
    final created = n.createdAt;
    final when = noticeWhenLine(l, n);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        key: ValueKey('notice-${n.id}'),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(noticeTypeLabel(l, n.type), style: tx.labelMedium!.copyWith(color: t.mut))),
            if (created != null) Text('${istanbulWall(created).day} ${monthNameL(l, istanbulWall(created).month)}', style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
          if (n.title != null) ...[
            const SizedBox(height: 4),
            Text(noticeHeadline(l, n), style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w500)),
          ],
          if (when != null) ...[
            const SizedBox(height: 4),
            Text(when, style: tx.bodyMedium!.copyWith(color: t.ink)),
          ],
          if (n.note != null) ...[
            const SizedBox(height: 6),
            Text(n.note!, style: tx.bodyMedium!.copyWith(color: t.ink, height: 1.4)),
          ],
          for (final f in n.files) NoticeFileRow(session: session, courseId: courseId, noticeId: n.id, file: f),
        ]),
      ),
      const AcadRule(),
    ]);
  }
}
