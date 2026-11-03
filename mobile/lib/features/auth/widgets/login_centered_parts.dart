import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/identifier.dart';
import '../../../core/locale_controller.dart';
import '../../../widgets/bu.dart';
import 'auth_motion.dart';

/// Giriş sayfasına özel parçalar (ortalanmış marka yönü). Ortak `auth_ref.dart` değişmez.

/// Büyük marka karosu: squircle, ince iç çizgi, gölgesiz. Zemin `pr`; iç çizgi beyazın düşük opaklığı.
class LoginBrandTile extends StatelessWidget {
  const LoginBrandTile({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final outer = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(size * .3));
    final inset = size * .06;
    final inner = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(size * .3 - inset),
      side: BorderSide(color: t.onPr.withValues(alpha: .22), width: 1),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: t.pr, shape: outer),
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: DecoratedBox(
              decoration: ShapeDecoration(shape: inner),
              child: Center(
                child: Text(
                  'BU',
                  style: tx.titleLarge!.copyWith(
                    color: t.onPr,
                    fontWeight: FontWeight.w800,
                    fontSize: size * .36,
                    letterSpacing: -.8,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ayrı yuvarlak (14 dp) giriş kutusu: etiket üstte, odakta ince marka halkası, hata durumunda danger çerçeve.
/// İçte TextFormField (Form doğrulaması çalışır). Doğrulama: alandan çıkınca, hata göründükten sonra yazdıkça.
class LoginField extends StatefulWidget {
  const LoginField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscureText = false,
    this.trailing,
    this.suffixText,
    this.onSubmitted,
    this.enabled = true,
    this.autocorrect = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? trailing;
  final String? suffixText;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final bool autocorrect;

  @override
  State<LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<LoginField> {
  final _key = GlobalKey<FormFieldState<String>>();
  final _focus = FocusNode();
  bool _touched = false;
  bool _focused = false;
  String? _error;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    final f = _focus.hasFocus;
    if (!f && !_touched && widget.controller.text.isNotEmpty) {
      _touched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _key.currentState?.validate();
      });
    }
    if (f != _focused) setState(() => _focused = f);
  }

  void _onText() {
    final st = _key.currentState;
    if (st != null && (st.hasError || _error != null)) {
      st.validate();
      final e = widget.validator?.call(widget.controller.text);
      if (mounted && e != _error) setState(() => _error = e);
    }
  }

  String? _validate(String? v) {
    final e = widget.validator?.call(v);
    if (e != null && _error == null && mounted) _shake++;
    if (e != _error && mounted) {
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _error = e);
        });
      } else {
        setState(() => _error = e);
      }
    }
    return e;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final err = _error;
    final hasError = err != null;
    final border = hasError ? t.danger : (_focused ? t.pr : t.bdStrong);
    final ringColor = (hasError ? t.danger : t.pr).withValues(alpha: .16);
    final showRing = _focused || hasError;
    final suffix = widget.suffixText;
    final input = TextFormField(
      key: _key,
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.autocorrect,
      inputFormatters: widget.inputFormatters,
      validator: _validate,
      errorBuilder: (context, error) => const SizedBox.shrink(),
      autovalidateMode: _touched ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w500),
      cursorColor: t.pr,
      decoration: InputDecoration(
        isCollapsed: true,
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        counterText: '',
        hintText: widget.hint,
        hintStyle: tx.bodyLarge!.copyWith(color: t.mut.withValues(alpha: .7)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
          child: Text(widget.label, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
        ),
        AuthShake(
          trigger: _shake,
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.fast),
            curve: AppMotion.enter,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 0),
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BuRadius.bControl,
              border: Border.all(color: border, width: _focused || hasError ? 1.5 : 1),
              // Odak halkası: bulanıklıksız ince halka (gölge değil).
              boxShadow: showRing ? [BoxShadow(color: ringColor, blurRadius: 0, spreadRadius: 3)] : const [],
            ),
            child: Row(
              children: [
                Expanded(child: input),
                if (suffix != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Text(suffix, style: tx.bodyLarge!.copyWith(color: t.mut)),
                  ),
                ],
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: hasError
              ? TweenAnimationBuilder<double>(
                  key: ValueKey('login-err-$err'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: AppMotion.of(context, AppMotion.fast),
                  builder: (context, v, child) => Opacity(opacity: v, child: child),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 8, start: 4),
                    child: Text(err, style: tx.bodySmall!.copyWith(color: t.danger, fontWeight: FontWeight.w500, height: 1.3)),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Okul numarası alanı: rakam klavyesi, harf girilemez (en çok 12 hane); rakam yazılınca sağda `@bingol.edu.tr`.
class LoginNumberField extends StatelessWidget {
  const LoginNumberField({super.key, required this.controller, this.enabled = true});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => LoginField(
        controller: controller,
        label: context.l10n.authIdNumberLabel,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
        autocorrect: false,
        autofillHints: const [AutofillHints.username],
        validator: validateIdentifier,
        suffixText: isStudentNumberInput(value.text) ? '@$kEmailDomain' : null,
      ),
    );
  }
}

/// Şifre alanı: göster/gizle gözü (44 dp+ hedef).
class LoginPasswordField extends StatefulWidget {
  const LoginPasswordField({
    super.key,
    required this.controller,
    required this.hint,
    required this.validator,
    required this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?) validator;
  final VoidCallback onSubmitted;
  final bool enabled;

  @override
  State<LoginPasswordField> createState() => _LoginPasswordFieldState();
}

class _LoginPasswordFieldState extends State<LoginPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return LoginField(
      controller: widget.controller,
      label: context.l10n.authPasswordLabel,
      hint: widget.hint,
      obscureText: _hidden,
      autocorrect: false,
      enabled: widget.enabled,
      validator: widget.validator,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onSubmitted: widget.onSubmitted,
      keyboardType: TextInputType.visiblePassword,
      trailing: IconButton(
        tooltip: _hidden ? context.l10n.authShowPassword : context.l10n.authHidePassword,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff, size: 22, color: t.mut),
        onPressed: () {
          authHaptic(AuthHaptic.tap);
          setState(() => _hidden = !_hidden);
        },
      ),
    );
  }
}

/// İkincil alt satır ("Giriş yapamıyor musunuz? Yardım al"): marka rengi yok, eylem `ink` yarı kalın; 48 dp hedef.
class LoginQuietPrompt extends StatelessWidget {
  const LoginQuietPrompt({super.key, required this.prompt, required this.action, required this.onPressed});

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: tx.bodyMedium!.copyWith(color: t.mut)),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: t.ink,
          ),
          child: Text(action, style: tx.bodyMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: t.mut)),
        ),
      ],
    );
  }
}
