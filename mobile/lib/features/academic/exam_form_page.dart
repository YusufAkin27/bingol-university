import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';

/// Kişisel sınav ekle / düzenle. Başarıda `true` ile kapanır.
class ExamFormPage extends StatefulWidget {
  const ExamFormPage({super.key, required this.session, this.exam, this.courses = const []});

  final Session session;
  final Exam? exam;
  final List<Course> courses;

  @override
  State<ExamFormPage> createState() => _ExamFormPageState();
}

class _ExamFormPageState extends State<ExamFormPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  late final _title = TextEditingController(text: widget.exam?.title ?? '');
  late final _room = TextEditingController(text: widget.exam?.room ?? '');
  late final _note = TextEditingController(text: widget.exam?.note ?? '');
  late String _type = widget.exam?.type ?? 'VIZE';
  late int? _courseId = widget.exam?.courseId;
  DateTime? _day; // duvar tarihi
  int _start = 10 * 60;
  int? _end;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.exam != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    if (e != null) {
      final w = istanbulWall(e.startsAt);
      _day = DateTime.utc(w.year, w.month, w.day);
      _start = w.hour * 60 + w.minute;
      if (e.endsAt != null) {
        final x = istanbulWall(e.endsAt!);
        _end = x.hour * 60 + x.minute;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<int?> _pickTime(int current) async {
    final r = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    return r == null ? null : r.hour * 60 + r.minute;
  }

  String _iso(int minutes) {
    final d = _day!;
    return '${isoDate(d)}T${hhmm(minutes)}:00+03:00';
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return setState(() => _error = 'Sınav başlığı gerekli.');
    if (_day == null) return setState(() => _error = 'Sınav tarihini seç.');
    if (_end != null && _end! <= _start) return setState(() => _error = 'Bitiş saati başlangıçtan sonra olmalı.');
    final body = {
      'title': _title.text.trim(),
      'type': _type,
      if (_courseId != null) 'courseId': _courseId,
      'startsAt': _iso(_start),
      if (_end != null) 'endsAt': _iso(_end!),
      'room': _room.text.trim(),
      'note': _note.text.trim(),
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_editing) {
        await _api.updateExam(widget.exam!.id, body);
      } else {
        await _api.createExam(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Sınavı sil', text: '"${widget.exam!.title}" silinecek.', action: 'Sil', danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.deleteExam(widget.exam!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AcademicScaffold(
      title: _editing ? 'Sınavı düzenle' : 'Yeni sınav',
      actions: [if (_editing) BuIconButton(icon: LucideIcons.trash2, tooltip: 'Sınavı sil', onTap: _busy ? null : _delete)],
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
        children: [
          const FormLabel('Başlık'),
          TextField(
            controller: _title,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            style: BuType.body.copyWith(color: t.ink),
            decoration: const InputDecoration(hintText: 'Örn. Veri Yapıları Vize 1', counterText: ''),
          ),
          const SizedBox(height: 12),
          const FormLabel('Tür'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in examTypes) BuChip(label: examTypeLabel(k), selected: _type == k, onTap: () => setState(() => _type = k)),
          ]),
          if (widget.courses.isNotEmpty) ...[
            const SizedBox(height: 12),
            const FormLabel('Ders (isteğe bağlı)'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              BuChip(label: 'Yok', selected: _courseId == null, onTap: () => setState(() => _courseId = null)),
              for (final c in widget.courses)
                BuChip(label: c.name, selected: _courseId == c.id, onTap: () => setState(() => _courseId = c.id)),
            ]),
          ],
          const SizedBox(height: 12),
          const FormLabel('Tarih ve saat'),
          PickerField(
            icon: LucideIcons.calendar,
            label: 'Sınav tarihi',
            hint: 'Tarih seç',
            value: _day == null ? null : fmtWallDate(_day!),
            onTap: () async {
              final now = istanbulWall(academicClock());
              final d = await showDatePicker(
                context: context,
                initialDate: _day ?? DateTime(now.year, now.month, now.day),
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
              );
              if (d != null && mounted) setState(() => _day = DateTime.utc(d.year, d.month, d.day));
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: PickerField(
                icon: LucideIcons.clock,
                label: 'Başlangıç saati',
                value: hhmm(_start),
                onTap: () async {
                  final m = await _pickTime(_start);
                  if (m != null && mounted) setState(() => _start = m);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PickerField(
                icon: LucideIcons.clock,
                label: 'Bitiş saati',
                hint: 'Bitiş (ops.)',
                value: _end == null ? null : hhmm(_end!),
                onTap: () async {
                  final m = await _pickTime(_end ?? _start + 90);
                  if (m != null && mounted) setState(() => _end = m);
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const FormLabel('Derslik'),
          TextField(
              controller: _room,
              maxLength: 60,
              style: BuType.body.copyWith(color: t.ink),
              decoration: const InputDecoration(hintText: 'Örn. B-204', counterText: '')),
          const SizedBox(height: 12),
          const FormLabel('Not'),
          TextField(
              controller: _note,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              style: BuType.body.copyWith(color: t.ink),
              decoration: const InputDecoration(hintText: 'İsteğe bağlı', counterText: '')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: BuType.caption.copyWith(color: t.danger))),
          const SizedBox(height: 16),
          BuButton(label: _editing ? 'Kaydet' : 'Sınavı ekle', busy: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}
