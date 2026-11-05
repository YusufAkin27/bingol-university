import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/notify/local_reminders.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/platform/device_alarm.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'acad_ref_widgets.dart';
import 'academic_models.dart';
import 'alarm_planner.dart';
import 'alarm_service.dart';
import 'reminders.dart';

/// Sınavlar ve Ders programı sayfalarının "alarm kur" eylemi ve önizleme alt sayfaları.
/// Android: Saat uygulamasına alarm; iOS: Saat'e alarm eklenemediği için bildirim (etiketler ona göre değişir).

/// Kartsız eylem satırı: soldaki simge, başlık (+ isteğe bağlı alt satır), sağda ok. Dokunma alanı >= 56 dp.
class AcadActionRow extends StatelessWidget {
  const AcadActionRow({super.key, required this.icon, required this.title, this.sub, required this.onTap, this.trailing});

  final IconData icon;
  final String title;
  final String? sub;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return AcadRow(
      minHeight: 60,
      rule: false,
      semanticLabel: sub == null ? title : '$title. $sub',
      onTap: onTap,
      child: Row(children: [
        ExcludeSemantics(child: Icon(icon, size: 20, color: t.ink)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: t.ink)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        const SizedBox(width: 8),
        ExcludeSemantics(child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 18, color: t.mut)),
      ]),
    );
  }
}

/// Önizleme satırı: başlık + alt satırlar, sağda anahtar (tek tek kapatılabilir).
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.title, required this.lines, required this.value, required this.onChanged});

  final String title;
  final List<String> lines;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return MergeSemantics(
      child: InkWell(
        onTap: () {
          buHaptic(BuHaptic.selection);
          onChanged(!value);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(
                child: Opacity(
                  opacity: value ? 1 : .55,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: t.ink)),
                    for (final s in lines) ...[
                      const SizedBox(height: 2),
                      Text(s, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(width: 16),
              Transform.scale(scale: .92, child: Switch(value: value, onChanged: onChanged)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Önizleme alt sayfasının ortak iskeleti: satırlar + notlar + eylem düğmesi; uygulandıktan sonra sonuç satırları.
class _PlanSheetBody extends StatelessWidget {
  const _PlanSheetBody({required this.rows, required this.notes, required this.actionLabel, required this.onAction, required this.busy, required this.result, required this.empty, this.warn});

  final List<Widget> rows;
  final List<String> notes;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool busy;
  final List<String>? result;
  final String? empty;
  final String? warn;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final res = result;
    if (res != null) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final s in res) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(s, style: tx.bodyLarge!.copyWith(color: t.ink, height: 1.4))),
        const SizedBox(height: 8),
        BuButton(label: l.commonClose, onPressed: () => Navigator.of(context).pop(true)),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (empty != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(empty!, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut))),
      for (var i = 0; i < rows.length; i++) ...[rows[i], if (i < rows.length - 1) const AcadRule()],
      const SizedBox(height: 12),
      for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(n, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut, height: 1.4))),
      if (warn != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: AcadAmberNote(text: warn!)),
      const SizedBox(height: 8),
      if (empty == null) BuButton(label: actionLabel, busy: busy, onPressed: onAction),
      TextButton(
        onPressed: busy ? null : () => Navigator.of(context).pop(false),
        style: TextButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size.fromHeight(48)),
        child: Text(empty != null ? l.commonClose : l.commonCancel, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
      ),
    ]);
  }
}

/// iOS yedeğinde bildirim izni gerekir: yoksa ortak izin akışı (gerekçe + sistem istemi + Ayarlar yolu).
Future<bool> _ensureNotifications(BuildContext context) async {
  final allowed = await LocalReminders.instance.backend.notificationsAllowed();
  if (allowed || !context.mounted) return allowed;
  return ensurePermission(context, AppPermission.notifications);
}

String _alarmTime(ExamAlarm a, AppLocalizations l) {
  final t = hhmm(a.hour * 60 + a.minute);
  if (a.alarmDay == a.examDay) return t;
  return '$t (${a.alarmDay.day} ${monthNameL(l, a.alarmDay.month)})';
}

