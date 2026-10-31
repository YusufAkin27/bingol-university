import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/identifier.dart';
import '../../../core/locale_controller.dart';
import '../../../widgets/bu.dart';
import 'auth_motion.dart';

/// Kimlik akışı (Stitch 01/02/03) ortak yapı taşları: düz zemin, beyaz yuvarlak kartlar, üstte etiketli alanlar.
/// Renkler yalnız `context.bu`; yazı `textTheme`. Eski AuthShell/AuthTextField (hareketli sahne) başka paketlerin
/// ekranlarında kullanıldığı için olduğu gibi durur.
const double kRefPad = 16;
const double kRefFieldH = 56;

/// Ekran iskeleti: yalnız geri oku olan üst çubuk + kaydırılan gövde.
class RefPage extends StatelessWidget {
  const RefPage({
    super.key,
    required this.children,
    this.showBack = true,
    this.onBack,
    this.trailing,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.bottomPad = 24,
  });

  final List<Widget> children;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;
  final CrossAxisAlignment crossAxisAlignment;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (showBack)
                      Semantics(
                        button: true,
                        label: context.l10n.authBack,
                        excludeSemantics: true,
                        onTap: onBack ?? () => Navigator.maybePop(context),
                        child: IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: Icon(buDirIcon(context, LucideIcons.arrowLeft), color: t.ink, size: 24),
                          onPressed: onBack ?? () => Navigator.maybePop(context),
                        ),
                      ),
                    const Spacer(),
                    if (trailing != null) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: trailing),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsetsDirectional.fromSTEB(kRefPad, 0, kRefPad, bottomPad),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    // Ekran öğeleri [BuStaggerItem] ile sarılırsa kapsam her indeksi yalnız bir kez oynatır.
                    child: BuStaggerScope(child: Column(crossAxisAlignment: crossAxisAlignment, children: children)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Başlık + açıklama (sola dayalı). [emphasis] açıklamada kalın gösterilir (ör. e-posta).
class RefHeading extends StatelessWidget {
  const RefHeading({super.key, required this.title, this.subtitle, this.emphasis, this.center = false});

  final String title;
  final String? subtitle;
  final String? emphasis;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final align = center ? TextAlign.center : TextAlign.start;
    final base = tx.bodyLarge!.copyWith(color: t.mut, height: 1.45);
    final s = subtitle;
    Widget? sub;
    if (s != null) {
      final e = emphasis;
      final at = e == null ? -1 : s.indexOf(e);
      sub = at < 0
          ? Text(s, textAlign: align, style: base)
          : Text.rich(
              TextSpan(style: base, children: [
                TextSpan(text: s.substring(0, at)),
                TextSpan(text: e, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                TextSpan(text: s.substring(at + e!.length)),
              ]),
              textAlign: align,
            );
    }
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, textAlign: align, style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.2)),
        ),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 8), child: sub),
      ],
    );
  }
}

/// Başlık üstündeki yuvarlak köşeli simge karosu.
class RefIconTile extends StatelessWidget {
  const RefIconTile(this.icon, {super.key, this.size = 56, this.bg, this.fg, this.radius = 18});

  final IconData icon;
  final double size;
  final Color? bg;
  final Color? fg;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? t.soft, borderRadius: BorderRadius.circular(radius)),
      child: Icon(icon, color: fg ?? t.pr, size: size * .46),
    );
  }
}

/// Beyaz yuvarlak kart (28 dp), açık temada ince gölge.
class RefCard extends StatelessWidget {
  const RefCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 28, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? t.sf,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: BuElevation.of(context, 1),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

enum RefTone { error, warn, info, success, neutral }

/// Satır içi durum bandı: yuvarlak simge + başlık/metin (+ ikinci satır, kapat, eylemler).
class RefBanner extends StatelessWidget {
  const RefBanner(
    this.text, {
    super.key,
    this.tone = RefTone.error,
    this.icon,
    this.title,
    this.sub,
    this.subIcon,
    this.onClose,
    this.closeKey,
    this.actions = const [],
    this.boldText = false,
  });

  final String text;
  final RefTone tone;
  final IconData? icon;

