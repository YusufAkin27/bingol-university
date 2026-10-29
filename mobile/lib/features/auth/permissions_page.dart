import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/permissions/permission_service.dart';
import '../../widgets/bu.dart';
import '../system/gate_views.dart' show GateArrowButton;

/// "İlk giriş izinleri gösterildi" bayrağı. Cihaz başınadır (hesap değişse de tekrar etmez);
/// Keychain/Keystore'da tutulur.
class PermissionOnboarding {
  static const _key = 'perms_onboarded';
  static const _storage = FlutterSecureStorage();

  static Future<bool> isDone() async {
    try {
      return await _storage.read(key: _key) == '1';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markDone() async {
    try {
      await _storage.write(key: _key, value: '1');
    } catch (_) {}
  }
}

/// İlk başarılı girişten sonra, [PermissionOnboarding] bayrağı yoksa [child] yerine izin sayfasını gösterir.
class PostLoginGate extends StatefulWidget {
  const PostLoginGate({super.key, required this.child, this.onNotificationsGranted, this.service});

  final Widget child;

  /// Bildirim izni verilince (FCM kaydını başlatmak için).
  final VoidCallback? onNotificationsGranted;
  final PermissionService? service;

  @override
  State<PostLoginGate> createState() => _PostLoginGateState();
}

class _PostLoginGateState extends State<PostLoginGate> {
  bool? _done;

  @override
  void initState() {
    super.initState();
    PermissionOnboarding.isDone().then((v) {
      if (mounted) setState(() => _done = v);
    });
  }

  Future<void> _finish() async {
    await PermissionOnboarding.markDone();
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    // Bayrak okunurken (milisaniyeler) düz zemin: tam sayfa çember yok.
    if (done == null) return Scaffold(backgroundColor: context.bu.bg);
    if (done) return widget.child;
    return PermissionsPage(
      service: widget.service,
      onFinished: _finish,
      onGranted: (p) {
        if (p == AppPermission.notifications) widget.onNotificationsGranted?.call();
      },
    );
  }
}

const _firstRun = [AppPermission.notifications, AppPermission.contacts, AppPermission.camera];

/// Tam ekran "Birkaç izin" sayfası (06/1-2): bildirim, rehber, kamera/galeri; 3 parçalı adım ilerlemesi.
/// Her kart tek tek atlanabilir ("Şimdi değil"); "Başla"/"Devam" sayfayı kapatır.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key, required this.onFinished, this.onGranted, this.service});

  /// "Başla" / "Devam" ile çıkış.
  final VoidCallback onFinished;
  final ValueChanged<AppPermission>? onGranted;
  final PermissionService? service;

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  final Map<AppPermission, PermState> _st = {};
  final Set<AppPermission> _asked = {};
  final Set<AppPermission> _skipped = {};
  AppPermission? _busy;

  PermissionService get _svc => widget.service ?? PermissionService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ayarlar'dan dönünce durumlar tazelenir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    for (final p in _firstRun) {
      final s = await _svc.status(p);
      if (!mounted) return;
      setState(() => _st[p] = s);
    }
  }

  Future<void> _ask(AppPermission p) async {
    if (_busy != null) return;
    setState(() => _busy = p);
    final s = await _svc.request(p);
    if (!mounted) return;
    setState(() {
      _st[p] = s;
      _busy = null;
      if (!s.usable) _asked.add(p);
    });
    if (s.usable) widget.onGranted?.call(p);
  }

  Future<void> _settings() async {
    await _svc.openSettings();
  }

  bool _denied(AppPermission p) {
    final s = _st[p];
    return s != null && !s.usable && (s.needsSettings || _asked.contains(p));
  }

  /// Karar verilmiş: verildi, reddedildi ya da atlandı.
  bool _answered(AppPermission p) => (_st[p]?.usable ?? false) || _denied(p) || _skipped.contains(p);

  bool get _allGranted => _firstRun.every((p) => _st[p]?.usable ?? false);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final answered = _firstRun.where(_answered).length;
    final total = _firstRun.length;
    final step = answered >= total ? total : answered + 1;
    final stepText = l.sistemuiPermStep(step.toString(), total.toString());
    final start = answered == 0 || _allGranted;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Semantics(
              container: true,
              label: stepText,
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stepText, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < total; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedContainer(
                            key: ValueKey('perm-step-$i'),
                            duration: BuMotion.of(context, BuMotion.medium),
                            height: 5,
                            decoration: BoxDecoration(color: i < step ? t.pr : t.bd, borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(l.permPageTitle, style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            Text(l.permPageIntro, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.6)),
            const SizedBox(height: 20),
            for (final p in _firstRun) ...[
              _PermCard(
                permission: p,
                state: _st[p],
                busy: _busy == p,
                denied: _denied(p),
                onAllow: () => _ask(p),
                onSkip: () => setState(() => _skipped.add(p)),
                onSettings: _settings,
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            if (start)
              GateArrowButton(label: l.permStart, onPressed: widget.onFinished)
            else
              BuButton(label: l.permContinue, onPressed: widget.onFinished),
          ],
        ),
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.permission,
    required this.state,
    required this.busy,
    required this.denied,
    required this.onAllow,
    required this.onSkip,
    required this.onSettings,
  });

  final AppPermission permission;
  final PermState? state;
  final bool busy;

  /// Reddedildi (sistem kalıcı reddetti ya da bu sayfada istem reddedildi).
  final bool denied;
  final VoidCallback onAllow;
  final VoidCallback onSkip;
  final VoidCallback onSettings;

  (String, IconData, String) _content(BuildContext context) {
    final l = context.l10n;
    final info = permissionInfo(permission, context);
    return switch (permission) {
      AppPermission.notifications => (info.title, info.icon, l.sistemuiPermNotifText),
      AppPermission.contacts => (info.title, info.icon, l.sistemuiPermContactsText),
      AppPermission.camera => (l.sistemuiPermCameraTitle, info.icon, l.sistemuiPermCameraText),
      _ => (info.title, info.icon, info.rationale),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final (title, icon, text) = _content(context);
    final st = state;
    final granted = st != null && st.usable;

    Widget? badge;
    if (granted) {
      badge = _StatusPill(key: ValueKey('ok-${permission.name}'), color: t.ok, bg: t.okSoft, icon: Icons.check_circle, text: l.permGranted);
    } else if (denied) {
      badge = _StatusPill(color: t.onSoft, bg: t.soft, icon: Icons.error, text: l.permDenied);
    }

    final Widget? actions;
    if (granted) {
      actions = null;
    } else if (denied) {
      actions = Wrap(
        key: ValueKey('perm-${permission.name}'),
        spacing: 8,
        runSpacing: 4,
        children: [
          _TonalPill(label: l.permRetry, icon: LucideIcons.rotateCw, onTap: busy ? null : onAllow),
          BuButton(label: l.permOpenSettings, icon: LucideIcons.settings, kind: BuButtonKind.soft, compact: true, onPressed: onSettings),
        ],
      );
    } else {
      actions = Row(
        key: ValueKey('ask-${permission.name}-$denied'),
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: Text(l.permNotNow, style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          BuButton(label: l.permAllow, compact: true, busy: busy, onPressed: st == null ? null : onAllow),
        ],
      );
    }

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), boxShadow: BuElevation.of(context, 1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: granted ? t.sf2 : t.soft, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, size: 22, color: t.pr),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(title, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          if (badge != null) ...[const SizedBox(width: 8), badge],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(text, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
            if (actions != null) ...[
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: BuMotion.of(context, BuMotion.medium),
                child: Align(alignment: denied ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd, child: actions),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Durum hapı: "Verildi" (yeşil) / "Reddedildi" (kırmızı ton), dolu daire simgeli.
class _StatusPill extends StatelessWidget {
  const _StatusPill({super.key, required this.color, required this.bg, required this.icon, required this.text});

  final Color color;
  final Color bg;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 4),
          Text(text, maxLines: 1, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Gri tonal hap düğme ("Tekrar dene"): görsel 36 dp, dokunma hedefi 48 dp.
class _TonalPill extends StatelessWidget {
  const _TonalPill({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: t.sf2,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap == null
                  ? null
                  : () {
                      buHaptic(BuHaptic.selection);
                      onTap!();
                    },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: t.ink),
                      const SizedBox(width: 6),
                      Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
