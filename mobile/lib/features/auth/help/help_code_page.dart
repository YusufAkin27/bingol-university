import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../widgets/bu.dart';
import '../otp_code_boxes.dart';
import '../widgets/auth_controls.dart';
import '../widgets/auth_motion.dart';
import '../widgets/auth_ref.dart';
import 'help_track_page.dart';
import 'public_support_api.dart';

/// Yardım talebi kod doğrulama (Stitch v3 "25"): 08'deki OTP dilinin aynısı. Başarıda takip jetonu cihazın güvenli
/// deposuna yazılır ve talep durumu ekranına geçilir. [resend] aynı talebi yeniden göndererek yeni kod ister.
class HelpCodePage extends StatefulWidget {
  const HelpCodePage({super.key, required this.session, required this.email, required this.resend});

  final Session session;
  final String email;
  final Future<void> Function() resend;

  @override
  State<HelpCodePage> createState() => _HelpCodePageState();
}

class _HelpCodePageState extends State<HelpCodePage> {
  final _code = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  bool _busy = false;
  bool _ok = false;
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
      _fail(context.l10n.p66CodeSix);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final token = await PublicSupportApi(widget.session.api).verify(widget.email, _code.text);
      await TrackTokenStore.save(token);
      if (!mounted) return;
      setState(() => _ok = true);
      authHaptic(AuthHaptic.success);
      if (!BuMotion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HelpTrackPage(session: widget.session, token: token)),
      );
      return;
    } catch (e) {
      if (mounted) {
        _fail(e is ApiError && e.status == 429 ? _rate(e) : context.l10n.p66CodeBad);
        _code.clear();
        if (e is ApiError && e.code == 'TOO_MANY_ATTEMPTS') _resendKey.currentState?.makeReady();
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  String _rate(ApiError e) => e.message.isNotEmpty ? e.message : context.l10n.coreErrTooMany;

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await widget.resend();
      if (!mounted) return;
      setState(() => _info = context.l10n.authNewCodeSent);
      _resendKey.currentState?.restart();
    } catch (e) {
      if (mounted) _fail(e is ApiError && e.status == 429 ? _rate(e) : errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return RefPage(
      children: [
        RefHeading(title: l.authVerifyEmailTitle, subtitle: l.authVerifySubtitle(widget.email), emphasis: widget.email),
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
            RefLink(label: l.authChangeEmail, compact: true, onPressed: _busy ? null : () => Navigator.maybePop(context)),
          ],
        ),
        const SizedBox(height: 24),
        RefButton(label: l.authVerify, busy: _busy, onPressed: _verify),
      ],
    );
  }
}
