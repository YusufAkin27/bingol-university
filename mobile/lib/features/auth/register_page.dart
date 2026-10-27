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

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _terms = false;
  bool _termsError = false;
  bool _busy = false;
  String? _error;
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

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    final academic = (_faculty ?? '').isNotEmpty && (_department ?? '').isNotEmpty && (_grade ?? '').isNotEmpty;
    setState(() {
      _termsError = !_terms;
      _tried = true;
      if (!academic && _catalog.state == CatalogState.error) {
        _error = context.l10n.authDepartmentsLoadFailed;
      }
    });
    if (_busy || !valid || !academic || !_terms) return;
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
      if (mounted) setState(() => _error = errorText(e));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AuthScaffold(
      showBack: true,
      title: context.l10n.authCreateAccount,
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) Notice(_error!),
                AcademicFields(
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
                  }),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  maxLength: 80,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? context.l10n.authNameRequired : null,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: authFieldDecoration(context, hint: context.l10n.authNameHint, icon: LucideIcons.user)
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 14),
                IdentifierField(controller: _email),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  label: context.l10n.authPasswordMin8,
                  validator: validateNewPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _terms,
                  onChanged: _busy ? null : (v) => setState(() {
                        _terms = v ?? false;
                        _termsError = false;
                      }),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: t.pr,
                  title: Text.rich(
                    TextSpan(
                      style: BuType.caption.copyWith(height: 1.45, color: _termsError ? t.danger : t.mut),
                      children: [
                        TextSpan(text: context.l10n.authTermsPrefix),
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
                        TextSpan(text: context.l10n.authTermsSuffix),
                      ],
                    ),
                  ),
                  subtitle: _termsError
                      ? Text(context.l10n.authMustAccept,
                          style: BuType.caption.copyWith(color: t.danger))
                      : null,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: BusyLabel(busy: _busy, label: context.l10n.loginRegister),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
    );
  }
}
