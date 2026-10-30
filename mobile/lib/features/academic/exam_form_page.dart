import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
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
  List<String> _errors = const [];

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
    final errs = <String>[
      if (_title.text.trim().isEmpty) l.acadFormErrTitle,
      if (_day == null) l.acadFormErrDate,
      if (_end != null && _end! <= _start) l.acadFormErrEnd,
    ];
    if (errs.isNotEmpty) return setState(() => _errors = errs);
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
      _errors = const [];
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
          _errors = [errorText(e)];
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
          _errors = [errorText(e)];
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
    return AcademicScaffold(
      title: _editing ? l.acadFormEdit : l.acadFormNew,
      actions: [
        if (_editing) BuIconButton(icon: LucideIcons.trash2, tooltip: l.acadFormDeleteTitle, onTap: _busy ? null : _delete),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AkadCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AkadTextField(
                label: l.acadFormTitleLabel,
                requiredMark: true,
                controller: _title,
                maxLength: 120,
                capitalization: TextCapitalization.sentences,
                hint: l.acadFormTitleHint,
              ),
              const SizedBox(height: 16),
              AkadFieldLabel(l.acadFormType),
              Wrap(spacing: 8, children: [
                for (final k in examTypes) AkadChip(label: examTypeLabelL(l, k), selected: _type == k, onTap: () => setState(() => _type = k)),
              ]),
              if (widget.courses.isNotEmpty) ...[
                const SizedBox(height: 16),
                AkadPicker(
                  label: l.acadFormCourseOpt,
                  icon: LucideIcons.chevronDown,
                  value: course == null ? null : _courseLabel(course),
                  hint: l.acadFormNone,
                  onTap: _pickCourse,
                ),
              ],
              const SizedBox(height: 16),
              AkadPicker(
                icon: LucideIcons.calendar,
                requiredMark: true,
                label: l.acadFormExamDate,
                hint: l.acadFormPickDate,
                value: _day == null ? null : fmtWallDateL(l, _day!),
                onTap: () async {
                  final now = istanbulWall(academicClock());
                  final d = await pickAcadDate(context,
                      initial: _day ?? DateTime(now.year, now.month, now.day), first: DateTime(now.year - 1), last: DateTime(now.year + 2), help: l.acadFormExamDate);
                  if (d != null && mounted) setState(() => _day = DateTime.utc(d.year, d.month, d.day));
                },
              ),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: AkadPicker(
                    icon: LucideIcons.clock,
                    compact: true,
                    label: l.acadFormStartTime,
                    value: hhmm(_start),
                    onTap: () async {
                      final m = await _pickTime(_start, l.acadFormStartTime);
                      if (m != null && mounted) setState(() => _start = m);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AkadPicker(
                    icon: LucideIcons.clock,
                    compact: true,
                    label: l.acadFormEndHint,
                    hint: l.acadSelect,
                    value: _end == null ? null : hhmm(_end!),
                    onTap: () async {
                      final m = await _pickTime(_end ?? _start + 90, l.acadFormEndTime);
                      if (m != null && mounted) setState(() => _end = m);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              AkadTextField(label: l.acadFormRoom, controller: _room, maxLength: 60, hint: l.acadFormRoomHint, icon: LucideIcons.doorOpen),
              const SizedBox(height: 16),
              AkadTextField(label: l.acadFormNote, controller: _note, maxLength: 500, minLines: 3, maxLines: 5, hint: l.acadFormNoteHint),
            ]),
          ),
          AnimatedSize(
            duration: BuMotion.of(context, BuMotion.medium),
            curve: BuMotion.standard,
            alignment: Alignment.topCenter,
            child: _errors.isEmpty ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(top: 16), child: _errorBox(t, tx, l)),
          ),
          const SizedBox(height: 16),
          BuButton(
            label: _editing ? l.acadSave : l.acadFormAdd,
            icon: _editing ? LucideIcons.circleCheck : LucideIcons.calendarPlus,
            busy: _busy,
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _errorBox(BuTokens t, TextTheme tx, AppLocalizations l) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bLg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(LucideIcons.circleAlert, size: 18, color: t.onSoft),
              const SizedBox(width: 8),
              Expanded(child: Text(l.p17CheckFields, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: t.onSoft))),
            ]),
            const SizedBox(height: 8),
            for (final e in _errors)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: t.onSoft, shape: BoxShape.circle))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e, style: tx.bodyMedium!.copyWith(color: t.onSoft))),
                ]),
              ),
          ]),
        ),
      );
}
