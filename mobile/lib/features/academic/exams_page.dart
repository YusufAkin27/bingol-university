import 'dart:async';

import 'package:flutter/material.dart';

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
import 'exam_form_page.dart';
import 'reminders.dart';

/// Sınavlar: kişisel sınavlar (geri sayım) ve resmi sınav programı (bölüme göre).
class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key, required this.session, this.initialTab = 0});

  final Session session;
  final int initialTab;

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  late int _tab = widget.initialTab;

  List<Exam> _mine = [];
  List<Course> _courses = [];
  List<OfficialExam> _official = [];
  bool _profileComplete = true;
  bool _showAll = false;
  bool _loadingMine = true, _loadingOfficial = true;
  Object? _errMine, _errOfficial;

  @override
  void initState() {
    super.initState();
    _loadMine();
    _loadOfficial();
  }

  Future<void> _loadMine() async {
    setState(() => _loadingMine = true);
    try {
      final r = await Future.wait([_api.exams(), _api.timetable()]);
      if (!mounted) return;
      setState(() {
        _mine = r[0] as List<Exam>;
        _courses = (r[1] as TimetableData).courses;
        _errMine = null;
        _loadingMine = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errMine = e;
          _loadingMine = false;
        });
      }
    }
  }

  Future<void> _loadOfficial() async {
    setState(() => _loadingOfficial = true);
    try {
      final r = await _api.officialExams(all: _showAll);
      if (!mounted) return;
      setState(() {
        _official = r.items;
        _profileComplete = r.profileComplete;
        _errOfficial = null;
        _loadingOfficial = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errOfficial = e;
          _loadingOfficial = false;
        });
      }
    }
  }

  Future<void> _openForm([Exam? exam]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ExamFormPage(session: widget.session, exam: exam, courses: _courses)),
    );
    if (ok == true) {
      await _loadMine();
      unawaited(ReminderService.sync(_api));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AcademicScaffold(
      title: l.acadExamsTitle,
      bottomBar: _tab == 0 ? AkadBottomBar(children: [AkadButton(label: l.acadExamsAdd, icon: LucideIcons.plus, onPressed: () => _openForm())]) : null,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(children: [
            Flexible(child: AkadChip(label: l.acadExamsTabMine, selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
            const SizedBox(width: 8),
            Flexible(child: AkadChip(label: l.acadExamsTabOfficial, selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
          ]),
        ),
        const SizedBox(height: 4),
        Expanded(child: _tab == 0 ? _mineView() : _officialView()),
      ]),
    );
  }

  // ---- kişisel
  Widget _mineView() {
    if (_loadingMine && _mine.isEmpty) return const LoadingView();
    if (_errMine != null && _mine.isEmpty) return AcademicErrorView(error: _errMine!, onRetry: _loadMine);
    final now = academicClock();
    final upcoming = _mine.where((e) => (e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = _mine.where((e) => !(e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final l = context.l10n;
    if (_mine.isEmpty) {
      return EmptyView(icon: LucideIcons.fileText, text: l.acadExamsEmptyMine);
    }
    final t = context.bu;
    return RefreshIndicator(
      onRefresh: _loadMine,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, AkadBottomBar.reserve),
        children: [
          if (upcoming.isNotEmpty) ...[
            AkadSection(l.acadExamsUpcoming),
            for (final e in upcoming) Padding(padding: const EdgeInsets.only(bottom: 12), child: _examCard(t, e, now)),
          ] else
            Padding(padding: const EdgeInsets.only(bottom: 8), child: StaleBanner(text: l.acadExamsNoUpcoming, icon: LucideIcons.partyPopper)),
          if (past.isNotEmpty) ...[
            AkadSection(l.acadExamsPast, padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8, top: 8)),
            for (final e in past) Padding(padding: const EdgeInsets.only(bottom: 12), child: _examCard(t, e, now)),
          ],
        ],
      ),
    );
  }

  Widget _examCard(BuTokens t, Exam e, DateTime now) {
    final l = context.l10n;
    final cd = countdownTextL(l, e.startsAt, now);
    final color = e.courseId == null
        ? courseColor('gray')
        : courseColor(_courses.where((c) => c.id == e.courseId).map((c) => c.color).firstOrNull ?? 'blue');
    final typeText = examTypeLabelL(l, e.type);
    final dateText = fmtInstantL(l, e.startsAt);
    final isPast = cd == null;
    return _ExamTile(
      color: color,
      past: isPast,
      start: e.startsAt,
      end: e.endsAt,
      title: e.title,
      typeText: typeText,
      course: e.courseName,
      room: e.room,
      pill: isPast ? l.akademik2Passed : cd,
      onTap: () => _openForm(e),
      semanticLabel: cd != null ? l.acadExamsSemanticCd(typeText, e.title, dateText, cd) : l.acadExamsSemantic(typeText, e.title, dateText),
    );
  }

  // ---- resmi
  Widget _officialView() {
    if (_loadingOfficial && _official.isEmpty) return const LoadingView();
    if (_errOfficial != null && _official.isEmpty) return AcademicErrorView(error: _errOfficial!, onRetry: _loadOfficial);
    final t = context.bu;
    final l = context.l10n;
    final now = academicClock();
    return RefreshIndicator(
      onRefresh: _loadOfficial,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
        children: [
          if (!_profileComplete)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StaleBanner(text: l.acadExamsProfileIncomplete, icon: LucideIcons.info),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(spacing: 8, children: [
              AkadChip(label: l.acadMyDept, selected: !_showAll, onTap: () => _toggleAll(false)),
              AkadChip(label: l.acadAll, selected: _showAll, onTap: () => _toggleAll(true)),
            ]),
          ),
          const SizedBox(height: 8),
          if (_official.isEmpty)
            EmptyView(icon: LucideIcons.fileText, text: l.acadExamsEmptyOfficial)
          else
            for (final e in _official) Padding(padding: const EdgeInsets.only(bottom: 12), child: _officialCard(t, e, now)),
        ],
      ),
    );
  }

  void _toggleAll(bool all) {
    if (_showAll == all) return;
    setState(() => _showAll = all);
    _loadOfficial();
  }

  Widget _officialCard(BuTokens t, OfficialExam e, DateTime now) {
    final l = context.l10n;
    final cd = countdownTextL(l, e.startsAt, now);
    final who = [if (e.department != null) e.department!, if (e.grade != null) l.acadGradeN(e.grade!)].join(' · ');
    final typeText = examTypeLabelL(l, e.type);
    final dateText = fmtInstantL(l, e.startsAt);
    return _ExamTile(
      color: courseColor(switch (e.type) { 'FINAL' => 'blue', 'BUT' => 'purple', 'VIZE' => 'red', _ => 'teal' }),
      past: cd == null,
      start: e.startsAt,
      end: e.endsAt,
      title: e.title,
      typeText: typeText,
      code: e.courseCode,
      room: e.room,
      who: who.isEmpty ? null : who,
      note: e.note,
      pill: cd ?? l.akademik2Passed,
      semanticLabel: e.room != null ? l.acadOfficialSemanticRoom(typeText, e.title, dateText, e.room!) : l.acadOfficialSemantic(typeText, e.title, dateText),
    );
  }
}

