import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/oauth/real_email_api.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'otp_code_boxes.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';
import 'widgets/login_underline_field.dart';

enum _Step { email, code, done }

/// "Gerçek e-posta adresiniz": Apple "E-postamı gizle" ile açılan hesabın gizli (röle) adresi bildirimleri ve şifre sıfırlamayı
/// alamaz; kullanıcıdan aktif e-posta adresi istenir, 6 haneli kodla doğrulanır ve hesabın TEK e-postası olur.
///
/// - [mandatory] true (yeni hesapta sunucu kapısı, `realEmailRequired`): atlanamaz, geri/kapatma yok; tek çıkış "Çıkış yap".
/// - [mandatory] false (mevcut hesap, yumuşak adım): "Şimdi değil" ile [onSkip] çağrılır (kapı birkaç gün tekrar sormaz).
///
/// Adım 1 e-posta (kayıt sayfasıyla aynı alan, örnek adres ipucu ve alan adı kısıtı yok), adım 2 kod (yeniden gönder sayacı,
/// hatalı/süresi dolmuş kod, hız sınırı mesajları), adım 3 başarı. Sözleşme: docs/changes/auth.md "Gercek e-posta (role) dogrulamasi".
class RealEmailPage extends StatefulWidget {
  const RealEmailPage({
    super.key,
    required this.session,
    required this.mandatory,
    required this.onDone,
    this.onSkip,
    this.api,
  });

  final Session session;
  final bool mandatory;

  /// Doğrulama bitti ve kullanıcı "Devam et"e bastı.
  final VoidCallback onDone;

  /// Yumuşak adımda "Şimdi değil".
  final VoidCallback? onSkip;

  /// Testler için.
  final RealEmailApi? api;

  @override
  State<RealEmailPage> createState() => _RealEmailPageState();
}