  /// Verilirse kalın başlık; [text] altında açıklama olur.
  final String? title;

  /// Metin altında küçük ikinci satır (ör. "40 sn sonra tekrar deneyin.").
  final String? sub;
  final IconData? subIcon;
  final VoidCallback? onClose;
  final Key? closeKey;
  final List<Widget> actions;
  final bool boldText;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, ic) = switch (tone) {
      RefTone.error => (cs.errorContainer, t.danger, LucideIcons.circleAlert),
      RefTone.warn => (t.warnSoft, t.onWarnSoft, LucideIcons.triangleAlert),
      RefTone.info => (t.tint(1).bg, t.ink, LucideIcons.info),
      RefTone.success => (t.okSoft, t.ok, LucideIcons.circleCheck),
      RefTone.neutral => (t.sf2, t.ink, LucideIcons.info),
    };
    final accent = switch (tone) {
      RefTone.warn => t.warn,
      RefTone.info => t.tint(1).fg,
      _ => fg,
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .14)),
              child: Icon(icon ?? ic, color: accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(title!, style: tx.titleSmall!.copyWith(color: tone == RefTone.info ? t.ink : fg, fontWeight: FontWeight.w800)),
                    Text(text,
                        style: tx.bodyMedium!.copyWith(
                            color: tone == RefTone.info ? t.mut : fg, height: 1.4, fontWeight: boldText || title == null ? FontWeight.w600 : FontWeight.w400)),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (subIcon != null) ...[Icon(subIcon, size: 14, color: fg), const SizedBox(width: 6)],
                            Flexible(child: Text(sub!, style: tx.bodySmall!.copyWith(color: fg, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                    for (final a in actions) Padding(padding: const EdgeInsets.only(top: 12), child: a),
                  ],
                ),
              ),
            ),
            if (onClose != null)
              IconButton(
                key: closeKey,
                tooltip: context.l10n.commonClose,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(LucideIcons.x, size: 18, color: fg),
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }
}

/// Kısa bilgi kartı: yuvarlak simge + metin (ör. "Bölümünüz ... kullanılır.").
class RefNote extends StatelessWidget {
  const RefNote(this.text, {super.key, this.icon = LucideIcons.info, this.tone = RefTone.neutral, this.title, this.iconTint});

  final String text;
  final IconData icon;
  final RefTone tone;
  final String? title;

