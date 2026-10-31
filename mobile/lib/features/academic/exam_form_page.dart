import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'acad_ref_widgets.dart';
import 'akad_widgets.dart';

/// Kişisel sınav ekle / düzenle. Başarıda `true` ile kapanır.
/// Başlık, tür çipleri, (varsa) ders çipleri, tarih/saat seçiciler, yer ve not; hata üstte bir şeritte çıkar.
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
  String? _titleErr, _dateErr, _endErr, _serverErr;

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

  Future<int?> _pickTime(int current, String help) => pickAcadTime(context, current, help: help);

  String _iso(int minutes) {
    final d = _day!;
    return '${isoDate(d)}T${hhmm(minutes)}:00+03:00';
  }

  Future<void> _save() async {
    final l = context.l10n;
    final titleErr = _title.text.trim().isEmpty ? l.p69ExamNameErr : null;
    final dateErr = _day == null ? l.acadFormErrDate : null;
    final endErr = (_end != null && _end! <= _start) ? l.acadFormErrEnd : null;
    if (titleErr != null || dateErr != null || endErr != null) {
      return setState(() {
        _titleErr = titleErr;
        _dateErr = dateErr;
        _endErr = endErr;
        _serverErr = null;
      });
    }
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
      _titleErr = _dateErr = _endErr = _serverErr = null;
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
          _serverErr = errorText(e);
        });
      }
    }
  }

  /// Ders seçimi: alt sayfada "Yok" + dersler.
  Future<void> _pickCourse() async {
    final l = context.l10n;
    final r = await BuSheet.show<int>(
      context,
      title: l.acadFormCourseOpt,
      builder: (c) => Column(children: [
        BuListTile(title: l.acadFormNone, selected: _courseId == null, onTap: () => Navigator.pop(c, -1)),
        for (final co in widget.courses) BuListTile(title: _courseLabel(co), selected: _courseId == co.id, onTap: () => Navigator.pop(c, co.id)),
      ]),
    );
    if (r != null && mounted) setState(() => _courseId = r < 0 ? null : r);
  }

  String _courseLabel(Course c) => c.code == null ? c.name : '${c.code} ${c.name}';

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
          _serverErr = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final course = widget.courses.where((c) => c.id == _courseId).firstOrNull;
    const gap = SizedBox(height: 16);
    return AcademicScaffold(
      title: _editing ? l.acadFormEdit : l.acadExamsAdd,
      actions: [
        if (_editing) BuIconButton(icon: LucideIcons.trash2, tooltip: l.acadFormDeleteTitle, onTap: _busy ? null : _delete),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 1, 20, 32),
        children: [
          AcadTextField(
            label: l.p69ExamName,
            controller: _title,
            maxLength: 120,
            capitalization: TextCapitalization.sentences,
            hint: l.p69ExamNameHint,
            error: _titleErr,
            onChanged: (_) {
              if (_titleErr != null) setState(() => _titleErr = null);
            },
          ),
          gap,
          if (widget.courses.isNotEmpty) ...[
            AcadPicker(
              label: l.akademik2Course,
              trailing: LucideIcons.chevronDown,
              value: course == null ? null : _courseLabel(course),
              hint: l.p69PickCourse,
              onTap: _pickCourse,
            ),
            gap,
          ],
          AcadLabeled(
            label: l.acadFormType,
            gap: 3,
            child: Wrap(spacing: 8, children: [
              for (final k in examTypes) AkadChip(label: examTypeLabelL(l, k), selected: _type == k, onTap: () => setState(() => _type = k)),
            ]),
          ),
          const SizedBox(height: 8),
          AcadPicker(
            label: l.p69DateLabel,
            trailing: LucideIcons.calendar,
            hint: l.acadFormPickDate,
            value: _day == null ? null : fmtWallDateL(l, _day!),
            error: _dateErr,
            onTap: () async {
              final now = istanbulWall(academicClock());
              final d = await pickAcadDate(context,
                  initial: _day ?? DateTime(now.year, now.month, now.day), first: DateTime(now.year - 1), last: DateTime(now.year + 2), help: l.acadFormExamDate);
              if (d != null && mounted) {
                setState(() {
                  _day = DateTime.utc(d.year, d.month, d.day);
                  _dateErr = null;
                });
              }
            },
          ),
          gap,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: AcadPicker(
                label: l.p69TimeLabel,
                trailing: LucideIcons.clock,
                value: hhmm(_start),
                onTap: () async {
                  final m = await _pickTime(_start, l.acadFormStartTime);
                  if (m != null && mounted) {
                    setState(() {
                      _start = m;
                      _endErr = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AcadPicker(
                label: l.acadFormEndHint,
                trailing: LucideIcons.clock,
                hint: l.acadSelect,
                value: _end == null ? null : hhmm(_end!),
                error: _endErr,
                onTap: () async {
                  final m = await _pickTime(_end ?? _start + 90, l.acadFormEndTime);
                  if (m != null && mounted) {
                    setState(() {
                      _end = m;
                      _endErr = null;
                    });
                  }
                },
              ),
            ),
          ]),
          gap,
          AcadTextField(label: l.akademik2Place, controller: _room, maxLength: 60, hint: l.acadFormRoomHint),
          gap,
          AcadTextField(label: l.acadFormNote, controller: _note, maxLength: 500, minLines: 1, maxLines: 4, hint: l.acadFormNoteHint),
          const SizedBox(height: 18),
          Text(l.p69ExamNote, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
          AnimatedSize(
            duration: BuMotion.of(context, BuMotion.medium),
            curve: BuMotion.standard,
            alignment: Alignment.topCenter,
            child: _serverErr == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(liveRegion: true, container: true, child: Text(_serverErr!, style: tx.bodyMedium!.copyWith(color: t.danger, fontWeight: FontWeight.w500))),
                  ),
          ),
          const SizedBox(height: 22),
          BuButton(label: l.acadSave, busy: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}
