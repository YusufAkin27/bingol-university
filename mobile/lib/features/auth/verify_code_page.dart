import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'otp_code_boxes.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// E-posta doğrulama (Stitch 02): 6 haneli kod, yeniden gönderme beklemesi, "E-postayı değiştir", spam ipucu.
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

  /// Girişte doğrulanmamış hesap ya da yarım kalan kayıt: bilgi bandı + "Başka hesapla giriş yap".
  final bool unverified;

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  // Kayıt şifresi bellekte yoksa (uygulama yeniden açıldı) parola kanıtı için kullanıcıdan istenir.
  late final bool _needsPassword =
      !widget.session.hasRememberedPassword(widget.email);
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
      await widget.session.verifyEmail(widget.email, _code.text,
          password: _needsPassword ? _password.text : null);
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
      if (e is ApiError && e.code == 'RESEND_COOLDOWN') {
        _resendKey.currentState?.restart();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final mail = widget.displayEmail ?? fullEmail(widget.email);
    return RefPage(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: RefIconTile(LucideIcons.mailCheck,
              bg: t.soft, fg: t.pr, radius: 16),
        ),
        const SizedBox(height: 16),
        RefHeading(
            title: l.authVerifyEmailTitle,
            subtitle: l.authVerifySubtitle(mail),
            emphasis: mail),
        if (widget.unverified) ...[
          const SizedBox(height: 16),
          RefBanner(l.authUnverifiedNotice, tone: RefTone.info),
        ],
        const SizedBox(height: 24),
        RefCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OtpCodeBoxes(
                controller: _code,
                enabled: !_busy,
                hasError: _error != null,
                shakeTrigger: _shake,
                onCompleted: _verify,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: RefPill(_error!, key: ValueKey('e$_error')))
                    : _info != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: RefPill(_info!, tone: RefTone.success))
                        : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: t.bd),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AuthResendRow(
                    key: _resendKey,
                    onResend: _busy ? () {} : _resend,
                    waitingLabel: (s) => l.authResendIn('$s'),
                    resendLabel: l.authResendCode,
                  ),
                  RefLink(
                      label: l.authChangeEmail,
                      onPressed:
                          _busy ? null : () => Navigator.maybePop(context)),
                ],
              ),
            ],
          ),
        ),
        if (_needsPassword) ...[
          const SizedBox(height: 16),
          RefCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.authVerifyPasswordNote,
                    style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
                const SizedBox(height: 12),
                RefPasswordField(
                  controller: _password,
                  label: l.authVerifyPasswordLabel,
                  onCard: true,
                  enabled: !_busy,
                  onSubmitted: _verify,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        RefNote(l.authTrustCode,
            icon: LucideIcons.lightbulb,
            title: l.p02TipTitle,
            iconTint: t.tint(1)),
        const SizedBox(height: 24),
        RefButton(
          label: l.authVerify,
          icon: buDirIcon(context, LucideIcons.arrowRight),
          busy: _busy,
          onPressed: _verify,
        ),
        if (widget.unverified)
          Center(
            child: RefLink(
              label: l.authUseOtherAccount,
              muted: true,
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),
      ],
    );
  }
}