  /// Simge dairesi için kategori rengi (verilmezse tonun rengi).
  final BuTint? iconTint;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    var (bg, iconBg, iconFg) = switch (tone) {
      RefTone.error => (t.soft.withValues(alpha: .55), t.soft, t.pr),
      RefTone.info => (t.tint(1).bg, t.sf, t.tint(1).fg),
      _ => (t.sf2, t.sf, t.mut),
    };
    if (iconTint != null) {
      iconBg = iconTint!.bg;
      iconFg = iconTint!.fg;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                Text(text, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum RefButtonKind { primary, secondary, warn, danger, soft }

/// Ana eylem: 56 dp, 20 dp yuvarlak; etiket + sonda ok; yüklenirken çember + [busyLabel].
class RefButton extends StatelessWidget {
  const RefButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.busyLabel,
    this.kind = RefButtonKind.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final String? busyLabel;
  final RefButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (kind) {
      RefButtonKind.primary => (t.pr, t.onPr),
      RefButtonKind.warn => (t.warn, dark ? t.bg : t.onMedia),
      RefButtonKind.secondary => (t.sf, t.ink),
      RefButtonKind.danger => (Theme.of(context).colorScheme.error, Theme.of(context).colorScheme.onError),
      RefButtonKind.soft => (t.tint(1).bg, t.tint(1).fg),
    };
    final disabled = onPressed == null && !busy;
    final faded = busy || disabled;
    final fill = kind == RefButtonKind.secondary ? bg : (faded ? bg.withValues(alpha: busy ? .5 : .45) : bg);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: kind == RefButtonKind.secondary ? BorderSide(color: t.bd) : BorderSide.none,
    );
    final content = busy
        ? Row(
            key: const ValueKey('ref-btn-busy'),
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg)),
              if (busyLabel != null) ...[
                const SizedBox(width: 12),
                Flexible(child: Text(busyLabel!, style: tx.titleMedium!.copyWith(color: fg, fontWeight: FontWeight.w700))),
              ],
            ],
          )
        : Row(
            key: const ValueKey('ref-btn-label'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: tx.titleMedium!.copyWith(color: disabled && kind == RefButtonKind.secondary ? t.mut : fg, fontWeight: FontWeight.w700)),
              ),
              if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20, color: fg)],
            ],
          );
    final tap = busy || disabled
        ? null
        : () {
            authHaptic(AuthHaptic.tap);
            onPressed!();
          };
    return Semantics(
      button: true,
      enabled: !disabled && !busy,
      label: busy ? (busyLabel ?? label) : null,
      child: BuPressable(
        scale: .985,
        enabled: tap != null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: kind == RefButtonKind.primary && !faded && !dark
                ? [BoxShadow(color: t.pr.withValues(alpha: .28), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -4)]
                : const [],
          ),
          child: Material(
            color: fill,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: tap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kRefFieldH),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  // Etiket <-> çember yumuşak geçer (150 ms; azalt açıkken anında).
                  child: Center(
                    heightFactor: 1,
                    child: AnimatedSwitcher(duration: BuMotion.of(context, BuMotion.short), child: content),
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

/// Bağlantı gibi metin eylemi (en az 48 dp).
class RefLink extends StatelessWidget {
  const RefLink({super.key, required this.label, required this.onPressed, this.muted = false, this.icon, this.color, this.compact = false});

  final String label;

  /// Satır içi küçük bağlantı: görsel yükseklik 32 dp, dokunma alanı yine 48 dp.
  final bool compact;
  final VoidCallback? onPressed;
  final bool muted;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final c = color ?? (muted ? t.mut : t.pr);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: c,
        minimumSize: Size(48, compact ? 32 : 48),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: c), const SizedBox(width: 6)],
          Flexible(child: Text(label, style: tx.labelLarge!.copyWith(color: c, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// "Hesabınız yok mu? Kayıt ol" satırı.
class RefFooterPrompt extends StatelessWidget {
  const RefFooterPrompt({super.key, required this.prompt, required this.action, required this.onPressed});

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
            foregroundColor: t.pr,
          ),
          child: Text(action, style: tx.titleSmall!.copyWith(color: t.pr, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

/// Etiketli metin alanı: etiket kutunun üstünde (ya da [innerLabel] ile içinde), dolgulu yuvarlak kutu,
/// satır içi hata/yardım metni. "Kullanıcıyı cezalandırmayan" doğrulama: alandan çıkınca doğrular,
/// hata göründükten sonra yazdıkça anında düzelir. İçte TextFormField (Form doğrulaması çalışır).
class RefTextField extends StatefulWidget {
  const RefTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.helper,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscureText = false,
    this.trailing,
    this.suffixChip,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.innerLabel = false,
    this.onCard = false,
    this.autocorrect = true,
    this.forceError,
    this.focusNode,
    this.labelAction,
  });

  final TextEditingController controller;
  final String label;

  /// Soldaki simge; null ise simgesiz alan.
  final IconData? icon;
  final String? hint;
  final String? helper;

  /// Etiket satırının sağında küçük eylem (ör. "Şifremi unuttum").
  final Widget? labelAction;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;

  /// Sağ uçta (göz düğmesi gibi) parça.
  final Widget? trailing;

  /// Sağ uçta beyaz hap içinde sabit metin (ör. "@bingol.edu.tr").
  final String? suffixChip;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  /// Küçük etiket kutunun içinde değerin üstünde durur.
  final bool innerLabel;

  /// Beyaz kart üstünde: gri dolgu (kart dışında beyaz dolgu + ince çizgi).
  final bool onCard;
  final bool autocorrect;

  /// Doğrulayıcıdan bağımsız, dışarıdan verilen hata (ör. sunucu yanıtı); null ise yok.
  final String? forceError;
  final FocusNode? focusNode;

  @override
  State<RefTextField> createState() => _RefTextFieldState();
}

class _RefTextFieldState extends State<RefTextField> {
  final _key = GlobalKey<FormFieldState<String>>();
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());
  bool _touched = false;
  bool _focused = false;
  String? _error;

  /// Hata ilk kez belirince alan hafifçe sarsılır (azalt açıkken sarsılmaz).
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
    _own?.dispose();
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
      // Yazarken düzelen hata hemen kalksın (çerçeve beklemeden).
      final e = widget.validator?.call(widget.controller.text);
      if (mounted && e != _error) setState(() => _error = e);
    }
  }

  String? _validate(String? v) {
    final e = widget.validator?.call(v);
    if (e != null && _error == null && mounted) _shake++;
    if (e != _error && mounted) {
      // Yapı (build) aşamasında setState yasak: o durumda çerçeve sonrasına ertele.
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
    final err = widget.forceError ?? _error;
    final hasError = err != null;
    final fill = hasError
        ? Color.alphaBlend(t.danger.withValues(alpha: .09), widget.onCard ? t.sf2 : t.sf)
        : (widget.onCard ? t.sf2 : t.sf);
    final borderColor = hasError
        ? t.danger.withValues(alpha: .55)
        : _focused
            ? t.pr
            : (widget.onCard ? Colors.transparent : t.bd);
    final iconColor = hasError ? t.danger : (_focused ? t.pr : t.mut);
    final textStyle = tx.bodyLarge!.copyWith(color: hasError ? t.danger : t.ink, fontWeight: FontWeight.w500);
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
      maxLength: widget.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textCapitalization: widget.textCapitalization,
      validator: _validate,
      // Hata metnini kendimiz çiziyoruz; yerleşik hata alanı yer kaplamasın/ikinci kez okunmasın.
      errorBuilder: (context, error) => const SizedBox.shrink(),
      autovalidateMode: _touched ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      onChanged: widget.onChanged,
      style: textStyle,
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
        // Dokunma/anlam hedefi >= 44 dp olsun diye yatay çizgiler dışında dikey boşluk.
        contentPadding: EdgeInsets.symmetric(vertical: widget.innerLabel ? 6 : 12),
        counterText: '',
        hintText: widget.hint,
        hintStyle: tx.bodyLarge!.copyWith(color: t.mut.withValues(alpha: .7)),
      ),
    );
    final chip = widget.suffixChip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.innerLabel)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.label, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                ),
                if (widget.labelAction != null) widget.labelAction!,
              ],
            ),
          ),
        AuthShake(
          trigger: _shake,
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            constraints: BoxConstraints(minHeight: widget.innerLabel ? 68 : kRefFieldH),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: _focused || hasError ? 1.5 : 1),
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 22, color: iconColor),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: widget.innerLabel
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.label, style: tx.bodySmall!.copyWith(color: hasError ? t.danger : t.mut, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            input,
                          ],
                        )
                      : input,
                ),
                if (chip != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: widget.onCard && !hasError ? t.sf : (hasError ? t.sf : t.sf2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(chip, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                  ),
                ],
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
        // Hata metni: alan yumuşakça uzar, metin solarak belirir (azalt açıkken anında).
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.decelerate,
          alignment: Alignment.topCenter,
          // Kalkarken anında kalkar (düzelten kullanıcı beklemez); belirirken solarak gelir.
          child: hasError
              ? TweenAnimationBuilder<double>(
                  key: ValueKey('ref-err-$err'),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: BuMotion.of(context, BuMotion.short),
                  builder: (context, v, child) => Opacity(opacity: v, child: child),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 8, start: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(LucideIcons.circleAlert, size: 16, color: t.danger)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(err, style: tx.bodyMedium!.copyWith(color: t.danger, fontWeight: FontWeight.w500, height: 1.3))),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8, start: 4),
            child: Text(widget.helper!, style: tx.bodySmall!.copyWith(color: t.mut)),
          ),
      ],
    );
  }
}

