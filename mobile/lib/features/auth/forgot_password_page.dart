import 'package:flutter/material.dart';

import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import 'reset_code_page.dart';
import 'widgets/auth_art.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_fields.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_shell.dart';

/// Şifremi unuttum, 1. adım: e-posta gir, kod gönder. Sonra kod doğrulama ekranına geçer.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.session, this.initialEmail = ''});

  final Session session;
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _error;
  int _shake = 0;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      authHaptic(AuthHaptic.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.forgotPassword(_email.text);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetCodePage(session: widget.session, email: normalizeIdentifier(_email.text)),
        ),
      );
    } catch (e) {
      if (mounted) {
        authHaptic(AuthHaptic.error);
        setState(() {
          _error = errorText(e);
          _shake++;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthShell(
      showBack: true,
      step: 0,
      stepLabel: l.authStepOf('1', '3'),
      art: AuthArtKind.key,
      title: l.authResetTitle,
      subtitle: l.authForgotSub,
      body: [
        AuthFeedbackSlot(error: _error, shake: _shake),
        Form(
          key: _form,
          child: AuthIdentifierField(controller: _email, enabled: !_busy, textInputAction: TextInputAction.done, onSubmitted: _sendCode),
        ),
      ],
      bottom: [
        AuthPrimaryButton(onPressed: _busy ? null : _sendCode, busy: _busy, label: l.authSendCode),
        const SizedBox(height: 4),
        Center(child: AuthTextAction(label: l.authBackToLogin, muted: true, onPressed: _busy ? null : () => Navigator.maybePop(context))),
      ],
    );
  }
}
