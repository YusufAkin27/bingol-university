import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Akademik alt sayfaların (Ak1-Ak8) ortak tasarım bileşenleri (Material 3 + marka).

/// Rengin açık zemin tonu: açıkta yüzey üstüne %11, koyuda %22.
Color akadTint(BuildContext context, Color base) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Color.alphaBlend(base.withValues(alpha: dark ? .22 : .11), context.bu.sf);
}

/// Ton zemini üzerindeki yazı/simge rengi (koyuda okunur olması için açılır).
Color akadOnTint(BuildContext context, Color base) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? Color.lerp(base, context.bu.onMedia, .5)! : base;
}

/// Büyük harfe çevirir (Türkçede i -> İ, ı -> I).
String akadUpper(BuildContext context, String s) {
  final lang = Localizations.maybeLocaleOf(context)?.languageCode;
  if (lang == 'tr') return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  return s.toUpperCase();
}

bool _isArabic(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

/// Bölüm başlığı (ör. YAKLAŞAN): küçük, soluk, harf aralıklı; ekran okuyucuya başlık.
class AkadSection extends StatelessWidget {
  const AkadSection(this.text, {super.key, this.padding = const EdgeInsetsDirectional.only(start: 4, bottom: 8, top: 4), this.trailing});

  final String text;
  final EdgeInsetsGeometry padding;

  /// Satır sonunda küçük yardımcı (sayaç vb.).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = Text(akadUpper(context, text),
        style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, letterSpacing: _isArabic(context) ? 0 : .7, color: t.mut));
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: trailing == null ? label : Row(children: [Expanded(child: label), trailing!]),
      ),
    );
  }
}

/// Çip: seçili = marka tonu (soft + onSoft), kayan renk geçişi, titreşim + hafif küçülme. Dokunma hedefi >= 48 dp.
class AkadChip extends StatelessWidget {
  const AkadChip({super.key, required this.label, this.selected = false, this.onTap, this.expand = false, this.semanticLabel, this.fontSize = 14});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expand; // gün çipleri gibi eşit genişlik
  final String? semanticLabel;

  /// Eski imza (kullanılmaz; yazı boyutu TextTheme'den gelir). `expand` çiplerde etiket küçülerek sığar.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fg = selected ? t.onSoft : t.ink;
    void tap() {
      buHaptic(BuHaptic.selection);
      onTap?.call();
    }

    final text = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: expand
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: tx.labelLarge!.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: fg)),
            )
          : Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx.labelLarge!.copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: fg)),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: BuPressable(
        scale: .95,
        child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.standard,
          decoration: ShapeDecoration(
            color: selected ? t.soft : t.sf,
            shape: StadiumBorder(side: BorderSide(color: selected ? t.pr.withValues(alpha: .5) : t.bd)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              excludeFromSemantics: true,
              onTap: onTap == null ? null : tap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: expand ? 2 : 16),
                  child: Center(widthFactor: expand ? null : 1, child: text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük hap etiket (Resmi, Yeni, Vize...).
class AkadPill extends StatelessWidget {
  const AkadPill(this.text, {super.key, required this.bg, required this.fg, this.icon});

  final String text;
  final Color bg, fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: 12, color: fg)), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: fg)),
          ),
        ]),
      );
}

/// Kart: yüzey rengi, ince çizgi, 20 yarıçap; [shadow] açıkken yumuşak gölge (koyuda yok). Tıklanabilirse basınca küçülür.
class AkadCard extends StatelessWidget {
  const AkadCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.borderColor, this.color, this.shadow = true});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor, color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    const r = BuRadius.bLg;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? t.sf,
        borderRadius: r,
        border: Border.all(color: borderColor ?? t.bd),
        boxShadow: shadow ? BuElevation.of(context, 1) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
    return onTap == null ? card : BuPressable(scale: .985, child: card);
  }
}

/// Ay + gün pulu (54x58 / 50x50).
class AkadDateTile extends StatelessWidget {
  const AkadDateTile(
      {super.key, required this.month, required this.day, required this.bg, required this.fg, this.width = 54, this.height = 58, this.daySize = 22});

  final String month;
  final int day;
  final Color bg, fg;
  final double width, height;

  /// Eski imza (kullanılmaz; sayı TextTheme.titleLarge ile yazılır).
  final double daySize;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bMd),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(akadUpper(context, String.fromCharCodes(month.runes.take(3))),
                maxLines: 1, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: fg, height: 1.1)),
            Text('$day', style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, height: 1.1, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// Alt sabit eylem çubuğu: yüzey zemini + ince üst çizgi; düğmeler eşit genişlikte. `Scaffold.bottomNavigationBar`
/// olarak ya da `AcademicScaffold.bottomBar` ile kullanılır.
class AkadBottomBar extends StatelessWidget {
  const AkadBottomBar({super.key, required this.children});

  final List<Widget> children;

  /// Listelerin altına bırakılacak boşluk ([AcademicScaffold] içindeki eski yerleşim için).
  static const double reserve = 120;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.bd.withValues(alpha: .7))),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12 + bottom),
        child: Row(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ]),
      ),
    );
  }
}