/// Parola alanı: göster/gizle gözü (48 dp hedef).
class RefPasswordField extends StatefulWidget {
  const RefPasswordField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.onChanged,
    this.enabled = true,
    this.innerLabel = false,
    this.onCard = false,
    this.forceError,
    this.labelAction,
    this.showIcon = true,
  });

  final TextEditingController controller;
  final String? label;
  final bool showIcon;
  final String? hint;
  final Widget? labelAction;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final Iterable<String> autofillHints;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool innerLabel;
  final bool onCard;
  final String? forceError;

  @override
  State<RefPasswordField> createState() => _RefPasswordFieldState();
}

class _RefPasswordFieldState extends State<RefPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return RefTextField(
      controller: widget.controller,
      label: widget.label ?? context.l10n.authPasswordLabel,
      hint: widget.hint,
      icon: widget.showIcon ? LucideIcons.lock : null,
      obscureText: _hidden,
      autocorrect: false,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      innerLabel: widget.innerLabel,
      onCard: widget.onCard,
      forceError: widget.forceError,
      labelAction: widget.labelAction,
      keyboardType: TextInputType.visiblePassword,
      trailing: IconButton(
        tooltip: _hidden ? context.l10n.authShowPassword : context.l10n.authHidePassword,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 22, color: t.mut),
        onPressed: () {
          authHaptic(AuthHaptic.tap);
          setState(() => _hidden = !_hidden);
        },
      ),
    );
  }
}