class _RealEmailPageState extends State<RealEmailPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _resendKey = GlobalKey<AuthResendRowState>();
  late final RealEmailApi _api = widget.api ?? RealEmailApi(widget.session.api);

  _Step _step = _Step.email;
  bool _busy = false;
  bool _ok = false;
  String? _error;
  String? _info;
  String? _emailFieldError;
  String? _emailErrorFor;
  int _shake = 0;
  int _resendSeconds = 180;

  /// Kodun gönderildiği, normalleştirilmiş tam adres.
  String _sentTo = '';

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _fail(String message) {
    authHaptic(AuthHaptic.error);
    setState(() {
      _error = message;
      _info = null;
      _shake++;
    });
  }

  /// Alan altı hata: sunucunun adres hakkındaki kararı (alan değişince kendiliğinden kalkar).
  void _failField(String message) {
    authHaptic(AuthHaptic.error);
    setState(() {
      _emailFieldError = message;
      _emailErrorFor = _email.text;
      _error = null;
      _info = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _form.currentState?.validate());
  }

  String? _validateEmail(String? v) {
    final server = _emailFieldError;
    if (server != null && _emailErrorFor == v) return server;
    return validateRegisterEmail(v);
  }

  /// Hata kodu -> yerel metin (sunucu da istek dilinde döner; yerel metin proxy/boş gövde için güvence).
  String _textFor(Object e) {
    final l = context.l10n;
    if (e is ApiError) {
      switch (e.code) {
        case 'EMAIL_RELAY_NOT_ALLOWED':
          return l.realEmailErrRelay;
        case 'EMAIL_UNAVAILABLE':
          return l.realEmailErrUnavailable;
        case 'EMAIL_UNCHANGED':
          return l.realEmailErrUnchanged;
        case 'REAL_EMAIL_REQUIRED':
          return l.realEmailErrRequired;
      }
    }
    return errorText(e);
  }

  Future<void> _send() async {
    if (_busy) return;
    if (!(_form.currentState?.validate() ?? false)) {
      authHaptic(AuthHaptic.error);
      return;
    }
    final email = normalizeIdentifier(_email.text);
    if (isRelayEmail(email)) {
      _failField(context.l10n.realEmailErrRelay);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final r = await _api.start(email);
      if (!mounted) return;
      _toCodeStep(email, r.resendInSeconds);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'RESEND_COOLDOWN') {
        // Aynı adrese kısa süre önce kod gitti: kod adımına geç, sayaç kalan süreden başlasın.
        _toCodeStep(email, e.retryAfter ?? 180);
      } else if (const {'EMAIL_RELAY_NOT_ALLOWED', 'EMAIL_ALIAS_NOT_ALLOWED', 'EMAIL_UNCHANGED', 'VALIDATION_ERROR'}.contains(e.code)) {
        _failField(e.code == 'VALIDATION_ERROR' ? context.l10n.coreIdEmail : _textFor(e));
      } else {
        _fail(_textFor(e));
      }
    } catch (e) {
      if (mounted) _fail(_textFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toCodeStep(String email, int resendSeconds) {
    authHaptic(AuthHaptic.tap);
    _code.clear();
    setState(() {
      _sentTo = email;
      _resendSeconds = resendSeconds <= 0 ? 180 : resendSeconds;
      _step = _Step.code;
      _error = null;
      _info = null;
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
      final email = await _api.verify(_code.text);
      if (!mounted) return;
      widget.session.realEmailVerified(email);
      setState(() {
        _ok = true;
        _sentTo = email;
      });
      authHaptic(AuthHaptic.success);
      if (!BuMotion.reduced(context)) await Future<void>.delayed(const Duration(milliseconds: 260));
      if (mounted) setState(() => _step = _Step.done);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_UNAVAILABLE') {
        // Kod doğruydu ama adres başka hesapta kayıtlı: kod tüketildi, kullanıcı başka adres yazmalı.
        _code.clear();
        setState(() {
          _step = _Step.email;
          _error = null;
        });
        _failField(_textFor(e));
        return;
      }
      _fail(_textFor(e));
      if (e.code == 'TOO_MANY_ATTEMPTS') {
        _code.clear();
        _resendKey.currentState?.makeReady();
      }
    } catch (e) {
      if (mounted) _fail(_textFor(e));
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
      final r = await _api.start(_sentTo);
      if (!mounted) return;
      setState(() => _info = context.l10n.authNewCodeSent);
      _resendKey.currentState?.restart(r.resendInSeconds);
    } catch (e) {
      if (!mounted) return;
      _fail(_textFor(e));
      if (e is ApiError && e.code == 'RESEND_COOLDOWN') {
        _resendKey.currentState?.restart(e.retryAfter);
      }
    }
  }

  void _backToEmail() {
    if (_busy) return;
    _code.clear();
    setState(() {
      _step = _Step.email;
      _error = null;
      _info = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.email:
        return _emailStep(context);
      case _Step.code:
        return _codeStep(context);
      case _Step.done:
        return _doneStep(context);
    }
  }

  Widget _footer(BuildContext context) {
    final l = context.l10n;
    if (widget.mandatory) {
      // Zorunlu kapı: tek çıkış, kullanıcı tuzağa düşmesin diye sakin bir "Çıkış yap" bağlantısı.
      return Center(
        child: RefLink(label: l.profileSignOut, muted: true, onPressed: _busy ? null : () => widget.session.signOut()),
      );
    }
    return Center(
      child: RefLink(label: l.realEmailLater, muted: true, onPressed: _busy ? null : widget.onSkip),
    );
  }

  Widget _message(BuildContext context) {
    return AnimatedSize(
      duration: BuMotion.of(context, BuMotion.short),
      alignment: Alignment.topCenter,
      child: _error != null
          ? Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AuthShake(trigger: _shake, child: RefBanner(_error!, key: ValueKey('re-error-$_error'))),
            )
          : _info != null
              ? Padding(padding: const EdgeInsets.only(top: 16), child: RefPill(_info!, tone: RefTone.success))
              : const SizedBox(width: double.infinity),
    );
  }

  Widget _emailStep(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: false,
      child: RefPage(
        showBack: false,
        children: [
          RefHeading(title: l.realEmailTitle, subtitle: l.realEmailSubtitle),
          if (!widget.mandatory) ...[
            const SizedBox(height: 16),
            RefBanner(l.realEmailSoftNote, tone: RefTone.info),
          ],
          const SizedBox(height: 32),
          Form(
            key: _form,
            child: AutofillGroup(
              child: LoginIdentifierField(
                controller: _email,
                strict: true,
                enabled: !_busy,
                validator: _validateEmail,
                textInputAction: TextInputAction.done,
                onSubmitted: _send,
              ),
            ),
          ),
          _message(context),
          const SizedBox(height: 24),
          RefButton(label: l.realEmailSendCode, busy: _busy, onPressed: _send),
          const SizedBox(height: 8),
          _footer(context),
        ],
      ),
    );
  }

  Widget _codeStep(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: RefPage(
        showBack: true,
        onBack: _backToEmail,
        children: [
          RefHeading(
            title: l.realEmailCodeTitle,
            subtitle: l.authVerifySubtitle(_sentTo),
            emphasis: _sentTo,
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
          _message(context),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AuthResendRow(
                key: _resendKey,
                initialSeconds: _resendSeconds,
                onResend: _busy ? () {} : _resend,
                waitingLabel: (s) => l.authResendInTime('${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'),
                resendLabel: l.authResendCode,
              ),
              RefLink(label: l.authChangeEmail, compact: true, onPressed: _busy ? null : _backToEmail),
            ],
          ),
          const SizedBox(height: 16),
          Text(l.realEmailNoCodeHint, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.45)),
          const SizedBox(height: 24),
          RefButton(label: l.authVerify, busy: _busy, onPressed: _verify),
          const SizedBox(height: 8),
          _footer(context),
        ],
      ),
    );
  }

  Widget _doneStep(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    return PopScope(
      canPop: false,
      child: RefPage(
        showBack: false,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RefIconTile(BuIcons.mailCheck, size: 56, bg: t.tint(1).bg, fg: t.tint(1).fg),
          ),
          const SizedBox(height: 24),
          RefHeading(title: l.realEmailDoneTitle, subtitle: l.realEmailDoneBody(_sentTo), emphasis: _sentTo),
          const SizedBox(height: 32),
          RefButton(label: l.realEmailContinue, onPressed: widget.onDone),
        ],
      ),
    );
  }
}
