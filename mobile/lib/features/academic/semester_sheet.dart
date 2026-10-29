import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'reminders.dart';

class SemesterAction {
  const SemesterAction({this.semesterId, this.changed = false});

  final int? semesterId; // seçilen dönem (null: sunucu güncel dönemi seçsin)
  final bool changed; // dönem oluşturuldu/silindi/güncel yapıldı
}

/// Dönem seçimi: listele, seç, güncel yap, sil, yeni dönem ekle, resmi takvimden oluştur.
/// `BuSheet.show(scrollable: false, padding: EdgeInsets.zero)` içinde gösterilir (tutamacı BuSheet çizer).
class SemesterSheet extends StatefulWidget {
  const SemesterSheet({super.key, required this.api, this.activeId});

  final AcademicApi api;
  final int? activeId;

  @override
  State<SemesterSheet> createState() => _SemesterSheetState();
}

class _SemesterSheetState extends State<SemesterSheet> {
  List<Semester> _items = [];
  Map<String, dynamic>? _official;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.api.semesters();
      if (!mounted) return;
      setState(() {
        _items = r.items;
        _official = r.official;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) academicToast(context, errorText(e), kind: BuToastKind.error);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _create() async {
    final r = await BuDialog.show<({String name, DateTime start, DateTime end})>(context, builder: (_) => const _NewSemesterDialog());
    if (r == null) return;
    await _run(() => widget.api.createSemester(r.name, r.start, r.end));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 12, 8),
        child: Row(children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(l.akademik2SemesterTitle, style: tx.titleLarge!.copyWith(color: t.ink)),
            ),
          ),
          BuIconButton(
            icon: LucideIcons.x,
            tooltip: l.acadTimeClose,
            onTap: () => Navigator.pop(context, _changed ? const SemesterAction(changed: true) : null),
          ),
        ]),
      ),
      Flexible(child: _body()),
      if (!_loading && _error == null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BuButton(label: l.acadTimeAddSemester, icon: LucideIcons.plus, kind: BuButtonKind.soft, busy: _busy, onPressed: _create),
            if (_official != null) ...[
              const SizedBox(height: 8),
              BuButton(
                label: l.acadTimeOfficial('${_official!['name'] ?? l.acadTimeOfficialDefault}'),
                icon: LucideIcons.landmark,
                kind: BuButtonKind.outline,
                onPressed: _busy ? null : () => _run(widget.api.semesterFromOfficial),
              ),
            ],
          ]),
        ),
    ]);
  }

  Widget _body() {
    final t = context.bu;
    if (_loading) {
      return Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: const BuSkeletonScope(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
            child: Column(children: [
              BuSkeleton(height: 72, radius: 20),
              SizedBox(height: 8),
              BuSkeleton(height: 72, radius: 20),
              SizedBox(height: 8),
              BuSkeleton(height: 72, radius: 20),
            ]),
          ),
        ),
      );
    }
    if (_error != null) return BuErrorState(error: _error, onRetry: _load, compact: true);
    if (_items.isEmpty) {
      return BuEmptyState(
        illustration: BuIllustration.calendar,
        title: context.l10n.p17SemestersEmptyTitle,
        message: context.l10n.acadTimeNoSemester,
        compact: true,
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (c, i) => _row(t, _items[i]),
    );
  }

  Widget _row(BuTokens t, Semester s) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final active = s.id == widget.activeId;
    final range = s.startDate != null && s.endDate != null ? '${acadDate(context, s.startDate!)} - ${acadDate(context, s.endDate!)}' : null;
    final official = _official != null && '${_official!['name'] ?? ''}'.isNotEmpty && '${_official!['name']}' == s.name;
    void pick() => Navigator.pop(context, SemesterAction(semesterId: s.id, changed: _changed));
    return Semantics(
      container: true,
      selected: active,
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        decoration: BoxDecoration(
          color: active ? t.soft : t.sf,
          borderRadius: BuRadius.bLg,
          border: Border.all(color: active ? t.pr.withValues(alpha: .5) : t.bd, width: active ? 1.5 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BuRadius.bLg,
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  buHaptic(BuHaptic.selection);
                  pick();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 14, top: 10, bottom: 10, end: 4),
                    child: Row(children: [
                      AnimatedSwitcher(
                        duration: BuMotion.of(context, BuMotion.short),
                        child: active
                            ? Container(
                                key: const ValueKey('on'),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                                child: Icon(LucideIcons.check, size: 16, color: t.onPr),
                              )
                            : Container(
                                key: const ValueKey('off'),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.bd, width: 2)),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: active ? t.onSoft : t.ink)),
                          if (range != null) Text(range, style: tx.bodySmall!.copyWith(color: active ? t.onSoft : t.mut)),
                          if (s.current || official)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(spacing: 6, runSpacing: 4, children: [
                                if (s.current) AkadPill(l.acadTimeCurrent, bg: active ? t.sf : t.soft, fg: t.onSoft),
                                if (official) AkadPill(l.akademik2OfficialTag, bg: t.okSoft, fg: t.ok),
                              ]),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            if (!s.current)
              IconButton(
                tooltip: l.acadTimeMakeCurrent,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(LucideIcons.badgeCheck, size: 20, color: t.mut),
                onPressed: _busy ? null : () => _run(() => widget.api.makeCurrent(s.id)),
              ),
            IconButton(
              tooltip: l.acadTimeDeleteSemester,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(LucideIcons.trash2, size: 19, color: t.mut),
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await confirmDialog(context,
                          title: l.acadTimeDeleteSemester, text: l.acadTimeDeleteSemesterText(s.name), action: l.acadTimeDelete, danger: true);
                      if (ok) await _run(() => widget.api.deleteSemester(s.id));
                    },
            ),
            const SizedBox(width: 2),
          ]),
        ),
      ),
    );
  }
}

