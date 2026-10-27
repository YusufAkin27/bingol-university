import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
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
    return AcademicScaffold(
      title: 'Sınavlar',
      actions: [if (_tab == 0) BuIconButton(icon: LucideIcons.plus, tooltip: 'Sınav ekle', filled: true, onTap: () => _openForm())],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: BuSegmented(items: const ['Sınavlarım', 'Resmi program'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        ),
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
    if (_mine.isEmpty) {
      return Column(children: [
        const Expanded(child: EmptyView(icon: LucideIcons.fileText, text: 'Kişisel sınav eklemedin.\nVize, final ya da quiz tarihlerini buradan takip et.')),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: BuButton(label: 'Sınav ekle', icon: LucideIcons.plus, onPressed: () => _openForm())),
      ]);
    }
    final t = context.bu;
    return RefreshIndicator(
      onRefresh: _loadMine,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
        children: [
          if (upcoming.isNotEmpty) ...[
            Text('Yaklaşan', style: BuType.heading.copyWith(color: t.ink)),
            const SizedBox(height: 8),
            for (final e in upcoming) Padding(padding: const EdgeInsets.only(bottom: 8), child: _examCard(t, e, now)),
          ] else
            const Padding(padding: EdgeInsets.only(bottom: 8), child: StaleBanner(text: 'Yaklaşan sınavın yok.', icon: LucideIcons.partyPopper)),
          if (past.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Geçmiş', style: BuType.heading.copyWith(color: t.mut)),
            const SizedBox(height: 8),
            for (final e in past) Padding(padding: const EdgeInsets.only(bottom: 8), child: Opacity(opacity: .6, child: _examCard(t, e, now))),
          ],
        ],
      ),
    );
  }

  Widget _examCard(BuTokens t, Exam e, DateTime now) {
    final cd = countdownText(e.startsAt, now);
    final color = e.courseId == null
        ? courseColor('gray')
        : courseColor(_courses.where((c) => c.id == e.courseId).map((c) => c.color).firstOrNull ?? 'blue');
    return ColorCard(
      color: color,
      onTap: () => _openForm(e),
      semanticLabel: '${examTypeLabel(e.type)}: ${e.title}. ${fmtInstant(e.startsAt)}${cd != null ? '. $cd' : ''}. Düzenlemek için dokun.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          BuBadge(examTypeLabel(e.type), soft: true),
          const Spacer(),
          if (cd != null) Text(cd, style: BuType.label.copyWith(color: t.pr)),
        ]),
        const SizedBox(height: 6),
        Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
        if (e.courseName != null) MetaLine(LucideIcons.bookOpen, e.courseName!),
        MetaLine(LucideIcons.calendarClock, fmtInstant(e.startsAt)),
        if (e.room != null) MetaLine(LucideIcons.mapPin, e.room!),
      ]),
    );
  }

  // ---- resmi
  Widget _officialView() {
    if (_loadingOfficial && _official.isEmpty) return const LoadingView();
    if (_errOfficial != null && _official.isEmpty) return AcademicErrorView(error: _errOfficial!, onRetry: _loadOfficial);
    final t = context.bu;
    final now = academicClock();
    return RefreshIndicator(
      onRefresh: _loadOfficial,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
        children: [
          if (!_profileComplete)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: StaleBanner(text: 'Profilinde bölüm bilgisi yok; yalnız herkese açık sınavlar gösteriliyor. Profili düzenleyerek bölümünü ekleyebilirsin.', icon: LucideIcons.info),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(spacing: 8, children: [
              BuChip(label: 'Bölümüm', selected: !_showAll, onTap: () => _toggleAll(false)),
              BuChip(label: 'Tümü', selected: _showAll, onTap: () => _toggleAll(true)),
            ]),
          ),
          const SizedBox(height: 12),
          if (_official.isEmpty)
            const EmptyView(icon: LucideIcons.fileText, text: 'Henüz yayınlanmış resmi sınav programı yok.')
          else
            for (final e in _official) Padding(padding: const EdgeInsets.only(bottom: 8), child: _officialCard(t, e, now)),
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
    final cd = countdownText(e.startsAt, now);
    final who = [if (e.department != null) e.department!, if (e.grade != null) '${e.grade}. sınıf'].join(' · ');
    return ColorCard(
      color: courseColor(switch (e.type) { 'FINAL' => 'red', 'BUT' => 'purple', 'VIZE' => 'orange', _ => 'teal' }),
      semanticLabel: '${examTypeLabel(e.type)}: ${e.title}. ${fmtInstant(e.startsAt)}${e.room != null ? ', ${e.room}' : ''}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          BuBadge(examTypeLabel(e.type), soft: true),
          if (e.courseCode != null) ...[const SizedBox(width: 6), Text(e.courseCode!, style: BuType.label.copyWith(color: t.mut))],
          const Spacer(),
          if (cd != null) Text(cd, style: BuType.label.copyWith(color: t.pr)),
        ]),
        const SizedBox(height: 6),
        Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink)),
        MetaLine(LucideIcons.calendarClock, fmtInstant(e.startsAt)),
        if (e.room != null) MetaLine(LucideIcons.mapPin, e.room!),
        if (who.isNotEmpty) MetaLine(LucideIcons.graduationCap, who),
        if (e.note != null) MetaLine(LucideIcons.info, e.note!),
      ]),
    );
  }
}