/// Büyük düğme: dolgulu (birincil) ya da çizgili. [BuButton] üzerine ince sarmalayıcı (eski imza).
class AkadButton extends StatelessWidget {
  const AkadButton(
      {super.key, required this.label, required this.onPressed, this.icon, this.outlined = false, this.busy = false, this.accentOutline = false, this.tooltip});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined, busy, accentOutline;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = BuButton(
      label: label,
      icon: icon,
      busy: busy,
      kind: !outlined ? BuButtonKind.primary : (accentOutline ? BuButtonKind.soft : BuButtonKind.outline),
      onPressed: onPressed,
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, excludeFromSemantics: true, child: btn);
  }
}

/// Form etiketi (bölüm içi alt başlık).
class AkadLabel extends StatelessWidget {
  const AkadLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: context.bu.ink)),
      );
}

/// Tema (dolu, çerçeveli, odakta 2 dp marka) metin alanı biçimi; yalnız ipucu/hata ve sayaç gizleme ekler.
InputDecoration akadInput(BuildContext context, {String? hint, String? error, bool tall = false, String? label}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    counterText: '',
    floatingLabelBehavior: label == null ? null : FloatingLabelBehavior.auto,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: tall ? 16 : 16),
  );
}

/// Etiketli metin alanı (yüzen etiket; hata altında kırmızı).
class AkadTextField extends StatelessWidget {
  const AkadTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.maxLength,
    this.capitalization = TextCapitalization.none,
    this.minLines,
    this.maxLines = 1,
    this.icon,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint, error;
  final int? maxLength;
  final TextCapitalization capitalization;
  final int? minLines, maxLines;
  final IconData? icon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: capitalization,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: context.bu.ink),
        decoration: akadInput(context, hint: hint, error: error, label: label, tall: (maxLines ?? 1) > 1).copyWith(
          prefixIcon: icon == null ? null : Icon(icon, size: 18),
          alignLabelWithHint: (maxLines ?? 1) > 1,
        ),
      );
}

/// Dokununca seçici açan alan (tarih/saat): metin alanı görünümünde, yüzen etiketli.
class AkadPicker extends StatelessWidget {
  const AkadPicker({super.key, required this.label, required this.icon, required this.onTap, this.value, this.hint, this.compact = false});

  final String label;
  final IconData icon;
  final bool compact; // dar sütun: simgesiz, 12 dp iç boşluk
  final String? value, hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final shown = value ?? hint ?? '';
    return Semantics(
      button: true,
      label: label,
      value: shown,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        onTap: onTap,
        haptic: BuHaptic.selection,
        scale: .98,
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 16),
            suffixIcon: compact ? null : Icon(icon, size: 18),
          ),
          child: Text(shown,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: value == null ? t.mut : t.ink)),
        ),
      ),
    );
  }
}

/// Anahtar satırı (başlık + isteğe bağlı alt yazı + temalı Switch).
class AkadSwitchRow extends StatelessWidget {
  const AkadSwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return MergeSemantics(
      child: InkWell(
        onTap: () {
          buHaptic(BuHaptic.selection);
          onChanged(!value);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsetsDirectional.only(start: 16, end: 8, top: 8, bottom: 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
                if (subtitle != null) Text(subtitle!, style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ),
            Switch(value: value, onChanged: onChanged),
          ]),
        ),
      ),
    );
  }
}

/// Kart içi satırlar arası ince ayraç.
class AkadDivider extends StatelessWidget {
  const AkadDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, color: context.bu.bd.withValues(alpha: .6));
}

/// Yönlü ikon düğmesi kısayolu (başlık eylemleri).
Widget akadHeaderAction(BuildContext context, {required IconData icon, required String tooltip, VoidCallback? onTap}) =>
    BuIconButton(icon: icon, tooltip: tooltip, onTap: onTap);

/// Kesikli marka çizgili, tonal dolgulu düğme (Başka gün ekle).
class AkadDashedButton extends StatelessWidget {
  const AkadDashedButton({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      container: true,
      child: BuPressable(
        scale: .98,
        child: CustomPaint(
          foregroundPainter: _DashedRRect(color: t.pr.withValues(alpha: .55), radius: BuRadius.sm),
          child: Material(
            color: t.soft.withValues(alpha: .55),
            borderRadius: BuRadius.bSm,
            child: InkWell(
              borderRadius: BuRadius.bSm,
              onTap: () {
                buHaptic(BuHaptic.selection);
                onPressed();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 16, color: t.onSoft),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft)),
                      ),
                    ]),
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

class _DashedRRect extends CustomPainter {
  _DashedRRect({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color || old.radius != radius;
}
