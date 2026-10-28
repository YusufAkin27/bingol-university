import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import 'academic_api.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'reminders.dart';

/// Ayarlar > Hatırlatmalar: ders ve sınav yerel bildirimleri.
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key, required this.session});

  final Session session;

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  ReminderSettings _s = const ReminderSettings();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    ReminderService.store.load().then((v) {
      if (mounted) {
        setState(() {
          _s = v;
          _loaded = true;
        });
      }
    });
  }

  void _update(ReminderSettings s) {
    setState(() => _s = s);
    ReminderService.store.save(s);
    unawaited(ReminderService.sync(AcademicApi(widget.session), settings: s));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return AcademicScaffold(
      title: l.acadTimeRemindersTitle,
      child: !_loaded
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, end: 6),
                  child: Text(l.acadTimeRemindersIntro, style: BuType.body.copyWith(fontSize: 13, height: 1.5, color: t.mut)),
                ),
                const SizedBox(height: 16),
                AkadCard(
                  padding: EdgeInsets.zero,
                  child: AkadSwitchRow(
                    title: l.acadTimeClassReminder,
                    subtitle: l.akademik2RemindEach,
                    value: _s.classEnabled,
                    onChanged: (v) => _update(_s.copyWith(classEnabled: v)),
                  ),
                ),
                if (_s.classEnabled) ...[
                  const SizedBox(height: 16),
                  AkadSection(l.akademik2BeforeClassShort),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in ReminderSettings.leadOptions)
                      AkadChip(
                        label: m == 60 ? l.acadTimeOneHour : l.acadTimeMinutes(m.toString()),
                        selected: _s.classLeadMin == m,
                        onTap: () => _update(_s.copyWith(classLeadMin: m)),
                      ),
                  ]),
                ],
                const SizedBox(height: 16),
                AkadSection(l.acadTimeExamReminders),
                AkadCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    AkadSwitchRow(title: l.acadTimeDayBefore, value: _s.examDayBefore, onChanged: (v) => _update(_s.copyWith(examDayBefore: v))),
                    const AkadDivider(),
                    AkadSwitchRow(title: l.acadTimeHourBefore, value: _s.examHourBefore, onChanged: (v) => _update(_s.copyWith(examHourBefore: v))),
                  ]),
                ),
              ],
            ),
    );
  }
}
