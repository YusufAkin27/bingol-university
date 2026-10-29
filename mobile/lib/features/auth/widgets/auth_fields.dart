import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/identifier.dart';
import '../../../core/locale_controller.dart';
import '../../../core/theme.dart';
import '../../../core/typography.dart';
import '../../../widgets/bu_widgets.dart';
import 'auth_motion.dart';

const double kAuthRadius = 20;

/// Etiketi kutunun İÇİNDE yüzdüren kenarlık (Material'in "çentikli" dış çizgi düzeni yerine): dolgu + yuvarlak çizgi.
class _InsetBorder extends InputBorder {
  const _InsetBorder({super.borderSide = BorderSide.none});

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  RRect _rrect(Rect r) => RRect.fromRectAndRadius(r, const Radius.circular(kAuthRadius));

  @override
  InputBorder copyWith({BorderSide? borderSide}) => _InsetBorder(borderSide: borderSide ?? this.borderSide);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect.deflate(borderSide.width)));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_rrect(rect));

  @override
  ShapeBorder scale(double t) => _InsetBorder(borderSide: borderSide.scale(t));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) =>
      a is _InsetBorder ? _InsetBorder(borderSide: BorderSide.lerp(a.borderSide, borderSide, t)) : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is _InsetBorder ? _InsetBorder(borderSide: BorderSide.lerp(borderSide, b.borderSide, t)) : super.lerpTo(b, t);

  @override
  void paint(Canvas canvas, Rect rect,
      {double? gapStart, double gapExtent = 0.0, double gapPercentage = 0.0, TextDirection? textDirection}) {
    if (borderSide.style == BorderStyle.none) return;
    canvas.drawRRect(_rrect(rect.deflate(borderSide.width / 2)), borderSide.toPaint());
  }

  @override
  bool operator ==(Object other) => other is _InsetBorder && other.borderSide == borderSide;

  @override
  int get hashCode => borderSide.hashCode;
}

