import 'package:flutter/gestures.dart';
import '../../core/locale_controller.dart';
import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../widgets/academic_picker.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import 'auth_widgets.dart';
import '../profile/legal_pages.dart';
import 'verify_code_page.dart';
import '../../core/typography.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.session});

  final Session session;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

/// Kayıt 3 adımda istenir: akademik bilgi → kişisel bilgi → şifre. Sözleşme onayı kayıtla birlikte
/// otomatik verilmiş sayılır (sunucuya `acceptTerms=true` gider); kullanıcıya yalnız bilgi satırı gösterilir.
class _RegisterPageState extends State<RegisterPage> {
  static const _steps = 3;

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int _step = 0;
  bool _busy = false;
  String? _error;

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
        _step = step;
        _error = null;
      });

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0) {
      setState(() {
        _tried = true;
        if (!_academicOk && _catalog.state == CatalogState.error) {
          _error = context.l10n.authDepartmentsLoadFailed;
        }
      });
      if (_academicOk) _goTo(1);
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_step < _steps - 1) {
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
          _step = 1;
          _error = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _form.currentState?.validate());
      } else {
        setState(() => _error = errorText(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
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
    final t = context.bu;
    switch (_step) {
      case 0:
        return AcademicFields(
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
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              maxLength: 80,
              validator: (v) => (v == null || v.trim().isEmpty) ? context.l10n.authNameRequired : null,
              style: BuType.body.copyWith(color: t.ink),
              decoration: authFieldDecoration(context, hint: context.l10n.authNameHint, icon: LucideIcons.user)
                  .copyWith(counterText: ''),
            ),
            const SizedBox(height: 14),
            IdentifierField(controller: _email, onSubmitted: _next, validator: _validateRegisterId),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PasswordField(
              controller: _password,
              label: context.l10n.authPasswordMin8,
              validator: newPasswordValidator(context),
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: _next,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _password,
              builder: (_, v, __) => PasswordStrength(password: v.text),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final last = _step == _steps - 1;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _goTo(_step - 1);
      },
      child: AuthScaffold(
        showBack: true,
        trailing: Text(context.l10n.authStepOf('${_step + 1}', '$_steps'),
            style: BuType.label.copyWith(color: t.mut, fontSize: 13)),
        progress: AuthProgress(step: _step, total: _steps),
        title: _title(context),
        subtitle: _hint(context),
        children: [
          Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) Notice(_error!),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(key: ValueKey(_step), child: _stepBody(context)),
                  ),
                  const SizedBox(height: 28),
                  AuthButton(
                    onPressed: _busy ? null : _next,
                    busy: _busy,
                    label: last ? context.l10n.loginRegister : context.l10n.authNext,
                  ),
                  if (last) ...[
                    const SizedBox(height: 14),
                    Text.rich(
                      TextSpan(
                        style: BuType.caption.copyWith(height: 1.5, color: t.mut),
                        children: [
                          TextSpan(text: context.l10n.authTermsAutoPrefix),
                          TextSpan(
                            text: context.l10n.authTermsLink,
                            recognizer: _termsLink,
                            style: TextStyle(color: t.pr, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: context.l10n.authTermsSep),
                          TextSpan(
                            text: context.l10n.authPrivacyLink,
                            recognizer: _privacyLink,
                            style: TextStyle(color: t.pr, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: context.l10n.authTermsAutoSuffix),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.authHaveAccount, style: BuType.body.copyWith(color: t.mut)),
              TextButton(
                onPressed: _busy ? null : () => Navigator.maybePop(context),
                child: Text(context.l10n.loginSubmit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
