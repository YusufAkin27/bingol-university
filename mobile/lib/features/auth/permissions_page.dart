import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/locale_controller.dart';
import '../../core/permissions/ensure_permission.dart';
import '../../core/permissions/permission_service.dart';
import '../../widgets/bu.dart';
import 'widgets/auth_ref.dart' show RefLink, kRefPad;

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

  /// Karar verilmiş: verildi ya da reddedildi.
  bool _answered(AppPermission p) => (_st[p]?.usable ?? false) || _denied(p);

  bool get _allGranted => _firstRun.every((p) => _st[p]?.usable ?? false);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final answered = _firstRun.where(_answered).length;
    final start = answered == 0 || _allGranted;
    // Stitch v3 "13/14 İzinler": adım çubuğu ve kart yok; düz satırlar + ince ayırıcı; altta tek birincil düğme.
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kRefPad, 24, kRefPad, 24),
          children: [
            Semantics(
              header: true,
              child: Text(l.permPageTitle, style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Text(l.permPageIntro, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
            const SizedBox(height: 24),
            for (var i = 0; i < _firstRun.length; i++) ...[
              if (i > 0) Divider(height: 1, color: t.bd),
              _PermRow(
                permission: _firstRun[i],
                state: _st[_firstRun[i]],
                busy: _busy == _firstRun[i],
                denied: _denied(_firstRun[i]),
                onAllow: () => _ask(_firstRun[i]),
                onSettings: _settings,
              ),
            ],
            Divider(height: 1, color: t.bd),
            const SizedBox(height: 32),
            start ? BuButton(label: l.permStart, onPressed: widget.onFinished) : BuButton(label: l.permContinue, onPressed: widget.onFinished),
            if (answered == 0) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: widget.onFinished,
                  style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(48, 48)),
                  child: Text(l.permNotNow, style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
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
    required this.denied,
    required this.onAllow,
    required this.onSettings,
  });

  final AppPermission permission;
  final PermState? state;
  final bool busy;

  /// Reddedildi (sistem kalıcı reddetti ya da bu sayfada istem reddedildi).
  final bool denied;
  final VoidCallback onAllow;
  final VoidCallback onSettings;

  (String, String) _content(BuildContext context) {
    final l = context.l10n;
    final info = permissionInfo(permission, context);
    return switch (permission) {
      AppPermission.notifications => (info.title, l.sistemuiPermNotifText),
      AppPermission.contacts => (info.title, l.sistemuiPermContactsText),
      AppPermission.camera => (l.sistemuiPermCameraTitle, l.sistemuiPermCameraText),
      _ => (info.title, info.rationale),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final (title, text) = _content(context);
    final st = state;
    final granted = st != null && st.usable;

    // Sağ üst: izin ver (outlined) / Verildi + onay (ok) / Reddedildi (danger).
    final Widget trailing;
    if (granted) {
      trailing = Row(
        key: ValueKey('ok-${permission.name}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(LucideIcons.check, size: 18, color: t.ok)),
          const SizedBox(width: 4),
          Text(l.permGranted, style: tx.labelLarge!.copyWith(color: t.ok, fontWeight: FontWeight.w600)),
        ],
      );
    } else if (denied) {
      trailing = Text(l.permDenied, style: tx.labelLarge!.copyWith(color: t.danger, fontWeight: FontWeight.w600));
    } else {
      trailing = BuButton(
        key: ValueKey('ask-${permission.name}-$denied'),
        label: l.permAllow,
        compact: true,
        kind: BuButtonKind.outline,
        busy: busy,
        onPressed: st == null ? null : onAllow,
      );
    }

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600))),
                const SizedBox(width: 12),
                AnimatedSwitcher(duration: BuMotion.of(context, BuMotion.medium), child: trailing),
              ],
            ),
            const SizedBox(height: 4),
            Text(text, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
            if (denied && !granted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  key: ValueKey('perm-${permission.name}'),
                  spacing: 16,
                  children: [
                    RefLink(label: l.permRetry, muted: true, compact: true, onPressed: busy ? null : onAllow),
                    RefLink(label: l.permOpenSettings, compact: true, onPressed: onSettings),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
