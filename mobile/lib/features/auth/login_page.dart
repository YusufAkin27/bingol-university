import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_gate.dart' show appVersion;
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/pending_verification.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'forgot_password_page.dart';
import 'help/about_page.dart';
import 'help/help_form_page.dart';
import 'register_page.dart';
import 'verify_code_page.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';
import 'widgets/login_grouped_form.dart';

/// Giriş (lg1, iOS Ayarlar / Apple ID düzeni): sol üstte büyük başlık, tek yuvarlak gruplu kart içinde iki satır
/// (okul numarası | şifre), sayfa altına sabit tam genişlik düğme (klavye açılınca onunla yükselir), sakin alt
/// bağlantılar. Üstte bekleyen doğrulama ve "başka cihazdan giriş" bantları; hız sınırı ve ağ hataları satır içi
/// bantla gösterilir.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final Session session;

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
    _loadPending();
  }

  Future<void> _loadPending() async {
    final p = await widget.session.pending.load();
    if (mounted) setState(() => _pending = p);
  }

  Future<void> _openVerify(String identifier) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) {
      return VerifyCodePage(session: widget.session, email: identifier, unverified: true);
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
    if (e is ApiError && e.status == 429 && !e.isNetwork) {
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
      await widget.session.login(_email.text, _password.text);
      await widget.session.pending.clear();
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        // Kod gönderilmemiş olabilir: yeniden gönderip doğrulama ekranına geç.
        try {
          await widget.session.resendCode(_email.text);
        } catch (_) {}
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
          builder: (_) => ForgotPasswordPage(session: widget.session, initialEmail: normalizeIdentifier(_email.text)),
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
    // Kısa ekran / büyük yazıda sabit alt bölüm gövdeyi ezmesin: bağlantılar kaydırılan içeriğin sonuna geçer.
    final mq = MediaQuery.of(context);
    final inlineLinks = mq.size.height / mq.textScaler.scale(1) < 660;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: BuSize.appBar,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Navigator.canPop(context)
                      ? Semantics(
                          button: true,
                          label: l.authBack,
                          excludeSemantics: true,
                          onTap: () => Navigator.maybePop(context),
                          child: IconButton(
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            icon: Icon(buDirIcon(context, BuIcons.arrowLeft), color: t.ink, size: 24),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsetsDirectional.fromSTEB(kRefPad, 0, kRefPad, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: BuStaggerScope(child: _content(context, t, l, tx, inlineLinks && !keyboard)),
                  ),
                ),
              ),
            ),
            // Sabit alt bölüm: düğme sayfa altında durur; klavye açılınca (Scaffold gövdeyi küçültür) onunla yükselir.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(kRefPad, 8, kRefPad, keyboard ? 12 : 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RefButton(
                        label: l.loginSubmit,
                        busy: _busy,
                        busyLabel: l.p02LoginBusy,
                        onPressed: _submit,
                      ),
                      AnimatedSize(
                        duration: AppMotion.of(context, AppMotion.normal),
                        curve: AppMotion.enter,
                        alignment: Alignment.topCenter,
                        child: keyboard || inlineLinks ? const SizedBox(width: double.infinity) : _quietLinks(context, t, l, tx),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, BuTokens t, AppLocalizations l, TextTheme tx, bool withLinks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Yuva her zaman ağaçta (alt öğelerin durumu korunur).
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
                          RefLink(label: l.authUseOtherAccount, color: t.onWarnSoft, compact: true, onPressed: _otherAccount),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        BuStaggerItem(
          index: 0,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, top: 4, bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Marka satırı: küçük karo + "BÜ Kampüs" (ikincil renk); büyük başlığın üstünde sakin bir imza.
                Row(
                  children: [
                    const RefBrandMark(size: 28),
                    const SizedBox(width: 10),
                    Flexible(child: Text('BÜ Kampüs', style: tx.titleSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    l.loginWelcome,
                    style: tx.headlineMedium!.copyWith(color: t.ink, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -.4, height: 1.15),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.loginSubtitleNumber, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.4)),
              ],
            ),
          ),
        ),
        BuStaggerItem(
          index: 1,
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LoginGroupedFields(
                    idController: _email,
                    passwordController: _password,
                    enabled: !_busy,
                    onSubmitted: _submit,
                    passwordValidator: (v) => (v == null || v.isEmpty) ? l.loginPasswordRequired : null,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: RefLink(label: l.loginForgotPassword, compact: true, onPressed: _busy ? null : _forgot),
                    ),
                  ),
                  AnimatedSize(
                    duration: AppMotion.of(context, AppMotion.fast),
                    curve: AppMotion.enter,
                    alignment: Alignment.topCenter,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            // Yeni hatada metin hafifçe sarsılır (azalt açıkken sarsılmaz).
                            child: AuthShake(
                              trigger: _shake,
                              child: _retry != null
                                  ? RefBanner(_error!, key: ValueKey('login-error-$_error'), tone: RefTone.warn, sub: _retry)
                                  : RefBanner(_error!, key: ValueKey('login-error-$_error')),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (withLinks) Padding(padding: const EdgeInsets.only(top: 16), child: _quietLinks(context, t, l, tx)),
      ],
    );
  }

  /// Sakin, küçük alt bağlantılar: kayıt, yardım, sürüm (sürüm → Hakkında). Klavye açıkken gizlenir.
  Widget _quietLinks(BuildContext context, BuTokens t, AppLocalizations l, TextTheme tx) {
    Widget link(String prompt, String action, VoidCallback? onTap) => Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(prompt, style: tx.bodySmall!.copyWith(color: t.mut)),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                foregroundColor: t.prPressed,
              ),
              child: Text(action, style: tx.bodySmall!.copyWith(color: t.prPressed, fontWeight: FontWeight.w700)),
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        link(l.loginNoAccount, l.loginRegister,
            _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterPage(session: widget.session)))),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            link(l.p66HelpPrompt, l.p66HelpAction,
                _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => HelpFormPage(session: widget.session)))),
            // Sürüm satırına dokunmak Hakkında'yı açar (giriş öncesi herkese açık).
            TextButton(
              onPressed: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AboutPage(session: widget.session))),
              style: TextButton.styleFrom(foregroundColor: t.mut, minimumSize: const Size(48, 48)),
              child: Text(l.profileVersion(appVersion), style: tx.bodySmall!.copyWith(color: t.mut)),
            ),
          ],
        ),
      ],
    );
  }
}
