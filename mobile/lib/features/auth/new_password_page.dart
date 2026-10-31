import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import 'auth_widgets.dart' show newPasswordValidator;
import 'forgot_password_page.dart';
import 'reset_success_page.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// Şifremi unuttum, 3. adım (Stitch 03): kod doğrulandıktan sonra yeni şifre + tekrarı. Başarıda onay ekranı açılır.
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
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _fail(String m) {
    authHaptic(AuthHaptic.error);
    setState(() => _error = m);
  }

  Future<void> _save() async {
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
      await widget.session.resetPassword(widget.email, widget.resetToken, _password.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ResetSuccessPage()));
      return;
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'INVALID_CODE') {
        // Anahtarın süresi dolmuş: "Şifremi unuttum" ekranına dön, "Süre doldu" bandıyla yeni kod iste.
        ForgotPasswordPage.expiredNotice.value = true;
        Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == kForgotPasswordRoute);
        return;
      }
      _fail(errorText(e));
    } catch (e) {
      if (mounted) _fail(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final validate = newPasswordValidator(context);
    return RefPage(
      children: [
        RefHeading(title: l.authNewPasswordTitle, subtitle: l.authNewPwSub),
        const SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.zero,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  RefBanner(_error!, key: ValueKey('np-error-$_error')),
                  const SizedBox(height: 16),
                ],
                RefPasswordField(
                  controller: _password,
                  label: l.authNewPasswordLabel,
                  onCard: true,
                  enabled: !_busy,
                  validator: validate,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _password,
                  builder: (_, v, __) => AuthPasswordGuide(password: v.text),
                ),
                const SizedBox(height: 18),
                RefPasswordField(
                  controller: _repeat,
                  label: l.profil2SecRepeatLabel,
                  onCard: true,
                  enabled: !_busy,
                  validator: (v) => (v ?? '') == _password.text ? null : l.profil2SecMismatch,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: _save,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        RefButton(
          label: l.authUpdatePassword,
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}
