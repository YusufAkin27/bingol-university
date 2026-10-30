import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/push/push_health.dart';
import '../../core/push/push_registrar.dart';
import '../../widgets/bu.dart';
import '../academic/academic_widgets.dart';
import '../academic/akad_widgets.dart';

/// "Bildirimler çalışmıyor mu?" (P2): izin, kanal, cihaz kaydı ve pil/otomatik başlatma kontrol listesi.
/// Her satır ölçülebilir bir durumu gösterir; düzeltilebilenlerin eylemi vardır. Ayarlardan dönünce kendini yeniler.
class PushHelpPage extends StatefulWidget {
  const PushHelpPage({super.key, required this.source});

  final PushHealthSource source;

  @override
  State<PushHelpPage> createState() => _PushHelpPageState();
}

class _PushHelpPageState extends State<PushHelpPage> with WidgetsBindingObserver {
  PushHealth? _h;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Sistem ayarından dönünce durum tazelenir (izin/kanal açılmış olabilir); kayıt da yenilenir.
    if (s == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final h = await widget.source.read();
    if (mounted) setState(() => _h = h);
  }

  Future<void> _reregister() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.source.reregister();
    } catch (_) {}
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final h = _h;
    return AcademicScaffold(
      title: l.p21HelpTitle,
      child: h == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _banner(h),
                const SizedBox(height: 16),
                _row(
                  ok: h.osAllowed,
                  title: l.p21HelpPermTitle,
                  body: h.osAllowed ? l.p21HelpPermOk : l.p21HelpPermOff,
                  action: h.osAllowed ? null : (l.p20RemOpenSettings, widget.source.openNotificationSettings),
                ),
                if (h.blockedChannels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _row(
                    ok: false,
                    title: l.p21HelpChanTitle,
                    body: h.chatBlocked ? l.p21HelpChanChat : l.p21HelpChanOther,
                    action: (l.p20RemOpenSettings, widget.source.openNotificationSettings),
                  ),
                ],
                const SizedBox(height: 12),
                _row(
                  ok: h.supported && h.registration == PushRegState.registered,
                  title: l.p21HelpDeviceTitle,
                  body: !h.supported
                      ? l.p21HelpDeviceUnsupported
                      : h.registration == PushRegState.registered
                          ? l.p21HelpDeviceOk
                          : l.p21HelpDeviceBad,
                  action: !h.supported || !h.osAllowed || h.registration == PushRegState.registered ? null : (l.p21HelpDeviceRetry, _reregister),
                  busy: _busy,
                ),
                if (h.isAndroid) ...[
                  const SizedBox(height: 12),
                  _row(
                    ok: null,
                    title: l.p21HelpBatteryTitle,
                    body: h.aggressiveOem ? l.p21HelpBatteryOem : l.p21HelpBatteryGeneric,
                    action: (l.p21HelpBatteryOpen, widget.source.openBatterySettings),
                  ),
                ],
                const SizedBox(height: 16),
                Text(l.p21HelpFooter, style: tx.bodySmall!.copyWith(color: t.mut)),
              ],
            ),
    );
  }

  /// Üstte tek satırlık özet.
  Widget _banner(PushHealth h) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final good = h.allGood;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: good ? t.okSoft : t.warnSoft, borderRadius: BuRadius.bLg),
      child: Row(children: [
        Icon(good ? LucideIcons.circleCheck : LucideIcons.triangleAlert, size: 26, color: good ? t.ok : t.onWarnSoft),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            good ? l.p21HelpAllGood : l.p21HelpSomeIssue,
            style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: good ? t.ink : t.onWarnSoft),
          ),
        ),
      ]),
    );
  }

  /// [ok]: true tamam, false sorun, null bilgi (ölçülemeyen ipucu).
  Widget _row({required bool? ok, required String title, required String body, (String, FutureOr<Object?> Function())? action, bool busy = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final icon = ok == null ? LucideIcons.info : (ok ? LucideIcons.circleCheck : LucideIcons.circleAlert);
    final color = ok == null ? t.mut : (ok ? t.ok : t.pr);
    return AkadCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
              const SizedBox(height: 4),
              Text(body, style: tx.bodyMedium!.copyWith(color: t.mut)),
            ]),
          ),
        ]),
        if (action != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BuButton(
              label: action.$1,
              kind: ok == false ? BuButtonKind.primary : BuButtonKind.outline,
              compact: true,
              busy: busy,
              onPressed: () async {
                await action.$2();
                if (mounted) unawaited(_load());
              },
            ),
          ),
        ],
      ]),
    );
  }
}