// ---------------------------------------------------------------------------------------------------------- sınav

/// "İlk sınav alarmlarını kur" önizleme alt sayfası. Kurulum yapıldıysa true döner.
Future<bool?> showExamAlarmSheet(BuildContext context, {required List<Exam> exams, AlarmService? service}) {
  final l = context.l10n;
  final clock = DeviceAlarmService.instance.usesClockApp;
  return BuSheet.show<bool>(
    context,
    title: clock ? l.alarmExamSheetTitle : l.alarmExamSheetTitleIos,
    subtitle: l.alarmExamSheetSub,
    builder: (_) => ExamAlarmSheetBody(exams: exams, service: service ?? AlarmService.instance),
  );
}

class ExamAlarmSheetBody extends StatefulWidget {
  const ExamAlarmSheetBody({super.key, required this.exams, required this.service});

  final List<Exam> exams;
  final AlarmService service;

  @override
  State<ExamAlarmSheetBody> createState() => _ExamAlarmSheetBodyState();
}

class _ExamAlarmSheetBodyState extends State<ExamAlarmSheetBody> {
  late final List<ExamAlarm> _plans = planExamAlarms(widget.exams, academicClock());
  late final Set<String> _on = {for (final p in _plans) p.key};
  bool _busy = false;
  List<String>? _result;

  bool get _clock => DeviceAlarmService.instance.usesClockApp;

  Future<void> _apply() async {
    final l = context.l10n;
    setState(() => _busy = true);
    if (_clock) {
      if (!await DeviceAlarmService.instance.isAvailable()) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _result = [l.alarmUnavailable];
        });
        return;
      }
    } else if (!await _ensureNotifications(context)) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    final out = await widget.service.applyExams([for (final p in _plans) if (_on.contains(p.key)) p], l);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = [
        if (out.set.isNotEmpty) _clock ? l.alarmDoneSet(out.set.length.toString()) : l.alarmDoneNotif(out.set.length.toString()),
        if (out.deferred.isNotEmpty) l.alarmDoneDeferred(out.deferred.length.toString()),
        if (out.failed.isNotEmpty) l.alarmDoneFail(out.failed.length.toString()),
        _clock ? l.alarmClockNote : l.alarmIosNote,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = academicClock();
    final selected = _plans.where((p) => _on.contains(p.key)).toList();
    final deferred = _clock ? _plans.where((p) => !p.canSetInClockNow(now)).length : 0;
    return _PlanSheetBody(
      empty: _plans.isEmpty ? l.alarmExamNone : null,
      rows: [
        for (final p in _plans)
          _PlanRow(
            title: p.exam.title,
            value: _on.contains(p.key),
            onChanged: (v) => setState(() => v ? _on.add(p.key) : _on.remove(p.key)),
            lines: [
              acadLongDate(context, p.examDay),
              l.alarmExamRow(hhmm(istanbulWall(p.exam.startsAt).hour * 60 + istanbulWall(p.exam.startsAt).minute), _alarmTime(p, l)),
              if (p.skipped.isNotEmpty)
                l.alarmExamSkipped(p.skipped.map((e) => hhmm(istanbulWall(e.startsAt).hour * 60 + istanbulWall(e.startsAt).minute)).join(', ')),
              if (_clock && !p.canSetInClockNow(now)) l.alarmExamDeferredRow,
            ],
          ),
      ],
      notes: [
        if (deferred > 0) l.alarmExamDeferred(deferred.toString()),
        _clock ? l.alarmClockNote : l.alarmIosNote,
      ],
      actionLabel: _clock ? l.alarmSetCount(selected.length.toString()) : l.alarmNotifyCount(selected.length.toString()),
      onAction: selected.isEmpty ? null : _apply,
      busy: _busy,
      result: _result,
    );
  }
}

// ------------------------------------------------------------------------------------------------------------ ders

/// "Sabah alarmlarını kur" önizleme alt sayfası. Kurulum yapıldıysa true döner.
Future<bool?> showClassAlarmSheet(BuildContext context, {required List<Course> courses, Semester? semester, AlarmService? service}) {
  final l = context.l10n;
  final clock = DeviceAlarmService.instance.usesClockApp;
  return BuSheet.show<bool>(
    context,
    title: clock ? l.alarmClassSheetTitle : l.alarmClassSheetTitleIos,
    subtitle: l.alarmClassSheetSub,
    builder: (_) => ClassAlarmSheetBody(courses: courses, semester: semester, service: service ?? AlarmService.instance),
  );
}