/// Sınav kartı (Ak4): ay/gün pulu + başlık + "tür · saat" + yer + sağda geri sayım hapı.
class _ExamTile extends StatelessWidget {
  const _ExamTile({
    required this.color,
    required this.past,
    required this.start,
    required this.title,
    required this.typeText,
    required this.semanticLabel,
    this.end,
    this.course,
    this.code,
    this.room,
    this.who,
    this.note,
    this.pill,
    this.onTap,
  });

  final Color color;
  final bool past;
  final DateTime start;
  final DateTime? end;
  final String title, typeText, semanticLabel;
  final String? course, code, room, who, note, pill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final w = istanbulWall(start);
    final time = end == null
        ? hhmm(w.hour * 60 + w.minute)
        : '${hhmm(w.hour * 60 + w.minute)} – ${hhmm(istanbulWall(end!).hour * 60 + istanbulWall(end!).minute)}';
    final tileBg = past ? t.sf2 : akadTint(context, color);
    final tileFg = past ? t.mut : akadOnTint(context, color);
    Widget sub(String s, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(children: [
            if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 13, color: t.mut)), const SizedBox(width: 4)],
            Expanded(child: Text(s, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.mut))),
          ]),
        );
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: AkadCard(
        onTap: onTap,
        child: Row(children: [
          AkadDateTile(month: monthNameL(l, w.month), day: w.day, bg: tileBg, fg: tileFg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink)),
              if (course != null) sub(course!, icon: LucideIcons.bookOpen),
              sub('${code == null ? '' : '$code · '}$typeText · $time'),
              if (room != null) sub(room!, icon: LucideIcons.mapPin),
              if (who != null) sub(who!, icon: LucideIcons.graduationCap),
              if (note != null) sub(note!, icon: LucideIcons.info),
            ]),
          ),
          if (pill != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: past
                  ? AkadPill(pill!, bg: t.sf2, fg: t.mut)
                  : AkadPill(pill!, bg: Theme.of(context).brightness == Brightness.dark ? akadOnTint(context, color) : color, fg: Theme.of(context).brightness == Brightness.dark ? t.onPr : Colors.white),
            ),
          ],
        ]),
      ),
    );
  }
}