/// Kimlik ekranları için alan: yüzen etiket, odakta yumuşak halka, "kullanıcıyı cezalandırmayan" doğrulama
/// (alandan çıkınca doğrular; hata göründükten sonra yazdıkça anında düzelir) ve doğru/yanlış ikon geçişi.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscureText = false,
    this.trailing,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.suffixText,
    this.showValidity = true,
    this.autocorrect = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;

  /// Sağ uçta (ör. parola göster/gizle) gösterilen parça; verilirse doğrulama ikonunun yerine geçer.
  final Widget? trailing;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final String? suffixText;
  final bool showValidity;
  final bool autocorrect;
  final FocusNode? focusNode;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _key = GlobalKey<FormFieldState<String>>();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  bool _touched = false;
  bool _focused = false;
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_onText);
    _valid = _isValid();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    widget.controller.removeListener(_onText);
    _ownFocus?.dispose();
    super.dispose();
  }

  bool _isValid() {
    final v = widget.validator;
    final text = widget.controller.text;
    if (v == null || text.trim().isEmpty) return false;
    return v(text) == null;
  }

  void _onFocus() {
    final f = _focus.hasFocus;
    if (!f && !_touched && widget.controller.text.isNotEmpty) {
      // Alandan çıkış: ilk kez doğrula (yazarken değil).
      _touched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _key.currentState?.validate();
      });
    }
    if (f != _focused) setState(() => _focused = f);
  }

  void _onText() {
    final v = _isValid();
    if (v != _valid && mounted) setState(() => _valid = v);
    // Hata göründüyse yazdıkça anında yeniden değerlendir.
    final st = _key.currentState;
    if (st != null && st.hasError) st.validate();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    InputBorder border(Color c, [double w = 1]) => _InsetBorder(borderSide: BorderSide(color: c, width: w));
    final hasError = _key.currentState?.hasError ?? false;
    final Widget? suffix = widget.trailing ??
        (widget.showValidity
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                child: _valid && !hasError
                    ? Padding(
                        key: const ValueKey('ok'),
                        padding: const EdgeInsetsDirectional.only(end: 14),
                        child: Icon(LucideIcons.circleCheck, size: 20, color: t.ok),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              )
            : null);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kAuthRadius),
        boxShadow: _focused
            ? [BoxShadow(color: t.pr.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .22 : .13), spreadRadius: 4)]
            : const [],
      ),
      child: TextFormField(
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
        maxLength: widget.maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textCapitalization: widget.textCapitalization,
        validator: widget.validator,
        autovalidateMode: _touched ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        onChanged: widget.onChanged,
        style: BuType.body.copyWith(color: t.ink, fontSize: 16, fontWeight: FontWeight.w500),
        cursorColor: t.pr,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          counterText: '',
          filled: true,
          fillColor: t.sf,
          isDense: false,
          labelStyle: WidgetStateTextStyle.resolveWith((s) => BuType.body.copyWith(
                fontSize: 15,
                color: s.contains(WidgetState.error)
                    ? t.danger
                    : s.contains(WidgetState.focused)
                        ? t.pr
                        : t.mut,
              )),
          floatingLabelStyle: WidgetStateTextStyle.resolveWith((s) => BuType.label.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: s.contains(WidgetState.error)
                    ? t.danger
                    : s.contains(WidgetState.focused)
                        ? t.pr
                        : t.mut,
              )),
          hintStyle: BuType.body.copyWith(color: t.mut.withValues(alpha: .75), fontSize: 14),
          errorStyle: BuType.caption.copyWith(color: t.danger, fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w500),
          errorMaxLines: 3,
          prefixIcon: Icon(widget.icon, size: 20),
          prefixIconColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.error)
              ? t.danger
              : s.contains(WidgetState.focused)
                  ? t.pr
                  : t.mut),
          suffixIcon: suffix,
          suffixText: widget.suffixText,
          suffixStyle: BuType.body.copyWith(color: t.mut, fontSize: 14),
          contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 22, 16, 12),
          border: border(t.bd),
          enabledBorder: border(t.bd),
          disabledBorder: border(t.bd.withValues(alpha: .6)),
          focusedBorder: border(t.pr, 2),
          errorBorder: border(t.danger, 1.4),
          focusedErrorBorder: border(t.danger, 2),
        ),
      ),
    );
  }
}

/// Parola alanı: göster/gizle (48 dp hedef), yazılırken sağda tik yerine göz düğmesi.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final Iterable<String> autofillHints;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return AuthTextField(
      controller: widget.controller,
      label: widget.label ?? context.l10n.authPasswordLabel,
      icon: LucideIcons.lock,
      obscureText: _hidden,
      autocorrect: false,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      keyboardType: TextInputType.visiblePassword,
      showValidity: false,
      trailing: IconButton(
        tooltip: _hidden ? context.l10n.authShowPassword : context.l10n.authHidePassword,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
          child: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff,
              key: ValueKey(_hidden), size: 20, color: t.mut),
        ),
        onPressed: () {
          authHaptic(AuthHaptic.tap);
          setState(() => _hidden = !_hidden);
        },
      ),
    );
  }
}

/// Okul numarası ya da e-posta. Yalnız rakam yazılırken sona soluk `@bingol.edu.tr` soneki görünür.
class AuthIdentifierField extends StatelessWidget {
  const AuthIdentifierField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.enabled = true,
    this.validator,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => AuthTextField(
        controller: controller,
        label: context.l10n.authIdHint,
        hint: context.l10n.authIdHelper,
        icon: LucideIcons.mail,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        textInputAction: textInputAction,
        autocorrect: false,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        validator: validator ?? validateIdentifier,
        onSubmitted: onSubmitted,
        suffixText: isStudentNumberInput(value.text) ? '@bingol.edu.tr' : null,
      ),
    );
  }
}