class ClassAlarmSheetBody extends StatefulWidget {
  const ClassAlarmSheetBody({super.key, required this.courses, required this.semester, required this.service});

  final List<Course> courses;
  final Semester? semester;
  final AlarmService service;

  @override
  State<ClassAlarmSheetBody> createState() => _ClassAlarmSheetBodyState();
}

class _ClassAlarmSheetBodyState extends State<ClassAlarmSheetBody> {
  late final List<ClassAlarmDay> _days = planClassAlarmDays(widget.courses, semester: widget.semester, now: academicClock());
  late final Set<int> _on = {for (final d in _days) d.classWeekday};
  DateTime? _previous;
  bool _confirmedRepeat = false;
  bool _busy = false;
  List<String>? _result;

  bool get _clock => DeviceAlarmService.instance.usesClockApp;

  List<ClassAlarm> get _plans => groupClassAlarms([for (final d in _days) if (_on.contains(d.classWeekday)) d]);

  @override
  void initState() {
    super.initState();
    _refreshPrevious();
  }

  Future<void> _refreshPrevious() async {
    final p = await widget.service.previousClassSetup(_plans);
    if (mounted) setState(() => _previous = p);
  }

  Future<void> _apply() async {
    final l = context.l10n;
    // Aynı alarmlar daha önce kurulduysa Saat'te çift alarm olmasın diye ilk dokunuş uyarır, ikincisi kurar.
    if (_previous != null && !_confirmedRepeat) {
      setState(() => _confirmedRepeat = true);
      return;
    }
    setState(() => _busy = true);
    if (_clock) {
      if (!await DeviceAlarmService.instance.isAvailable()) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _result = [l.alarmUnavailable];
        });
        return;
      }
    } else if (!await _ensureNotifications(context)) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    final out = await widget.service.applyClasses(_plans, l);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = [
        if (out.set.isNotEmpty) _clock ? l.alarmDoneClassSet(out.set.length.toString()) : l.alarmDoneNotif(out.set.length.toString()),
        if (out.failed.isNotEmpty) l.alarmDoneFail(out.failed.length.toString()),
        _clock ? l.alarmClockNote : l.alarmIosNote,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plans = _plans;
    final alarmCount = plans.length;
    final morningDays = {for (final d in _days) d.classWeekday};
    final skippedDays = [
      for (var d = 1; d <= 7; d++)
        if (!morningDays.contains(d) && widget.courses.any((c) => c.sessions.any((s) => s.dayOfWeek == d))) acadDayName(l, d)
    ];
    return _PlanSheetBody(
      empty: _days.isEmpty ? l.alarmClassNone : null,
      rows: [
        for (final d in _days)
          _PlanRow(
            title: '${acadDayName(l, d.classWeekday)} · ${d.course.name}',
            value: _on.contains(d.classWeekday),
            onChanged: (v) {
              setState(() => v ? _on.add(d.classWeekday) : _on.remove(d.classWeekday));
              _confirmedRepeat = false;
              _refreshPrevious();
            },
            lines: [
              l.alarmClassRow(d.session.start, hhmm(d.alarmMin)),
            ],
          ),
      ],
      notes: [
        if (skippedDays.isNotEmpty) l.alarmClassSkipped(skippedDays.join(', ')),
        _clock ? l.alarmClockNote : l.alarmIosNote,
      ],
      warn: _previous != null && _confirmedRepeat ? l.alarmRepeatWarn(acadDate(context, istanbulWall(_previous!))) : null,
      actionLabel: _previous != null && _confirmedRepeat
          ? l.alarmSetAnyway
          : (_clock ? l.alarmSetCount(alarmCount.toString()) : l.alarmNotifyCount(alarmCount.toString())),
      onAction: alarmCount == 0 ? null : _apply,
      busy: _busy,
      result: _result,
    );
  }
}
