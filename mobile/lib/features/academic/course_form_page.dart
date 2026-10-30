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

/// Ders ekle / düzenle (Stitch 44). Başarıda `true` ile kapanır (liste yenilenir).
/// Üstte ders bilgileri + renk, ardından oturum kartları (gün çipleri, saatler, derslik) ve not.
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
  final Set<int> _endErrors = {}; // bitişi başlangıçtan önce olan oturumlar
  bool _selfConflict = false;

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

  /// Çakışma diyaloğu: başlık, giriş metni, çakışan ders kartları; `true` = "Yine de kaydet".
  Future<bool> _conflictDialog({List<CourseConflict> conflicts = const [], bool own = false, String? serverMessage}) async {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final r = await BuDialog.show<bool>(
      context,
      builder: (ctx) => BuDialog(
        title: l.acadTimeConflictTitle,
        icon: LucideIcons.triangleAlert,
        message: serverMessage ?? l.p17ConflictIntro,
        content: serverMessage != null
            ? null
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final c in conflicts.take(3))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.course.name, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(LucideIcons.clock, size: 14, color: t.mut),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text('${acadDayShort(l, c.session.dayOfWeek.clamp(1, 7))} ${c.session.start}-${c.session.end}',
                                style: tx.bodySmall!.copyWith(color: t.mut))),
                      ]),
                      if (c.session.room != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(children: [
                            Icon(LucideIcons.mapPin, size: 14, color: t.mut),
                            const SizedBox(width: 6),
                            Expanded(child: Text(c.session.room!, style: tx.bodySmall!.copyWith(color: t.mut))),
                          ]),
                        ),
                    ]),
                  ),
                if (own) Text(l.acadTimeOwnConflict, style: tx.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: t.danger)),
              ]),
        actions: [
          BuDialogAction(label: l.acadCancel, onPressed: () => Navigator.pop(ctx, false)),
          BuDialogAction(label: l.acadTimeSaveAnyway, kind: BuDialogActionKind.primary, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _save({bool force = false}) async {
    final l = context.l10n;
    final name = _name.text.trim();
    final sessions = [for (final s in _sessions) s.toSession()];
    final bad = <int>{for (var i = 0; i < sessions.length; i++) if (sessions[i].endMin <= sessions[i].startMin) i};
    setState(() {
      _nameError = name.isEmpty ? l.acadTimeNameRequired : null;
      _endErrors
        ..clear()
        ..addAll(bad);
      _selfConflict = false;
    });
    if (name.isEmpty || bad.isNotEmpty) return;
    if (!force) {
      final conflicts = findConflicts(widget.allCourses, sessions, excludeCourseId: widget.course?.id);
      final own = selfConflicts(sessions);
      if (conflicts.isNotEmpty || own.isNotEmpty) {
        if (own.isNotEmpty) setState(() => _selfConflict = true);
        final go = await _conflictDialog(conflicts: conflicts, own: own.isNotEmpty);
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
        final go = await _conflictDialog(serverMessage: e.message);
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
    return AcademicScaffold(
      title: _editing ? l.acadTimeEditCourse : l.acadTimeNewCourse,
      actions: [
        if (_editing) BuIconButton(icon: LucideIcons.trash2, tooltip: l.acadTimeDeleteCourse, onTap: _busy ? null : _delete),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AkadCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
              const SizedBox(height: 16),
              AkadTextField(
                  label: l.acadTimeCourseCode, controller: _code, maxLength: 20, capitalization: TextCapitalization.characters, hint: 'BIL201', icon: LucideIcons.hash),
              const SizedBox(height: 16),
              AkadTextField(
                label: l.acadTimeInstructor,
                controller: _instructor,
                maxLength: 120,
                capitalization: TextCapitalization.words,
                hint: l.acadTimeInstructorHint,
                icon: LucideIcons.idCard,
              ),
              const SizedBox(height: 16),
              AkadFieldLabel(l.acadTimeColor,
                  trailing: _color == null
                      ? null
                      : Text(l.p17ColorSelected(acadColorName(l, _color!)),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.pr))),
              Row(children: [for (final k in courseColorKeys) Expanded(child: _swatch(t, k))]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(LucideIcons.info, size: 14, color: t.mut),
                const SizedBox(width: 6),
                Expanded(child: Text(l.acadTimeColorAuto, style: tx.bodySmall!.copyWith(color: t.mut))),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: AkadTitle(l.acadTimeDaysAndTimes)),
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
          if (_selfConflict)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                liveRegion: true,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.circleAlert, size: 16, color: t.danger)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.acadTimeOwnConflict, style: tx.bodySmall!.copyWith(color: t.danger))),
                ]),
              ),
            ),
          if (_sessions.length < 12) ...[
            const SizedBox(height: 12),
            Semantics(
              button: true,
              container: true,
              child: AkadCard(
                onTap: () => setState(() {
                  final last = _sessions.last;
                  _sessions.add(_SessionDraft(day: last.day % 7 + 1, start: last.start, end: last.end));
                }),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(LucideIcons.circlePlus, size: 20, color: t.mut),
                  const SizedBox(width: 8),
                  Flexible(child: Text(l.acadTimeAddSession, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.mut))),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 20),
          AkadCard(
            padding: const EdgeInsets.all(16),
            child: AkadTextField(
              label: l.acadTimeNote,
              controller: _note,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              capitalization: TextCapitalization.sentences,
              hint: l.acadTimeNoteHint,
              icon: LucideIcons.textAlignStart,
            ),
          ),
          const SizedBox(height: 24),
          BuButton(
            label: _editing ? l.acadTimeSave : l.acadTimeAddCourseBtn,
            icon: LucideIcons.circleCheck,
            busy: _busy,
            onPressed: _busy ? null : () => _save(),
          ),
        ],
      ),
    );
  }

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
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: sel ? t.ink : Colors.transparent, width: 2),
                ),
                child: AnimatedScale(
                  scale: sel ? 1 : 0,
                  duration: BuMotion.of(context, BuMotion.short),
                  child: Icon(LucideIcons.check, size: 15, color: t.onMedia),
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
    final endBad = _endErrors.contains(i);
    return AkadCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(l.acadTimeSessionN((i + 1).toString()), style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
          if (_sessions.length > 1)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: t.danger, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () => setState(() {
                _sessions.removeAt(i).room.dispose();
                _endErrors.clear();
              }),
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: Text(l.acadTimeRemoveSession, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.danger)),
            ),
        ]),
        const SizedBox(height: 12),
        AkadFieldLabel(l.p17WeekDay),
        Row(children: [
          for (var d = 1; d <= 7; d++)
            Expanded(
              child: AkadChip(
                label: acadDayShort(l, d),
                semanticLabel: acadDayName(l, d),
                selected: s.day == d,
                expand: true,
                onTap: () => setState(() => s.day = d),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: AkadPicker(
              icon: LucideIcons.clock,
              leading: LucideIcons.clock,
              bold: true,
              compact: true,
              label: l.acadTimeStartTime,
              value: hhmm(s.start),
              onTap: () async {
                final m = await _pickTime(s.start);
                if (m != null && mounted) {
                  setState(() {
                    final len = s.end - s.start;
                    s.start = m;
                    if (s.end <= m) s.end = (m + (len > 0 ? len : 50)).clamp(0, 23 * 60 + 59);
                    _endErrors.remove(i);
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AkadPicker(
              icon: LucideIcons.clock,
              leading: LucideIcons.clock,
              bold: true,
              compact: true,
              error: endBad,
              label: l.acadTimeEndTime,
              value: hhmm(s.end),
              onTap: () async {
                final m = await _pickTime(s.end);
                if (m != null && mounted) {
                  setState(() {
                    s.end = m;
                    _endErrors.remove(i);
                  });
                }
              },
            ),
          ),
        ]),
        if (endBad)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.circleAlert, size: 14, color: t.danger)),
                const SizedBox(width: 6),
                Expanded(child: Text(l.acadTimeEndAfterStart, style: tx.bodySmall!.copyWith(color: t.danger))),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        AkadTextField(label: l.acadFormRoom, controller: s.room, maxLength: 60, hint: l.acadTimeRoomHint, icon: LucideIcons.doorOpen),
      ]),
    );
  }
}
