import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_widgets.dart';
import '../../core/typography.dart';

/// Şifremi unuttum, 3. adım: kod doğrulandıktan sonra yeni şifreyi belirle.
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({
    super.key,
    required this.session,
    required this.email,
    required this.resetToken,
  });

  final Session session;
  final String email;
  final String resetToken;

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.resetPassword(widget.email, widget.resetToken, _password.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((r) => r.isFirst);
      messenger.showSnackBar(const SnackBar(
        content: Text('Şifreniz güncellendi. Yeni şifrenizle giriş yapabilirsiniz.'),
      ));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'INVALID_CODE') {
        // Anahtarın süresi dolmuş: başa dön, yeni kod iste.
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).popUntil((r) => r.isFirst);
        messenger.showSnackBar(
            const SnackBar(content: Text('Süre doldu. Lütfen şifre sıfırlamayı baştan başlatın.')));
        return;
      }
      setState(() => _error = errorText(e));
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
      title: 'Yeni şifre belirleyin',
      subtitle: 'Hesabınız için yeni bir şifre seçin.',
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: context.bu.okSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(Icons.check_circle_outline, size: 18, color: context.bu.ok),
            const SizedBox(width: 10),
            Text('Kod doğrulandı',
                style: BuType.label.copyWith(color: context.bu.ok)),
          ]),
        ),
        if (_error != null) Notice(_error!),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _password,
                label: 'Yeni şifre (en az 8 karakter)',
                validator: validateNewPassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password2,
                label: 'Yeni şifre (tekrar)',
                validator: (v) => v != _password.text ? 'Şifreler eşleşmiyor.' : null,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: _save,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: BusyLabel(busy: _busy, label: 'Şifreyi güncelle'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
