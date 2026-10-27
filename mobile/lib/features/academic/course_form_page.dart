import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';

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

  String _describe(CourseSession s) => '${dayNames[(s.dayOfWeek - 1).clamp(0, 6)]} ${s.start}-${s.end}';

  Future<void> _save({bool force = false}) async {
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Ders adı gerekli' : null;
      _sessionError = null;
    });
    if (name.isEmpty) return;
    final sessions = [for (final s in _sessions) s.toSession()];
    for (final s in sessions) {
      if (s.endMin <= s.startMin) {
        setState(() => _sessionError = 'Bitiş saati başlangıçtan sonra olmalı.');
        return;
      }
    }
    if (!force) {
      final conflicts = findConflicts(widget.allCourses, sessions, excludeCourseId: widget.course?.id);
      final own = selfConflicts(sessions);
      if (conflicts.isNotEmpty || own.isNotEmpty) {
        final lines = [
          for (final c in conflicts.take(3)) '${c.course.name} (${_describe(c.session)})',
          if (own.isNotEmpty) 'Bu dersin kendi oturumları çakışıyor',
        ];
        final go = await confirmDialog(context,
            title: 'Ders çakışması',
            text: 'Şu derslerle saatler çakışıyor:\n${lines.join('\n')}\n\nYine de kaydedilsin mi?',
            action: 'Yine de kaydet');
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
        final go = await confirmDialog(context, title: 'Ders çakışması', text: '${e.message}\n\nYine de kaydedilsin mi?', action: 'Yine de kaydet');
        if (go && mounted) return _save(force: true);
        return;
      }
      academicToast(context, errorText(e));
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Dersi sil', text: '"${widget.course!.name}" dersi ve tüm oturumları silinecek.', action: 'Sil', danger: true);
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
    return AcademicScaffold(
      title: _editing ? 'Dersi düzenle' : 'Yeni ders',
      actions: [if (_editing) BuIconButton(icon: LucideIcons.trash2, tooltip: 'Dersi sil', onTap: _busy ? null : _delete)],
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 32),
        children: [
          const FormLabel('Ders adı'),
          TextField(
            controller: _name,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            style: BuType.body.copyWith(color: t.ink),
            decoration: InputDecoration(hintText: 'Örn. Veri Yapıları', counterText: '', errorText: _nameError),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FormLabel('Ders kodu'),
                TextField(
                    controller: _code,
                    maxLength: 20,
                    textCapitalization: TextCapitalization.characters,
                    style: BuType.body.copyWith(color: t.ink),
                    decoration: const InputDecoration(hintText: 'BIL201', counterText: '')),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const FormLabel('Öğretim üyesi'),
                TextField(
                    controller: _instructor,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    style: BuType.body.copyWith(color: t.ink),
                    decoration: const InputDecoration(hintText: 'Dr. Ayşe Yılmaz', counterText: '')),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          const FormLabel('Renk'),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final k in courseColorKeys)
              Semantics(
                button: true,
                selected: _color == k,
                label: 'Renk ${colorLabel(k)}',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _color = _color == k ? null : k),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: courseColor(k),
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == k ? t.ink : Colors.transparent, width: 2.5),
                      ),
                      child: _color == k ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
                ),
              ),
          ]),
          if (_color == null) Text('Seçmezseniz otomatik atanır.', style: BuType.caption.copyWith(color: t.mut)),
          const SizedBox(height: 16),
          Text('Gün ve saatler', style: BuType.heading.copyWith(color: t.ink)),
          const SizedBox(height: 8),
          for (var i = 0; i < _sessions.length; i++) _sessionCard(t, i),
          if (_sessionError != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_sessionError!, style: BuType.caption.copyWith(color: t.danger))),
          if (_sessions.length < 12)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BuButton(
                compact: true,
                kind: BuButtonKind.soft,
                icon: LucideIcons.plus,
                label: 'Başka gün/saat ekle',
                onPressed: () => setState(() {
                  final last = _sessions.last;
                  _sessions.add(_SessionDraft(day: last.day % 7 + 1, start: last.start, end: last.end));
                }),
              ),
            ),
          const SizedBox(height: 16),
          const FormLabel('Not'),
          TextField(
            controller: _note,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: BuType.body.copyWith(color: t.ink),
            decoration: const InputDecoration(hintText: 'İsteğe bağlı (örn. laptop getir)', counterText: ''),
          ),
          const SizedBox(height: 20),
          BuButton(label: _editing ? 'Kaydet' : 'Dersi ekle', busy: _busy, onPressed: _busy ? null : () => _save()),
        ],
      ),
    );
  }

  Widget _sessionCard(BuTokens t, int i) {
    final s = _sessions[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BuCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${i + 1}. oturum', style: BuType.label.copyWith(color: t.mut))),
            if (_sessions.length > 1)
              IconButton(
                tooltip: 'Oturumu kaldır',
                visualDensity: VisualDensity.compact,
                icon: Icon(LucideIcons.x, size: 18, color: t.mut),
                onPressed: () => setState(() => _sessions.removeAt(i).room.dispose()),
              ),
          ]),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var d = 1; d <= 7; d++)
              Semantics(
                label: dayNames[d - 1],
                child: BuChip(label: dayShort[d - 1], selected: s.day == d, onTap: () => setState(() => s.day = d)),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: PickerField(
                icon: LucideIcons.clock,
                label: 'Başlangıç saati',
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
            const SizedBox(width: 8),
            Expanded(
              child: PickerField(
                icon: LucideIcons.clock,
                label: 'Bitiş saati',
                value: hhmm(s.end),
                onTap: () async {
                  final m = await _pickTime(s.end);
                  if (m != null && mounted) setState(() => s.end = m);
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: s.room,
            maxLength: 60,
            style: BuType.body.copyWith(color: t.ink),
            decoration: const InputDecoration(hintText: 'Derslik (örn. B-204)', counterText: ''),
          ),
        ]),
      ),
    );
  }
}

