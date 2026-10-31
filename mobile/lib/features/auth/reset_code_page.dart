import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'new_password_page.dart';
import 'otp_code_boxes.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// Şifremi unuttum, 2. adım (Stitch 03): kodu doğrula. Doğruysa yeni şifre ekranına geçilir.
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

  /// Kod doğrulandı: kutular kısa süre yeşil gösterilir, sonra yeni şifre ekranı açılır.
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
      final token =
          await widget.session.verifyResetCode(widget.email, _code.text);
      if (!mounted) return;
      setState(() => _ok = true);
      authHaptic(AuthHaptic.success);
      if (!BuMotion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordPage(
              session: widget.session, email: widget.email, resetToken: token),
        ),
      );
    } catch (e) {
      if (mounted) {
        _fail(errorText(e));
        _code.clear();
        // Deneme sınırı aşıldıysa beklemeden yeni kod istenebilir.
        if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') {
          _resendKey.currentState?.makeReady();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _ok = false;
        });
      }
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
    return RefPage(
      children: [
        RefHeading(title: l.authEnterCode, subtitle: l.authCodeSentTo(mail)),
        const SizedBox(height: 24),
        RefCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: RefPill(_error!, key: ValueKey('e$_error')))
                    : _info != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: RefPill(_info!, tone: RefTone.success))
                        : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 8),
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
        const SizedBox(height: 20),
        RefButton(label: l.authVerify, busy: _busy, onPressed: _verify),
      ],
    );
  }
}
