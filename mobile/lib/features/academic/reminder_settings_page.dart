import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'academic_api.dart';
import 'academic_widgets.dart';
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
    return AcademicScaffold(
      title: 'Hatırlatmalar',
      child: !_loaded
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32),
              children: [
                Text('Bildirimler cihazında zamanlanır; internet gerekmez. Ders programın veya sınavların değişince yenilenir.',
                    style: BuType.caption.copyWith(color: t.mut)),
                const SizedBox(height: 14),
                BuGroup(children: [
                  _switch('Ders hatırlatması', _s.classEnabled, (v) => _update(_s.copyWith(classEnabled: v))),
                ]),
                if (_s.classEnabled) ...[
                  const SizedBox(height: 14),
                  Text('Ders başlamadan önce', style: BuType.heading.copyWith(color: t.ink)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in ReminderSettings.leadOptions)
                      BuChip(label: m == 60 ? '1 saat' : '$m dk', selected: _s.classLeadMin == m, onTap: () => _update(_s.copyWith(classLeadMin: m))),
                  ]),
                ],
                const SizedBox(height: 18),
                Text('Sınav hatırlatmaları', style: BuType.heading.copyWith(color: t.ink)),
                const SizedBox(height: 8),
                BuGroup(children: [
                  _switch('1 gün önce', _s.examDayBefore, (v) => _update(_s.copyWith(examDayBefore: v))),
                  _switch('1 saat önce', _s.examHourBefore, (v) => _update(_s.copyWith(examHourBefore: v))),
                ]),
              ],
            ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    final t = context.bu;
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
        child: Row(children: [
          Expanded(child: Text(label, style: BuType.bodyStrong.copyWith(color: t.ink))),
          Switch(value: value, onChanged: onChanged),
        ]),
      ),
    );
  }
}
