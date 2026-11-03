import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/identifier.dart';
import '../../../core/locale_controller.dart';
import '../../../widgets/bu.dart';
import 'auth_motion.dart';
import 'auth_ref.dart';

/// Giriş sayfasına özel "materyal" yüzeyleri (iOS/visionOS hissi): katmanlı kart, kuyu gibi gömülü alanlar,
/// odakta yumuşak ölçek + halka, cilalı düğme çerçevesi, yumuşak giren bildirim. Backdrop blur YOK (hafif tutulur);
/// derinlik yalnız ince çizgi, çok hafif gradyan ve iki yumuşak gölgeyle verilir. Renkler yalnız `context.bu`,
/// hareket yalnız `AppMotion`; "animasyonları azalt" açıkken tüm geçişler anında olur.

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Katmanlı form kartı: arkada bir "ikinci yaprak" (kenarı görünür), önde çok ince kenarlıklı, üstten alta hafif
/// koyulaşan yüzey ve üst kenarda yatay solan ince vurgu çizgisi.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 20, 18, 18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  static const double radius = 24;
  static const double _peek = 8;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dark = _dark(context);
    // Açıkta kart zeminden azıcık ayrışır, koyuda kuyular (sf) karttan daha koyu = gömülü görünür.
    final top = dark ? Color.lerp(t.sf, t.sf2, .55)! : Color.lerp(t.sf, t.sf2, .25)!;
    final bottom = dark ? Color.lerp(t.sf, t.sf2, .25)! : Color.lerp(t.sf, t.sf2, .8)!;
    final highlight = dark ? t.ink.withValues(alpha: .16) : t.sf;
    return Stack(
      children: [
        // Arka yaprak: kartın altından 8 dp taşar, iki yandan içeride.
        PositionedDirectional(
          start: 20,
          end: 20,
          bottom: 0,
          height: 40,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? Color.lerp(t.bg, t.sf, .6) : t.sf2,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: t.bd),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: _peek),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: BuElevation.of(context, 1),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: t.bd),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
              ),
              child: Stack(
                children: [
                  Padding(padding: padding, child: child),
                  // Üst kenar vurgusu: 1 dp, uçlara doğru solar.
                  PositionedDirectional(
                    top: 0,
                    start: radius * .6,
                    end: radius * .6,
                    height: 1,
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [highlight.withValues(alpha: 0), highlight, highlight.withValues(alpha: 0)]),
                        ),
                      ),
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
}

/// Karta gömülü giriş alanı. [RefTextField] ile aynı doğrulama davranışı (alandan çıkınca doğrula, hata sonrası
/// yazdıkça düzelt, ilk hatada hafif sarsıl); görünüm: iç gölgeli kuyu, odakta %1 büyüme + marka halkası.
class GlassField extends StatefulWidget {
  const GlassField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscureText = false,
    this.trailing,
    this.suffixChip,
    this.onSubmitted,
    this.enabled = true,
    this.autocorrect = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? trailing;
  final String? suffixChip;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final bool autocorrect;

