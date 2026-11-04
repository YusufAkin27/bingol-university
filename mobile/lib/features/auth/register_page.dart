import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/name_format.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/legal_pages.dart';
import 'auth_widgets.dart' show newPasswordValidator;
import 'verify_code_page.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';
import 'widgets/login_underline_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.session});

  final Session session;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

/// Kayıt tek sayfadır: ad soyad + okul numarası + şifre. Bölüm ve sınıf burada istenmez; e-posta doğrulanıp oturum
/// açılınca zorunlu "bölümünü seç" adımında bir kez alınır ([ProfileSetupPage]). Sözleşme onayı kayıtla birlikte
/// otomatik verilmiş sayılır (sunucuya `acceptTerms=true` gider); kullanıcıya yalnız bağlantılı bilgi satırı gösterilir.
class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  int _shake = 0;

  /// Sunucudan dönen e-posta hatası (EMAIL_ALIAS_NOT_ALLOWED): numara alanının altında gösterilir.
  String? _emailFieldError;
  String _emailErrorFor = '';
  late final _termsLink = TapGestureRecognizer()..onTap = () => _openLegal('TERMS');
  late final _privacyLink = TapGestureRecognizer()..onTap = () => _openLegal('PRIVACY');

  void _openLegal(String type) =>
      Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'legal_doc'), builder: (_) => LegalDocPage(session: widget.session, type: type)));

  @override
  void initState() {
    super.initState();
    // Kullanıcı numarayı değiştirince eski sunucu hatası kalkar.
    _email.addListener(() {
      if (_emailFieldError != null && _email.text != _emailErrorFor) setState(() => _emailFieldError = null);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _termsLink.dispose();
    _privacyLink.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_form.currentState?.validate() ?? false)) {
      authHaptic(AuthHaptic.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final full = await widget.session.register(email: fullEmail(_email.text), password: _password.text, displayName: _name.text);
      final id = normalizeIdentifier(fullEmail(_email.text));
      widget.session.rememberCredentials(id, _password.text);
      await widget.session.pending.save(id);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'verify_code'), builder: (_) {
        return VerifyCodePage(session: widget.session, email: id, displayEmail: full);
      }));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_ALIAS_NOT_ALLOWED') {
        // Alan altında göster: doğrulamayı yeniden tetikle.
        setState(() {
          _emailFieldError = errorText(e);
          _emailErrorFor = _email.text;
          _error = null;
        });
        authHaptic(AuthHaptic.error);
        WidgetsBinding.instance.addPostFrameCallback((_) => _form.currentState?.validate());
      } else {
        _fail(e);
      }
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(Object e) {
    authHaptic(AuthHaptic.error);
    setState(() {
      _error = errorText(e);
      _shake++;
    });
  }

  /// Kayıtta kimlik alanı: genel kurallar + "+" etiketi (sunucu 400 EMAIL_ALIAS_NOT_ALLOWED döner).
  String? _validateRegisterId(String? v) {
    final server = _emailFieldError;
    if (server != null) return server;
    // Alan yalnız rakam kabul eder (6-12 hane): giriştekiyle aynı kural.
    return validateSchoolNumber(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final link = TextStyle(color: t.ink, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
    return RefPage(
      children: [
        Semantics(
          header: true,
          child: Text(
            l.regTitle,
            style: tx.displayMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.1),
          ),
        ),
        const SizedBox(height: 10),
        Text(l.regSubtitle, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.4)),
        const SizedBox(height: 40),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LoginUnderlineField(
                  controller: _name,
                  label: l.authNameHint,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  // Her kelimenin ilk harfi otomatik büyük (Türkçe i/İ kuralıyla): "ahmet yılmaz" -> "Ahmet Yılmaz".
                  inputFormatters: [const NameCaseFormatter(), LengthLimitingTextInputFormatter(80)],
                  enabled: !_busy,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l.authNameRequired : null,
                ),
                const SizedBox(height: 28),
                // Giriş ile aynı alan: okul numarası (iri rakamlar, rakam klavyesi, @bingol.edu.tr soneki). Kayıt e-postası
                // `<numara>@bingol.edu.tr` olur; böylece girişte aynı numara geçer.
                LoginNumberField(
                  controller: _email,
                  boxed: true,
                  enabled: !_busy,
                  validator: _validateRegisterId,
                ),
                const SizedBox(height: 28),
                LoginPasswordField(
                  controller: _password,
                  label: l.authPasswordMin8,
                  enabled: !_busy,
                  validator: newPasswordValidator(context),
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Hukuki gereklilik: koşullar ve gizlilik politikası bağlantıları kalır.
        Text.rich(
          TextSpan(
            style: tx.bodySmall!.copyWith(color: t.mut, height: 1.5),
            children: [
              TextSpan(text: l.authTermsAutoPrefix),
              TextSpan(text: l.authTermsLink, recognizer: _termsLink, style: link),
              TextSpan(text: l.authTermsSep),
              TextSpan(text: l.authPrivacyLink, recognizer: _privacyLink, style: link),
              TextSpan(text: l.authTermsAutoSuffix),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        RefButton(onPressed: _submit, busy: _busy, label: l.loginRegister),
        // Hata bandı yumuşakça açılır; yeni hatada hafifçe sarsılır.
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.decelerate,
          alignment: Alignment.topCenter,
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AuthShake(trigger: _shake, child: RefBanner(_error!, key: ValueKey('reg-error-$_error'))),
                ),
        ),
        const SizedBox(height: 24),
        Center(
          child: RefFooterPrompt(
            prompt: l.authHaveAccount,
            action: l.loginSubmit,
            onPressed: _busy ? null : () => Navigator.maybePop(context),
          ),
        ),
      ],
    );
  }
}
