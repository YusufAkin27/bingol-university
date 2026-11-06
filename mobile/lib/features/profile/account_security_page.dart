import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/oauth/oauth_api.dart';
import '../../core/oauth/oauth_services.dart';
import '../../core/oauth_config.dart';
import '../../core/session.dart';
import '../../core/two_factor.dart';
import '../../widgets/bu.dart';
import 'devices_page.dart';
import 'password_page.dart';
import 'profil_widgets.dart';
import 'two_factor_page.dart';

/// Hesap ve güvenlik (Stitch 49-2): e-posta kartı, Şifre satırı (ayrı sayfa), 2FA, bağlı hesaplar, Cihazlarım girişi.
class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key, required this.session});

  final Session session;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  /// İki faktörlü doğrulama durumu (satırın değeri). Sessizce yüklenir; alınamazsa satır değersiz kalır, sayfa bozulmaz.
  bool? _twoFactorOn;

  // ------------------------------------------------------------------------- bağlı hesaplar (Google / Apple)
  late final OAuthApi _oauth = OAuthApi(widget.session.api);

  /// Bağlı dış hesaplar; null = henüz yüklenmedi ya da yüklenemedi ([_idFailed]).
  List<OAuthIdentity>? _identities;
  bool _idFailed = false;
  OAuthProvider? _idBusy;

  /// Yapılandırması açık ve sunucuda kapatılmamış sağlayıcılar: bölüm yalnız biri varsa görünür.
  List<OAuthProvider> get _providers {
    final c = OAuthConfig.current;
    final off = widget.session.oauthDisabled.value;
    return [
      if (c.googleEnabled && !off.contains(OAuthProvider.google)) OAuthProvider.google,
      if (c.appleEnabled && !off.contains(OAuthProvider.apple)) OAuthProvider.apple,
    ];
  }

  Future<void> _loadIdentities() async {
    if (_providers.isEmpty) return;
    try {
      final list = await _oauth.identities();
      if (!mounted) return;
      setState(() {
        _identities = list;
        _idFailed = false;
      });
    } on ApiError catch (e) {
      if (e.code == 'OAUTH_DISABLED') {
        for (final p in OAuthProvider.values) {
          widget.session.disableOAuth(p);
        }
      }
      if (mounted) setState(() => _idFailed = true);
    } catch (_) {
      if (mounted) setState(() => _idFailed = true);
    }
  }

  bool _isLinked(OAuthProvider p) => _identities?.any((i) => i.provider == p) ?? false;

  String _providerName(OAuthProvider p) => p == OAuthProvider.apple ? context.l10n.oaProviderApple : context.l10n.oaProviderGoogle;

  Future<void> _toggleProvider(OAuthProvider p) async {
    if (_idBusy != null) return;
    if (_identities == null) {
      await _loadIdentities(); // liste yüklenemediyse dokunuş yeniden dener
      return;
    }
    setState(() => _idBusy = p);
    try {
      if (_isLinked(p)) {
        await _unlink(p);
      } else {
        await _link(p);
      }
    } finally {
      if (mounted) setState(() => _idBusy = null);
    }
  }

  Future<void> _link(OAuthProvider p) async {
    final l = context.l10n;
    final svc = OAuthServices.current;
    String token;
    String? nonce;
    try {
      if (p == OAuthProvider.google) {
        final c = await svc.google.signIn();
        if (c == null) return; // iptal: sessiz
        token = c.idToken;
      } else {
        final c = await svc.apple.signIn();
        if (c == null) return;
        token = c.identityToken;
        nonce = c.nonce;
      }
    } catch (_) {
      if (mounted) _toast(l.oaErrFailed, kind: BuToastKind.error);
      return;
    }
    if (!mounted) return;
    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PasswordDialog(
        provider: _providerName(p),
        onSubmit: (password) async {
          try {
            await _oauth.link(p, token: token, nonce: nonce, password: password);
            return null;
          } on ApiError catch (e) {
            if (e.code == 'OAUTH_DISABLED') widget.session.disableOAuth(p);
            if (e.status == 403 && e.code == 'WRONG_PASSWORD') {
              return e.message.isNotEmpty ? e.message : l.profil2SecWrongCurrent;
            }
            return errorText(e);
          } catch (e) {
            return errorText(e);
          }
        },
      ),
    );
    if (done != true || !mounted) return;
    _toast(l.oaLinkDone(_providerName(p)), kind: BuToastKind.success);
    await _loadIdentities();
  }

  Future<void> _unlink(OAuthProvider p) async {
    final l = context.l10n;
    final ok = await BuDialog.confirm(
      context,
      title: l.oaUnlinkTitle,
      message: l.oaUnlinkBody(_providerName(p)),
      confirmLabel: l.oaUnlinkAction,
      cancelLabel: l.commonCancel,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _oauth.unlink(p);
      if (!mounted) return;
      _toast(l.oaUnlinkDone(_providerName(p)), kind: BuToastKind.success);
      await _loadIdentities();
    } catch (e) {
      if (mounted) _toast(errorText(e), kind: BuToastKind.error); // 409 OAUTH_LAST_LOGIN_METHOD dahil
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTwoFactor();
    _loadIdentities();
  }

  Future<void> _loadTwoFactor() async {
    try {
      final s = await TwoFactorApi(widget.session.api).status();
      if (mounted) setState(() => _twoFactorOn = s.enabled);
    } catch (_) {
      // Durum alınamadı: satır yine açılır, ayrıntı sayfası hatayı ve yeniden denemeyi gösterir.
    }
  }

  Future<void> _openTwoFactor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: TwoFactorPage.routeName),
        builder: (_) => TwoFactorPage(session: widget.session),
      ),
    );
    if (mounted) _loadTwoFactor();
  }

  void _toast(String m, {BuToastKind kind = BuToastKind.info}) => BuToast.show(context, m, kind: kind);

  Future<void> _openPassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: PasswordPage.routeName),
        builder: (_) => PasswordPage(session: widget.session),
      ),
    );
  }

  Future<void> _openDevices() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: DevicesPage.routeName),
        builder: (_) => DevicesPage(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final email = widget.session.email ?? '';
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          ProfilTopBar(title: l.profil2SecTitle),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // Stitch v3: e-posta bloğu tam genişlik beyaz; etiket 13 mut, değer 16/600 ink, altında kilit + durum 12 mut.
                ColoredBox(
                  color: t.sf,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.profileEmail, style: tx.labelLarge!.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.mut)),
                      const SizedBox(height: 2),
                      Text(email,
                          key: const ValueKey('sec-email'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tx.bodyLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: t.ink)),
                      const SizedBox(height: 6),
                      Row(children: [
                        ExcludeSemantics(child: Icon(BuIcons.lock, size: 16, color: t.mut)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('${l.profil2SecVerified} · ${l.profil2SecEmailFixed}', style: tx.bodySmall!.copyWith(fontSize: 12, color: t.mut)),
                        ),
                      ]),
                    ]),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: t.bd),
                ProfilFlatSection(l.tfSecSection, top: 24, upper: true),
                ProfilFlatGroup(outlined: true, children: [
                  // Şifre güncelleme/sıfırlama ayrı sayfadadır; bu sayfada satır içi form yoktur.
                  ProfilFlatRow(
                    key: const ValueKey('sec-password'),
                    icon: BuIcons.lock,
                    plainIcon: true,
                    label: l.pwRowLabel,
                    sub: l.pwRowSub,
                    onTap: _openPassword,
                  ),
                  ProfilFlatRow(
                    key: const ValueKey('sec-2fa'),
                    icon: BuIcons.shieldCheck,
                    plainIcon: true,
                    label: l.tfTitle,
                    value: _twoFactorOn == null ? null : (_twoFactorOn! ? l.tfOn : l.tfOff),
                    onTap: _openTwoFactor,
                  ),
                ]),
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 1, color: t.bd),
                if (_providers.isNotEmpty) ...[
                  ProfilFlatSection(l.oaLinkedTitle, top: 24, upper: true),
                  ProfilFlatGroup(outlined: true, children: [
                    for (final p in _providers)
                      ProfilFlatRow(
                        key: ValueKey('sec-oauth-${p.wire}'),
                        icon: BuIcons.globe,
                        plainIcon: true,
                        label: _providerName(p),
                        value: _identities == null ? (_idFailed ? l.oaLinkedFailed : null) : (_isLinked(p) ? l.oaLinkedYes : l.oaLinkedNo),
                        trailing: _idBusy == p ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                        onTap: _idBusy != null ? null : () => _toggleProvider(p),
                      ),
                  ]),
                  const SizedBox(height: 24),
                  Divider(height: 1, thickness: 1, color: t.bd),
                ],
                ProfilFlatSection(l.profil2SecSessions, top: 24, upper: true),
                ProfilFlatGroup(outlined: true, children: [
                  // "Tüm cihazlardan çık" bu sayfaya taşındı (Cihazlarım'ın altında); burada yalnız giriş satırı var.
                  ProfilFlatRow(
                    key: const ValueKey('sec-devices'),
                    icon: BuIcons.smartphone,
                    plainIcon: true,
                    label: l.devTitle,
                    onTap: _openDevices,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hesap bağlama için şifre yeniden doğrulaması: sağlayıcı kimliği alındıktan sonra açılır; yanlış şifrede iletişim kutusu
/// kapanmaz, hata alan altında görünür ([onSubmit] hata metni döner, başarıda null). Başarıda `true` ile kapanır.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.provider, required this.onSubmit});

  final String provider;
  final Future<String?> Function(String password) onSubmit;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _pw = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_pw.text.isEmpty) {
      setState(() => _error = context.l10n.profilePrefsEnterPassword);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSubmit(_pw.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: t.sf3,
      title: Text(l.oaLinkPwTitle, style: tx.titleLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.oaLinkPwBody(widget.provider), style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('oauth-link-password'),
              controller: _pw,
              obscureText: _hidden,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !_busy,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              style: tx.bodyLarge!.copyWith(color: t.ink),
              decoration: InputDecoration(
                labelText: l.oaPasswordLabel,
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
                  icon: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff, size: 20, color: t.mut),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        TextButton(
          key: const ValueKey('oauth-link-confirm'),
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.oaLinkAction),
        ),
      ],
    );
  }
}
