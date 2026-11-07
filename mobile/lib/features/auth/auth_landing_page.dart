import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/oauth/oauth_services.dart';
import '../../core/oauth_config.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/legal_pages.dart';
import 'login_page.dart';
import 'oauth_flow.dart';
import 'register_page.dart';
import 'two_factor_code_page.dart';
import 'welcome_page.dart' show WelcomeLangPill;
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';
import 'widgets/oauth_buttons.dart';

/// Premium giriş / karşılama ekranı (çıkış yapmış kullanıcının kök ekranı): "Kampüsün burada." + üç yöntem:
/// Google ile devam et, Apple ile devam et (yalnız iOS), E-posta ile devam et (mevcut e-posta/şifre girişi ve kayıt).
///
/// Google/Apple düğmeleri YALNIZ yapılandırma açıkken görünür ([OAuthConfig]) ve sunucu `OAUTH_DISABLED` derse o oturum
/// boyunca gizlenir; sahte çalışma yoktur. Çift dokunma tek istek üretir (bir yöntem sürerken diğerleri de pasiftir),
/// kullanıcı iptali sessizdir, hatalar ekran içi bantta gösterilir.
class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({super.key, required this.session, this.services, this.addAccount = false, this.prefillEmail, this.reloginHint});

  final Session session;

  /// "Hesap ekle" kipi: mevcut hesap açık kalır, geri düğmesi iptal eder, başarılı girişte yeni hesap etkin olur.
  final bool addAccount;

  /// Oturumu dolmuş hesap için yeniden giriş: bilinen tam e-posta (yoksa null) ve maskeli ipucu.
  final String? prefillEmail;
  final String? reloginHint;

  /// Test için: sağlayıcı SDK uygulamaları (null: [OAuthServices.current]).
  final OAuthServices? services;

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  OAuthProvider? _busy;
  String? _error;
  int _shake = 0;
  OAuthOutcome? _link; // 409 OAUTH_LINK_REQUIRED

  bool _visible(OAuthProvider p) {
    final cfg = OAuthConfig.current;
    final on = p == OAuthProvider.google ? cfg.googleEnabled : cfg.appleEnabled;
    return on && !widget.session.oauthDisabled.value.contains(p);
  }

  Future<void> _run(OAuthProvider p) async {
    if (_busy != null) return; // çift dokunma / eşzamanlı iki yöntem engellenir
    setState(() {
      _busy = p;
      _error = null;
      _link = null;
    });
    final out = await runOAuthSignIn(widget.session, p, services: widget.services);
    if (!mounted) return;
    setState(() => _busy = null);
    switch (out.kind) {
      case OAuthOutcomeKind.cancelled:
      case OAuthOutcomeKind.signedIn: // kök ekran kendiliğinden ana sayfa / profil kapısına geçer
        return;
      case OAuthOutcomeKind.twoFactor:
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: TwoFactorLoginPage.routeName),
            builder: (_) => TwoFactorLoginPage(session: widget.session, challenge: out.challenge!),
          ),
        );
      case OAuthOutcomeKind.linkRequired:
        authHaptic(AuthHaptic.error);
        setState(() => _link = out);
      case OAuthOutcomeKind.disabled:
        authHaptic(AuthHaptic.error);
        setState(() {
          _error = context.l10n.oaErrDisabled;
          _shake++;
        });
      case OAuthOutcomeKind.failed:
        authHaptic(AuthHaptic.error);
        setState(() {
          _error = oauthErrorText(context, out.error);
          _shake++;
        });
    }
  }

  void _openEmail() => Navigator.push(
        context,
        MaterialPageRoute(
            settings: const RouteSettings(name: 'login'),
            builder: (_) => LoginPage(session: widget.session, initialEmail: widget.prefillEmail)),
      );

  void _openRegister() => Navigator.push(
        context,
        MaterialPageRoute(settings: const RouteSettings(name: 'register'), builder: (_) => RegisterPage(session: widget.session)),
      );

  void _openLegal(String type) => Navigator.push(
        context,
        MaterialPageRoute(settings: const RouteSettings(name: 'legal_doc'), builder: (_) => LegalDocPage(session: widget.session, type: type)),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kRefPad),
                    child: BuStaggerScope(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: IntrinsicHeight(
                          child: ListenableBuilder(
                            listenable: widget.session.oauthDisabled,
                            builder: (context, _) {
                              final google = _visible(OAuthProvider.google);
                              final apple = _visible(OAuthProvider.apple);
                              final social = google || apple;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (widget.addAccount) ...[
                                        BuIconButton(
                                          key: const ValueKey('add-account-back'),
                                          icon: BuIcons.chevronLeft,
                                          tooltip: l.commonBack,
                                          onTap: () => Navigator.maybePop(context),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      const RefBrandMark(size: 44),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('BÜ Kampüs',
                                            style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400, letterSpacing: -.3)),
                                      ),
                                      const WelcomeLangPill(),
                                    ],
                                  ),
                                  const Spacer(),
                                  const SizedBox(height: 40),
                                  BuStaggerItem(
                                    index: 0,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Semantics(
                                          header: true,
                                          child: Text(l.oaHeadline,
                                              key: const ValueKey('landing-headline'),
                                              style: tx.displayMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.08, letterSpacing: -1.2)),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(widget.addAccount ? l.accAddSub : l.oaSub, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
                                        if (widget.reloginHint != null) ...[
                                          const SizedBox(height: 16),
                                          RefBanner(l.accReloginHint(widget.reloginHint!), key: const ValueKey('relogin-hint'), tone: RefTone.warn),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  BuStaggerItem(
                                    index: 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (google) ...[
                                          GoogleContinueButton(
                                            label: l.oaContinueGoogle,
                                            busy: _busy == OAuthProvider.google,
                                            onPressed: _busy != null ? null : () => _run(OAuthProvider.google),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        if (apple) ...[
                                          AppleContinueButton(
                                            label: l.oaContinueApple,
                                            busy: _busy == OAuthProvider.apple,
                                            onPressed: _busy != null ? null : () => _run(OAuthProvider.apple),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        if (social) ...[
                                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: OAuthOrDivider()),
                                          const SizedBox(height: 4),
                                        ],
                                        RefButton(
                                          key: const ValueKey('landing-email'),
                                          label: l.oaContinueEmail,
                                          kind: social ? RefButtonKind.secondary : RefButtonKind.primary,
                                          icon: buDirIcon(context, BuIcons.arrowRight),
                                          onPressed: _busy != null ? null : _openEmail,
                                        ),
                                        AnimatedSize(
                                          duration: AppMotion.of(context, AppMotion.fast),
                                          curve: AppMotion.enter,
                                          alignment: Alignment.topCenter,
                                          child: _error == null
                                              ? const SizedBox(width: double.infinity)
                                              : Padding(
                                                  padding: const EdgeInsets.only(top: 16),
                                                  child: AuthShake(trigger: _shake, child: RefBanner(_error!, key: ValueKey('landing-error-$_error'))),
                                                ),
                                        ),
                                        AnimatedSize(
                                          duration: AppMotion.of(context, AppMotion.fast),
                                          curve: AppMotion.enter,
                                          alignment: Alignment.topCenter,
                                          child: _link == null
                                              ? const SizedBox(width: double.infinity)
                                              : Padding(
                                                  padding: const EdgeInsets.only(top: 16),
                                                  child: _LinkRequiredCard(
                                                    outcome: _link!,
                                                    onEmail: _openEmail,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  BuStaggerItem(
                                    index: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Center(
                                          child: RefFooterPrompt(
                                            prompt: l.loginNoAccount,
                                            action: l.loginRegister,
                                            onPressed: _busy != null ? null : _openRegister,
                                          ),
                                        ),
                                        if (!keyboard) ...[
                                          const SizedBox(height: 4),
                                          Text(l.oaLegalLead,
                                              textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            children: [
                                              RefLink(key: const ValueKey('landing-terms'), label: l.oaTermsLink, onPressed: () => _openLegal('TERMS')),
                                              RefLink(key: const ValueKey('landing-privacy'), label: l.oaPrivacyLink, onPressed: () => _openLegal('PRIVACY')),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
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

/// 409 `OAUTH_LINK_REQUIRED`: aynı e-postayla zaten hesap var. Otomatik birleşme YOK; kullanıcı önce e-posta + şifreyle
/// girer, sonra Hesap ve güvenlik > Bağlı hesaplar'dan sağlayıcıyı bağlar.
class _LinkRequiredCard extends StatelessWidget {
  const _LinkRequiredCard({required this.outcome, required this.onEmail});

  final OAuthOutcome outcome;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = outcome.provider == OAuthProvider.apple ? l.oaProviderApple : l.oaProviderGoogle;
    final mail = outcome.emailMasked;
    return Semantics(
      liveRegion: true,
      container: true,
      child: RefBanner(
        mail == null ? l.oaLinkBody(provider) : '${l.oaLinkBody(provider)} ${l.oaLinkMasked(mail)}',
        key: const ValueKey('oauth-link-card'),
        tone: RefTone.warn,
        title: l.oaLinkTitle,
        actions: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RefLink(
              key: const ValueKey('oauth-link-email'),
              label: l.oaContinueEmail,
              color: context.bu.onWarnSoft,
              compact: true,
              onPressed: onEmail,
            ),
          ),
        ],
      ),
    );
  }
}

/// OAuth hata metni: SDK hatası ([OAuthFailure]) genel "giriş tamamlanamadı"; sunucu hataları [errorText].
String oauthErrorText(BuildContext context, Object? e) {
  if (e is OAuthFailure) return context.l10n.oaErrFailed;
  if (e == null) return context.l10n.oaErrFailed;
  return errorText(e);
}
