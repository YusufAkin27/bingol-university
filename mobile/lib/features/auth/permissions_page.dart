import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/permissions/ensure_permission.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

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

const _firstRun = [AppPermission.notifications, AppPermission.location, AppPermission.contacts];

/// Tam ekran, sıcak bir "İzinler" sayfası: bildirim, yaklaşık konum, rehber. Atlanabilir.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key, required this.onFinished, this.onGranted, this.service});

  /// "Devam" ya da "Şimdi değil" ile çıkış.
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

  bool get _allGranted => _firstRun.every((p) => _st[p]?.usable ?? false);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                    child: Icon(LucideIcons.shieldCheck, size: 27, color: t.onSoft),
                  ),
                  const SizedBox(height: 18),
                  Text('Birkaç izin', style: BuType.display.copyWith(color: t.ink)),
                  const SizedBox(height: 6),
                  Text(
                    'Uygulamayı en iyi şekilde kullanabilmeniz için aşağıdaki izinleri isteriz. '
                    'Hiçbirini şimdi vermek zorunda değilsiniz; sonradan Ayarlar\'dan da değiştirebilirsiniz.',
                    style: BuType.body.copyWith(color: t.mut),
                  ),
                  const SizedBox(height: 20),
                  for (final p in _firstRun) ...[
                    _PermRow(
                      permission: p,
                      state: _st[p],
                      busy: _busy == p,
                      asked: _asked.contains(p),
                      onAllow: () => _ask(p),
                      onSettings: _settings,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BuButton(label: _allGranted ? 'Başla' : 'Devam', onPressed: widget.onFinished),
                  if (!_allGranted) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: widget.onFinished,
                      child: Text('Şimdi değil', style: BuType.bodyStrong.copyWith(color: t.mut)),
                    ),
                  ],
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
    required this.onAllow,
    required this.onSettings,
  });

  final AppPermission permission;
  final PermState? state;
  final bool busy;

  /// Bu sayfada istem gösterildi ve reddedildi.
  final bool asked;
  final VoidCallback onAllow;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final info = permissionInfo(permission);
    final st = state;
    final Widget action;
    if (st != null && st.usable) {
      action = _Mark(key: ValueKey('ok-${permission.name}'), color: t.ok, bg: t.okSoft, icon: LucideIcons.check, text: 'Verildi');
    } else if (st != null && st.needsSettings) {
      action = Wrap(
        key: ValueKey('perm-${permission.name}'),
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Mark(color: t.danger, bg: t.soft, icon: LucideIcons.x, text: 'Reddedildi'),
          BuButton(label: 'Ayarlardan aç', compact: true, kind: BuButtonKind.outline, onPressed: onSettings),
        ],
      );
    } else {
      action = Wrap(
        key: ValueKey('ask-${permission.name}-$asked'),
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (asked) _Mark(color: t.danger, bg: t.soft, icon: LucideIcons.x, text: 'Reddedildi'),
          BuButton(
            label: asked ? 'Tekrar dene' : 'İzin ver',
            compact: true,
            busy: busy,
            onPressed: st == null ? null : onAllow,
          ),
        ],
      );
    }
    return BuCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
            child: Icon(info.icon, size: 20, color: t.onSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title, style: BuType.bodyStrong.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                Text(info.rationale, style: BuType.caption.copyWith(color: t.mut)),
                const SizedBox(height: 10),
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
        ],
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
