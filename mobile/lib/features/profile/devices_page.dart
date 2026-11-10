import 'package:flutter/material.dart';

import 'signout_guard.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/user_sessions.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show relativeTime;
import 'profil_widgets.dart';

/// Cihazlarım (Ayarlar > Hesap ve güvenlik > Cihazlarım): hesaba açık oturumlar (cihaz adı, platform, son kullanım,
/// "Bu cihaz"), her satırda "Çıkış yap" ve altta "Tüm cihazlardan çık". Yeni cihaz girişi bildirimine dokunulunca da
/// bu sayfa açılır. Sözleşme: docs/changes/auth.md "Çoklu oturum + Cihazlarım".
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.session});

  final Session session;

  static const routeName = 'devices';

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late final UserSessionsApi _api = UserSessionsApi(widget.session.api);
  List<UserSessionInfo> _items = const [];
  bool _loading = true;
  Object? _error;

  /// Çıkışı süren oturumlar (satır kilitlenir) ve "tümünden çık" isteği.
  final Set<String> _busy = {};
  bool _loggingOutAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _api.list();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Sessiz yenilemede (çekerek yenile / satır silindikten sonra) eldeki liste korunur.
        if (!quiet || _items.isEmpty) _error = e;
        _loading = false;
      });
    }
  }

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) => BuToast.show(context, m, kind: kind);

  String _name(UserSessionInfo s) {
    final l = context.l10n;
    if (s.deviceName.isNotEmpty) return s.deviceName;
    return switch (s.platform) {
      'ANDROID' => l.devNameAndroid,
      'IOS' => l.devNameIos,
      'WEB' => l.devNameWeb,
      _ => l.devNameUnknown,
    };
  }

  Future<void> _signOutOne(UserSessionInfo s) async {
    if (_busy.contains(s.id) || _loggingOutAll) return;
    final l = context.l10n;
    final name = _name(s);
    final ok = await BuDialog.confirm(
      context,
      title: l.devSignOutTitle,
      message: s.current ? l.devSignOutThisBody : l.devSignOutBody(name),
      confirmLabel: l.devSignOut,
      cancelLabel: l.commonCancel,
      destructive: true,
      icon: BuIcons.logOut,
    );
    if (!ok || !mounted) return;
    if (s.current) {
      if (!await confirmUnsentLoss(context, widget.session) || !mounted) return;
      // Bu cihaz: normal çıkış (refresh iptali + bu cihazın push kaydı), ardından giriş ekranı.
      setState(() => _busy.add(s.id));
      await widget.session.signOut();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _busy.add(s.id));
    try {
      await _api.revoke(s.id);
      if (!mounted) return;
      setState(() {
        _busy.remove(s.id);
        _items = _items.where((x) => x.id != s.id).toList();
      });
      _toast(l.devSignedOut(name), kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(s.id));
      if (e is ApiError && e.status == 404) {
        // Oturum zaten kapanmış (başka cihazdan ya da süresi dolmuş): listeyi tazele.
        _toast(l.devGone);
        _load(quiet: true);
      } else {
        _toast(errorText(e), kind: BuToastKind.error);
      }
    }
  }

  Future<void> _logoutAll() async {
    if (_loggingOutAll) return;
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.settingsLogoutAllTitle,
      message: l.settingsLogoutAllBody,
      confirmLabel: l.settingsLogoutAllConfirm,
      cancelLabel: l.commonCancel,
      destructive: true,
      icon: BuIcons.logOut,
    );
    if (!ok || !mounted) return;
    setState(() => _loggingOutAll = true);
    try {
      await widget.session.logoutAll();
    } catch (e) {
      if (mounted) {
        setState(() => _loggingOutAll = false);
        _toast(errorText(e), kind: BuToastKind.error);
      }
      return;
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    Widget body;
    if (_loading) {
      body = const _DevicesSkeleton();
    } else if (_error != null && _items.isEmpty) {
      body = BuErrorState(error: _error, onRetry: _load);
    } else {
      body = BuRefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: ListView(
          key: const ValueKey('dev-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(l.devIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
            ),
            ProfilFlatSection(l.devSection, top: 16, upper: true),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(l.devEmpty, key: const ValueKey('dev-empty'), style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
              )
            else
              ProfilFlatGroup(outlined: true, children: [
                for (final s in _items)
                  _SessionRow(
                    key: ValueKey('dev-${s.id}'),
                    info: s,
                    name: _name(s),
                    busy: _busy.contains(s.id),
                    onSignOut: () => _signOutOne(s),
                  ),
              ]),
            ProfilFlatSection(l.devAllSection, top: 24, upper: true),
            ProfilFlatGroup(outlined: true, children: [
              ProfilFlatRow(
                key: const ValueKey('dev-logout-all'),
                icon: BuIcons.logOut,
                plainIcon: true,
                label: l.settingsLogoutAll,
                danger: true,
                trailing: _loggingOutAll ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                onTap: _loggingOutAll ? null : _logoutAll,
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(l.devAllHint, style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut, height: 1.4)),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.devTitle),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Yükleniyor: üç satırlık iskelet.
class _DevicesSkeleton extends StatelessWidget {
  const _DevicesSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('dev-loading'),
      padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        BuSkeleton.line(width: 260),
        SizedBox(height: 10),
        BuSkeleton.line(width: 200),
        SizedBox(height: 24),
        BuSkeleton(height: 64, radius: 14),
        SizedBox(height: 8),
        BuSkeleton(height: 64, radius: 14),
      ]),
    );
  }
}

/// Oturum satırı: simge, cihaz adı, "Bu cihaz"/son kullanım, platform · sürüm · maskeli IP ve "Çıkış yap".
class _SessionRow extends StatelessWidget {
  const _SessionRow({super.key, required this.info, required this.name, required this.busy, required this.onSignOut});

  final UserSessionInfo info;
  final String name;
  final bool busy;
  final VoidCallback onSignOut;

  String _platform(AppLocalizations l) => switch (info.platform) {
        'ANDROID' => l.devPlatformAndroid,
        'IOS' => l.devPlatformIos,
        'WEB' => l.devPlatformWeb,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final used = info.lastUsedAt ?? info.createdAt;
    final first = info.current
        ? l.devThisDevice
        : (used == null ? '' : l.devLastUsed(relativeTime(used.toIso8601String(), context: context)));
    final second = [
      _platform(l),
      if (info.appVersion.isNotEmpty) 'v${info.appVersion}',
      if (info.ipMasked.isNotEmpty) info.ipMasked,
    ].where((p) => p.isNotEmpty).join(' · ');
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
        child: Row(children: [
          ExcludeSemantics(child: Icon(info.isWeb ? BuIcons.laptop : BuIcons.smartphone, size: 22, color: t.ink)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: BuType.emphasisWeight)),
              if (first.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(first, style: tx.bodySmall!.copyWith(color: info.current ? t.ink : t.mut, height: 1.35)),
                ),
              if (second.isNotEmpty)
                Text(second, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
            ]),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  key: ValueKey('dev-signout-${info.id}'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: info.current ? t.ink : t.danger,
                  ),
                  onPressed: onSignOut,
                  child: Text(l.devSignOut),
                ),
        ]),
      ),
    );
  }
}
