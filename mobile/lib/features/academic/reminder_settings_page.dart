import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../profile/notification_prefs_page.dart';
import 'academic_api.dart';
import 'academic_widgets.dart';
import 'acad_ref_widgets.dart';
import 'akad_widgets.dart';
import 'reminders.dart';

/// Hatırlatmalar (Stitch 45): ders ve sınav yerel bildirimleri. Bildirim izni yoksa uyarı kartı ve pasif anahtarlar.
/// Sınavdan 2 saat önceki bildirim sunucudan gelen gerçek push'tur (yerel değil): satır yalnız bilgilendirir ve
/// Profil > Bildirim tercihleri'ne (Akademik duyurular) götürür; yeni uç/istek yoktur.
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key, required this.session});

  final Session session;

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> with WidgetsBindingObserver {
  ReminderSettings _s = const ReminderSettings();
  bool _loaded = false;
  bool _permOk = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReminderService.store.load().then((v) {
      if (mounted) {
        setState(() {
          _s = v;
          _loaded = true;
        });
      }
    });
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ayarlardan dönünce izin durumunu yeniden okur.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final st = await PermissionService.instance.status(AppPermission.notifications);
    if (mounted) setState(() => _permOk = st.usable);
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
    final tx = Theme.of(context).textTheme;
    return AcademicScaffold(
      title: l.acadTimeRemindersTitle,
      child: !_loaded
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                if (!_permOk) ...[
                  AcadAmberNote(
                    text: l.p69PermOff,
                    actionLabel: l.p20RemOpenSettings,
                    onAction: () async {
                      await PermissionService.instance.openSettings();
                      unawaited(_checkPermission());
                    },
                  ),
                  const SizedBox(height: 40),
                ] else
                  const SizedBox(height: 8),
                _sectionTitle(t, tx, l.acadExamsTitle),
                const SizedBox(height: 4),
                IgnorePointer(
                  ignoring: !_permOk,
                  child: Opacity(
                    opacity: _permOk ? 1 : .55,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _SwitchRow(title: l.p69ExamReminder, sub: l.p69ExamReminderSub, value: _permOk && _s.examDayBefore, onChanged: _permOk ? (v) => _update(_s.copyWith(examDayBefore: v)) : null),
                      _serverPushRow(t, tx, l),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                const AcadRule(),
                const SizedBox(height: 22),
                _sectionTitle(t, tx, l.p69Classes),
                const SizedBox(height: 4),
                IgnorePointer(
                  ignoring: !_permOk,
                  child: Opacity(
                    opacity: _permOk ? 1 : .55,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _SwitchRow(
                        title: l.acadTimeClassReminder,
                        sub: l.p69ClassReminderSub(_s.classLeadMin.toString()),
                        value: _permOk && _s.classEnabled,
                        onChanged: _permOk ? (v) => _update(_s.copyWith(classEnabled: v)) : null,
                      ),
                      if (_s.classEnabled || !_permOk) ...[
                        const SizedBox(height: 20),
                        Semantics(header: true, child: Text(l.p69Duration, style: tx.bodyMedium!.copyWith(color: t.ink))),
                        const SizedBox(height: 3),
                        _leadChips(l),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                const AcadRule(),
                const SizedBox(height: 25),
                Text(l.p69RemindersFooter, style: tx.bodyMedium!.copyWith(color: t.mut)),
              ],
            ),
    );
  }

  Widget _sectionTitle(BuTokens t, TextTheme tx, String text) => Semantics(
        header: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
        ),
      );

  /// Ders hatırlatma süresi çipleri: 5 / 15 / 30 dk (+ kayıtlı değer bunların dışındaysa o da, seçili görünsün).
  Widget _leadChips(AppLocalizations l) {
    final opts = {5, 15, 30, _s.classLeadMin}.toList()..sort();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(spacing: 8, children: [
        for (final m in opts)
          AkadChip(
            label: m == 60 ? l.acadTimeOneHour : l.acadTimeMinutes(m.toString()),
            selected: _s.classLeadMin == m,
            radius: 8,
            onTap: _permOk ? () => _update(_s.copyWith(classLeadMin: m)) : null,
          ),
      ]),
    );
  }

  /// "Sınavdan 2 saat önce (bildirim)": sunucu push'u; yerel anahtar değil, akademik bildirim tercihine gider.
  Widget _serverPushRow(BuTokens t, TextTheme tx, AppLocalizations l) => AcadRow(
        rule: false,
        minHeight: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        semanticLabel: '${l.acadTimeHourBefore}. ${l.p20RemHourSub}',
        onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => NotificationPrefsPage(session: widget.session))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(l.acadTimeHourBefore, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink)),
              const SizedBox(height: 2),
              Text(l.p20RemHourSub, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
            ]),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut)),
        ]),
      );
}

/// Anahtar satırı (kartsız, ikonsuz): başlık 16 sp + muted açıklama, sağda anahtar (48 dp genişlik); tüm satır dokunulur.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.sub, required this.value, required this.onChanged});

  final String title, sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null
            ? null
            : () {
                buHaptic(BuHaptic.selection);
                onChanged!(!value);
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink)),
                  const SizedBox(height: 2),
                  Text(sub, style: tx.bodySmall!.copyWith(fontSize: 13, color: t.mut)),
                ]),
              ),
              const SizedBox(width: 24),
              Transform.translate(
                offset: Offset(Directionality.of(context) == TextDirection.rtl ? -4 : 4, 0),
                child: Transform.scale(scale: .92, alignment: AlignmentDirectional.centerEnd, child: Switch(value: value, onChanged: onChanged)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
