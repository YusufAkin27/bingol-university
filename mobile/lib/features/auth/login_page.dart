import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/pending_verification.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'verify_code_page.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_fields.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_shell.dart';
import 'widgets/auth_sheets.dart';

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

  void _fail(String message) {
    authHaptic(AuthHaptic.error);
    setState(() {
      _error = message;
      _shake++;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      authHaptic(AuthHaptic.error);
      setState(() => _shake++);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
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
        _fail(errorText(e));
      }
    } catch (e) {
      if (mounted) _fail(errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgot() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForgotPasswordPage(session: widget.session, initialEmail: normalizeIdentifier(_email.text)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AuthShell(
      title: l.loginWelcome,
      subtitle: l.loginSubtitle,
      trailing: const AuthLanguageButton(),
      body: [
        // Bildirimler tek kapta: yuva her zaman ağaçta (alt öğelerin durumu korunur).
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: widget.session.replacedNotice,
              builder: (context, show, _) => AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: show
                    ? AuthBanner(
                        l.loginReplacedNotice,
                        key: const ValueKey('replaced-notice'),
                        kind: AuthBannerKind.info,
                        icon: LucideIcons.shieldAlert,
                        closeKey: const ValueKey('replaced-notice-close'),
                        onClose: widget.session.dismissReplacedNotice,
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
                      child: _PendingBanner(pending: _pending!, onTap: () => _openVerify(_pending!.identifier)),
                    ),
            ),
            AuthFeedbackSlot(error: _error, shake: _shake),
          ],
        ),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthIdentifierField(controller: _email, enabled: !_busy),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _password,
                  enabled: !_busy,
                  validator: (v) => (v == null || v.isEmpty) ? l.loginPasswordRequired : null,
                  onSubmitted: _submit,
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AuthTextAction(label: l.loginForgotPassword, onPressed: _busy ? null : _forgot),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        AuthTrustNote(l.authTrustSecure, icon: LucideIcons.lockKeyhole),
      ],
      bottom: [
        AuthPrimaryButton(onPressed: _busy ? null : _submit, busy: _busy, label: l.loginSubmit),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: keyboard
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AuthFooterPrompt(
                    prompt: l.loginNoAccount,
                    action: l.loginRegister,
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterPage(session: widget.session))),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Doğrulaması yarım kalan kayıt için "Doğrulamayı tamamla" kartı.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.pending, required this.onTap});

  final PendingVerification pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: context.l10n.loginCompleteVerification,
      child: Material(
        color: t.soft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const ValueKey('pending-verify-banner'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(13)),
                  child: Icon(LucideIcons.mailCheck, color: t.pr, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.loginCompleteVerification,
                          style: BuType.bodyStrong.copyWith(color: t.onSoft, fontWeight: FontWeight.w800, fontSize: 14.5)),
                      const SizedBox(height: 1),
                      Text(pending.email,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.onSoft, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(buDirIcon(context, LucideIcons.chevronRight), color: t.onSoft, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
