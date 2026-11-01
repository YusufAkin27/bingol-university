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

/// Kod ekranından girişe dönüş nedeni.
enum TwoFactorExit {
  /// Kod/oturum anahtarı süresi doldu ya da deneme hakkı bitti: giriş baştan yapılmalı.
  expired,
}

/// Giriş kodu (iki adımlı doğrulama): `POST /auth/login` 202 döndüğünde açılır. 6 haneli kod e-postaya gitmiştir;
/// doğru kod oturumu açar (kök ekran ana sayfaya geçer). "Bu cihaza güven" açıkken cihaz güvenilir olur.
class TwoFactorLoginPage extends StatefulWidget {
  const TwoFactorLoginPage({super.key, required this.session, required this.challenge});

  final Session session;
  final TwoFactorChallenge challenge;

  @override
  State<TwoFactorLoginPage> createState() => _TwoFactorLoginPageState();
}

class _TwoFactorLoginPageState extends State<TwoFactorLoginPage> {
  final _code = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  bool _busy = false;
  bool _trust = true;
  String? _error;
  String? _info;
  int _shake = 0;

  /// Kod doğrulandı: kutular kısa süre yeşil gösterilir, sonra ekran kapanır.
  bool _ok = false;

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

  /// Anahtar süresi doldu: giriş ekranına dön (orada bilgi bandı gösterilir).
  void _expired() {
    authHaptic(AuthHaptic.error);
    Navigator.of(context).pop(TwoFactorExit.expired);
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
      await widget.session.loginTwoFactor(widget.challenge.token, _code.text, trustDevice: _trust);
      if (!mounted) return;
      setState(() => _ok = true);
      authHaptic(AuthHaptic.success);
      if (!BuMotion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 260));
      // Oturum açıldı: kök ekran ana sayfaya geçer, kimlik ekranlarını kapat.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.code == 'TWO_FACTOR_CHALLENGE_EXPIRED') {
        _expired();
        return;
      }
      _fail(errorText(e));
      _code.clear();
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
      await widget.session.resendTwoFactor(widget.challenge.token);
      if (!mounted) return;
      setState(() => _info = context.l10n.authNewCodeSent);
      _resendKey.currentState?.restart();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiError && e.code == 'TWO_FACTOR_CHALLENGE_EXPIRED') {
        _expired();
        return;
      }
      _fail(errorText(e));
      // Hız sınırı: sunucunun bildirdiği süre kadar beklet.
      if (e is ApiError && e.status == 429) _resendKey.currentState?.restart(e.retryAfter != null && e.retryAfter! > 0 ? e.retryAfter : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final hint = widget.challenge.emailHint;
    return RefPage(
      children: [
        RefHeading(
          title: l.tfLoginTitle,
          subtitle: hint.isEmpty ? l.authRestCodeLabel : l.tfLoginSubtitle(hint),
          emphasis: hint.isEmpty ? null : hint,
        ),
        const SizedBox(height: 32),
        OtpCodeBoxes(
          controller: _code,
          enabled: !_busy,
          hasError: _error != null,
          success: _ok,
          shakeTrigger: _shake,
          onCompleted: _verify,
        ),
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.short),
          alignment: Alignment.topCenter,
          child: _error != null
              ? Padding(padding: const EdgeInsets.only(top: 16), child: RefPill(_error!, key: ValueKey('e$_error')))
              : _info != null
                  ? Padding(padding: const EdgeInsets.only(top: 16), child: RefPill(_info!, tone: RefTone.success))
                  : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 16),
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
          ],
        ),
        const SizedBox(height: 8),
        _TrustSwitch(
          value: _trust,
          onChanged: _busy ? null : (v) => setState(() => _trust = v),
        ),
        const SizedBox(height: 16),
        Text(l.tfLoginNote, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
        const SizedBox(height: 24),
        RefButton(label: l.authVerify, busy: _busy, onPressed: _verify),
        Center(
          child: RefLink(
            label: l.tfBackToLogin,
            muted: true,
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}

/// "Bu cihaza güven" anahtarı: tüm satır dokunulabilir (≥ 56 dp), ekran okuyucuda tek anahtar.
class _TrustSwitch extends StatelessWidget {
  const _TrustSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: InkWell(
          key: const ValueKey('tf-trust'),
          borderRadius: BorderRadius.circular(BuRadius.md),
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.tfTrustDevice, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(l.tfTrustDeviceSub, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(child: Switch(value: value, onChanged: onChanged)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
