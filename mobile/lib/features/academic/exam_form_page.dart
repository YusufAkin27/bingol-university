import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';

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
    final l = context.l10n;
    if (_title.text.trim().isEmpty) return setState(() => _error = l.acadFormErrTitle);
    if (_day == null) return setState(() => _error = l.acadFormErrDate);
    if (_end != null && _end! <= _start) return setState(() => _error = l.acadFormErrEnd);
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
    final l = context.l10n;
    final ok = await confirmDialog(context, title: l.acadFormDeleteTitle, text: l.acadFormDeleteText(widget.exam!.title), action: l.acadDelete, danger: true);
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
    final l = context.l10n;
    return AcademicScaffold(
      title: _editing ? l.acadFormEdit : l.acadExamsAdd,
      actions: [if (_editing) BuIconButton(icon: LucideIcons.trash2, tooltip: l.acadFormDeleteTitle, onTap: _busy ? null : _delete)],
      bottomBar: AkadBottomBar(children: [
        AkadButton(label: _editing ? l.acadSave : l.acadFormAdd, busy: _busy, onPressed: _busy ? null : _save),
      ]),
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, AkadBottomBar.reserve),
        children: [
          AkadTextField(
            label: l.akademik2ExamTitle,
            controller: _title,
            maxLength: 120,
            capitalization: TextCapitalization.sentences,
            hint: l.acadFormTitleHint,
          ),
          const SizedBox(height: 14),
          AkadLabel(l.acadFormType),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in examTypes) AkadChip(label: examTypeLabelL(l, k), selected: _type == k, onTap: () => setState(() => _type = k)),
          ]),
          if (widget.courses.isNotEmpty) ...[
            const SizedBox(height: 14),
            AkadLabel(l.akademik2Course),
            Wrap(spacing: 8, runSpacing: 8, children: [
              AkadChip(label: l.acadFormNone, selected: _courseId == null, onTap: () => setState(() => _courseId = null)),
              for (final c in widget.courses) AkadChip(label: c.name, selected: _courseId == c.id, onTap: () => setState(() => _courseId = c.id)),
            ]),
          ],
          const SizedBox(height: 14),
          AkadPicker(
            icon: LucideIcons.calendar,
            label: l.acadFormExamDate,
            hint: l.acadFormPickDate,
            value: _day == null ? null : fmtWallDateL(l, _day!),
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
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: AkadPicker(
                icon: LucideIcons.clock,
                label: l.akademik2Start,
                value: hhmm(_start),
                onTap: () async {
                  final m = await _pickTime(_start);
                  if (m != null && mounted) setState(() => _start = m);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AkadPicker(
                icon: LucideIcons.clock,
                label: l.akademik2EndOptional,
                hint: l.acadFormEndHint,
                value: _end == null ? null : hhmm(_end!),
                onTap: () async {
                  final m = await _pickTime(_end ?? _start + 90);
                  if (m != null && mounted) setState(() => _end = m);
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          AkadTextField(label: l.akademik2Place, controller: _room, maxLength: 60, hint: l.acadFormRoomHint),
          const SizedBox(height: 14),
          AkadTextField(label: l.acadFormNote, controller: _note, maxLength: 500, minLines: 2, maxLines: 4, hint: l.acadFormNoteHint),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: BuType.caption.copyWith(color: t.danger))),
        ],
      ),
    );
  }
}
