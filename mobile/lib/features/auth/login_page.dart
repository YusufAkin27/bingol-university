import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_gate.dart' show appVersion;
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/pending_verification.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'forgot_password_page.dart';
import 'help/about_page.dart';
import 'help/help_form_page.dart';
import 'register_page.dart';
import 'two_factor_code_page.dart';
import 'verify_code_page.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';
import 'widgets/login_underline_field.dart';

/// Calm, compact login with branded header and clearly bounded form controls.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session, this.initialEmail});

  final Session session;

  /// Oturumu dolan hesabı yeniden eklerken önceden doldurulan e-posta.
  final String? initialEmail;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  int _shake = 0;

  /// 429: bandın ikinci satırı ("40 sn sonra tekrar deneyin.").
  String? _retry;
  PendingVerification? _pending;

  @override
  void initState() {
    super.initState();
    final pre = widget.initialEmail;
    if (pre != null) _email.text = pre;
    _loadPending();
  }

  Future<void> _loadPending() async {
    final p = await widget.session.pending.load();
    if (mounted) setState(() => _pending = p);
  }

  Future<void> _openVerify(String identifier) async {
    await Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'verify_code'), builder: (_) {
      return VerifyCodePage(
          session: widget.session, email: identifier, unverified: true);
    }));
    if (mounted) _loadPending();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    authHaptic(AuthHaptic.error);
    final l = context.l10n;
    String? retry;
    var text = errorText(e);
    if (e is ApiError && e.status == 429 && !e.isNetwork && e.code != 'TWO_FACTOR_LOCKED') {
      // Başlık ile bekleme süresi ayrı satırlarda gösterilir.
      retry = retryAfterText(e.retryAfter, l);
      text = e.message.isNotEmpty ? e.message : l.coreErrTooMany;
    }
    setState(() {
      _error = text;
      _retry = retry;
      _shake++;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      authHaptic(AuthHaptic.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _retry = null;
    });
    try {
      final challenge = await widget.session.login(_email.text, _password.text);
      if (challenge != null) {
        // İki faktörlü doğrulama: şifre doğru, kod e-postaya gitti. Oturum henüz yok; kod adımı açılır.
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: TwoFactorLoginPage.routeName),
            builder: (_) => TwoFactorLoginPage(session: widget.session, challenge: challenge),
          ),
        );
        // Geri dönüldüyse (oturum açılmadıysa) şifre alanı temizlenir; yeniden giriş yeni kod üretir.
        if (mounted) _password.clear();
        return;
      }
      await widget.session.pending.clear();
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        // Kod gönderilmemiş olabilir: yeniden gönderip doğrulama ekranına geç.
        try {
          await widget.session.resendCode(_email.text);
        } on ApiError catch (re) {
          // 429: kod az önce gönderilmiş, doğrulama ekranı yeniden gönderme sayacını gösterir. Başka hata: kod
          // gitmeden kullanıcıyı bekleyen bir ekrana düşürme, nedeni göster.
          if (re.status != 429) {
            if (mounted) _fail(re);
            return;
          }
        } catch (re) {
          if (mounted) _fail(re);
          return;
        }
        if (!mounted) return;
        final id = normalizeIdentifier(_email.text);
        widget.session.rememberCredentials(id, _password.text);
        await widget.session.pending.save(id);
        if (!mounted) return;
        await _openVerify(id);
      } else {
        _fail(e);
      }
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgot() => Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: kForgotPasswordRoute),
          builder: (_) => ForgotPasswordPage(
              session: widget.session,
              initialEmail: normalizeIdentifier(_email.text)),
        ),
      );

  Future<void> _otherAccount() async {
    await widget.session.pending.clear();
    if (mounted) setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return RefPage(
      showBack: Navigator.canPop(context),
      children: [
        // Keep notice slots mounted so the form retains its state.
        ValueListenableBuilder<bool>(
          valueListenable: widget.session.replacedNotice,
          builder: (context, show, _) => AnimatedSize(
            duration: AppMotion.of(context, AppMotion.normal),
            curve: AppMotion.enter,
            alignment: Alignment.topCenter,
            child: show
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RefBanner(
                      l.loginReplacedNotice,
                      key: const ValueKey('replaced-notice'),
                      tone: RefTone.warn,
                      title: l.p02ReplacedTitle,
                      closeKey: const ValueKey('replaced-notice-close'),
                      onClose: widget.session.dismissReplacedNotice,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.normal),
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: _pending == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  // İki METİN düğmesi (altı çizgisiz), ikon yok.
                  child: RefBanner(
                    l.p02PendingBody,
                    tone: RefTone.warn,
                    title: l.p02PendingTitle,
                    actions: [
                      Wrap(
                        spacing: 16,
                        children: [
                          RefLink(
                            key: const ValueKey('pending-verify-banner'),
                            label: l.loginCompleteVerification,
                            color: t.onWarnSoft,
                            compact: true,
                            onPressed: () => _openVerify(_pending!.identifier),
                          ),
                          RefLink(
                              label: l.authUseOtherAccount,
                              color: t.onWarnSoft,
                              compact: true,
                              onPressed: _otherAccount),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        BuStaggerItem(
          index: 0,
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Marka satırı: küçük karo + kelime işareti; klavye açılınca sayfa yer açsın diye kapanır.
                  AnimatedSize(
                    duration: AppMotion.of(context, AppMotion.normal),
                    curve: AppMotion.enter,
                    alignment: Alignment.topCenter,
                    child: keyboard
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 40),
                            child: Row(
                              children: [
                                // Marka logosu: tema duyarlı BÜ (koyu: beyaz, açık: siyah glif).
                                const BuLogo(width: 56, semanticLabel: null),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('BÜ Kampüs',
                                          style: tx.titleLarge!.copyWith(
                                              color: t.ink,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: -.5)),
                                      const SizedBox(height: 3),
                                      Text(l.oaUniversityName,
                                          style: tx.bodySmall!
                                              .copyWith(color: t.mut)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  Semantics(
                    header: true,
                    child: Text(
                      l.loginWelcome,
                      style: tx.headlineLarge!.copyWith(
                          color: t.ink,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -1,
                          height: 1.15),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(l.loginSubtitleNumber,
                      style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
                  SizedBox(height: keyboard ? 24 : 32),
                  // E-posta (her sağlayıcı); yazılan aynen gider, istemci alan adı eklemez.
                  LoginIdentifierField(
                      controller: _email, enabled: !_busy),
                  const SizedBox(height: 28),
                  LoginPasswordField(
                    controller: _password,
                    enabled: !_busy,
                    validator: (v) => (v == null || v.isEmpty)
                        ? l.loginPasswordRequired
                        : null,
                    onSubmitted: _submit,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: RefLink(
                        label: l.loginForgotPassword,
                        compact: true,
                        onPressed: _busy ? null : _forgot),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: RefButton(
                      label: l.loginSubmit,
                      icon: buDirIcon(context, BuIcons.arrowRight),
                      busy: _busy,
                      busyLabel: l.p02LoginBusy,
                      onPressed: _submit,
                    ),
                  ),
                  AnimatedSize(
                    duration: AppMotion.of(context, AppMotion.fast),
                    curve: AppMotion.enter,
                    alignment: Alignment.topCenter,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            // Yeni hatada metin hafifçe sarsılır (azalt açıkken sarsılmaz).
                            child: AuthShake(
                              trigger: _shake,
                              child: _retry != null
                                  ? RefBanner(_error!,
                                      key: ValueKey('login-error-$_error'),
                                      tone: RefTone.warn,
                                      sub: _retry)
                                  : RefBanner(_error!,
                                      key: ValueKey('login-error-$_error')),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // "Kayıt ol" her zaman görünür (klavye açıkken de): yeni kullanıcı yolu gizlenmez. Yardım ve sürüm satırı yalnız
        // klavye kapalıyken gösterilir.
        BuStaggerItem(
          index: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.normal),
                curve: AppMotion.enter,
                height: keyboard ? 20 : 28,
              ),
              Center(
                child: RefFooterPrompt(
                  prompt: l.loginNoAccount,
                  action: l.loginRegister,
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              settings: const RouteSettings(name: 'register'),
                              builder: (_) =>
                                  RegisterPage(session: widget.session))),
                ),
              ),
              AnimatedSize(
                duration: AppMotion.of(context, AppMotion.normal),
                curve: AppMotion.enter,
                alignment: Alignment.topCenter,
                child: keyboard
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 12),
                            child: Divider(height: 1, color: t.bd),
                          ),
                          Center(
                            child: RefFooterPrompt(
                              prompt: l.p66HelpPrompt,
                              action: l.p66HelpAction,
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          settings: const RouteSettings(name: 'help_form'),
                                          builder: (_) => HelpFormPage(
                                              session: widget.session))),
                            ),
                          ),
                          // Sürüm satırına dokunmak Hakkında'yı açar (giriş öncesi herkese açık).
                          Center(
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          settings: const RouteSettings(name: 'about'),
                                          builder: (_) => AboutPage(
                                              session: widget.session))),
                              style: TextButton.styleFrom(
                                  foregroundColor: t.mut,
                                  minimumSize: const Size(48, 48)),
                              child: Text(l.profileVersion(appVersion),
                                  style: tx.bodySmall!.copyWith(color: t.mut)),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
