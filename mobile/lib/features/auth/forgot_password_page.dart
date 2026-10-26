import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
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
          builder: (_) => ResetCodePage(session: widget.session, email: _email.text.trim()),
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
      title: 'Şifremi unuttum',
      subtitle: 'Okul e-postanızı girin, size sıfırlama kodu gönderelim.',
      children: [
        if (_error != null) Notice(_error!),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmailField(controller: _email, onSubmitted: _sendCode),
              const SizedBox(height: 16),
              const Notice('Adres kayıtlıysa 6 haneli bir kod göndeririz. Kod 10 dakika geçerlidir.',
                  error: false),
              FilledButton(
                onPressed: _busy ? null : _sendCode,
                child: BusyLabel(busy: _busy, label: 'Kod gönder'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text.rich(TextSpan(
            style: TextStyle(color: context.bu.mut, fontSize: 14),
            children: [
              const TextSpan(text: 'Hatırladınız mı? '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Text('Giriş yap',
                      style: TextStyle(
                          color: context.bu.pr, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          )),
        ),
      ],
    );
  }
}
