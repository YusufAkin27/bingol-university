import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'reset_code_page.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

/// Girişten bu ada sahip rota ile açılır; yeni şifre adımında süre dolarsa buraya dönülür.
const kForgotPasswordRoute = '/forgot-password';

/// Şifremi unuttum, 1. adım (Stitch 03): e-posta gir, kod gönder. Sonra kod doğrulama ekranına geçer.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.session, this.initialEmail = ''});

  final Session session;
  final String initialEmail;

  /// Yeni şifre adımında anahtar süresi dolunca true yapılır; bu sayfa bir kez "Süre doldu" bandı gösterir.
  static final expiredNotice = ValueNotifier<bool>(false);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;
  String? _retry;
  bool _network = false;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _expired = ForgotPasswordPage.expiredNotice.value;
    ForgotPasswordPage.expiredNotice.value = false;
    ForgotPasswordPage.expiredNotice.addListener(_onExpired);
  }

  void _onExpired() {
    if (!ForgotPasswordPage.expiredNotice.value) return;
    ForgotPasswordPage.expiredNotice.value = false;
    if (mounted) {
      setState(() {
        _expired = true;
        _sent = false;
      });
    }
  }

  @override
  void dispose() {
    ForgotPasswordPage.expiredNotice.removeListener(_onExpired);
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      authHaptic(AuthHaptic.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _retry = null;
      _network = false;
      _expired = false;
    });
    try {
      await widget.session.forgotPassword(_email.text);
      if (!mounted) return;
      setState(() => _sent = true);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetCodePage(session: widget.session, email: normalizeIdentifier(_email.text)),
        ),
      );
    } catch (e) {
      if (mounted) {
        authHaptic(AuthHaptic.error);
        final l = context.l10n;
        String text = errorText(e);
        String? retry;
        if (e is ApiError && e.status == 429 && !e.isNetwork) {
          retry = retryAfterText(e.retryAfter, l);
          text = e.message.isNotEmpty ? e.message : l.coreErrTooMany;
        }
        setState(() {
          _error = text;
          _retry = retry;
          _network = e is ApiError && e.isNetwork;
          _sent = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return RefPage(
      children: [
        const SizedBox(height: 4),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
            child: Icon(LucideIcons.keyRound, size: 30, color: t.pr),
          ),
        ),
        const SizedBox(height: 20),
        RefHeading(title: l.authResetTitle, subtitle: l.authForgotSub, center: true),
        const SizedBox(height: 24),
        RefCard(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: _expired
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: RefBanner(l.authSessionExpired, tone: RefTone.error, icon: LucideIcons.timerOff, boldText: true),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                RefIdentifierField(
                  controller: _email,
                  enabled: !_busy,
                  onCard: true,
                  helper: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _sendCode,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: RefBanner(
                            _error!,
                            key: ValueKey('forgot-error-$_error'),
                            icon: _network
                                ? LucideIcons.cloudOff
                                : (_retry != null ? LucideIcons.hourglass : LucideIcons.circleAlert),
                            sub: _retry,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                RefButton(
                  label: l.authSendCode,
                  icon: buDirIcon(context, LucideIcons.arrowRight),
                  busy: _busy,
                  onPressed: _sendCode,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: _sent && _error == null && !_busy
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: RefBanner(l.authCodeSent, tone: RefTone.success, boldText: true),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: RefLink(
            label: l.authBackToLogin,
            icon: buDirIcon(context, LucideIcons.arrowLeft),
            onPressed: _busy ? null : () => Navigator.maybePop(context),
          ),
        ),
      ],
    );
  }
}
