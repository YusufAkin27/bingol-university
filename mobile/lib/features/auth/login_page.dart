import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_gate.dart' show appVersion;
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/pending_verification.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'verify_code_page.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// Giriş (Stitch 01): beyaz kart içinde e-posta/okul numarası + şifre; üstte bekleyen doğrulama ve
/// "başka cihazdan giriş" bantları; hız sınırı ve ağ hataları satır içi bantla gösterilir.
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
    return RefPage(
      showBack: Navigator.canPop(context),
      children: [
        // Yuva her zaman ağaçta (alt öğelerin durumu korunur).
        ValueListenableBuilder<bool>(
          valueListenable: widget.session.replacedNotice,
          builder: (context, show, _) => AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: show
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RefBanner(
                      l.loginReplacedNotice,
                      key: const ValueKey('replaced-notice'),
                      tone: RefTone.info,
                      icon: LucideIcons.smartphone,
                      title: l.p02ReplacedTitle,
                      closeKey: const ValueKey('replaced-notice-close'),
                      onClose: widget.session.dismissReplacedNotice,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _pending == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: RefBanner(
                    l.p02PendingBody,
                    tone: RefTone.warn,
                    icon: LucideIcons.mailCheck,
                    title: l.p02PendingTitle,
                    actions: [
                      RefButton(
                        key: const ValueKey('pending-verify-banner'),
                        label: l.loginCompleteVerification,
                        kind: RefButtonKind.warn,
                        icon: buDirIcon(context, LucideIcons.arrowRight),
                        onPressed: () => _openVerify(_pending!.identifier),
                      ),
                      Center(child: RefLink(label: l.authUseOtherAccount, color: t.onWarnSoft, onPressed: _otherAccount)),
                    ],
                  ),
                ),
        ),
        BuStaggerItem(
          index: 0,
          child: RefCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Klavye açılınca marka bloğu yumuşakça daralır (düzen sıçramaz, alanlar görünür kalır).
                    AnimatedSize(
                      duration: BuMotion.of(context, BuMotion.medium),
                      curve: BuMotion.decelerate,
                      alignment: Alignment.topCenter,
                      child: keyboard
                          ? const SizedBox(width: double.infinity)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Center(child: RefBrandMark(size: 64, badge: true)),
                                const SizedBox(height: 10),
                                Text(l.p02BrandSub,
                                    textAlign: TextAlign.center,
                                    style: tx.labelMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 14),
                              ],
                            ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(l.loginWelcome,
                          textAlign: TextAlign.center, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 6),
                    Text(l.loginSubtitle, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
                    const SizedBox(height: 24),
                    RefIdentifierField(controller: _email, enabled: !_busy, onCard: true),
                    const SizedBox(height: 18),
                    RefPasswordField(
                      controller: _password,
                      onCard: true,
                      enabled: !_busy,
                      hint: l.loginPasswordRequired.replaceAll(RegExp(r'\.$'), ''),
                      validator: (v) => (v == null || v.isEmpty) ? l.loginPasswordRequired : null,
                      onSubmitted: _submit,
                      labelAction: RefLink(label: l.loginForgotPassword, compact: true, onPressed: _busy ? null : _forgot),
                    ),
                    const SizedBox(height: 22),
                    RefButton(
                      label: l.loginSubmit,
                      icon: buDirIcon(context, LucideIcons.arrowRight),
                      busy: _busy,
                      busyLabel: l.p02LoginBusy,
                      onPressed: _submit,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: RefBanner(
                                _error!,
                                key: ValueKey('login-error-$_error'),
                                icon: _retry != null ? LucideIcons.triangleAlert : LucideIcons.circleAlert,
                                sub: _retry,
                                subIcon: LucideIcons.hourglass,
                                onClose: () => setState(() {
                                  _error = null;
                                  _retry = null;
                                }),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.medium),
          curve: BuMotion.decelerate,
          alignment: Alignment.topCenter,
          child: keyboard
              ? const SizedBox(width: double.infinity)
              : BuStaggerItem(
                  index: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: RefFooterPrompt(
                          prompt: l.loginNoAccount,
                          action: l.loginRegister,
                          onPressed: _busy
                              ? null
                              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterPage(session: widget.session))),
                        ),
                      ),
                      Center(
                        child: Text(l.profileVersion(appVersion), style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
