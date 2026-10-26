import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_widgets.dart';
import 'otp_code_boxes.dart';

/// E-posta doğrulama: 6 haneli kod, 60 sn'lik yeniden gönderme beklemesi.
class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({super.key, required this.session, required this.email});

  final Session session;
  final String email;

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
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

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
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
      await widget.session.verifyEmail(widget.email, _code.text);
      // Oturum açıldı: kök ekran ana sayfaya geçer, kimlik ekranlarını kapat.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
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
      await widget.session.resendCode(widget.email);
      if (!mounted) return;
      setState(() => _info = 'Yeni kod gönderildi.');
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
      if (e is ApiError && e.code == 'RESEND_COOLDOWN') _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AuthScaffold(
      showBack: true,
      title: 'E-postanızı doğrulayın',
      subtitle: '${widget.email} adresine 6 haneli bir kod gönderdik. Kod 10 dakika geçerlidir.',
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
        const SizedBox(height: 12),
        Center(
          child: _cooldown > 0
              ? Text.rich(TextSpan(style: TextStyle(color: t.mut, fontSize: 14), children: [
                  const TextSpan(text: 'Yeni kod için '),
                  TextSpan(text: '$_cooldown sn', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' bekleyin'),
                ]))
              : TextButton(onPressed: _busy ? null : _resend, child: const Text('Kodu yeniden gönder')),
        ),
      ],
    );
  }
}