/// Okul numarası ya da e-posta alanı. Yalnız rakam yazılırken (okul numarası) sağda `@bingol.edu.tr` hapı görünür;
/// tam adres yazılınca hap kalkar.
class RefIdentifierField extends StatelessWidget {
  const RefIdentifierField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.enabled = true,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onCard = false,
    this.forceError,
    this.helper = true,
    this.label,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final TextInputAction textInputAction;
  final bool onCard;
  final String? forceError;
  final bool helper;

  /// Etiket (varsayılan: okul e-postanız).
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => RefTextField(
        controller: controller,
        label: label ?? context.l10n.authIdHint,
        helper: helper ? context.l10n.authIdHelper : null,
        icon: LucideIcons.atSign,
        enabled: enabled,
        onCard: onCard,
        forceError: forceError,
        keyboardType: TextInputType.emailAddress,
        textInputAction: textInputAction,
        autocorrect: false,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        validator: validator ?? validateIdentifier,
        onSubmitted: onSubmitted,
        suffixChip: isStudentNumberInput(value.text) ? '@$kEmailDomain' : null,
      ),
    );
  }
}

/// Kart içi tek satırlık durum hapı (kod hatalı, yeni kod gönderildi gibi).
class RefPill extends StatelessWidget {
  const RefPill(this.text, {super.key, this.tone = RefTone.error});

  final String text;
  final RefTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, ic) = switch (tone) {
      RefTone.success => (t.okSoft, t.ok, LucideIcons.circleCheck),
      RefTone.warn => (t.warnSoft, t.onWarnSoft, LucideIcons.triangleAlert),
      _ => (cs.errorContainer, t.danger, LucideIcons.circleAlert),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(ic, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: tx.bodyMedium!.copyWith(color: fg, fontWeight: FontWeight.w600, height: 1.3))),
          ],
        ),
      ),
    );
  }
}

/// Marka karosu: kırmızı yuvarlak kare + beyaz "BU" (Stitch karşılama/giriş logosu).
class RefBrandMark extends StatelessWidget {
  const RefBrandMark({super.key, this.size = 48, this.badge = false});

  final double size;

  /// Sağ alt köşede küçük mezuniyet şapkası rozeti (giriş kartı).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.pr,
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: [BoxShadow(color: t.pr.withValues(alpha: .25), blurRadius: size * .25, offset: Offset(0, size * .08))],
      ),
      child: Text('BU',
          style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: t.onPr, fontWeight: FontWeight.w900, fontSize: size * .42, letterSpacing: -.5, height: 1)),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            tile,
            if (badge)
              PositionedDirectional(
                end: -size * .08,
                bottom: -size * .08,
                child: Container(
                  width: size * .36,
                  height: size * .36,
                  decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle, boxShadow: BuElevation.of(context, 1)),
                  child: Icon(LucideIcons.graduationCap, size: size * .2, color: t.pr),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
