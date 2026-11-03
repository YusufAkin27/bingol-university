import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/identifier.dart';
import '../../../core/locale_controller.dart';
import '../../../widgets/bu.dart';
import 'auth_motion.dart';

/// Giriş formu (iOS Ayarlar / Apple ID düzeni): tek yuvarlak gruplu kart içinde iki satır
/// (okul numarası | şifre), satır başında sabit etiket sütunu, satırlar arası ince iç ayraç.
/// Hatalar kartın altında (grup alt bilgisi gibi) danger renkte tek tek listelenir.
/// Yalnız giriş sayfası kullanır; ortak `RefTextField` bileşenlerine dokunmaz.
class LoginGroupedFields extends StatefulWidget {
  const LoginGroupedFields({
    super.key,
    required this.idController,
    required this.passwordController,
    required this.passwordValidator,
    required this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController idController;
  final TextEditingController passwordController;
  final String? Function(String?) passwordValidator;
  final VoidCallback onSubmitted;
  final bool enabled;

  @override
  State<LoginGroupedFields> createState() => _LoginGroupedFieldsState();
}

class _LoginGroupedFieldsState extends State<LoginGroupedFields> {
  final _idKey = GlobalKey<FormFieldState<String>>();
  final _pwKey = GlobalKey<FormFieldState<String>>();
  final _idFocus = FocusNode();
  final _pwFocus = FocusNode();
  bool _idTouched = false;
  bool _pwTouched = false;
  bool _hidden = true;
  String? _idError;
  String? _pwError;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _idFocus.addListener(_onIdFocus);
    _pwFocus.addListener(_onPwFocus);
  }

  @override
  void dispose() {
    _idFocus.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  // Alandan çıkınca (ve doluysa) doğrula; hata görününce yazdıkça düzelir (cezalandırmayan doğrulama).
  void _onIdFocus() {
    if (!_idFocus.hasFocus && !_idTouched && widget.idController.text.isNotEmpty) {
      _idTouched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _idKey.currentState?.validate();
      });
    }
  }

