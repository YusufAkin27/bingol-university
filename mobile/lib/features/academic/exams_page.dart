import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart' show AcademicLabels, gradeLabelL;
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'acad_ref_widgets.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'exam_form_page.dart';
import 'reminders.dart';

/// Sınavlar (Stitch v3 03): geri oku + 28 sp başlık + `pr` "+"; metin sekmeleri (Sınavlarım | Okul programı);
/// kartsız satırlar (ad, muted "tarih · saat · derslik", sağda kalan süre). Resmi program satırları aynı biçimde.
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
  bool _showAll = false; // resmi program kapsamı: false = Bölümüm, true = Tümü (GET /exams/official?scope=all)

  List<Exam> _mine = [];
  List<Course> _courses = [];
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

  void _toggleAll(bool all) {
    if (_showAll == all) return;
    setState(() {
      _showAll = all;
      _official = []; // eski kapsamın listesi yeni kapsam yüklenirken görünmesin
      _errOfficial = null;
    });
    _loadOfficial();
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
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final mine = _tab == 0;
    final canAdd = mine && (!_loadingMine || _mine.isNotEmpty);
    return AcademicScaffold(
      title: l.acadExamsTitle,
      showTitle: false,
      child: RefreshIndicator(
        onRefresh: mine ? _loadMine : _loadOfficial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(children: [
                  Expanded(
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Semantics(header: true, child: Text(l.acadExamsTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.headlineLarge!.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0, color: t.ink))),
                    ),
                  ),
                  if (canAdd)
                    Semantics(
                      button: true,
                      label: l.acadExamsAdd,
                      excludeSemantics: true,
                      onTap: () => _openForm(),
                      child: Tooltip(
                        message: l.acadExamsAdd,
                        excludeFromSemantics: true,
                        child: BuPressable(
                          onTap: () => _openForm(),
                          haptic: BuHaptic.selection,
                          scale: .94,
                          child: SizedBox(width: 48, height: 48, child: Center(child: Icon(LucideIcons.plus, size: 18, color: t.pr))),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            AcadTabs(labels: [l.acadExamsTabMine, l.p69SchoolSchedule], index: _tab, onChanged: (i) => setState(() => _tab = i)),
            if (!mine) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 0), child: _scopeChips()),
            // Sekme değişince içerik yatay kayarak yer değiştirir (Sınavlarım <- -> Okul programı).
            BuSharedAxis(
              reverse: mine,
              distance: 24,
              child: KeyedSubtree(
                key: ValueKey<int>(_tab),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: mine ? _mineBody() : _officialBody()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resmi program kapsamı (ürün kararı, referansta yok): küçük çip çifti, sekmelerin hemen altında.
  Widget _scopeChips() {
    final l = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(spacing: 8, children: [
        AkadChip(label: l.acadMyDept, selected: !_showAll, onTap: () => _toggleAll(false)),
        AkadChip(label: l.acadAll, selected: _showAll, onTap: () => _toggleAll(true)),
      ]),
    );
  }

  /// "18 Kasım · 10:30 · B-204" (İstanbul duvar saati; bugünse "Bugün · 10:30").
  String _when(AppLocalizations l, DateTime startsAt, DateTime now, String? room) {
    final w = istanbulWall(startsAt);
    final n = istanbulWall(now);
    final today = w.year == n.year && w.month == n.month && w.day == n.day;
    return [
      today ? l.acadTimeToday : '${w.day} ${monthNameL(l, w.month)}',
      hhmm(w.hour * 60 + w.minute),
      if (room != null && room.isNotEmpty) room,
    ].join(' · ');
  }

  // ---- kişisel
  List<Widget> _mineBody() {
    final l = context.l10n;
    final err = _mine.isEmpty ? _errMine : null;
    if (_loadingMine && _mine.isEmpty && err == null) return const [AcadRowsSkeleton(count: 3)];
    if (err != null) return _errorBlock(err, _loadMine);
    final now = academicClock();
    final all = _mine;
    final shown = _filter == null ? all : all.where((e) => e.type == _filter).toList();
    final upcoming = shown.where((e) => (e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = shown.where((e) => !(e.endsAt ?? e.startsAt).isAfter(now)).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final stale = _errMine != null ? [Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: AcadAmberNote(text: l.acadTimeStale))] : const <Widget>[];
    if (all.isEmpty) {
      return [
        ...stale,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
          child: Row(children: [
            Expanded(child: Text(l.p69NoExams, style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 13, color: context.bu.mut))),
            AcadTextAction(l.acadExamsAdd, onTap: () => _openForm(), size: 15, weight: FontWeight.w700),
          ]),
        ),
      ];
    }
    final types = {for (final e in all) e.type};
    return [
      ...stale,
      if (types.length > 1) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 0, 0), child: _filters(all, types)),
      if (upcoming.isNotEmpty)
        BuStaggerScope(
          child: Column(children: [
            for (var i = 0; i < upcoming.length; i++) BuStaggerItem(index: i, child: _examRow(upcoming[i], now, first: i == 0)),
          ]),
        )
      else
        AcadStateText(text: l.acadExamsNoUpcoming, top: 24),
      if (past.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 0),
          child: Semantics(header: true, child: Text(l.acadExamsPast, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, color: context.bu.mut))),
        ),
        for (final e in past) _examRow(e, now),
      ],
    ];
  }

  List<Widget> _errorBlock(Object err, Future<void> Function() retry) {
    final l = context.l10n;
    if (err is ApiError && err.status == 503) {
      return [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: AcadAmberNote(text: err.message.isNotEmpty ? err.message : l.acadMaintenance)),
        AcadStateText(text: '', actionLabel: l.acadRetry, onAction: retry, top: 0),
      ];
    }
    return [AcadStateText(text: '${l.sistemuiErrorTitle}\n${errorText(err)}', actionLabel: l.acadRetry, onAction: retry)];
  }

  Widget _filters(List<Exam> all, Set<String> types) {
    final l = context.l10n;
    final chips = <(String?, String)>[
      (null, '${l.acadAll} (${all.length})'),
      for (final k in examTypes)
        if (types.contains(k)) (k, examTypeLabelL(l, k)),
    ];
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

  Widget _examRow(Exam e, DateTime now, {bool first = false}) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cd = countdownTextL(l, e.startsAt, now);
    final past = cd == null;
    final typeText = examTypeLabelL(l, e.type);
    final semantic = cd != null
        ? l.acadExamsSemanticCd(typeText, e.title, fmtInstantL(l, e.startsAt), cd)
        : l.acadExamsSemantic(typeText, e.title, fmtInstantL(l, e.startsAt));
    final right = past ? l.akademik2Passed : cd;
    return AcadRow(
      onTap: () => _openForm(e),
      semanticLabel: semantic,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: past ? t.mut : t.ink)),
            const SizedBox(height: 4),
            Text(_when(l, e.startsAt, now, e.room), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
          ]),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 0,
          child: Text(right, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: first && !past ? t.pr : t.mut)),
        ),
      ]),
    );
  }

  // ---- resmi
  List<Widget> _officialBody() {
    final l = context.l10n;
    final t = context.bu;
    final now = academicClock();
    if (_loadingOfficial && _official.isEmpty && _errOfficial == null) return const [AcadRowsSkeleton(count: 3)];
    if (_official.isEmpty && _errOfficial != null) return _errorBlock(_errOfficial!, _loadOfficial);
    return [
      if (!_profileComplete)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: AcadAmberNote(text: l.acadExamsProfileIncomplete, actionLabel: l.p20EditProfile, onAction: () => openEditProfile(context, widget.session)),
        ),
      if (_official.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(children: [
            Semantics(header: true, child: Text(l.acadExamsEmptyOfficial, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink))),
            const SizedBox(height: 6),
            Text(l.p17OfficialEmptyBody, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
          ]),
        )
      else
        BuStaggerScope(
          child: Column(children: [
            for (var i = 0; i < _official.length; i++) BuStaggerItem(index: i, child: _officialRow(_official[i], now)),
          ]),
        ),
    ];
  }

  Widget _officialRow(OfficialExam e, DateTime now) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final who = [if (e.department != null) context.departmentName(e.department), if (e.grade != null) gradeLabelL(l, e.grade)].join(' · ');
    final sub = [if (e.courseCode != null) e.courseCode!, if (who.isNotEmpty) who].join(' · ');
    final typeText = examTypeLabelL(l, e.type);
    final semantic = e.room != null
        ? l.acadOfficialSemanticRoom(typeText, e.title, fmtInstantL(l, e.startsAt), e.room!)
        : l.acadOfficialSemantic(typeText, e.title, fmtInstantL(l, e.startsAt));
    return AcadRow(
      semanticLabel: semantic,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
            const SizedBox(height: 4),
            Text(_when(l, e.startsAt, now, e.room), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
            if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
            if (e.note != null) Text(e.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
          ]),
        ),
        const SizedBox(width: 12),
        Flexible(flex: 0, child: Text(typeText, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w500, color: t.mut))),
      ]),
    );
  }
}
