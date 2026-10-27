import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';

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
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Text('Dönem', style: BuType.heading.copyWith(color: t.ink)),
          const SizedBox(height: 8),
          Flexible(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(32), child: LoadingView())
                : _error != null
                    ? Padding(padding: const EdgeInsets.all(8), child: ErrorView(error: _error!, onRetry: _load))
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        children: [
                          if (_items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Henüz dönem yok. Bir dönem ekleyerek derslerini düzenleyebilirsin.',
                                  textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
                            ),
                          for (final s in _items) _row(t, s),
                          const SizedBox(height: 8),
                          BuButton(label: 'Yeni dönem ekle', icon: LucideIcons.plus, kind: BuButtonKind.soft, busy: _busy, onPressed: _create),
                          if (_official != null) ...[
                            const SizedBox(height: 8),
                            BuButton(
                              label: '${_official!['name'] ?? 'Resmi dönem'} (akademik takvimden)',
                              icon: LucideIcons.landmark,
                              kind: BuButtonKind.outline,
                              onPressed: _busy ? null : () => _run(widget.api.semesterFromOfficial),
                            ),
                          ],
                        ],
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: BuButton(
              label: 'Kapat',
              kind: BuButtonKind.outline,
              onPressed: () => Navigator.pop(context, _changed ? const SemesterAction(changed: true) : null),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(BuTokens t, Semester s) {
    final active = s.id == widget.activeId;
    final range = s.startDate != null && s.endDate != null ? '${fmtWallDate(s.startDate!)} - ${fmtWallDate(s.endDate!)}' : null;
    return Semantics(
      button: true,
      selected: active,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: active ? t.soft : t.sf,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: active ? t.pr : t.bd)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, SemesterAction(semesterId: s.id, changed: _changed)),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(color: t.ink))),
                    if (s.current) ...[const SizedBox(width: 6), const BuBadge('Güncel', soft: true)],
                  ]),
                  if (range != null) Text(range, style: BuType.caption.copyWith(color: t.mut)),
                ]),
              ),
              if (!s.current)
                IconButton(
                  tooltip: 'Güncel dönem yap',
                  icon: Icon(LucideIcons.badgeCheck, size: 19, color: t.mut),
                  onPressed: _busy ? null : () => _run(() => widget.api.makeCurrent(s.id)),
                ),
              IconButton(
                tooltip: 'Dönemi sil',
                icon: Icon(LucideIcons.trash2, size: 18, color: t.mut),
                onPressed: _busy
                    ? null
                    : () async {
                        final ok = await confirmDialog(context,
                            title: 'Dönemi sil', text: '"${s.name}" silinecek. Dersler dönemsiz kalır.', action: 'Sil', danger: true);
                        if (ok) await _run(() => widget.api.deleteSemester(s.id));
                      },
              ),
            ]),
          ),
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
      backgroundColor: t.sf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Yeni dönem', style: BuType.title.copyWith(color: t.ink)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _name, maxLength: 60, decoration: const InputDecoration(hintText: '2026-2027 Güz', counterText: '')),
          const SizedBox(height: 10),
          PickerField(
            icon: LucideIcons.calendar,
            label: 'Başlangıç tarihi',
            hint: 'Başlangıç tarihi',
            value: _start == null ? null : fmtWallDate(_start!),
            onTap: () async {
              final d = await _pick(_start);
              if (d != null && mounted) setState(() => _start = DateTime.utc(d.year, d.month, d.day));
            },
          ),
          const SizedBox(height: 8),
          PickerField(
            icon: LucideIcons.calendar,
            label: 'Bitiş tarihi',
            hint: 'Bitiş tarihi',
            value: _end == null ? null : fmtWallDate(_end!),
            onTap: () async {
              final d = await _pick(_end ?? _start);
              if (d != null && mounted) setState(() => _end = DateTime.utc(d.year, d.month, d.day));
            },
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: BuType.caption.copyWith(color: t.danger))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Vazgeç', style: BuType.bodyStrong.copyWith(color: t.mut))),
        TextButton(
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty || _start == null || _end == null) {
              setState(() => _error = 'Ad ve iki tarih de gerekli.');
            } else if (!_end!.isAfter(_start!)) {
              setState(() => _error = 'Bitiş tarihi başlangıçtan sonra olmalı.');
            } else {
              Navigator.pop(context, (name: n, start: _start!, end: _end!));
            }
          },
          child: Text('Ekle', style: BuType.bodyStrong.copyWith(color: t.pr)),
        ),
      ],
    );
  }
}
