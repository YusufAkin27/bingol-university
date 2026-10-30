import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/academic_catalog.dart' show gradeLabelL;
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'exam_form_page.dart';
import 'reminders.dart';

/// Sınavlar (Stitch 44): kişisel sınavlar (geri sayım, tür süzgeci) ve resmi sınav programı (bölüme göre).
/// Üstte dönem + "Sınav ekle", koyu seçili segment (Sınavlarım / Resmi program).
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
  String? _filter; // tür süzgeci (null = tümü)

  List<Exam> _mine = [];
  List<Course> _courses = [];
  String? _semesterName;
  List<OfficialExam> _official = [];
  bool _profileComplete = true;
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
        final tt = r[1] as TimetableData;
        _courses = tt.courses;
        _semesterName = tt.semester?.name;
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
      final r = await _api.officialExams();
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
    final mine = _tab == 0;
    return AcademicScaffold(
      title: l.acadExamsTitle,
      child: RefreshIndicator(
        onRefresh: mine ? _loadMine : _loadOfficial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            if (mine && _mine.isNotEmpty) ...[_topRow(), const SizedBox(height: 14)],
            _segment(),
            const SizedBox(height: 14),
            ...(mine ? _mineBody() : _officialBody()),
          ],
        ),
      ),
    );
  }

  Widget _topRow() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final canAdd = !_loadingMine || _mine.isNotEmpty;
    return Row(children: [
      AkadIconTile(icon: LucideIcons.calendarCheck, bg: t.soft, fg: t.onSoft, size: 36, radius: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(_semesterName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
      ),
      const SizedBox(width: 8),
      if (canAdd) BuButton(label: l.acadExamsAdd, icon: LucideIcons.plus, compact: true, onPressed: () => _openForm()),
    ]);
  }

  /// Koyu seçili iki parçalı segment.
  Widget _segment() {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    Widget part(int i, String label) {
      final sel = _tab == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: sel,
          label: label,
          excludeSemantics: true,
          onTap: () => setState(() => _tab = i),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              buHaptic(BuHaptic.selection);
              setState(() => _tab = i);
            },
            child: AnimatedContainer(
              duration: BuMotion.of(context, BuMotion.short),
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: sel ? t.ink : Colors.transparent, borderRadius: BuRadius.bPill),
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: sel ? t.bg : t.mut)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
      child: Row(children: [part(0, l.acadExamsTabMine), part(1, l.acadExamsTabOfficial)]),
    );
  }

  String _longDate(DateTime wall) => DateFormat('d MMMM EEEE', Localizations.localeOf(context).toString()).format(wall);

  // ---- kişisel
  List<Widget> _mineBody() {
    final l = context.l10n;
    final t = context.bu;
    final err = _mine.isEmpty ? _errMine : null;
    if (_loadingMine && _mine.isEmpty && err == null) return const [_ExamsSkeleton()];
    if (err != null) {
      final maintenance = err is ApiError && err.status == 503;
      return [
        if (maintenance)
          AkadNoticeCard(text: (err).message.isNotEmpty ? err.message : l.acadMaintenance)
        else
          AkadErrorCard(title: l.sistemuiErrorTitle, message: errorText(err), onRetry: _loadMine, retryLabel: l.acadRetry),
      ];
    }
    final now = academicClock();
    final all = _mine;
    final shown = _filter == null ? all : all.where((e) => e.type == _filter).toList();
    final upcoming = shown.where((e) => (e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = shown.where((e) => !(e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    if (all.isEmpty) {
      return [
        if (_errMine != null) AkadStaleStrip(text: l.acadTimeStale),
        _InfoCard(
          icon: LucideIcons.clipboardList,
          tileBg: t.soft,
          tileFg: t.onSoft,
          title: l.p17ExamsEmptyMineTitle,
          body: l.p17ExamsEmptyMineBody,
          action: BuButton(label: l.acadExamsAdd, icon: LucideIcons.plus, onPressed: () => _openForm()),
        ),
      ];
    }
    return [
      if (_errMine != null) ...[AkadStaleStrip(text: l.acadTimeStale), const SizedBox(height: 12)],
      _filters(all),
      const SizedBox(height: 16),
      if (upcoming.isNotEmpty) ...[
        AkadTitle(l.acadExamsUpcoming, count: upcoming.length),
        const SizedBox(height: 12),
        for (final e in upcoming) Padding(padding: const EdgeInsets.only(bottom: 14), child: _examCard(e, now)),
      ] else
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _InfoCard(icon: LucideIcons.calendarCheck, tileBg: t.tint(1).bg, tileFg: t.tint(1).fg, title: l.acadExamsNoUpcoming, body: l.p17ExamsNoUpcomingBody),
        ),
      if (past.isNotEmpty) ...[
        const SizedBox(height: 6),
        AkadTitle(l.acadExamsPast, count: past.length, muted: true),
        const SizedBox(height: 12),
        for (final e in past) Padding(padding: const EdgeInsets.only(bottom: 14), child: _examCard(e, now)),
      ],
    ];
  }

  Widget _filters(List<Exam> all) {
    final l = context.l10n;
    final chips = <(String?, String)>[(null, '${l.acadAll} (${all.length})'), for (final k in examTypes) (k, examTypeLabelL(l, k))];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(
          child: AkadChip(label: chips[i].$2, selected: _filter == chips[i].$1, onTap: () => setState(() => _filter = chips[i].$1)),
        ),
      ),
    );
  }

  (Color, Color) _typeColors(String type) {
    final t = context.bu;
    return switch (type) {
      'VIZE' => (t.soft, t.onSoft),
      'FINAL' => (t.tint(4).bg, t.tint(4).fg),
      'BUT' => (t.tint(3).bg, t.tint(3).fg),
      'QUIZ' => (t.tint(1).bg, t.tint(1).fg),
      _ => (t.sf2, t.mut),
    };
  }

  Widget _examCard(Exam e, DateTime now) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cd = countdownTextL(l, e.startsAt, now);
    final past = cd == null;
    final w = istanbulWall(e.startsAt);
    final nowWall = istanbulWall(now);
    final today = w.year == nowWall.year && w.month == nowWall.month && w.day == nowWall.day;
    final time = hhmm(w.hour * 60 + w.minute);
    final dateText = today ? '${l.acadTimeToday} · $time' : '${_longDate(w)} · $time';
    final typeText = examTypeLabelL(l, e.type);
    final (tBg, tFg) = past ? (t.sf2, t.mut) : _typeColors(e.type);
    final diff = e.startsAt.difference(now);
    final soon = !past && diff.inHours < 24;
    final foot = e.note ?? e.courseName;
    final semantic = cd != null
        ? l.acadExamsSemanticCd(typeText, e.title, fmtInstantL(l, e.startsAt), cd)
        : l.acadExamsSemantic(typeText, e.title, fmtInstantL(l, e.startsAt));
    Widget line(IconData icon, String text, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(icon, size: 18, color: color ?? t.mut),
            const SizedBox(width: 8),
            Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: color ?? t.mut, fontWeight: bold ? FontWeight.w700 : null))),
          ]),
        );
    final ink = past ? t.mut : t.ink;
    return Semantics(
      container: true,
      button: true,
      label: semantic,
      excludeSemantics: true,
      onTap: () => _openForm(e),
      child: Opacity(
        opacity: past ? .8 : 1,
        child: AkadCard(
          onTap: () => _openForm(e),
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Flexible(child: AkadPill(typeText, bg: tBg, fg: tFg, dot: !past)),
                  const SizedBox(width: 8),
                  const Spacer(),
                  if (past)
                    AkadPill(l.akademik2Passed, bg: t.sf2, fg: t.mut, icon: LucideIcons.circleCheck)
                  else
                    AkadPill(cd, bg: soon ? t.pr : t.soft, fg: soon ? t.onPr : t.onSoft, icon: soon ? LucideIcons.zap : LucideIcons.hourglass),
                ]),
                const SizedBox(height: 10),
                Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, fontSize: 20, color: ink)),
                const SizedBox(height: 4),
                line(past ? LucideIcons.circleCheck : (today ? LucideIcons.clock : LucideIcons.calendar), dateText,
                    color: past ? t.mut : (today ? t.pr : t.ink), bold: today && !past),
                if (e.room != null) line(LucideIcons.doorOpen, e.room!, color: past ? t.mut : t.mut),
              ]),
            ),
            if (!past)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: t.sf2.withValues(alpha: .6)),
                child: Row(children: [
                  if (foot != null) ...[
                    Icon(LucideIcons.bookOpen, size: 14, color: t.mut),
                    const SizedBox(width: 6),
                    Expanded(child: Text(foot, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut))),
                  ] else
                    const Spacer(),
                  const SizedBox(width: 8),
                  Text(l.p17ExamDetail, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w800, color: t.pr)),
                  Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: t.pr),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  // ---- resmi
  List<Widget> _officialBody() {
    final l = context.l10n;
    final t = context.bu;
    final now = academicClock();
    if (_loadingOfficial && _official.isEmpty && _errOfficial == null) return const [_ExamsSkeleton(count: 3)];
    if (_official.isEmpty && _errOfficial != null) {
      final err = _errOfficial!;
      final maintenance = err is ApiError && err.status == 503;
      return [
        if (maintenance)
          AkadNoticeCard(text: err.message.isNotEmpty ? err.message : l.acadMaintenance)
        else
          AkadErrorCard(title: l.sistemuiErrorTitle, message: errorText(err), onRetry: _loadOfficial, retryLabel: l.acadRetry),
      ];
    }
    return [
      if (!_profileComplete) ...[_noDeptCard(), const SizedBox(height: 14)],
      if (_official.isEmpty)
        _InfoCard(
          icon: LucideIcons.clipboardList,
          tileBg: t.sf2,
          tileFg: t.mut,
          title: l.acadExamsEmptyOfficial,
          body: l.p17OfficialEmptyBody,
          badge: l.acadExamsTabOfficial,
        )
      else
        for (final e in _official) Padding(padding: const EdgeInsets.only(bottom: 14), child: _officialCard(e, now)),
    ];
  }

  Widget _noDeptCard() {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bLg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.sf.withValues(alpha: .7), shape: BoxShape.circle),
              child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 18, color: t.onSoft)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l.acadExamsProfileIncomplete, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.onSoft))),
          ]),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: t.onSoft, minimumSize: const Size(48, 48)),
              onPressed: () => openEditProfile(context, widget.session),
              icon: const SizedBox.shrink(),
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(l.p20EditProfile, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: t.onSoft)),
                const SizedBox(width: 4),
                Icon(buDirIcon(context, LucideIcons.arrowRight), size: 16, color: t.onSoft),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _officialCard(OfficialExam e, DateTime now) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final w = istanbulWall(e.startsAt);
    final who = [if (e.department != null) e.department!, if (e.grade != null) gradeLabelL(l, e.grade)].join(' · ');
    final sub = [if (e.courseCode != null) e.courseCode!, if (who.isNotEmpty) who].join(' · ');
    final typeText = examTypeLabelL(l, e.type);
    final dateText = '${_longDate(w)} · ${hhmm(w.hour * 60 + w.minute)}';
    final (tBg, tFg) = _typeColors(e.type);
    final semantic = e.room != null
        ? l.acadOfficialSemanticRoom(typeText, e.title, fmtInstantL(l, e.startsAt), e.room!)
        : l.acadOfficialSemantic(typeText, e.title, fmtInstantL(l, e.startsAt));
    Widget row(IconData icon, String text, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(icon, size: 18, color: color ?? t.mut),
            const SizedBox(width: 10),
            Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: t.ink))),
          ]),
        );
    return Semantics(
      container: true,
      label: semantic,
      excludeSemantics: true,
      child: AkadCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 190), child: AkadPill(l.acadExamsTabOfficial, bg: t.ink, fg: t.bg, dot: true)),
            const SizedBox(width: 8),
            Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: AkadPill(typeText, bg: tBg, fg: tFg))),
          ]),
          const SizedBox(height: 12),
          Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
          if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              row(LucideIcons.calendar, dateText, color: t.pr),
              if (e.room != null) row(LucideIcons.mapPin, e.room!),
              if (e.note != null) row(LucideIcons.info, e.note!),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Başlık + açıklama + (isteğe bağlı) eylem içeren bilgi/boş durum kartı.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.tileBg, required this.tileFg, required this.title, required this.body, this.action, this.badge});

  final IconData icon;
  final Color tileBg, tileFg;
  final String title, body;
  final Widget? action;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: AkadCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (badge != null) ...[Align(alignment: AlignmentDirectional.centerStart, child: AkadPill(badge!, bg: t.sf2, fg: t.mut, icon: LucideIcons.graduationCap)), const SizedBox(height: 12)],
          Align(alignment: AlignmentDirectional.centerStart, child: AkadIconTile(icon: icon, bg: tileBg, fg: tileFg, size: 48, radius: 16)),
          const SizedBox(height: 14),
          Semantics(header: true, child: Text(title, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
          const SizedBox(height: 4),
          Text(body, style: tx.bodyMedium!.copyWith(color: t.mut)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

/// Sınav listesi iskeleti.
class _ExamsSkeleton extends StatelessWidget {
  const _ExamsSkeleton({this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: BuSkeletonScope(
          child: Column(children: [
            for (var i = 0; i < count; i++) const Padding(padding: EdgeInsets.only(bottom: 14), child: BuSkeleton(height: 150, radius: 20)),
          ]),
        ),
      );
}
