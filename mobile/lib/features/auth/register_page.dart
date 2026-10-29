import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../profile/legal_pages.dart';
import 'auth_widgets.dart' show newPasswordValidator;
import 'verify_code_page.dart';
import 'widgets/auth_academic.dart';
import 'widgets/auth_art.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_fields.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.session});

  final Session session;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

/// Kayıt 3 adımda istenir: akademik bilgi, kişisel bilgi, şifre. Sözleşme onayı kayıtla birlikte
/// otomatik verilmiş sayılır (sunucuya `acceptTerms=true` gider); kullanıcıya yalnız bilgi kartı gösterilir.
class _RegisterPageState extends State<RegisterPage> {
  static const _steps = 3;

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int _step = 0;
  int _dir = 1; // 1 ileri, -1 geri: adım geçişinin yönü
  bool _busy = false;
  String? _error;
  int _shake = 0;

  /// Sunucudan dönen e-posta hatası (EMAIL_ALIAS_NOT_ALLOWED): e-posta alanının altında gösterilir.
  String? _emailFieldError;
  String _emailErrorFor = '';
  late final AcademicCatalog _catalog = AcademicCatalog.of(widget.session);
  String? _faculty, _department, _grade;
  bool _tried = false;
  late final _termsLink = TapGestureRecognizer()..onTap = () => _openLegal('TERMS');
  late final _privacyLink = TapGestureRecognizer()..onTap = () => _openLegal('PRIVACY');

