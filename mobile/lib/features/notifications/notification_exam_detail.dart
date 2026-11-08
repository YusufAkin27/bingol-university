import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../academic/academic_api.dart';
import '../academic/academic_models.dart';
import '../../core/foreground_timer.dart';
import '../academic/reminders.dart';

/// Notification detail reads the current exam, so changed times/rooms never come from an old push.
class NotificationExamDetail extends StatefulWidget {
  const NotificationExamDetail(
      {super.key, required this.session, required this.examId});
  final Session session;
  final int examId;

  @override
  State<NotificationExamDetail> createState() => _NotificationExamDetailState();
}

class _NotificationExamDetailState extends State<NotificationExamDetail> with WidgetsBindingObserver, ForegroundTimer<NotificationExamDetail> {
  late Future<Exam?> _exam;

  /// Sınav hatırlatıcısı (yerel, "bir gün önce"): genel ayardır, sınav başına değil; etiket bunu dürüstçe söyler.
  bool? _alarm;

  Future<void> _loadAlarm() async {
    try {
      final s = await ReminderService.store.load();
      if (mounted) setState(() => _alarm = s.examDayBefore);
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  Future<void> _toggleAlarm() async {
    final on = _alarm;
    if (on == null) return;
    try {
      final cur = await ReminderService.store.load();
      final next = cur.copyWith(examDayBefore: !on);
      await ReminderService.store.save(next);
      if (mounted) setState(() => _alarm = !on);
      await ReminderService.sync(AcademicApi(widget.session), settings: next);
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  Future<Exam?> _load() async {
    final exams = await AcademicApi(widget.session).exams();
    for (final exam in exams) {
      if (exam.id == widget.examId) return exam;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _exam = _load();
    _loadAlarm();
    startForegroundTimer(const Duration(minutes: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    stopForegroundTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(BuIcons.graduationCap, color: t.ink),
            const SizedBox(width: 10),
            Expanded(
                child: Text(l.p17ExamDetail,
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                tooltip: l.commonClose,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(BuIcons.x)),
          ]),
          const SizedBox(height: 16),
          FutureBuilder<Exam?>(
            future: _exam,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Column(children: [
                  Text(l.p03NotifLoadFailed),
                  TextButton(
                      onPressed: () => setState(() => _exam = _load()),
                      child: Text(l.commonRetry)),
                ]);
              }
              final exam = snapshot.data;
              if (exam == null) return Text(l.acadExamsNoUpcoming);
              final countdown =
                  countdownTextL(l, exam.startsAt, DateTime.now());
              final duration = exam.endsAt?.difference(exam.startsAt).inMinutes;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (countdown != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: t.sf2,
                            border: Border.all(color: t.bd),
                            borderRadius: BorderRadius.circular(16)),
                        child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(BuIcons.alarmClock, color: t.ink),
                                const SizedBox(width: 12),
                                Flexible(
                                    child: Text(countdown,
                                        style: TextStyle(
                                            color: t.ink,
                                            fontWeight: FontWeight.w400))),
                              ]),
                              if (_alarm != null)
                                Semantics(
                                  button: true,
                                  toggled: _alarm,
                                  child: InkWell(
                                    key: const ValueKey('exam-alarm-toggle'),
                                    onTap: _toggleAlarm,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 44),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      decoration: BoxDecoration(
                                          color: t.sf,
                                          border: Border.all(color: t.bd),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                                _alarm!
                                                    ? BuIcons.bellRing
                                                    : BuIcons.bellOff,
                                                size: 18,
                                                color: t.ink),
                                            const SizedBox(width: 6),
                                            Flexible(
                                                child: Text(
                                                _alarm!
                                                    ? l.notifExamAlarmOn
                                                    : l.notifExamAlarmOff,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: t.ink,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w400))),
                                          ]),
                                    ),
                                  ),
                                ),
                            ]),
                      ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: t.sf2,
                          border: Border.all(color: t.bd),
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  Text(examTypeLabelL(l, exam.type),
                                      style: TextStyle(
                                          color: t.mut,
                                          fontWeight: FontWeight.w400)),
                                  if (duration != null && duration > 0)
                                    Text(
                                        l.bildirimShortMin(duration.toString()),
                                        style: TextStyle(color: t.mut)),
                                ]),
                            const SizedBox(height: 12),
                            if (exam.courseName?.isNotEmpty == true)
                              Text(exam.courseName!,
                                  style: TextStyle(color: t.mut)),
                            Text(exam.title,
                                style: TextStyle(
                                    color: t.ink,
                                    fontSize: 24,
                                    height: 1.2,
                                    fontWeight: FontWeight.w400)),
                            Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Divider(color: t.bd)),
                            Row(children: [
                              Icon(BuIcons.calendar,
                                  color: t.mut, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(fmtInstantL(l, exam.startsAt),
                                      style: TextStyle(
                                          color: t.ink,
                                          fontWeight: FontWeight.w400))),
                            ]),
                            if (exam.endsAt != null)
                              Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      start: 34, top: 4),
                                  child: Text(fmtInstantL(l, exam.endsAt!),
                                      style: TextStyle(color: t.mut))),
                          ]),
                    ),
                    if (exam.room?.isNotEmpty == true)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: t.sf2,
                            border: Border.all(color: t.bd),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          Icon(BuIcons.doorOpen, color: t.ink),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(exam.room!,
                                  style:
                                      Theme.of(context).textTheme.titleLarge)),
                        ]),
                      ),
                    if (exam.note?.isNotEmpty == true)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: t.sf2,
                            border: Border.all(color: t.bd),
                            borderRadius: BorderRadius.circular(16)),
                        child: Text(exam.note!,
                            style: Theme.of(context).textTheme.bodyLarge),
                      ),
                  ]);
            },
          ),
        ]),
      ),
    );
  }
}
