import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/identifier.dart';
import '../../../core/locale_controller.dart';
import '../../../widgets/bu.dart';
import 'auth_motion.dart';

/// Giriş sayfasının tipografik alanı (lg4): kutu ve dolgu yok; küçük etiket, altında büyük ölçekli tek satır
/// giriş ve ince alt çizgi. Çizgi odakta marka rengine soldan (RTL'de sağdan) dolarak geçer, hatada danger olur.
/// İçte TextFormField vardır (Form doğrulaması, otomatik doldurma ve testler çalışır).
/// "Kullanıcıyı cezalandırmayan" doğrulama: alandan çıkınca doğrular, hata göründükten sonra yazdıkça düzelir.
class LoginUnderlineField extends StatefulWidget {
  const LoginUnderlineField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.big = false,
    this.boxed = false,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.onSubmitted,
    this.suffix,
    this.trailing,
    this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;

  /// Okul numarası: iri rakamlar (32 sp, sabit genişlikli); kapalıyken şifre ölçeği (22 sp).
  final bool big;

  /// Login uses outlined surfaces; other auth screens keep the underline style.
  final bool boxed;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final VoidCallback? onSubmitted;

  /// Girişin sağında ikincil renkli sabit parça (ör. "@bingol.edu.tr"); null ise yok.
  final String? suffix;

  /// Satır sonunda parça (göz düğmesi).
  final Widget? trailing;
  final String? hint;
  final TextCapitalization textCapitalization;

  /// Çok satırlı metin (mesaj kutusu): şifre alanında yok sayılır.
  final int minLines;
  final int maxLines;

  @override
  State<LoginUnderlineField> createState() => _LoginUnderlineFieldState();
}

class _LoginUnderlineFieldState extends State<LoginUnderlineField> {
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
      final e = widget.validator(widget.controller.text);
      if (mounted && e != _error) setState(() => _error = e);
    }
  }

  String? _validate(String? v) {
    final e = widget.validator(v);
    if (e != null && _error == null && mounted) _shake++;
    if (e != _error && mounted) {
      // Yapı aşamasında setState yasak: o durumda çerçeve sonrasına ertele.
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
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
    return LayoutBuilder(
        builder: (context, c) => _content(context, compact: c.maxWidth < 340));
  }

  /// [compact]: dar ekranda (320 dp) rakamlar küçülür ve sonek ölçeklenmez; 9 hane + sonek tek satıra sığar.
  Widget _content(BuildContext context, {required bool compact}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final hasError = _error != null;
    final fast = AppMotion.of(context, AppMotion.fast);

    // Büyük rakamlar yalnız 1.15x'e kadar ölçeklenir: 12 hane + sonek dar ekrana sığsın (alan kaydırılır).
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: widget.big ? 1.15 : 1.3);
    final inputStyle =
        (widget.big ? tx.displaySmall! : tx.headlineSmall!).copyWith(
      color: t.ink,
      fontSize: widget.boxed ? 17 : (widget.big ? (compact ? 24 : 32) : 22),
      fontWeight:
          !widget.boxed && widget.big ? FontWeight.w400 : FontWeight.w500,
      letterSpacing: widget.big ? .4 : 0,
      height: 1.15,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final labelColor = hasError
        ? t.danger
        : _focused
            ? t.prPressed
            : t.mut;

    final input = TextFormField(
      key: _key,
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      minLines: widget.obscureText ? 1 : widget.minLines,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      keyboardType:
          widget.maxLines > 1 ? TextInputType.multiline : widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      autocorrect: false,
      enableSuggestions: false,
      validator: _validate,
      // Hata metnini kendimiz çiziyoruz; yerleşik hata alanı yer kaplamasın/ikinci kez okunmasın.
      errorBuilder: (context, error) => const SizedBox.shrink(),
      autovalidateMode: _touched
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      style: inputStyle,
      cursorColor: t.pr,
      cursorWidth: widget.big ? 2.5 : 2,
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
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        counterText: '',
        hintText: widget.hint,
        hintStyle: inputStyle.copyWith(
            color: widget.boxed ? t.mut : t.mut.withValues(alpha: .38)),
      ),
    );

    final suffix = widget.suffix;
    final row = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: input),
          // Sonek yalnız rakam yazılınca belirir; yumuşakça solar (azalt açıkken anında).
          AnimatedSwitcher(
            duration: fast,
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            child: suffix == null
                ? const SizedBox.shrink(key: ValueKey('login-suffix-none'))
                : Padding(
                    key: const ValueKey('login-suffix'),
                    padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
                    // Adres soneki her dilde soldan sağa okunur (RTL'de ters dizilmesin).
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: compact
                            ? MediaQuery.textScalerOf(context)
                                .clamp(maxScaleFactor: 1.0)
                            : scaler,
                      ),
                      child: Text(
                        suffix,
                        maxLines: 1,
                        softWrap: false,
                        textDirection: TextDirection.ltr,
                        style: (compact ? tx.bodyMedium! : tx.bodyLarge!)
                            .copyWith(
                                color: t.mut, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );

    return AuthShake(
      trigger: _shake,
      child: AnimatedOpacity(
        duration: fast,
        opacity: widget.enabled ? 1 : .55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Etiket: alanın anlam etiketi olarak verilir (okuyucu iki kez okumasın).
            ExcludeSemantics(
              child: AnimatedDefaultTextStyle(
                duration: fast,
                curve: AppMotion.standard,
                style: tx.labelLarge!
                    .copyWith(color: labelColor, fontWeight: FontWeight.w400),
                child: Text(widget.label),
              ),
            ),
            SizedBox(height: widget.boxed ? 10 : 2),
            Semantics(
              label: widget.label,
              child: widget.boxed
                  ? AnimatedContainer(
                      duration: fast,
                      padding:
                          const EdgeInsetsDirectional.only(start: 16, end: 8),
                      constraints: const BoxConstraints(minHeight: 58),
                      decoration: BoxDecoration(
                        color: _focused ? t.sf : t.sf2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                hasError ? t.danger : (_focused ? t.pr : t.bd)),
                      ),
                      child: row,
                    )
                  : row,
            ),
            if (!widget.boxed)
              _Underline(focused: _focused, hasError: hasError, duration: fast),
            AnimatedSize(
              duration: fast,
              curve: AppMotion.enter,
              alignment: Alignment.topCenter,
              child: hasError
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey('login-err-$_error'),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: fast,
                      builder: (context, v, child) =>
                          Opacity(opacity: v, child: child),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(top: 8),
                        child: Text(_error!,
                            style: tx.bodySmall!.copyWith(
                                color: t.danger,
                                fontWeight: FontWeight.w500,
                                height: 1.3)),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alt çizgi: 1 dp nötr çizgi; odakta 2 dp marka çizgisi başlangıçtan uca dolar; hatada 2 dp danger.
class _Underline extends StatelessWidget {
  const _Underline(
      {required this.focused, required this.hasError, required this.duration});

  final bool focused;
  final bool hasError;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return SizedBox(
      height: 2,
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: duration,
              height: hasError ? 2 : 1,
              color: hasError ? t.danger : t.bdStrong,
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            height: 2,
            child: AnimatedFractionallySizedBox(
              duration: duration,
              curve: AppMotion.enter,
              alignment: AlignmentDirectional.centerStart,
              widthFactor: focused && !hasError ? 1 : 0,
              heightFactor: 1,
              child: ColoredBox(color: t.pr),
            ),
          ),
        ],
      ),
    );
  }
}