  void _openLegal(String type) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => LegalDocPage(session: widget.session, type: type)));

  @override
  void initState() {
    super.initState();
    _catalog.load();
    // Kullanıcı e-postayı değiştirince eski sunucu hatası kalkar.
    _email.addListener(() {
      if (_emailFieldError != null && _email.text != _emailErrorFor) setState(() => _emailFieldError = null);
    });
  }

  String? get _departmentErr => _tried && (_department ?? '').isEmpty ? context.l10n.authSelectDepartment : null;
  String? get _gradeErr => _tried && (_grade ?? '').isEmpty ? context.l10n.authSelectGrade : null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _termsLink.dispose();
    _privacyLink.dispose();
    super.dispose();
  }

  bool get _academicOk => (_faculty ?? '').isNotEmpty && (_department ?? '').isNotEmpty && (_grade ?? '').isNotEmpty;

  void _goTo(int step) => setState(() {
        _dir = step >= _step ? 1 : -1;
        _step = step;
        _error = null;
      });

  void _reject() {
    authHaptic(AuthHaptic.error);
    setState(() => _shake++);
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0) {
      setState(() {
        _tried = true;
        if (!_academicOk && _catalog.state == CatalogState.error) {
          _error = context.l10n.authDepartmentsLoadFailed;
        }
      });
      if (_academicOk) {
        authHaptic(AuthHaptic.tap);
        _goTo(1);
      } else {
        _reject();
      }
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) {
      _reject();
      return;
    }
    if (_step < _steps - 1) {
      authHaptic(AuthHaptic.tap);
      _goTo(_step + 1);
    } else {
      await _submit();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final full = await widget.session.register(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        faculty: _faculty,
        department: _department,
        grade: _grade,
      );
      final id = normalizeIdentifier(_email.text);
      widget.session.rememberCredentials(id, _password.text);
      await widget.session.pending.save(id);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) {
        return VerifyCodePage(session: widget.session, email: id, displayEmail: full);
      }));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_ALIAS_NOT_ALLOWED') {
        // Alan altında göster: e-posta adımına dön ve doğrulamayı tetikle.
        setState(() {
          _emailFieldError = errorText(e);
          _emailErrorFor = _email.text;
          _dir = -1;
          _step = 1;
          _error = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _form.currentState?.validate());
      } else {
        authHaptic(AuthHaptic.error);
        setState(() {
          _error = errorText(e);
          _shake++;
        });
      }
    } catch (e) {
      if (mounted) {
        authHaptic(AuthHaptic.error);
        setState(() {
          _error = errorText(e);
          _shake++;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kayıtta kimlik alanı: genel kurallar + "+" etiketi (sunucu 400 EMAIL_ALIAS_NOT_ALLOWED döner).
  String? _validateRegisterId(String? v) {
    final server = _emailFieldError;
    if (server != null) return server;
    final base = validateIdentifier(v);
    if (base != null) return base;
    final s = normalizeIdentifier(v);
    final at = s.indexOf('@');
    if (at > 0 && s.substring(0, at).contains('+')) return context.l10n.errEmailAliasNotAllowed;
    return null;
  }

  String _title(BuildContext c) => switch (_step) {
        0 => c.l10n.authStep1Title,
        1 => c.l10n.authStep2Title,
        _ => c.l10n.authSectionPassword,
      };

  String _hint(BuildContext c) => switch (_step) {
        0 => c.l10n.authHintAcademic,
        1 => c.l10n.authHintPersonal,
        _ => c.l10n.authHintPassword,
      };

  Widget _stepBody(BuildContext context) {
    final l = context.l10n;
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthAcademicFields(
              catalog: _catalog,
              faculty: _faculty,
              department: _department,
              grade: _grade,
              enabled: !_busy,
              departmentError: _departmentErr,
              gradeError: _gradeErr,
              onChanged: (f, d, g) => setState(() {
                _faculty = f;
                _department = d;
                _grade = g;
                _error = null;
              }),
            ),
            const SizedBox(height: 22),
            AuthTrustNote(l.authTrustAcademic, icon: LucideIcons.info),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _name,
              label: l.authNameHint,
              icon: LucideIcons.user,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              maxLength: 80,
              enabled: !_busy,
              validator: (v) => (v == null || v.trim().isEmpty) ? l.authNameRequired : null,
            ),
            const SizedBox(height: 16),
            AuthIdentifierField(
              controller: _email,
              enabled: !_busy,
              validator: _validateRegisterId,
              textInputAction: TextInputAction.done,
              onSubmitted: _next,
            ),
            const SizedBox(height: 22),
            AuthTrustNote(l.authTrustName, icon: LucideIcons.eye),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPasswordField(
              controller: _password,
              label: l.authPasswordMin8,
              enabled: !_busy,
              validator: newPasswordValidator(context),
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: _next,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _password,
              builder: (_, v, __) => AuthPasswordGuide(password: v.text),
            ),
            const SizedBox(height: 22),
            _ConsentCard(termsLink: _termsLink, privacyLink: _privacyLink),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final last = _step == _steps - 1;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final art = switch (_step) {
      0 => AuthArtKind.cap,
      1 => AuthArtKind.user,
      _ => AuthArtKind.shield,
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _goTo(_step - 1);
      },
      child: AuthShell(
        showBack: true,
        step: _step,
        stepTotal: _steps,
        stepLabel: l.authStepOf('${_step + 1}', '$_steps'),
        trailing: Text(l.authStepOf('${_step + 1}', '$_steps'),
            style: BuType.label.copyWith(color: t.mut, fontSize: 13, fontWeight: FontWeight.w700)),
        art: art,
        title: _title(context),
        subtitle: _hint(context),
        body: [
          AuthFeedbackSlot(error: _error, shake: _shake),
          Form(
            key: _form,
            child: AutofillGroup(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (cur, prev) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...prev, if (cur != null) cur],
                ),
                transitionBuilder: (child, anim) {
                  // Gelen çocuk yönden süzülür, giden hızla solar (paylaşılan eksen).
                  final incoming = child.key == ValueKey(_step);
                  final begin = Offset((incoming ? .10 : -.10) * _dir * (rtl ? -1 : 1), 0);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: Tween(begin: begin, end: Offset.zero).animate(anim), child: child),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_step), child: _stepBody(context)),
              ),
            ),
          ),
        ],
        bottom: [
          AuthPrimaryButton(
            onPressed: _busy ? null : _next,
            busy: _busy,
            label: last ? l.loginRegister : l.authNext,
            icon: last ? null : buDirIcon(context, LucideIcons.arrowRight),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: keyboard
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AuthFooterPrompt(
                      prompt: l.authHaveAccount,
                      action: l.loginSubmit,
                      onPressed: _busy ? null : () => Navigator.maybePop(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Sözleşme bilgi kartı: kayıt = kabul (onay kutusu yok); metinlere bağlantılar.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.termsLink, required this.privacyLink});

  final TapGestureRecognizer termsLink;
  final TapGestureRecognizer privacyLink;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.sf2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.bd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
            child: Icon(LucideIcons.fileCheck, size: 17, color: t.pr),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: BuType.caption.copyWith(height: 1.55, color: t.mut, fontSize: 12.5),
                children: [
                  TextSpan(text: l.authTermsAutoPrefix),
                  TextSpan(
                    text: l.authTermsLink,
                    recognizer: termsLink,
                    style: TextStyle(color: t.pr, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: l.authTermsSep),
                  TextSpan(
                    text: l.authPrivacyLink,
                    recognizer: privacyLink,
                    style: TextStyle(color: t.pr, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: l.authTermsAutoSuffix),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
