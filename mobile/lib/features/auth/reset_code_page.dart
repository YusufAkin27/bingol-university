import 'dart:async';

import '../../core/locale_controller.dart';
import 'package:flutter/material.dart';

import '../../core/identifier.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_widgets.dart';
import 'otp_code_boxes.dart';
import 'new_password_page.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

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
  bool _busy = false;
  String? _error;
  String? _info;
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != 6) {
      setState(() => _error = context.l10n.authRestEnterCode);
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
          builder: (_) => NewPasswordPage(
            session: widget.session,
            email: widget.email,
            resetToken: token,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = errorText(e));
        _code.clear();
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
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AuthScaffold(
      showBack: true,
      icon: LucideIcons.mail,
      title: context.l10n.authEnterCode,
      subtitle: context.l10n.authCodeSentTo(fullEmail(widget.email)),
      children: [
        if (_error != null) Notice(_error!),
        if (_info != null) Notice(_info!, error: false),
        OtpCodeBoxes(
          controller: _code,
          enabled: !_busy,
          hasError: _error != null,
          onCompleted: _verify,
        ),
        const SizedBox(height: 14),
        Center(
          child: _cooldown > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(context.l10n.authResendIn('$_cooldown'), style: BuType.body.copyWith(color: t.mut)),
                )
              : TextButton(onPressed: _busy ? null : _resend, child: Text(context.l10n.authResendCode)),
        ),
        const SizedBox(height: 4),
        AuthButton(onPressed: _busy ? null : _verify, busy: _busy, label: context.l10n.authVerify),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => Navigator.maybePop(context),
            child: Text(context.l10n.authChangeEmail, style: BuType.bodyStrong),
          ),
        ),
      ],
    );
  }
}