/// Okul numarası alanı (lg4): yalnız rakam, rakam klavyesi, en çok 12 hane; rakam yazılınca sağda `@bingol.edu.tr`.
class LoginNumberField extends StatelessWidget {
  const LoginNumberField(
      {super.key,
      required this.controller,
      required this.enabled,
      this.onSubmitted,
      this.validator,
      this.textInputAction = TextInputAction.next,
      this.boxed = false});

  final bool boxed;

  /// Varsayılan: [validateIdentifier] (6-12 rakam). Kayıtta sunucu hatasını da gösterir.
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => LoginUnderlineField(
        controller: controller,
        label: context.l10n.authIdNumberLabel,
        big: true,
        boxed: boxed,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(12)
        ],
        autofillHints: const [AutofillHints.username],
        validator: validator ?? validateSchoolNumber,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        hint: '000000000',
        suffix: boxed || isStudentNumberInput(value.text)
            ? '@$kEmailDomain'
            : null,
      ),
    );
  }
}

/// Şifre alanı (lg4): aynı dilde, küçük ölçekte; göster/gizle gözü 48 dp hedef.
class LoginPasswordField extends StatefulWidget {
  const LoginPasswordField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.validator,
    this.onSubmitted,
    this.label,
    this.boxed = false,
    this.autofillHints = const [AutofillHints.password],
  });

  /// Varsayılan: "Şifre". Kayıtta "Şifre (en az 8 karakter)".
  final String? label;
  final bool boxed;
  final Iterable<String> autofillHints;
  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?) validator;
  final VoidCallback? onSubmitted;

  @override
  State<LoginPasswordField> createState() => _LoginPasswordFieldState();
}

class _LoginPasswordFieldState extends State<LoginPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return LoginUnderlineField(
      controller: widget.controller,
      boxed: widget.boxed,
      label: widget.label ?? l.authPasswordLabel,
      enabled: widget.enabled,
      obscureText: _hidden,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onSubmitted: widget.onSubmitted,
      trailing: IconButton(
        tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: EdgeInsets.zero,
        icon: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff,
            size: 22, color: t.mut),
        onPressed: () {
          authHaptic(AuthHaptic.tap);
          setState(() => _hidden = !_hidden);
        },
      ),
    );
  }
}
