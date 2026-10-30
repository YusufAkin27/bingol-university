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
        padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 20, 12),
        child: Row(children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(l.akademik2SemesterTitle, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
            ),
          ),
          if (!_loading && _error == null && _items.isNotEmpty) AkadPill(l.p17SemesterCount(_items.length.toString()), bg: t.sf2, fg: t.mut),
        ]),
      ),
      Flexible(child: _body()),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_loading && _error == null) BuButton(label: l.acadTimeAddSemester, icon: LucideIcons.circlePlus, busy: _busy, onPressed: _create),
          const SizedBox(height: 4),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(context, _changed ? const SemesterAction(changed: true) : null),
              child: Text(l.acadTimeClose, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
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
            padding: EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: Column(children: [
              BuSkeleton(height: 96, radius: 20),
              SizedBox(height: 12),
              BuSkeleton(height: 96, radius: 20),
              SizedBox(height: 12),
              BuSkeleton(height: 96, radius: 20),
            ]),
          ),
        ),
      );
    }
    if (_error != null) return BuErrorState(error: _error, onRetry: _load, compact: true);
    final officialName = '${_official?['name'] ?? ''}';
    final showOfficial = _official != null && !_items.any((s) => s.name == officialName);
    if (_items.isEmpty && !showOfficial) {
      return BuEmptyState(
        illustration: BuIllustration.calendar,
        title: context.l10n.p17SemestersEmptyTitle,
        message: context.l10n.acadTimeNoSemester,
        compact: true,
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
      children: [
        for (final s in _items) ...[_row(t, s), const SizedBox(height: 12)],
        if (showOfficial) _officialRow(t),
      ],
    );
  }

  Widget _radio(BuTokens t, bool on) => AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? t.pr : t.mut, width: 2)),
        child: on ? Container(width: 12, height: 12, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)) : null,
      );

  Widget _action(BuTokens t, {required IconData icon, required String label, required VoidCallback? onTap, bool danger = false}) {
    final color = danger ? t.danger : t.ink;
    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: color,
        textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _row(BuTokens t, Semester s) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final active = s.id == widget.activeId;
    final range = s.startDate != null && s.endDate != null ? '${acadDate(context, s.startDate!)} - ${acadDate(context, s.endDate!)}' : null;
    void pick() {
      buHaptic(BuHaptic.selection);
      Navigator.pop(context, SemesterAction(semesterId: s.id, changed: _changed));
    }

    return Semantics(
      container: true,
      selected: active,
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        decoration: BoxDecoration(
          color: active ? t.sf2 : t.sf,
          borderRadius: BuRadius.bLg,
          border: Border.all(color: active ? t.bd : t.bd.withValues(alpha: .6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            borderRadius: BuRadius.bLg,
            onTap: pick,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 6),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: active ? t.pr : t.sf2, shape: BoxShape.circle),
                  child: Icon(active ? LucideIcons.check : LucideIcons.history, size: 16, color: active ? t.onPr : t.mut),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(s.name, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                      if (s.current) AkadPill(l.acadTimeCurrent, bg: t.tint(1).bg, fg: t.tint(1).fg, dot: true),
                    ]),
                    if (range != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(range, style: tx.bodySmall!.copyWith(color: t.mut))),
                  ]),
                ),
                const SizedBox(width: 8),
                _radio(t, active),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 4),
            child: Row(children: [
              if (!s.current)
                Flexible(
                    child: _action(t,
                        icon: LucideIcons.star, label: l.acadTimeMakeCurrent, onTap: _busy ? null : () => _run(() => widget.api.makeCurrent(s.id)))),
              const Spacer(),
              Flexible(
                child: _action(t, icon: LucideIcons.trash2, label: l.acadTimeDeleteSemester, danger: true, onTap: _busy
                    ? null
                    : () async {
                        final ok = await confirmDialog(context,
                            title: l.acadTimeDeleteSemester, text: l.acadTimeDeleteSemesterText(s.name), action: l.acadTimeDelete, danger: true);
                        if (ok) await _run(() => widget.api.deleteSemester(s.id));
                      }),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  /// Akademik takvimin resmi dönemi: "Güncel dönem yap" ile dönem olarak eklenir.
  Widget _officialRow(BuTokens t) {
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final name = '${_official!['name'] ?? l.acadTimeOfficialDefault}';
    return Container(
      decoration: BoxDecoration(color: t.soft.withValues(alpha: .55), borderRadius: BuRadius.bLg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 6),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Icon(LucideIcons.graduationCap, size: 16, color: t.onSoft),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l.acadTimeOfficial(name), style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
            const SizedBox(width: 8),
            _radio(t, false),
          ]),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _action(t, icon: LucideIcons.arrowLeftRight, label: l.acadTimeMakeCurrent, onTap: _busy ? null : () => _run(widget.api.semesterFromOfficial)),
          ),
        ),
      ]),
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
            hint: l.acadSelect,
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
            hint: l.acadSelect,
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