  void _onPwFocus() {
    if (!_pwFocus.hasFocus && !_pwTouched && widget.passwordController.text.isNotEmpty) {
      _pwTouched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pwKey.currentState?.validate();
      });
    }
  }

  String? _validateId(String? v) {
    final e = validateIdentifier(v);
    _setError(e, _idError, (x) => _idError = x);
    return e;
  }

  String? _validatePw(String? v) {
    final e = widget.passwordValidator(v);
    _setError(e, _pwError, (x) => _pwError = x);
    return e;
  }

  void _setError(String? e, String? old, void Function(String?) assign) {
    if (e == old || !mounted) return;
    if (e != null && old == null) _shake++;
    void apply() {
      if (mounted) setState(() => assign(e));
    }

    // Yapı (build) aşamasında setState yasak: çerçeve sonrasına ertele.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final labelStyle = tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600);
    final idLabel = l.authIdNumberLabel;
    final pwLabel = l.authPasswordLabel;
    final errors = [if (_idError != null) _idError!, if (_pwError != null) _pwError!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthShake(
          trigger: _shake,
          child: LayoutBuilder(builder: (context, c) {
            // Etiket sütunu: en geniş etiket kadar; dar ekranda/büyük yazıda genişliğin %46'iyle sınırlı (2 satıra sarar).
            final inner = c.maxWidth - 32;
            final scaler = MediaQuery.textScalerOf(context);
            double w(String s) {
              final p = TextPainter(
                text: TextSpan(text: s, style: labelStyle),
                textDirection: Directionality.of(context),
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              final r = p.width;
              p.dispose();
              return r;
            }

            final labelW = (w(idLabel) > w(pwLabel) ? w(idLabel) : w(pwLabel)).ceilToDouble() + 2;
            final col = labelW.clamp(64.0, inner * .46);
            return AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              curve: AppMotion.standard,
              decoration: BoxDecoration(
                color: t.sf,
                borderRadius: BorderRadius.circular(BuRadius.md),
                border: Border.all(
                  color: (_idError != null || _pwError != null) ? t.danger.withValues(alpha: .6) : t.bd,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GroupRow(
                    hasError: _idError != null,
                    focus: _idFocus,
                    label: idLabel,
                    labelWidth: col,
                    labelStyle: labelStyle,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.idController,
                      builder: (context, value, _) {
                        final suffix = isStudentNumberInput(value.text) ? '@$kEmailDomain' : null;
                        return _IdInput(
                          field: TextFormField(
                            key: _idKey,
                            controller: widget.idController,
                            focusNode: _idFocus,
                            enabled: widget.enabled,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.username],
                            validator: _validateId,
                            errorBuilder: (context, error) => const SizedBox.shrink(),
                            autovalidateMode: _idTouched ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                            onChanged: (_) {
                              if (_idError != null) _idKey.currentState?.validate();
                            },
                            style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w500),
                            cursorColor: t.pr,
                            decoration: _decoration(tx, t.mut, hint: l.loginIdExample),
                          ),
                          suffix: suffix,
                        );
                      },
                    ),
                  ),
                  Divider(height: 1, thickness: 1, indent: 16, color: t.bd),
                  _GroupRow(
                    hasError: _pwError != null,
                    focus: _pwFocus,
                    label: pwLabel,
                    labelWidth: col,
                    labelStyle: labelStyle,
                    trailing: IconButton(
                      tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: EdgeInsets.zero,
                      icon: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff, size: 22, color: t.mut),
                      onPressed: () {
                        authHaptic(AuthHaptic.tap);
                        setState(() => _hidden = !_hidden);
                      },
                    ),
                    child: TextFormField(
                      key: _pwKey,
                      controller: widget.passwordController,
                      focusNode: _pwFocus,
                      enabled: widget.enabled,
                      obscureText: _hidden,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      validator: _validatePw,
                      errorBuilder: (context, error) => const SizedBox.shrink(),
                      autovalidateMode: _pwTouched ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                      onChanged: (_) {
                        if (_pwError != null) _pwKey.currentState?.validate();
                      },
                      onFieldSubmitted: (_) => widget.onSubmitted(),
                      style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w500),
                      cursorColor: t.pr,
                      decoration: _decoration(tx, t.mut, hint: l.loginPasswordRequired.replaceAll(RegExp(r'\.$'), '')),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        // Hata alt bilgisi: kart uzar, metin solarak belirir (azaltılmış harekette anında).
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: errors.isEmpty
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  container: true,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 8, start: 16, end: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in errors)
                          TweenAnimationBuilder<double>(
                            key: ValueKey('login-field-err-$e'),
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: AppMotion.of(context, AppMotion.fast),
                            builder: (context, v, child) => Opacity(opacity: v, child: child),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(e, style: tx.bodySmall!.copyWith(color: t.danger, fontWeight: FontWeight.w500, height: 1.35)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  InputDecoration _decoration(TextTheme tx, Color mut, {String? hint}) => InputDecoration(
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
        hintText: hint,
        hintStyle: tx.bodyLarge!.copyWith(color: mut.withValues(alpha: .7)),
      );
}

/// Gruplu kartın tek satırı: sabit genişlikli etiket sütunu + değer. Satırın her yerine dokunmak alanı odaklar;
/// hatada etiket danger olur (odak göstergesi imleçtir, Apple Ayarlar gibi).
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.hasError,
    required this.focus,
    required this.label,
    required this.labelWidth,
    required this.labelStyle,
    required this.child,
    this.trailing,
  });

  final bool hasError;
  final FocusNode focus;
  final String label;
  final double labelWidth;
  final TextStyle labelStyle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focus.requestFocus,
      child: Container(
        constraints: const BoxConstraints(minHeight: BuSize.field),
        padding: EdgeInsetsDirectional.only(start: 16, end: trailing == null ? 16 : 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.fade,
                style: labelStyle.copyWith(color: hasError ? t.danger : t.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Okul numarası girdisi: sağda ikincil renkte `@bingol.edu.tr`. Dar alanda sonek girdinin altına iner.
class _IdInput extends StatelessWidget {
  const _IdInput({required this.field, required this.suffix});

  final Widget field;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final s = suffix;
    if (s == null) return field;
    final style = tx.bodySmall!.copyWith(color: t.mut);
    return LayoutBuilder(builder: (context, c) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final sw = p.width;
      p.dispose();
      // Rakamlara en az ~88 dp (9 hane) bırakılamıyorsa sonek alt satıra iner.
      if (c.maxWidth - sw - 8 < 88) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            field,
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Directionality(textDirection: TextDirection.ltr, child: Text(s, style: style)),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: field),
          const SizedBox(width: 8),
          Directionality(textDirection: TextDirection.ltr, child: Text(s, style: style)),
        ],
      );
    });
  }
}
