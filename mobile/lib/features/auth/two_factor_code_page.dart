import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/two_factor.dart';
import '../../widgets/bu.dart';
import 'otp_code_boxes.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// Girişte ikinci adım: şifre doğru, e-postaya giden 6 haneli kod istenir. Challenge yalnız bellekte tutulur
/// (rota argümanı/kalıcı depo/günlük yok). Başarıda oturum açılır ve kimlik ekranları kapanır.
class TwoFactorLoginPage extends StatelessWidget {
  const TwoFactorLoginPage({super.key, required this.session, required this.challenge});

  final Session session;
  final TwoFactorChallenge challenge;

  static const routeName = 'two_factor_login';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hint = challenge.emailHint;
    return TwoFactorCodePage(
      semanticTitle: l.tfTitle,
      subtitle: hint.isEmpty ? l.tfLoginSubtitleNoMail : l.tfLoginSubtitle(hint),
      emphasis: hint.isEmpty ? null : hint,
      showTrust: true,
      verifyLabel: l.authVerify,
      backLabel: l.tfBackToLogin,
      verify: (code, trust) => session.loginTwoFactor(challenge, code, trustDevice: trust),
      resend: () => session.resendTwoFactor(challenge),
      // Oturum açıldı: kök ekran ana sayfaya geçer, kimlik ekranlarını kapat (e-posta doğrulamayla aynı kalıp).
      onSuccess: () => Navigator.of(context).popUntil((r) => r.isFirst),
      onExpired: () => Navigator.of(context).popUntil((r) => r.isFirst),
    );
  }
}

/// Ayarlardan açma: kod `POST /auth/2fa/enable/confirm` ile doğrulanır; başarıda `true` ile kapanır.
class TwoFactorEnablePage extends StatelessWidget {
  const TwoFactorEnablePage({super.key, required this.session, required this.api});

  final Session session;
  final TwoFactorApi api;

  static const routeName = 'two_factor_enable';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mail = session.email ?? '';
    return TwoFactorCodePage(
      semanticTitle: l.tfTitle,
      subtitle: mail.isEmpty ? l.tfEnableSubtitleNoMail : l.tfEnableSubtitle(mail),
      emphasis: mail.isEmpty ? null : mail,
      showTrust: false,
      verifyLabel: l.authVerify,
      backLabel: l.commonBack,
      verify: (code, _) => api.confirmEnable(code),
      resend: api.requestEnable,
      onSuccess: () => Navigator.of(context).pop(true),
      onExpired: () => Navigator.of(context).pop(false),
    );
  }
}

/// Altı haneli kod adımı (giriş ve açma için ortak): kod kutuları, yeniden gönderme geri sayımı, hata/başarı satırı.
/// "Bu cihaza güven" yalnız girişte ([showTrust]) ve VARSAYILAN KAPALI; kod tamamlanınca otomatik gönderildiği için
/// anahtar kutuların ÜSTÜNDEdir.
class TwoFactorCodePage extends StatefulWidget {
  const TwoFactorCodePage({
    super.key,
    required this.semanticTitle,
    required this.subtitle,
    required this.verify,
    required this.resend,
    required this.onSuccess,
    required this.onExpired,
    required this.verifyLabel,
    required this.backLabel,
    this.emphasis,
    this.showTrust = false,
    this.resendSeconds = 60,
  });

  /// Ekranda görünmez; ekran okuyucuya başlık olarak okunur.
  final String semanticTitle;
  final String subtitle;
  final String? emphasis;
  final bool showTrust;
  final String verifyLabel;

  /// Challenge süresi dolunca gösterilen düğmenin etiketi.
  final String backLabel;
  final int resendSeconds;

  /// Kodu doğrular; hata [ApiError] fırlatır.
  final Future<void> Function(String code, bool trust) verify;
  final Future<void> Function() resend;
  final VoidCallback onSuccess;

  /// Challenge geçersiz/süresi dolmuş: "geri dön" düğmesi.
  final VoidCallback onExpired;

  @override
  State<TwoFactorCodePage> createState() => _TwoFactorCodePageState();
}

class _TwoFactorCodePageState extends State<TwoFactorCodePage> {
  final _code = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  bool _trust = false;
  bool _busy = false;
  bool _ok = false;

