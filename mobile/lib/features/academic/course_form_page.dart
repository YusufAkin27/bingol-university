import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_models.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'reminders.dart';

class _SessionDraft {
  _SessionDraft({required this.day, required this.start, required this.end, String? room, this.id}) : room = TextEditingController(text: room ?? '');

  int day;
  int start; // dakika
  int end;
  final int? id;
  final TextEditingController room;

  CourseSession toSession() => CourseSession(id: id, dayOfWeek: day, start: hhmm(start), end: hhmm(end), room: room.text);
}

/// Ders ekle / düzenle. Başarıda `true` ile kapanır (liste yenilenir).
/// Üstte canlı önizleme kartı, renk seçici, oturum panelleri (gün çipleri + saat seçiciler + sınıf) ve not.
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
        final go = await confirmDialog(context, title: l.acadTimeConflictTitle, text: l.acadTimeConflictText(lines.join('\n')), action: l.acadTimeSaveAnyway);
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
      academicToast(context, errorText(e), kind: BuToastKind.error);
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
      academicToast(context, errorText(e), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return BuPageScaffold(
      title: _editing ? l.acadTimeEditCourse : l.acadTimeNewCourse,
      large: false,
      actions: [
        if (_editing) BuIconButton(icon: LucideIcons.trash2, tooltip: l.acadTimeDeleteCourse, onTap: _busy ? null : _delete),
        const SizedBox(width: 12),
      ],
      bottomBar: AkadBottomBar(children: [
        AkadButton(label: _editing ? l.acadTimeSave : l.acadTimeAddCourseBtn, busy: _busy, onPressed: _busy ? null : () => _save()),
      ]),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _preview(t),
              const SizedBox(height: 20),
              AkadTextField(
                label: l.acadTimeCourseName,
                controller: _name,
                maxLength: 120,
                capitalization: TextCapitalization.words,
                hint: l.acadTimeNameHint,
                error: _nameError,
                icon: LucideIcons.bookOpen,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: AkadTextField(
                      label: l.acadTimeCourseCode, controller: _code, maxLength: 20, capitalization: TextCapitalization.characters, hint: 'BIL201'),
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
              const SizedBox(height: 18),
              AkadLabel(l.acadTimeColor),
              Row(children: [for (final k in _paletteKeys) Expanded(child: _swatch(t, k))]),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.short),
                alignment: Alignment.topCenter,
                child: _color == null
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
                        child: Text(l.acadTimeColorAuto, style: tx.bodySmall!.copyWith(color: t.mut)))
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 22),
              Semantics(header: true, child: Text(l.akademik2CourseHours, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.standard,
                alignment: Alignment.topCenter,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < _sessions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _sessionBlock(t, i),
                  ],
                ]),
              ),
              if (_sessionError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.circleAlert, size: 16, color: t.danger)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_sessionError!, style: tx.bodySmall!.copyWith(color: t.danger))),
                    ]),
                  ),
                ),
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
              const SizedBox(height: 22),
              AkadTextField(
                label: l.acadTimeNote,
                controller: _note,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                capitalization: TextCapitalization.sentences,
                hint: l.acadTimeNoteHint,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  /// Canlı önizleme: yazdıkça ders kartı nasıl görünecek.
  Widget _preview(BuTokens t) {
    final tx = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: ListenableBuilder(
        listenable: Listenable.merge([_name, _code, _instructor]),
        builder: (context, _) {
          final color = courseColor(_color);
          final name = _name.text.trim();
          final meta = [if (_code.text.trim().isNotEmpty) _code.text.trim(), if (_instructor.text.trim().isNotEmpty) _instructor.text.trim()].join(' · ');
          final when = {for (final s in _sessions) '${acadDayShort(context.l10n, s.day.clamp(1, 7))} ${hhmm(s.start)}'}.join(' · ');
          return Container(
            decoration: BoxDecoration(color: akadTint(context, color), borderRadius: BuRadius.bLg),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(akadUpper(context, context.l10n.p17PreviewHint),
                      style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: akadOnTint(context, color), letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text(name.isEmpty ? context.l10n.acadTimeCourseName : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: name.isEmpty ? t.mut : t.ink)),
                  if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(LucideIcons.clock, size: 13, color: akadOnTint(context, color)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(when, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.ink))),
                    ]),
                  ],
                ]),
              ),
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: AnimatedContainer(duration: BuMotion.of(context, BuMotion.medium), color: color),
              ),
            ]),
          );
        },
      ),
    );
  }

  /// Tasarımdaki 6 renk; ders başka bir renkteyse o da eklenir.
  List<String> get _paletteKeys => [..._akadPalette, if (_color != null && !_akadPalette.contains(_color)) _color!];

  Widget _swatch(BuTokens t, String k) {
    final l = context.l10n;
    final sel = _color == k;
    final color = courseColor(k);
    void tap() {
      buHaptic(BuHaptic.selection);
      setState(() => _color = sel ? null : k);
    }

    return Semantics(
      button: true,
      selected: sel,
      label: l.acadTimeColorSemantic(acadColorName(l, k)),
      excludeSemantics: true,
      onTap: tap,
      child: BuPressable(
        scale: .9,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: tap,
          child: SizedBox(
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: BuMotion.of(context, BuMotion.short),
                curve: BuMotion.standard,
                width: sel ? 40 : 34,
                height: sel ? 40 : 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: sel ? t.ink : t.sf, width: sel ? 3 : 2),
                  boxShadow: [BoxShadow(color: t.bd, spreadRadius: 1)],
                ),
                child: AnimatedScale(
                  scale: sel ? 1 : 0,
                  duration: BuMotion.of(context, BuMotion.short),
                  child: Icon(LucideIcons.check, size: 18, color: t.onMedia),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionBlock(BuTokens t, int i) {
    final s = _sessions[i];
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 14),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bLg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_sessions.length > 1)
          Row(children: [
            Expanded(child: Text(l.acadTimeSessionN((i + 1).toString()), style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: l.acadTimeRemoveSession,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(LucideIcons.x, size: 18, color: t.mut),
              onPressed: () => setState(() => _sessions.removeAt(i).room.dispose()),
            ),
          ])
        else
          const SizedBox(height: 4),
        Row(children: [
          for (var d = 1; d <= 7; d++) ...[
            if (d > 1) const SizedBox(width: 4),
            Expanded(
              child: AkadChip(
                label: acadDayShort(l, d),
                semanticLabel: acadDayName(l, d),
                selected: s.day == d,
                expand: true,
                onTap: () => setState(() => s.day = d),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: AkadPicker(
              icon: LucideIcons.clock,
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
              label: l.akademik2End,
              value: hhmm(s.end),
              onTap: () async {
                final m = await _pickTime(s.end);
                if (m != null && mounted) setState(() => s.end = m);
              },
            ),
          ),
        ]),
        const SizedBox(height: 14),
        AkadTextField(label: l.akademik2RoomShort, controller: s.room, maxLength: 60, hint: 'B-204', icon: LucideIcons.mapPin),
      ]),
    );
  }
}

/// Renk seçicide gösterilen tasarım paleti.
const _akadPalette = ['red', 'blue', 'green', 'orange', 'purple', 'teal'];
