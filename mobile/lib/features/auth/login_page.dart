import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu_widgets.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/pending_verification.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'verify_code_page.dart';
import '../../core/typography.dart';

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

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
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
        setState(() => _error = errorText(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      minimal: true,
      title: context.l10n.loginWelcome,
      subtitle: context.l10n.loginSubtitle,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: widget.session.replacedNotice,
          builder: (context, show, _) => show
              ? Padding(
                  key: const ValueKey('replaced-notice'),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Stack(
                    children: [
                      Notice(
                        context.l10n.loginReplacedNotice,
                        error: false,
                      ),
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: IconButton(
                          key: const ValueKey('replaced-notice-close'),
                          tooltip: context.l10n.commonClose,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: widget.session.dismissReplacedNotice,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (_pending != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PendingBanner(pending: _pending!, onTap: () => _openVerify(_pending!.identifier)),
          ),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) Notice(_error!),
                IdentifierField(controller: _email),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  validator: (v) => (v == null || v.isEmpty) ? context.l10n.loginPasswordRequired : null,
                  onSubmitted: _submit,
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordPage(
                                  session: widget.session,
                                  initialEmail: normalizeIdentifier(_email.text),
                                ),
                              ),
                            ),
                    child: Text(context.l10n.loginForgotPassword,
                        style: BuType.bodyStrong),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: BusyLabel(busy: _busy, label: context.l10n.loginSubmit),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(context.l10n.loginNoAccount,
                style: BuType.body.copyWith(color: context.bu.mut)),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RegisterPage(session: widget.session)),
                      ),
              child: Text(context.l10n.loginRegister),
            ),
          ],
        ),
      ],
    );
  }
}

/// Doğrulaması yarım kalan kayıt için "Doğrulamayı tamamla" bandı.
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const ValueKey('pending-verify-banner'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(LucideIcons.mailCheck, color: t.onSoft, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.loginCompleteVerification, style: BuType.bodyStrong.copyWith(color: t.onSoft)),
                      Text(pending.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.caption.copyWith(color: t.onSoft)),
                    ],
                  ),
                ),
                Icon(buDirIcon(context, LucideIcons.chevronRight), color: t.onSoft, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
