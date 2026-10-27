import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import 'auth_widgets.dart';

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
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
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
        content: Text('Şifre güncellendi.'),
      ));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'INVALID_CODE') {
        // Anahtarın süresi dolmuş: başa dön, yeni kod iste.
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).popUntil((r) => r.isFirst);
        messenger.showSnackBar(
            const SnackBar(content: Text('Süre doldu. Baştan başlayın.')));
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
      title: 'Yeni şifre',
      children: [
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
