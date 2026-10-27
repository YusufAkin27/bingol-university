import 'package:flutter/material.dart';

import '../../core/api.dart';
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
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        // Kod gönderilmemiş olabilir: yeniden gönderip doğrulama ekranına geç.
        try {
          await widget.session.resendCode(_email.text);
        } catch (_) {}
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) {
          return VerifyCodePage(session: widget.session, email: _email.text.trim());
        }));
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
      title: 'Hoş geldiniz',
      subtitle: 'Bingöl Üniversitesi hesabınızla giriş yapın.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) Notice(_error!),
                EmailField(controller: _email),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  validator: (v) => (v == null || v.isEmpty) ? 'Şifrenizi girin.' : null,
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
                                  initialEmail: _email.text.trim(),
                                ),
                              ),
                            ),
                    child: const Text('Şifremi unuttum',
                        style: BuType.bodyStrong),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: BusyLabel(busy: _busy, label: 'Giriş yap'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hesabınız yok mu?',
                style: BuType.body.copyWith(color: context.bu.mut)),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RegisterPage(session: widget.session)),
                      ),
              child: const Text('Kayıt ol'),
            ),
          ],
        ),
      ],
    );
  }
}
