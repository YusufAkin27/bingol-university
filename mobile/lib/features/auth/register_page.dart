import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import 'auth_widgets.dart';
import 'verify_code_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.session});

  final Session session;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _terms = false;
  bool _termsError = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _termsError = !_terms);
    if (_busy || !valid || !_terms) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.register(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
      );
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) {
        return VerifyCodePage(session: widget.session, email: _email.text.trim());
      }));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AuthScaffold(
      showBack: true,
      title: 'Hesap oluştur',
      subtitle: 'Yalnızca bingol.edu.tr e-postasıyla kayıt olunur.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) Notice(_error!),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  maxLength: 80,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Adınızı ve soyadınızı girin.' : null,
                  style: TextStyle(color: t.ink, fontSize: 15),
                  decoration: authFieldDecoration(context, hint: 'Ad soyad', icon: LucideIcons.user)
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 14),
                EmailField(controller: _email),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  label: 'Şifre (en az 8 karakter)',
                  validator: validateNewPassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password2,
                  label: 'Şifre (tekrar)',
                  validator: (v) => v != _password.text ? 'Şifreler eşleşmiyor.' : null,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _terms,
                  onChanged: _busy ? null : (v) => setState(() {
                        _terms = v ?? false;
                        _termsError = false;
                      }),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: t.pr,
                  title: Text(
                    'Kullanım koşullarını, gizlilik politikasını, KVKK aydınlatma metnini ve topluluk kurallarını okudum, kabul ediyorum.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: _termsError ? t.danger : t.mut,
                    ),
                  ),
                  subtitle: _termsError
                      ? Text('Devam etmek için kabul etmelisiniz.',
                          style: TextStyle(color: t.danger, fontSize: 13))
                      : null,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: BusyLabel(busy: _busy, label: 'Kayıt ol'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Zaten hesabınız var mı?', style: TextStyle(color: t.mut, fontSize: 14)),
            TextButton(
              onPressed: _busy ? null : () => Navigator.maybePop(context),
              child: const Text('Giriş yap'),
            ),
          ],
        ),
      ],
    );
  }
}
