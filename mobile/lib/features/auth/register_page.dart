import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/api.dart';
import '../../core/identifier.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../profile/legal_pages.dart';
import 'auth_widgets.dart' show newPasswordValidator;
import 'verify_code_page.dart';
import 'widgets/auth_academic.dart';
import 'widgets/auth_controls.dart';
import 'widgets/auth_motion.dart';
import 'widgets/auth_ref.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.session});

  final Session session;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

/// Kayıt 3 adımda istenir (Stitch 02): akademik bilgi, kişisel bilgi, şifre. Sözleşme onayı kayıtla birlikte
/// otomatik verilmiş sayılır (sunucuya `acceptTerms=true` gider); kullanıcıya yalnız bilgi metni gösterilir.
class _RegisterPageState extends State<RegisterPage> {
  static const _steps = 3;

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int _step = 0;

  /// Son adım değişimi geri yönde mi (paylaşılan eksen geçişinin yönü).
  bool _back = false;
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
        _back = step < _step;
        _step = step;
        _error = null;
      });

  void _reject() => authHaptic(AuthHaptic.error);

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
          _back = _step > 1;
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

  Widget _section(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    if (_step == 2) return const SizedBox.shrink();
    final label = _step == 0 ? l.authSectionAcademic : l.authSectionPersonal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (_step == 0)
            Icon(LucideIcons.graduationCap, size: 18, color: t.pr)
          else
            Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              trUpper(label),
              style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w800, letterSpacing: .6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
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
            const SizedBox(height: 20),
            RefNote(l.authTrustAcademic, icon: LucideIcons.lightbulb, tone: RefTone.error),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RefTextField(
              controller: _name,
              label: l.authNameHint,
              icon: LucideIcons.user,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              maxLength: 80,
              enabled: !_busy,
              validator: (v) => (v == null || v.trim().isEmpty) ? l.authNameRequired : null,
            ),
            const SizedBox(height: 18),
            RefIdentifierField(
              label: l.p02IdLabel,
              controller: _email,
              enabled: !_busy,
              validator: _validateRegisterId,
              textInputAction: TextInputAction.done,
              onSubmitted: _next,
            ),
            const SizedBox(height: 20),
            RefNote(l.authTrustName, icon: LucideIcons.info, tone: RefTone.info),
          ],
        );
      default:
        final link = TextStyle(color: t.ink, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RefPasswordField(
              controller: _password,
              label: l.authPasswordMin8,
              innerLabel: true,
              showIcon: false,
              enabled: !_busy,
              validator: newPasswordValidator(context),
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: _next,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _password,
              builder: (_, v, __) => AuthPasswordGuide(password: v.text),
            ),
            const SizedBox(height: 20),
            RefNote(l.authTrustPassword, icon: LucideIcons.shieldCheck),
            const SizedBox(height: 24),
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
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final last = _step == _steps - 1;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _goTo(_step - 1);
      },
      child: RefPage(
        onBack: () {
          if (_step == 0) {
            Navigator.maybePop(context);
          } else if (!_busy) {
            _goTo(_step - 1);
          }
        },
        children: [
          Semantics(
            label: l.authStepOf('${_step + 1}', '$_steps'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(l.authStepOf('${_step + 1}', '$_steps'),
                      style: tx.labelMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                ExcludeSemantics(child: AuthStepBar(step: _step, steps: _steps)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: RefHeading(title: _title(context), subtitle: _hint(context))),
              if (_step == 1) ...[
                const SizedBox(width: 12),
                RefIconTile(LucideIcons.contact, bg: t.tint(1).bg, fg: t.tint(1).fg, radius: 16),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _section(context),
          // Hata bandı yumuşakça açılır; yeni hatada hafifçe sarsılır.
          AnimatedSize(
            duration: BuMotion.of(context, BuMotion.short),
            curve: BuMotion.decelerate,
            alignment: Alignment.topCenter,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AuthShake(trigger: _shake, child: RefBanner(_error!, key: ValueKey('reg-error-$_error'))),
                  ),
          ),
          Form(
            key: _form,
            child: AutofillGroup(
              // Adım geçişi: ileri/geri yönde paylaşılan eksen (kayma + solma); yükseklik farkı yumuşakça kapanır.
              child: AnimatedSize(
                duration: BuMotion.of(context, BuMotion.medium),
                curve: BuMotion.decelerate,
                alignment: Alignment.topCenter,
                child: BuSharedAxis(
                  reverse: _back,
                  duration: BuMotion.medium,
                  distance: 24,
                  child: KeyedSubtree(key: ValueKey(_step), child: _stepBody(context)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          RefButton(
            onPressed: _next,
            busy: _busy,
            label: last ? l.loginRegister : l.authNext,
            icon: buDirIcon(context, LucideIcons.arrowRight),
          ),
          if (_step == 0 && !keyboard) ...[
            const SizedBox(height: 8),
            Center(
              child: RefFooterPrompt(
                prompt: l.authHaveAccount,
                action: l.loginSubmit,
                onPressed: _busy ? null : () => Navigator.maybePop(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
