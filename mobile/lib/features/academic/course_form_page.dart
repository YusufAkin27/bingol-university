import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'reminders.dart';

class _SessionDraft {
  _SessionDraft({required this.day, required this.start, required this.end, String? room, this.id})
      : room = TextEditingController(text: room ?? '');

  int day;
  int start; // dakika
  int end;
  final int? id;
  final TextEditingController room;

  CourseSession toSession() => CourseSession(id: id, dayOfWeek: day, start: hhmm(start), end: hhmm(end), room: room.text);
}

/// Ders ekle / düzenle. Başarıda `true` ile kapanır (liste yenilenir).
class CourseFormPage extends StatefulWidget {
  const CourseFormPage({
    super.key,
    required this.session,
    this.course,
    this.allCourses = const [],
    this.semesterId,
    this.initialDay,
  });

  final Session session;
  final Course? course;
  final List<Course> allCourses;
  final int? semesterId;
  final int? initialDay;

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<CourseFormPage> {
  late final AcademicApi _api = AcademicApi(widget.session);
  late final _name = TextEditingController(text: widget.course?.name ?? '');
  late final _code = TextEditingController(text: widget.course?.code ?? '');
  late final _instructor = TextEditingController(text: widget.course?.instructor ?? '');
  late final _note = TextEditingController(text: widget.course?.note ?? '');
  late String? _color = widget.course?.color;
  late final List<_SessionDraft> _sessions;
  bool _busy = false;
  String? _nameError;
  String? _sessionError;

  bool get _editing => widget.course != null;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _sessions = c != null && c.sessions.isNotEmpty
        ? [for (final s in c.sessions) _SessionDraft(day: s.dayOfWeek, start: s.startMin, end: s.endMin, room: s.room, id: s.id)]
        : [_SessionDraft(day: widget.initialDay ?? 1, start: 9 * 60, end: 10 * 60 + 50)];
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _instructor, _note]) {
      c.dispose();
    }
    for (final s in _sessions) {
      s.room.dispose();
    }
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

  String _describe(CourseSession s) => '${acadDayName(context.l10n, s.dayOfWeek.clamp(1, 7))} ${s.start}-${s.end}';

  Future<void> _save({bool force = false}) async {
    final l = context.l10n;
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? l.acadTimeNameRequired : null;
      _sessionError = null;
    });
    if (name.isEmpty) return;
    final sessions = [for (final s in _sessions) s.toSession()];
    for (final s in sessions) {
      if (s.endMin <= s.startMin) {
        setState(() => _sessionError = l.acadTimeEndAfterStart);
        return;
      }
    }
    if (!force) {
      final conflicts = findConflicts(widget.allCourses, sessions, excludeCourseId: widget.course?.id);
      final own = selfConflicts(sessions);
      if (conflicts.isNotEmpty || own.isNotEmpty) {
        final lines = [
          for (final c in conflicts.take(3)) '${c.course.name} (${_describe(c.session)})',
          if (own.isNotEmpty) l.acadTimeOwnConflict,
        ];
        final go = await confirmDialog(context,
            title: l.acadTimeConflictTitle,
            text: l.acadTimeConflictText(lines.join('\n')),
            action: l.acadTimeSaveAnyway);
        if (!go || !mounted) return;
        return _save(force: true);
      }
    }
    final body = <String, dynamic>{
      'name': name,
      'code': _code.text.trim(),
      'instructor': _instructor.text.trim(),
      'note': _note.text.trim(),
      if (_color != null) 'color': _color,
      if (!_editing && widget.semesterId != null) 'semesterId': widget.semesterId,
      'force': force,
      'sessions': [for (final s in sessions) s.toJson()],
    };
    setState(() => _busy = true);
    try {
      if (_editing) {
        await _api.updateCourse(widget.course!.id, body);
      } else {
        await _api.createCourse(body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.status == 409 && e.code == 'COURSE_CONFLICT') {
        final l = context.l10n;
        final go = await confirmDialog(context, title: l.acadTimeConflictTitle, text: l.acadTimeConflictServerText(e.message), action: l.acadTimeSaveAnyway);
        if (go && mounted) return _save(force: true);
        return;
      }
      academicToast(context, errorText(e));
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: context.l10n.acadTimeDeleteCourse,
        text: context.l10n.acadTimeDeleteCourseText(widget.course!.name),
        action: context.l10n.acadTimeDelete,
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.deleteCourse(widget.course!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      academicToast(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return AcademicScaffold(
      title: _editing ? l.acadTimeEditCourse : l.acadTimeNewCourse,
      actions: [if (_editing) BuIconButton(icon: LucideIcons.trash2, tooltip: l.acadTimeDeleteCourse, onTap: _busy ? null : _delete)],
      bottomBar: AkadBottomBar(children: [
        AkadButton(label: _editing ? l.acadTimeSave : l.acadTimeAddCourseBtn, busy: _busy, onPressed: _busy ? null : () => _save()),
      ]),
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, AkadBottomBar.reserve),
        children: [
          AkadTextField(
            label: l.acadTimeCourseName,
            controller: _name,
            maxLength: 120,
            capitalization: TextCapitalization.words,
            hint: l.acadTimeNameHint,
            error: _nameError,
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: AkadTextField(
                label: l.acadTimeCourseCode,
                controller: _code,
                maxLength: 20,
                capitalization: TextCapitalization.characters,
                hint: 'BIL201',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AkadTextField(
                label: l.akademik2Instructor,
                controller: _instructor,
                maxLength: 120,
                capitalization: TextCapitalization.words,
                hint: l.acadTimeInstructorHint,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          AkadLabel(l.acadTimeColor),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 6,
            spacing: 6,
            children: [for (final k in _paletteKeys) _swatch(t, k)],
          ),
          if (_color == null) Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text(l.acadTimeColorAuto, style: BuType.caption.copyWith(color: t.mut))),
          const SizedBox(height: 14),
          AkadCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.akademik2CourseHours, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w800, color: t.ink)),
              for (var i = 0; i < _sessions.length; i++) ...[
                if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: AkadDivider()),
                if (i == 0) const SizedBox(height: 12),
                _sessionBlock(t, i),
              ],
              if (_sessionError != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(_sessionError!, style: BuType.caption.copyWith(color: t.danger))),
              if (_sessions.length < 12) ...[
                const SizedBox(height: 12),
                AkadDashedButton(
                  label: l.akademik2AddDay,
                  icon: LucideIcons.plus,
                  onPressed: () => setState(() {
                    final last = _sessions.last;
                    _sessions.add(_SessionDraft(day: last.day % 7 + 1, start: last.start, end: last.end));
                  }),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          AkadTextField(
            label: l.acadTimeNote,
            controller: _note,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            capitalization: TextCapitalization.sentences,
            hint: l.acadTimeNoteHint,
          ),
        ],
      ),
    );
  }

  /// Tasarımdaki 6 renk; ders başka bir renkteyse o da eklenir.
  List<String> get _paletteKeys => [..._akadPalette, if (_color != null && !_akadPalette.contains(_color)) _color!];

  Widget _swatch(BuTokens t, String k) {
    final l = context.l10n;
    final sel = _color == k;
    return Semantics(
      button: true,
      selected: sel,
      label: l.acadTimeColorSemantic(acadColorName(l, k)),
      excludeSemantics: true,
      onTap: () => setState(() => _color = sel ? null : k),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _color = sel ? null : k),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: courseColor(k),
            shape: BoxShape.circle,
            border: Border.all(color: sel ? t.ink : t.sf, width: 3),
            boxShadow: [BoxShadow(color: t.bd, spreadRadius: 1.5)],
          ),
          child: sel ? const Icon(LucideIcons.check, size: 18, color: Colors.white) : null,
        ),
      ),
    );
  }

  Widget _sessionBlock(BuTokens t, int i) {
    final s = _sessions[i];
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_sessions.length > 1)
        Row(children: [
          Expanded(child: Text(l.acadTimeSessionN((i + 1).toString()), style: BuType.label.copyWith(color: t.mut))),
          IconButton(
            tooltip: l.acadTimeRemoveSession,
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.x, size: 18, color: t.mut),
            onPressed: () => setState(() => _sessions.removeAt(i).room.dispose()),
          ),
        ]),
      Row(children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) const SizedBox(width: 4),
          Expanded(
            child: AkadChip(
              label: acadDayShort(l, d),
              semanticLabel: acadDayName(l, d),
              selected: s.day == d,
              expand: true,
              fontSize: 13,
              onTap: () => setState(() => s.day = d),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: AkadPicker(
            icon: LucideIcons.clock,
            compact: true,
            label: l.akademik2Start,
            value: hhmm(s.start),
            onTap: () async {
              final m = await _pickTime(s.start);
              if (m != null && mounted) {
                setState(() {
                  final len = s.end - s.start;
                  s.start = m;
                  if (s.end <= m) s.end = (m + (len > 0 ? len : 50)).clamp(0, 23 * 60 + 59);
                });
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AkadPicker(
            icon: LucideIcons.clock,
            compact: true,
            label: l.akademik2End,
            value: hhmm(s.end),
            onTap: () async {
              final m = await _pickTime(s.end);
              if (m != null && mounted) setState(() => s.end = m);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AkadLabel(l.akademik2RoomShort),
            TextField(
              controller: s.room,
              maxLength: 60,
              style: BuType.body.copyWith(fontSize: 16, color: t.ink),
              decoration: akadInput(context, hint: 'B-204').copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17)),
            ),
          ]),
        ),
      ]),
    ]);
  }
}

/// Renk seçicide gösterilen tasarım paleti.
const _akadPalette = ['red', 'blue', 'green', 'orange', 'purple', 'teal'];
