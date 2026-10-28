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
import 'reminders.dart';

class SemesterAction {
  const SemesterAction({this.semesterId, this.changed = false});

  final int? semesterId; // seçilen dönem (null: sunucu güncel dönemi seçsin)
  final bool changed; // dönem oluşturuldu/silindi/güncel yapıldı
}

/// Dönem seçimi: listele, seç, güncel yap, sil, yeni dönem ekle, resmi takvimden oluştur.
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
      if (mounted) academicToast(context, errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _create() async {
    final r = await showDialog<({String name, DateTime start, DateTime end})>(context: context, builder: (_) => const _NewSemesterDialog());
    if (r == null) return;
    await _run(() => widget.api.createSemester(r.name, r.start, r.end));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .86),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFD9CFC8), borderRadius: BorderRadius.circular(3))),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.akademik2SemesterTitle, style: BuType.title.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: t.ink)),
                ),
              ),
              BuIconButton(
                icon: LucideIcons.x,
                tooltip: l.acadTimeClose,
                onTap: () => Navigator.pop(context, _changed ? const SemesterAction(changed: true) : null),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(32), child: LoadingView())
                : _error != null
                    ? Padding(padding: const EdgeInsets.all(8), child: ErrorView(error: _error!, onRetry: _load))
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                        children: [
                          if (_items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(l.acadTimeNoSemester, textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
                            )
                          else
                            AkadCard(
                              padding: EdgeInsets.zero,
                              child: Column(children: [
                                for (var i = 0; i < _items.length; i++) ...[
                                  if (i > 0) const AkadDivider(),
                                  _row(t, _items[i]),
                                ],
                              ]),
                            ),
                          const SizedBox(height: 14),
                          AkadButton(
                            label: l.acadTimeAddSemester,
                            icon: LucideIcons.plus,
                            outlined: true,
                            accentOutline: true,
                            busy: _busy,
                            onPressed: _create,
                          ),
                          if (_official != null) ...[
                            const SizedBox(height: 10),
                            AkadButton(
                              label: l.acadTimeOfficial('${_official!['name'] ?? l.acadTimeOfficialDefault}'),
                              icon: LucideIcons.landmark,
                              outlined: true,
                              onPressed: _busy ? null : () => _run(widget.api.semesterFromOfficial),
                            ),
                          ],
                        ],
                      ),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _row(BuTokens t, Semester s) {
    final l = context.l10n;
    final active = s.id == widget.activeId;
    final range = s.startDate != null && s.endDate != null ? '${acadDate(context, s.startDate!)} - ${acadDate(context, s.endDate!)}' : null;
    final official = _official != null && '${_official!['name'] ?? ''}'.isNotEmpty && '${_official!['name']}' == s.name;
    void pick() => Navigator.pop(context, SemesterAction(semesterId: s.id, changed: _changed));
    return Container(
      color: active ? t.soft : null,
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            selected: active,
            child: InkWell(
              onTap: pick,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, top: 8, bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)),
                        if (range != null) Text(range, style: BuType.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.mut)),
                        if (s.current) Padding(padding: const EdgeInsets.only(top: 4), child: BuBadge(l.acadTimeCurrent, soft: true)),
                      ]),
                    ),
                    if (official) ...[
                      const SizedBox(width: 6),
                      AkadPill(l.akademik2OfficialTag, bg: akadTint(context, const Color(0xFF14633A)), fg: akadOnTint(context, const Color(0xFF14633A))),
                    ],
                    const SizedBox(width: 8),
                    active
                        ? Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                            child: Icon(LucideIcons.check, size: 16, color: t.onPr),
                          )
                        : Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFD9CFC8), width: 2))),
                  ]),
                ),
              ),
            ),
          ),
        ),
        if (!s.current)
          IconButton(
            tooltip: l.acadTimeMakeCurrent,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(LucideIcons.badgeCheck, size: 19, color: t.mut),
            onPressed: _busy ? null : () => _run(() => widget.api.makeCurrent(s.id)),
          ),
        IconButton(
          tooltip: l.acadTimeDeleteSemester,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Icon(LucideIcons.trash2, size: 18, color: t.mut),
          onPressed: _busy
              ? null
              : () async {
                  final ok = await confirmDialog(context,
                      title: l.acadTimeDeleteSemester, text: l.acadTimeDeleteSemesterText(s.name), action: l.acadTimeDelete, danger: true);
                  if (ok) await _run(() => widget.api.deleteSemester(s.id));
                },
        ),
        const SizedBox(width: 4),
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

  Future<DateTime?> _pick(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AlertDialog(
      backgroundColor: t.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(context.l10n.acadTimeNewSemester, style: BuType.title.copyWith(fontSize: 20, fontWeight: FontWeight.w800, color: t.ink)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _name,
            maxLength: 60,
            style: BuType.body.copyWith(fontSize: 16, color: t.ink),
            decoration: akadInput(context, hint: context.l10n.acadTimeSemesterHint),
          ),
          const SizedBox(height: 10),
          AkadPicker(
            icon: LucideIcons.calendar,
            label: context.l10n.acadTimeStartDate,
            hint: context.l10n.acadTimeStartDate,
            value: _start == null ? null : acadDate(context, _start!),
            onTap: () async {
              final d = await _pick(_start);
              if (d != null && mounted) setState(() => _start = DateTime.utc(d.year, d.month, d.day));
            },
          ),
          const SizedBox(height: 10),
          AkadPicker(
            icon: LucideIcons.calendar,
            label: context.l10n.acadTimeEndDate,
            hint: context.l10n.acadTimeEndDate,
            value: _end == null ? null : acadDate(context, _end!),
            onTap: () async {
              final d = await _pick(_end ?? _start);
              if (d != null && mounted) setState(() => _end = DateTime.utc(d.year, d.month, d.day));
            },
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: BuType.caption.copyWith(color: t.danger))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.acadTimeCancel, style: BuType.bodyStrong.copyWith(color: t.mut))),
        TextButton(
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty || _start == null || _end == null) {
              setState(() => _error = context.l10n.acadTimeSemesterNeedAll);
            } else if (!_end!.isAfter(_start!)) {
              setState(() => _error = context.l10n.acadTimeSemesterEndAfter);
            } else {
              Navigator.pop(context, (name: n, start: _start!, end: _end!));
            }
          },
          child: Text(context.l10n.acadTimeAdd, style: BuType.bodyStrong.copyWith(color: t.pr)),
        ),
      ],
    );
  }
}
