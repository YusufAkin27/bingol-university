import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import 'new_password_page.dart';
import 'otp_code_boxes.dart';
import 'widgets/auth_art.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_shell.dart';

/// Şifremi unuttum, 2. adım: kodu doğrula. Doğruysa yeni şifre ekranına geçilir.
class ResetCodePage extends StatefulWidget {
  const ResetCodePage({super.key, required this.session, required this.email});

  final Session session;
  final String email;

  @override
  State<ResetCodePage> createState() => _ResetCodePageState();
}

class _ResetCodePageState extends State<ResetCodePage> {
  final _code = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  bool _busy = false;
  String? _error;
  String? _info;
  int _shake = 0;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _fail(String m) {
    authHaptic(AuthHaptic.error);
    setState(() {
      _error = m;
      _info = null;
      _shake++;
    });
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != 6) {
      _fail(context.l10n.authRestEnterCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final token = await widget.session.verifyResetCode(widget.email, _code.text);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordPage(session: widget.session, email: widget.email, resetToken: token),
        ),
      );
    } catch (e) {
      if (mounted) {
        _fail(errorText(e));
        _code.clear();
        // Deneme sınırı aşıldıysa beklemeden yeni kod istenebilir.
        if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') _resendKey.currentState?.makeReady();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await widget.session.forgotPassword(widget.email);
      if (!mounted) return;
      setState(() => _info = context.l10n.authCodeSent);
      _resendKey.currentState?.restart();
    } catch (e) {
      if (mounted) _fail(errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mail = fullEmail(widget.email);
    return AuthShell(
      showBack: true,
      step: 1,
      stepLabel: l.authStepOf('2', '3'),
      art: AuthArtKind.envelope,
      title: l.authEnterCode,
      subtitle: l.authCodeSentTo(mail),
      emphasis: mail,
      body: [
        AuthFeedbackSlot(error: _error, info: _info, shake: _shake),
        OtpCodeBoxes(
          controller: _code,
          enabled: !_busy,
          hasError: _error != null,
          shakeTrigger: _shake,
          onCompleted: _verify,
        ),
        const SizedBox(height: 10),
        AuthResendRow(
          key: _resendKey,
          onResend: _busy ? () {} : _resend,
          waitingLabel: (s) => l.authResendIn('$s'),
          resendLabel: l.authResendCode,
        ),
      ],
      bottom: [
        AuthPrimaryButton(onPressed: _busy ? null : _verify, busy: _busy, label: l.authVerify),
        const SizedBox(height: 4),
        Center(child: AuthTextAction(label: l.authChangeEmail, muted: true, onPressed: _busy ? null : () => Navigator.maybePop(context))),
      ],
    );
  }
}
