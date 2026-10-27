import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/identifier.dart';
import '../../core/session.dart';
import 'auth_widgets.dart';
import 'reset_code_page.dart';

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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy || !_form.currentState!.validate()) return;
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
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: context.l10n.authResetTitle,
      children: [
        if (_error != null) Notice(_error!),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IdentifierField(controller: _email, onSubmitted: _sendCode),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _sendCode,
                child: BusyLabel(busy: _busy, label: context.l10n.authSendCode),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
