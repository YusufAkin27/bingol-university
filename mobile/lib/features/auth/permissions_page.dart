import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/sistem_widgets.dart';
import 'widgets/auth_art.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';

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
    if (done == null) {
      return Scaffold(backgroundColor: context.bu.bg, body: const Center(child: CircularProgressIndicator()));
    }
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

/// Tam ekran, sıcak bir "İzinler" sayfası (Sm1): bildirim, rehber, kamera/galeri; 3 parçalı adım ilerlemesi.
/// Her kart tek tek atlanabilir ("Şimdi değil"); "Devam" sayfayı kapatır.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key, required this.onFinished, this.onGranted, this.service});

  /// "Devam" ile çıkış.
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

  bool _resolved(AppPermission p) => (_st[p]?.usable ?? false) || _skipped.contains(p);

  bool get _allGranted => _firstRun.every((p) => _st[p]?.usable ?? false);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final resolved = _firstRun.where(_resolved).length;
    final total = _firstRun.length;
    final step = resolved >= total ? total : resolved + 1;
    final active = _firstRun.cast<AppPermission?>().firstWhere((p) => !_resolved(p!), orElse: () => null);
    final stepText = context.l10n.sistemuiPermStep(step.toString(), total.toString());
    return AuthClockHost(
      child: Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
        const Positioned(top: 0, left: 0, right: 0, child: AuthAmbient()),
        SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Semantics(
                      container: true,
                      label: stepText,
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          for (var i = 0; i < total; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: AnimatedContainer(
                                key: ValueKey('perm-step-$i'),
                                duration: const Duration(milliseconds: 220),
                                height: 7,
                                decoration: BoxDecoration(
                                  color: i < step ? t.pr : t.mut.withValues(alpha: .22),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: ExcludeSemantics(
                      child: Text(stepText, style: BuType.label.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Align(alignment: AlignmentDirectional.centerStart, child: AuthArt(AuthArtKind.shield, size: 92)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Semantics(
                      header: true,
                      child: Text(context.l10n.permPageTitle,
                          style: BuType.display.copyWith(color: t.ink, letterSpacing: -.5)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(context.l10n.permPageIntro, style: BuType.body.copyWith(color: t.mut, height: 1.45)),
                  ),
                  const SizedBox(height: 18),
                  for (final p in _firstRun) ...[
                    _PermRow(
                      permission: p,
                      state: _st[p],
                      busy: _busy == p,
                      asked: _asked.contains(p),
                      active: p == active,
                      onAllow: () => _ask(p),
                      onSkip: () => setState(() => _skipped.add(p)),
                      onSettings: _settings,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: AuthPrimaryButton(
                label: _allGranted ? context.l10n.permStart : context.l10n.permContinue,
                onPressed: widget.onFinished,
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.permission,
    required this.state,
    required this.busy,
    required this.asked,
    required this.active,
    required this.onAllow,
    required this.onSkip,
    required this.onSettings,
  });

  final AppPermission permission;
  final PermState? state;
  final bool busy;

  /// Bu sayfada istem gösterildi ve reddedildi.
  final bool asked;

  /// Sıradaki (vurgulu) adım.
  final bool active;
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
    final (title, icon, text) = _content(context);
    final st = state;
    final Widget action;
    if (st != null && st.usable) {
      action = _Mark(key: ValueKey('ok-${permission.name}'), color: t.ok, bg: t.okSoft, icon: LucideIcons.check, text: context.l10n.permGranted);
    } else if (st != null && st.needsSettings) {
      action = Wrap(
        key: ValueKey('perm-${permission.name}'),
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Mark(color: t.danger, bg: t.soft, icon: LucideIcons.x, text: context.l10n.permDenied),
          SistemButton(
            label: context.l10n.permOpenSettings,
            kind: SistemButtonKind.outline,
            height: 44,
            radius: 14,
            onPressed: onSettings,
          ),
        ],
      );
    } else {
      action = Column(
        key: ValueKey('ask-${permission.name}-$asked'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (asked) ...[
            _Mark(color: t.danger, bg: t.soft, icon: LucideIcons.x, text: context.l10n.permDenied),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: SistemButton(
                  label: asked ? context.l10n.permRetry : context.l10n.permAllow,
                  height: 44,
                  radius: 14,
                  busy: busy,
                  onPressed: st == null ? null : onAllow,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SistemButton(
                  label: context.l10n.permNotNow,
                  kind: SistemButtonKind.outline,
                  height: 44,
                  radius: 14,
                  onPressed: onSkip,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? t.pr : t.bd),
          boxShadow: [BoxShadow(color: t.ink.withValues(alpha: .10), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SistemTile(icon: icon, size: 48, radius: 16, iconSize: 21),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: BuType.heading.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(text, style: BuType.body.copyWith(color: t.mut, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(a), child: c),
              ),
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({super.key, required this.color, required this.bg, required this.icon, required this.text});

  final Color color;
  final Color bg;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: color),
            const SizedBox(width: 6),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(color: color))),
          ],
        ),
      ),
    );
  }
}