class _NewSemesterDialog extends StatefulWidget {
  const _NewSemesterDialog();

  @override
  State<_NewSemesterDialog> createState() => _NewSemesterDialogState();
}

class _NewSemesterDialogState extends State<_NewSemesterDialog> {
  final _name = TextEditingController();
  DateTime? _start, _end;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? initial, String help) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      helpText: help,
    );
  }

  void _submit() {
    final l = context.l10n;
    final n = _name.text.trim();
    if (n.isEmpty || _start == null || _end == null) {
      setState(() => _error = l.acadTimeSemesterNeedAll);
    } else if (!_end!.isAfter(_start!)) {
      setState(() => _error = l.acadTimeSemesterEndAfter);
    } else {
      Navigator.pop(context, (name: n, start: _start!, end: _end!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return BuDialog(
      title: l.acadTimeNewSemester,
      icon: LucideIcons.calendarPlus,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AkadTextField(label: l.p17SemesterName, controller: _name, maxLength: 60, hint: l.acadTimeSemesterHint, capitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          AkadPicker(
            icon: LucideIcons.calendar,
            label: l.acadTimeStartDate,
            hint: l.acadTimeStartDate,
            value: _start == null ? null : acadDate(context, _start!),
            onTap: () async {
              final d = await _pick(_start, l.acadTimeStartDate);
              if (d != null && mounted) setState(() => _start = DateTime.utc(d.year, d.month, d.day));
            },
          ),
          const SizedBox(height: 12),
          AkadPicker(
            icon: LucideIcons.calendar,
            label: l.acadTimeEndDate,
            hint: l.acadTimeEndDate,
            value: _end == null ? null : acadDate(context, _end!),
            onTap: () async {
              final d = await _pick(_end ?? _start, l.acadTimeEndDate);
              if (d != null && mounted) setState(() => _end = DateTime.utc(d.year, d.month, d.day));
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.circleAlert, size: 16, color: t.danger)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.danger))),
                ]),
              ),
            ),
        ]),
      ),
      actions: [
        BuDialogAction(label: l.acadTimeCancel, onPressed: () => Navigator.pop(context)),
        BuDialogAction(label: l.acadTimeAdd, kind: BuDialogActionKind.primary, onPressed: _submit),
      ],
    );
  }
}
