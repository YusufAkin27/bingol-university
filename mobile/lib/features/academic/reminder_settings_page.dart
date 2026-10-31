import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'academic_api.dart';
import 'academic_widgets.dart';
import 'akad_widgets.dart';
import 'reminders.dart';

/// Hatırlatmalar (Stitch 45): ders ve sınav yerel bildirimleri. Bildirim izni yoksa uyarı kartı ve pasif anahtarlar.
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_permOk) _introCard(t, tx, l) else ...[_permCard(t, tx, l), const SizedBox(height: 14), _plainIntro(t, tx, l)],
                const SizedBox(height: 22),
                IgnorePointer(
                  ignoring: !_permOk,
                  child: Opacity(
                    opacity: _permOk ? 1 : .55,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _sectionTitle(t, tx, LucideIcons.graduationCap, l.acadTimeClassReminder),
                      const SizedBox(height: 12),
                      _classCard(t, tx, l),
                      const SizedBox(height: 22),
                      _sectionTitle(t, tx, LucideIcons.clipboardList, l.acadTimeExamReminders),
                      const SizedBox(height: 12),
                      _examCard(t, tx, l),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(BuTokens t, TextTheme tx, IconData icon, String text) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Semantics(
          header: true,
          child: Row(children: [
            Icon(icon, size: 22, color: t.pr),
            const SizedBox(width: 10),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
          ]),
        ),
      );

  /// Pembe bilgi kartı: simge karosu + açıklama, köşede yarı saydam daire.
  Widget _introCard(BuTokens t, TextTheme tx, AppLocalizations l) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bLg),
        child: Stack(children: [
          PositionedDirectional(
            end: -30,
            bottom: -40,
            child: ExcludeSemantics(child: Container(width: 120, height: 120, decoration: BoxDecoration(color: t.pr.withValues(alpha: .08), shape: BoxShape.circle))),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AkadIconTile(icon: LucideIcons.bellRing, bg: t.pr, fg: t.onPr, size: 56, radius: 16, iconSize: 26),
              const SizedBox(width: 14),
              Expanded(child: Text(l.acadTimeRemindersIntro, style: tx.bodyMedium!.copyWith(color: t.onSoft, height: 1.5))),
            ]),
          ),
        ]),
      );

  /// İzin yokken beyaz bilgi satırı.
  Widget _plainIntro(BuTokens t, TextTheme tx, AppLocalizations l) => AkadCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          AkadIconTile(icon: LucideIcons.circleCheck, bg: t.sf2, fg: t.ink, size: 44, radius: 22, iconSize: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(l.acadTimeRemindersIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5))),
        ]),
      );

  /// Bildirim izni verilmedi: kehribar kart + "Ayarlardan aç".
  Widget _permCard(BuTokens t, TextTheme tx, AppLocalizations l) => Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.warnSoft, borderRadius: BuRadius.bLg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: t.sf.withValues(alpha: .6), shape: BoxShape.circle),
                child: ExcludeSemantics(child: Icon(LucideIcons.triangleAlert, size: 24, color: t.onWarnSoft)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.p20RemPermTitle, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.onWarnSoft)),
                  const SizedBox(height: 4),
                  Text(l.p20RemPermBody, style: tx.bodyMedium!.copyWith(color: t.onWarnSoft)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            BuButton(
              label: l.p20RemOpenSettings,
              icon: LucideIcons.settings,
              onPressed: () async {
                await PermissionService.instance.openSettings();
                unawaited(_checkPermission());
              },
            ),
          ]),
        ),
      );

  Widget _classCard(BuTokens t, TextTheme tx, AppLocalizations l) {
    final opts = ReminderSettings.leadOptions.where((m) => m != 5 || _s.classLeadMin == 5).toList();
    return AkadCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AkadSwitchRow(
          title: l.acadTimeClassReminder,
          subtitle: l.akademik2RemindEach,
          value: _permOk && _s.classEnabled,
          onChanged: (v) => _update(_s.copyWith(classEnabled: v)),
        ),
        if (_s.classEnabled || !_permOk)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(LucideIcons.clock, size: 16, color: t.mut),
                const SizedBox(width: 8),
                Expanded(child: Text('${l.acadTimeBeforeClass}:', style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.mut))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                for (var i = 0; i < opts.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 8),
                      child: _leadChip(t, tx, l, opts[i]),
                    ),
                  ),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _leadChip(BuTokens t, TextTheme tx, AppLocalizations l, int m) {
    final sel = _s.classLeadMin == m;
    final label = m == 60 ? l.acadTimeOneHour : l.acadTimeMinutes(m.toString());
    return Semantics(
      button: true,
      selected: sel,
      label: label,
      excludeSemantics: true,
      onTap: () => _update(_s.copyWith(classLeadMin: m)),
      child: BuPressable(
        scale: .95,
        onTap: () => _update(_s.copyWith(classLeadMin: m)),
        haptic: BuHaptic.selection,
        child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          decoration: ShapeDecoration(color: sel ? t.soft : t.sf2, shape: StadiumBorder(side: sel ? BorderSide(color: t.selectedBorder) : BorderSide.none)),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: sel ? t.onSoft : t.ink))),
          ),
        ),
      ),
    );
  }

  Widget _examCard(BuTokens t, TextTheme tx, AppLocalizations l) => AkadCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          _examRow(t, LucideIcons.calendar, l.acadTimeDayBefore, l.p20RemDaySub, _permOk && _s.examDayBefore, (v) => _update(_s.copyWith(examDayBefore: v))),
          const AkadDivider(),
          _examRow(t, LucideIcons.timer, l.acadTimeHourBefore, l.p20RemHourSub, _permOk && _s.examHourBefore, (v) => _update(_s.copyWith(examHourBefore: v))),
        ]),
      );

  Widget _examRow(BuTokens t, IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) => MergeSemantics(
        child: InkWell(
          onTap: () {
            buHaptic(BuHaptic.selection);
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 8, top: 8, bottom: 8),
            child: Row(children: [
              AkadIconTile(icon: icon, bg: t.sf2, fg: t.ink, size: 40, radius: 20, iconSize: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                  Text(sub, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut)),
                ]),
              ),
              Switch(value: value, onChanged: onChanged),
            ]),
          ),
        ),
      );
}
