import 'dart:async';

import '../../core/locale_controller.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_widgets.dart';
import 'otp_code_boxes.dart';
import '../../core/typography.dart';

/// E-posta doğrulama: 6 haneli kod, 60 sn'lik yeniden gönderme beklemesi.
class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({
    super.key,
    required this.session,
    required this.email,
    this.displayEmail,
    this.unverified = false,
  });

  final Session session;

  /// Numara ya da e-posta (sunucuya olduğu gibi gider).
  final String email;

  /// Gösterilecek tam e-posta (yoksa [email]'den türetilir).
  final String? displayEmail;

  /// Girişte doğrulanmamış hesap ya da yarım kalan kayıt: bilgi kutusu + "Başka hesapla giriş yap".
  final bool unverified;

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
      setState(() => _info = context.l10n.authNewCodeSent);
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
      title: context.l10n.authVerifyEmailTitle,
      subtitle: context.l10n.authVerifySubtitle(widget.displayEmail ?? fullEmail(widget.email)),
      children: [
        if (widget.unverified) Notice(context.l10n.authUnverifiedNotice, error: false),
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
          child: BusyLabel(busy: _busy, label: context.l10n.authVerify),
        ),
        const SizedBox(height: 12),
        Center(
          child: _cooldown > 0
              ? Text(context.l10n.authNewCodeIn('$_cooldown'), style: BuType.body.copyWith(color: t.mut))
              : TextButton(onPressed: _busy ? null : _resend, child: Text(context.l10n.authResendCode)),
        ),
        if (widget.unverified)
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text(context.l10n.authUseOtherAccount),
            ),
          ),
      ],
    );
  }
}
