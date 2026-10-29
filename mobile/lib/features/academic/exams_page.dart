import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show gradeLabelL;
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'exam_form_page.dart';
import 'reminders.dart';

/// Sınavlar: kişisel sınavlar (geri sayım) ve resmi sınav programı (bölüme göre).
/// Büyük başlık + sabit segment (Sınavlarım / Resmi program); kişisel sekmede "Sınav ekle" yüzen düğmesi.
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

  void _toggleAll(bool all) {
    if (_showAll == all) return;
    setState(() => _showAll = all);
    _loadOfficial();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mine = _tab == 0;
    final Object? err = mine ? (_mine.isEmpty ? _errMine : null) : (_official.isEmpty ? _errOfficial : null);
    final maintenance = err is ApiError && err.status == 503;
    final BuViewState state;
    if (mine && _loadingMine && _mine.isEmpty && err == null) {
      state = BuViewState.loading;
    } else if (err != null) {
      state = maintenance ? BuViewState.empty : BuViewState.error;
    } else if (mine && _mine.isEmpty) {
      state = BuViewState.empty;
    } else {
      state = BuViewState.ready;
    }
    return BuPageScaffold(
      title: l.acadExamsTitle,
      state: state,
      loading: const _ExamsSkeleton(),
      error: err,
      onRetry: mine ? _loadMine : _loadOfficial,
      empty: err != null
          ? AcademicErrorView(error: err, onRetry: mine ? _loadMine : _loadOfficial)
          : BuEmptyState(illustration: BuIllustration.document, title: l.p17ExamsEmptyTitle, message: l.acadExamsEmptyMine),
      onRefresh: mine ? _loadMine : _loadOfficial,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
          child: BuSegmented(items: [l.acadExamsTabMine, l.acadExamsTabOfficial], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        ),
      ),
      floatingActionButton: mine && !_loadingMine && state != BuViewState.error && !maintenance
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _openForm(),
              icon: const Icon(LucideIcons.plus),
              label: Text(l.acadExamsAdd),
            )
          : null,
      bottomInset: mine ? 104 : 32,
      slivers: mine ? _mineSlivers() : _officialSlivers(),
    );
  }

  // ---- kişisel
  List<Widget> _mineSlivers() {
    final now = academicClock();
    final upcoming = _mine.where((e) => (e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = _mine.where((e) => !(e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final l = context.l10n;
    final items = <Widget>[
      if (_errMine != null)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: BuOfflineBanner(message: l.acadTimeStale, showCachedHint: false, margin: EdgeInsets.zero)),
      if (upcoming.isNotEmpty) ...[
        AkadSection(l.acadExamsUpcoming),
        for (final e in upcoming) Padding(padding: const EdgeInsets.only(bottom: 12), child: _examCard(e, now)),
      ] else
        Padding(padding: const EdgeInsets.only(bottom: 12), child: StaleBanner(text: l.acadExamsNoUpcoming, icon: LucideIcons.partyPopper)),
      if (past.isNotEmpty) ...[
        AkadSection(l.acadExamsPast, padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8, top: 12)),
        for (final e in past) Padding(padding: const EdgeInsets.only(bottom: 12), child: _examCard(e, now)),
      ],
    ];
    return [_list(items)];
  }

  Widget _list(List<Widget> items) => SliverPadding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
        sliver: SliverList.builder(itemCount: items.length, itemBuilder: (c, i) => BuStaggerItem(index: i, child: items[i])),
      );

  Widget _examCard(Exam e, DateTime now) {
    final l = context.l10n;
    final cd = countdownTextL(l, e.startsAt, now);
    final color = e.courseId == null ? courseColor('gray') : courseColor(_courses.where((c) => c.id == e.courseId).map((c) => c.color).firstOrNull ?? 'blue');
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
  List<Widget> _officialSlivers() {
    final l = context.l10n;
    final now = academicClock();
    final loadingList = _loadingOfficial && _official.isEmpty;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
          ]),
        ),
      ),
      if (loadingList)
        const SliverToBoxAdapter(child: _ExamsSkeleton(count: 3))
      else if (_official.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BuEmptyState(illustration: BuIllustration.calendar, title: l.p17OfficialEmptyTitle, message: l.acadExamsEmptyOfficial, compact: true),
          ),
        )
      else
        _list([for (final e in _official) Padding(padding: const EdgeInsets.only(bottom: 12), child: _officialCard(e, now))]),
    ];
  }

  Widget _officialCard(OfficialExam e, DateTime now) {
    final l = context.l10n;
    final cd = countdownTextL(l, e.startsAt, now);
    final who = [if (e.department != null) e.department!, if (e.grade != null) gradeLabelL(l, e.grade)].join(' · ');
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

/// Sınav kartı: ay/gün pulu + başlık + tür hapı ve saat + yer/bölüm satırları + sağda geri sayım hapı.
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
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final w = istanbulWall(start);
    final time =
        end == null ? hhmm(w.hour * 60 + w.minute) : '${hhmm(w.hour * 60 + w.minute)} – ${hhmm(istanbulWall(end!).hour * 60 + istanbulWall(end!).minute)}';
    final tileBg = past ? t.sf2 : akadTint(context, color);
    final tileFg = past ? t.mut : akadOnTint(context, color);
    Widget sub(String s, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(children: [
            if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 14, color: t.mut)), const SizedBox(width: 6)],
            Expanded(child: Text(s, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
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
        shadow: false,
        color: past ? t.sf2 : t.sf,
        borderColor: past ? t.sf2 : t.bd,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AkadDateTile(month: monthNameL(l, w.month), day: w.day, bg: tileBg, fg: tileFg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (pill != null)
                  past
                      ? AkadPill(pill!, bg: t.sf, fg: t.mut)
                      : AkadPill(pill!,
                          bg: Color.alphaBlend(color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .3 : .18), t.sf),
                          fg: t.ink,
                          icon: LucideIcons.timer),
                AkadPill(typeText, bg: past ? t.sf : tileBg, fg: past ? t.mut : akadOnTint(context, color)),
              ]),
              const SizedBox(height: 6),
              Text(title,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: past ? t.mut : t.ink)),
              if (course != null) sub(course!, icon: LucideIcons.bookOpen),
              sub('${code == null ? '' : '$code · '}$time', icon: LucideIcons.clock),
              if (room != null) sub(room!, icon: LucideIcons.mapPin),
              if (who != null) sub(who!, icon: LucideIcons.graduationCap),
              if (note != null) sub(note!, icon: LucideIcons.info),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Sınav listesi iskeleti: tarih karosu + iki satır.
class _ExamsSkeleton extends StatelessWidget {
  const _ExamsSkeleton({this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: BuSkeletonScope(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(children: [
              for (var i = 0; i < count; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: BuSkeleton(height: 96, radius: 20),
                ),
            ]),
          ),
        ),
      );
}