  @override
  State<GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<GlassField> {
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
    final dark = _dark(context);
    final d = AppMotion.of(context, AppMotion.fast);
    final reduced = BuMotion.reduced(context);
    final borderColor = hasError ? t.danger : (_focused ? t.pr : t.bdStrong);
    final halo = hasError ? t.danger.withValues(alpha: .11) : (_focused ? t.pr.withValues(alpha: .20) : t.pr.withValues(alpha: 0));
    final labelColor = hasError ? t.danger : t.ink;
    final iconColor = hasError ? t.danger : (_focused ? t.pr : t.mut);
    // Dar ekran / büyük yazıda sonek hapı satır içinde numaraya yer bırakmaz: alanın altında küçük not olur.
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final wide = MediaQuery.sizeOf(context).width / scale >= 370;
    final suffix = widget.suffixChip;
    final chip = wide ? suffix : null;
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
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        counterText: '',
        hintText: widget.hint,
        hintStyle: tx.bodyLarge!.copyWith(color: t.mut.withValues(alpha: .7)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
          child: AnimatedDefaultTextStyle(
            duration: d,
            curve: AppMotion.enter,
            style: tx.labelLarge!.copyWith(color: labelColor, fontWeight: FontWeight.w600),
            child: ExcludeSemantics(child: Text(widget.label)),
          ),
        ),
        AuthShake(
          trigger: _shake,
          child: AnimatedScale(
            scale: _focused && !reduced ? 1.012 : 1,
            duration: d,
            curve: AppMotion.interactive,
            child: AnimatedContainer(
              duration: d,
              curve: AppMotion.enter,
              constraints: const BoxConstraints(minHeight: kRefFieldH),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 8, 0),
              decoration: BoxDecoration(
                color: t.sf,
                borderRadius: BuRadius.bControl,
                border: Border.all(color: borderColor, width: _focused || hasError ? 1.5 : 1),
                boxShadow: [BoxShadow(color: halo, blurRadius: 0, spreadRadius: 3.5)],
              ),
              // İç gölge: üstten yumuşak koyulaşma (kuyu hissi); odakta kalkar.
              foregroundDecoration: BoxDecoration(
                borderRadius: BuRadius.bControl,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .42],
                  colors: [
                    (dark ? t.bg : t.ink).withValues(alpha: _focused ? 0 : (dark ? .30 : .045)),
                    t.sf.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: d,
                    child: Icon(widget.icon, key: ValueKey(iconColor), size: 20, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Semantics(label: widget.label, child: input)),
                  if (chip != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(8)),
                      // Alan adı her dilde soldan sağa okunur (RTL'de "@" sona kaçmasın).
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(chip, style: tx.bodyMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
        if (suffix != null && !wide)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(suffix, textDirection: TextDirection.ltr, style: tx.bodySmall!.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
            ),
          ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: hasError
              ? SoftEnter(
                  key: ValueKey('glass-err-$err'),
                  dy: 4,
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

/// Okul numarası alanı (yalnız rakam, en çok 12 hane; rakam yazılınca sağda `@bingol.edu.tr`).
class GlassNumberField extends StatelessWidget {
  const GlassNumberField({super.key, required this.controller, this.enabled = true});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => GlassField(
        controller: controller,
        label: context.l10n.authIdNumberLabel,
        icon: BuIcons.idCard,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
        autocorrect: false,
        autofillHints: const [AutofillHints.username],
        validator: validateIdentifier,
        suffixChip: isStudentNumberInput(value.text) ? '@$kEmailDomain' : null,
      ),
    );
  }
}

/// Şifre alanı: göster/gizle gözü (48 dp hedef).
class GlassPasswordField extends StatefulWidget {
  const GlassPasswordField({super.key, required this.controller, this.hint, this.validator, this.onSubmitted, this.enabled = true});

  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final bool enabled;

  @override
  State<GlassPasswordField> createState() => _GlassPasswordFieldState();
}

class _GlassPasswordFieldState extends State<GlassPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return GlassField(
      controller: widget.controller,
      label: context.l10n.authPasswordLabel,
      icon: BuIcons.lock,
      hint: widget.hint,
      obscureText: _hidden,
      autocorrect: false,
      validator: widget.validator,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      keyboardType: TextInputType.visiblePassword,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      trailing: IconButton(
        tooltip: _hidden ? context.l10n.authShowPassword : context.l10n.authHidePassword,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.fast),
          child: Icon(_hidden ? BuIcons.eye : BuIcons.eyeOff, key: ValueKey(_hidden), size: 22, color: t.mut),
        ),
        onPressed: () {
          authHaptic(AuthHaptic.tap);
          setState(() => _hidden = !_hidden);
        },
      ),
    );
  }
}

/// Düğme çerçevesi: [RefButton]'un üstüne ince bir "cam" parlaması (üst kenar çizgisi + üst yarıda hafif ışık) ekler;
/// yüklenirken parlama söner (düğme düzleşir), bitince geri gelir. Basma ölçeği ve etiket<->çember geçişi
/// [RefButton]'dan gelir.
class GlassButtonFrame extends StatelessWidget {
  const GlassButtonFrame({super.key, required this.busy, required this.child});

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final d = AppMotion.of(context, AppMotion.normal);
    final dark = _dark(context);
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedOpacity(
                opacity: busy ? 0 : 1,
                duration: d,
                curve: AppMotion.standard,
                child: ClipRRect(
                  borderRadius: BuRadius.bControl,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BuRadius.bControl,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .5],
                        colors: [t.onMedia.withValues(alpha: dark ? .16 : .10), t.onMedia.withValues(alpha: 0)],
                      ),
                      border: Border(top: BorderSide(color: t.onMedia.withValues(alpha: dark ? .22 : .16))),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hata/uyarı bildirimi için yumuşak kap: ince kenarlı, yumuşak zeminli; içerik [SoftEnter] ile gelir.
class GlassNotice extends StatelessWidget {
  const GlassNotice({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.dangerSoft,
        borderRadius: BorderRadius.circular(BuRadius.sm),
        border: Border.all(color: t.danger.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: ExcludeSemantics(child: Icon(BuIcons.circleAlert, size: 18, color: t.danger)),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Belirirken solarak ve [dy] dp yukarı süzülerek gelir (anahtar değişince yeniden oynar).
class SoftEnter extends StatelessWidget {
  const SoftEnter({super.key, required this.child, this.dy = 8});

  final Widget child;
  final double dy;

  @override
  Widget build(BuildContext context) {
    final d = AppMotion.of(context, AppMotion.normal);
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: d,
      curve: AppMotion.enter,
      child: child,
      builder: (context, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: ch),
      ),
    );
  }
}
