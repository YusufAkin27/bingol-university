import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'otp_code_boxes.dart';
import 'widgets/auth_art.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_fields.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_shell.dart';

/// E-posta doğrulama: 6 haneli kod, 60 sn'lik yeniden gönderme beklemesi (halka geri sayım).
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
  final _password = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  // Kayıt şifresi bellekte yoksa (uygulama yeniden açıldı) parola kanıtı için kullanıcıdan istenir.
  late final bool _needsPassword = !widget.session.hasRememberedPassword(widget.email);
  bool _busy = false;
  String? _error;
  String? _info;
  int _shake = 0;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
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
    if (_needsPassword && _password.text.isEmpty) {
      _fail(context.l10n.authVerifyPasswordRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.session.verifyEmail(widget.email, _code.text, password: _needsPassword ? _password.text : null);
      // Oturum açıldı: kök ekran ana sayfaya geçer, kimlik ekranlarını kapat.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        _fail(errorText(e));
        // Deneme sınırı: yeni kod beklemeden istenebilir.
        if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') {
          _code.clear();
          _resendKey.currentState?.makeReady();
        }
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
      await widget.session.resendCode(widget.email);
      if (!mounted) return;
      setState(() => _info = context.l10n.authNewCodeSent);
      _resendKey.currentState?.restart();
    } catch (e) {
      if (!mounted) return;
      _fail(errorText(e));
      if (e is ApiError && e.code == 'RESEND_COOLDOWN') _resendKey.currentState?.restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mail = widget.displayEmail ?? fullEmail(widget.email);
    return AuthShell(
      showBack: true,
      art: AuthArtKind.envelope,
      title: l.authVerifyEmailTitle,
      subtitle: l.authVerifySubtitle(mail),
      emphasis: mail,
      body: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.unverified) AuthBanner(l.authUnverifiedNotice, kind: AuthBannerKind.info),
            AuthFeedbackSlot(error: _error, info: _info, shake: _shake),
          ],
        ),
        OtpCodeBoxes(
          controller: _code,
          enabled: !_busy,
          hasError: _error != null,
          shakeTrigger: _shake,
          onCompleted: _verify,
        ),
        if (_needsPassword) ...[
          const SizedBox(height: 18),
          Text(l.authVerifyPasswordNote, style: BuType.caption.copyWith(color: context.bu.mut, height: 1.45, fontSize: 12.5)),
          const SizedBox(height: 10),
          AuthPasswordField(
            controller: _password,
            label: l.authVerifyPasswordLabel,
            enabled: !_busy,
            onSubmitted: _verify,
          ),
        ],
        const SizedBox(height: 8),
        AuthResendRow(
          key: _resendKey,
          onResend: _busy ? () {} : _resend,
          waitingLabel: (s) => l.authNewCodeIn('$s'),
          resendLabel: l.authResendCode,
        ),
        const SizedBox(height: 8),
        AuthTrustNote(l.authTrustCode, icon: LucideIcons.mailCheck),
      ],
      bottom: [
        AuthPrimaryButton(onPressed: _busy ? null : _verify, busy: _busy, label: l.authVerify),
        if (widget.unverified) ...[
          const SizedBox(height: 4),
          Center(
            child: AuthTextAction(
              label: l.authUseOtherAccount,
              muted: true,
              onPressed: _busy ? null : () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),
        ],
      ],
    );
  }
}