  /// Challenge ölü (süre doldu / çok yanlış deneme): kod girişi kapanır, yalnız geri dönüş kalır.
  bool _expired = false;
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
    if (_busy || _expired || _ok) return;
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
      await widget.verify(_code.text, _trust);
      if (!mounted) return;
      // Başarı geri bildirimi: kutular yeşile döner (azalt açıkken beklemeden kapanır).
      setState(() => _ok = true);
      authHaptic(AuthHaptic.success);
      if (!BuMotion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 260));
      if (mounted) widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      _code.clear();
      if (e is ApiError && e.code == 'TWO_FACTOR_CHALLENGE_EXPIRED') {
        setState(() => _expired = true);
      }
      _fail(errorText(e));
      // Deneme sınırı: yeni kod beklemeden istenebilir.
      if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') _resendKey.currentState?.makeReady();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _expired) return;
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await widget.resend();
      if (!mounted) return;
      _code.clear();
      setState(() => _info = context.l10n.authNewCodeSent);
      _resendKey.currentState?.restart(widget.resendSeconds);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.code == 'TWO_FACTOR_CHALLENGE_EXPIRED') setState(() => _expired = true);
      _fail(errorText(e));
      // Yeniden gönderme sınırı (3 / 10 dk): geri sayım yeniden başlar.
      if (e is ApiError && e.status == 429) _resendKey.currentState?.restart(180);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final base = tx.bodyLarge!.copyWith(color: t.mut, height: 1.45);
    final e = widget.emphasis;
    final at = e == null ? -1 : widget.subtitle.indexOf(e);
    final Widget sub = at < 0
        ? Text(widget.subtitle, style: base)
        : Text.rich(TextSpan(style: base, children: [
            TextSpan(text: widget.subtitle.substring(0, at)),
            TextSpan(text: e, style: TextStyle(color: t.ink)),
            TextSpan(text: widget.subtitle.substring(at + e!.length)),
          ]));
    return RefPage(
      children: [
        const ExcludeSemantics(child: Align(alignment: AlignmentDirectional.centerStart, child: RefIconTile(BuIcons.shieldCheck, size: 56))),
        const SizedBox(height: 20),
        // Başlık görünmez: anlamsal etiket ekran okuyucuya başlık + açıklama olarak okunur.
        Semantics(
          header: true,
          label: '${widget.semanticTitle}. ${widget.subtitle}',
          excludeSemantics: true,
          child: sub,
        ),
        if (widget.showTrust) ...[
          const SizedBox(height: 24),
          _TrustRow(
            key: const ValueKey('tf-trust'),
            label: l.tfTrustLabel,
            hint: l.tfTrustHint,
            value: _trust,
            onChanged: _busy || _expired ? null : (v) => setState(() => _trust = v),
          ),
        ],
        const SizedBox(height: 24),
        OtpCodeBoxes(
          controller: _code,
          enabled: !_busy && !_expired,
          hasError: _error != null,
          success: _ok,
          shakeTrigger: _shake,
          onCompleted: _verify,
        ),
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.short),
          alignment: Alignment.topCenter,
          child: _error != null
              ? Padding(padding: const EdgeInsets.only(top: 16), child: RefPill(_error!, key: ValueKey('tf-error-$_error')))
              : _info != null
                  ? Padding(padding: const EdgeInsets.only(top: 16), child: RefPill(_info!, tone: RefTone.success))
                  : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 16),
        if (!_expired)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AuthResendRow(
              key: _resendKey,
              initialSeconds: widget.resendSeconds,
              onResend: _busy ? () {} : _resend,
              waitingLabel: (s) => l.authResendInTime('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'),
              resendLabel: l.authResendCode,
            ),
          ),
        const SizedBox(height: 24),
        if (_expired)
          RefButton(key: const ValueKey('tf-back'), label: widget.backLabel, onPressed: widget.onExpired)
        else
          RefButton(
            key: const ValueKey('tf-verify'),
            label: widget.verifyLabel,
            busy: _busy,
            onPressed: _verify,
          ),
      ],
    );
  }
}

/// "Bu cihaza güven" satırı: etiket + açıklama + anahtar; satırın tamamı dokunulabilir.
class _TrustRow extends StatelessWidget {
  const _TrustRow({super.key, required this.label, required this.hint, required this.value, required this.onChanged});

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: InkWell(
          borderRadius: BuRadius.bMd,
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: tx.bodyLarge!.copyWith(color: t.ink)),
                  const SizedBox(height: 2),
                  Text(hint, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
                ]),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(child: Switch(value: value, onChanged: onChanged)),
            ]),
          ),
        ),
      ),
    );
  }
}
