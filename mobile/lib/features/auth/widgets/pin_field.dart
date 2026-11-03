import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/locale_controller.dart';
import '../../../core/pin.dart';
import '../../../widgets/bu.dart';
import 'auth_motion.dart';

/// Banka uygulaması tarzı 6 haneli şifre (PIN) alanı: etiket üstte, altında 6 segment (her hane üstte nokta,
/// altta kendi çizgisi; sıradaki hane marka renginde kalın çizgi), sağda 48 dp göz düğmesi (rakamları gösterir).
///
/// İçte gizli bir `TextFormField` vardır: rakam klavyesi, yalnız rakam, en çok 6, otomatik doldurma ve
/// `Form` doğrulaması çalışır; metin görünmez, haneler [controller]'dan çizilir. Bu yüzden testler
/// `find.byType(TextFormField)` ile yazabilir. Tüm şifre alanları (giriş, kayıt, yeni şifre, profil,
/// hesap silme) bu bileşeni kullanır.
class PinField extends StatefulWidget {
  const PinField({
    super.key,
    required this.controller,
    this.label,
    this.validator,
    this.enabled = true,
    this.invalid = false,
    this.autofocus = false,
    this.onCompleted,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;

  /// Varsayılan: "Şifre".
  final String? label;

  /// Form doğrulayıcısı: alandan çıkınca doğrular, hata göründükten sonra yazdıkça düzelir. Boşsa yalnız dışarıdan
  /// [invalid] ile hata gösterilir.
  final String? Function(String?)? validator;
  final bool enabled;

  /// Dışarıdan (sunucu yanıtı vb.) hata durumu: haneler `danger` olur (metni çağıran gösterir).
  final bool invalid;
  final bool autofocus;

  /// 6. rakam girilince bir kez çağrılır.
  final ValueChanged<String>? onCompleted;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  final _key = GlobalKey<FormFieldState<String>>();
  final _focus = FocusNode();
  bool _hidden = true;
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
  void didUpdateWidget(PinField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
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

  bool _fixing = false;

  void _onText() {
    final c = widget.controller;
    // İmleç her zaman sonda kalır: ortaya dokunulsa bile rakam sona eklenir/sondan silinir.
    if (!_fixing && c.value.selection.isValid && c.value.selection.baseOffset != c.text.length ||
        !_fixing && !c.value.selection.isValid && c.text.isNotEmpty) {
      _fixing = true;
      c.value = c.value.copyWith(selection: TextSelection.collapsed(offset: c.text.length));
      _fixing = false;
    }
    final st = _key.currentState;
    if (st != null && (st.hasError || _error != null)) {
      st.validate();
      final e = widget.validator?.call(c.text);
      if (mounted && e != _error) setState(() => _error = e);
    }
  }

  String? _validate(String? v) {
    final e = widget.validator?.call(v);
    if (e != null && _error == null && mounted) _shake++;
    if (e != _error && mounted) {
      // Yapı aşamasında setState yasak: o durumda çerçeve sonrasına ertele.
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

  void _changed(String v) {
    widget.onChanged?.call(v);
    if (v.length == kPinLength) widget.onCompleted?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final fast = AppMotion.of(context, AppMotion.fast);
    final label = widget.label ?? l.authPasswordLabel;
    final hasError = _error != null || widget.invalid;
    // Büyük yazı tercihi hanelerdeki rakamları taşırmasın (320 dp'de 6 hane + göz düğmesi).
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

    final labelColor = hasError
        ? t.danger
        : _focused
            ? t.prPressed
            : t.mut;

    final field = Stack(
      alignment: Alignment.center,
      children: [
        // Gizli giriş: metin ve imleç görünmez; tüm hane alanı dokunmaya açıktır.
        Positioned.fill(
          child: TextFormField(
            key: _key,
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            showCursor: false,
            enableInteractiveSelection: false,
            contextMenuBuilder: (context, state) => const SizedBox.shrink(),
            keyboardType: TextInputType.number,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(kPinLength)],
            validator: _validate,
            errorBuilder: (context, error) => const SizedBox.shrink(),
            autovalidateMode: _touched ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            onChanged: _changed,
            onFieldSubmitted: (_) => widget.onSubmitted?.call(),
            style: const TextStyle(color: Colors.transparent, fontSize: 1, height: 1),
            cursorColor: Colors.transparent,
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              counterText: '',
            ),
          ),
        ),
        // Haneler: yalnız görsel (dokunma alttaki alana geçer). Rakam sırası her dilde soldan sağa.
        Positioned.fill(
          child: IgnorePointer(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  final text = value.text.length > kPinLength ? value.text.substring(0, kPinLength) : value.text;
                  // Altı eşit segment (çizgili alanla aynı dil): her hane üstte nokta/rakam, altta kendi çizgisi.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < kPinLength; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _PinSlot(
                            digit: i < text.length ? text[i] : null,
                            revealed: !_hidden,
                            active: _focused && widget.enabled && i == text.length && text.length < kPinLength,
                            error: hasError,
                            duration: fast,
                            scaler: scaler,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );

    return AuthShake(
      trigger: _shake,
      child: AnimatedOpacity(
        duration: fast,
        opacity: widget.enabled ? 1 : .55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: AnimatedDefaultTextStyle(
                duration: fast,
                curve: AppMotion.standard,
                style: tx.labelLarge!.copyWith(color: labelColor, fontWeight: FontWeight.w600),
                child: Text(label),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  // Tek alan olarak okunur: "Şifre, 6 haneli, n hane girildi" (rakamlar sesli okunmaz).
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, child) => Semantics(
                      textField: true,
                      obscured: _hidden,
                      focused: _focused,
                      enabled: widget.enabled,
                      label: l.pinFieldSemantics(label, '${value.text.length}'),
                      onTap: widget.enabled ? () => _focus.requestFocus() : null,
                      excludeSemantics: true,
                      child: child,
                    ),
                    child: SizedBox(height: 56, child: field),
                  ),
                ),
                IconButton(
                  tooltip: _hidden ? l.authShowPassword : l.authHidePassword,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  padding: EdgeInsets.zero,
                  icon: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff, size: 22, color: hasError ? t.danger : t.mut),
                  onPressed: widget.enabled
                      ? () {
                          authHaptic(AuthHaptic.tap);
                          setState(() => _hidden = !_hidden);
                        }
                      : null,
                ),
              ],
            ),
            AnimatedSize(
              duration: fast,
              curve: AppMotion.enter,
              alignment: Alignment.topCenter,
              child: _error != null
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey('pin-err-$_error'),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: fast,
                      builder: (context, v, child) => Opacity(opacity: v, child: child),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(top: 4),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_error!, style: tx.bodySmall!.copyWith(color: t.danger, fontWeight: FontWeight.w500, height: 1.3)),
                        ),
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

/// Tek hane: üstte nokta (dolunca yumuşakça belirir; rakam açıksa rakam), altta kendi çizgisi. Sıradaki hane çizgisi marka
/// renginde ve kalındır; dolu hane çizgisi `ink`, boş `bdStrong`, hata `danger`.
class _PinSlot extends StatelessWidget {
  const _PinSlot({
    required this.digit,
    required this.revealed,
    required this.active,
    required this.error,
    required this.duration,
    required this.scaler,
  });

  final String? digit;
  final bool revealed;
  final bool active;
  final bool error;
  final Duration duration;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final filled = digit != null;
    final tone = error ? t.danger : t.ink;
    final line = error ? t.danger : (active ? t.pr : (filled ? t.ink : t.bdStrong));
    final Widget mark;
    if (filled && revealed) {
      // Rakam açık: sabit genişlikli rakam, hane başına tek satır.
      mark = Text(
        digit!,
        maxLines: 1,
        textScaler: scaler,
        style: tx.headlineSmall!.copyWith(color: tone, fontSize: 26, fontWeight: FontWeight.w600, height: 1.1, fontFeatures: const [FontFeature.tabularFigures()]),
      );
    } else {
      mark = AnimatedScale(
        scale: filled ? 1 : 0,
        duration: duration,
        curve: AppMotion.interactive,
        child: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: tone)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(left: 0, right: 0, top: 0, bottom: 10, child: Center(child: mark)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.standard,
            height: active ? 3 : 2,
            decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ],
    );
  }
}
