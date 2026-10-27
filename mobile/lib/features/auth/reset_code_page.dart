import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/identifier.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_widgets.dart';
import 'otp_code_boxes.dart';
import 'new_password_page.dart';
import '../../core/typography.dart';

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
      setState(() => _error = '6 haneli kodu girin.');
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
      setState(() => _info = 'Kod gönderildi.');
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
      title: 'Kodu girin',
      subtitle: '${fullEmail(widget.email)} adresine kod gönderildi.',
      children: [
        if (_error != null) Notice(_error!),
        if (_info != null) Notice(_info!, error: false),
        OtpCodeBoxes(
          controller: _code,
          enabled: !_busy,
          hasError: _error != null,
          onCompleted: _verify,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: BusyLabel(busy: _busy, label: 'Doğrula'),
        ),
        const SizedBox(height: 8),
        Center(
          child: _cooldown > 0
              ? Text('Yeniden gönder ($_cooldown sn)', style: BuType.body.copyWith(color: t.mut))
              : TextButton(onPressed: _busy ? null : _resend, child: const Text('Kodu yeniden gönder')),
        ),
      ],
    );
  }
}
