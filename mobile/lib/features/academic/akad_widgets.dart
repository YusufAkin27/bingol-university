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
    final fg = selected ? t.bg : t.ink;
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
        child: Padding(
          // expand: görsel hap 2 dp içeriden, anlamsal/dokunma alanı hücrenin tamamı (7 gün sütunu).
          padding: EdgeInsets.symmetric(horizontal: expand ? 2 : 0),
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            curve: BuMotion.standard,
            decoration: ShapeDecoration(
              color: selected ? t.ink : t.sf,
              shape: StadiumBorder(side: BorderSide(color: selected ? t.ink : t.bd)),
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
      ),
    );
  }
}

/// Küçük hap etiket (Resmi, Yeni, Vize...).
class AkadPill extends StatelessWidget {
  const AkadPill(this.text, {super.key, required this.bg, required this.fg, this.icon, this.dot = false});

  final String text;
  final Color bg, fg;
  final IconData? icon;

  /// Başta küçük renkli nokta (durum etiketleri).
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[ExcludeSemantics(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle))), const SizedBox(width: 6)],
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

//// Referanstaki alan biçimi: dolu (sf2) yüzey, çerçevesiz; odakta 2 dp marka, hatada tehlike çizgisi.
InputDecoration akadInput(BuildContext context, {String? hint, String? error, bool tall = false, String? label}) {
  final t = context.bu;
  OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BuRadius.bMd, borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    errorText: error,
    counterText: '',
    filled: true,
    fillColor: t.sf2,
    hintStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.mut),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: b(Colors.transparent, 0),
    disabledBorder: b(Colors.transparent, 0),
    focusedBorder: b(t.pr, 2),
    errorBorder: b(t.danger, 1.5),
    focusedErrorBorder: b(t.danger, 2),
  );
}

/// Alan etiketi: alanın üstünde, küçük ve kalın (referans).
class AkadFieldLabel extends StatelessWidget {
  const AkadFieldLabel(this.text, {super.key, this.color, this.trailing});

  final String text;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = Text(text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: color ?? t.mut));
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
      child: trailing == null ? label : Row(children: [Expanded(child: label), trailing!]),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: Text('*', style: TextStyle(color: context.bu.danger, fontWeight: FontWeight.w800)));
}

/// Etiketi üstte, dolu yüzeyli metin alanı (simge başta).
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
    this.requiredMark = false,
  });

  final bool requiredMark; // etiketin sonunda kırmızı yıldız
  final String label;
  final TextEditingController controller;
  final String? hint, error;
  final int? maxLength;
  final TextCapitalization capitalization;
  final int? minLines, maxLines;
  final IconData? icon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tall = (maxLines ?? 1) > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AkadFieldLabel(label, color: error != null ? t.danger : null, trailing: requiredMark ? const _Star() : null),
      TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        textCapitalization: capitalization,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.ink),
        decoration: akadInput(context, hint: hint, error: error, tall: tall).copyWith(
          prefixIcon: icon == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
                  child: Align(
                      widthFactor: 1,
                      heightFactor: tall ? 3.2 : 1,
                      alignment: tall ? AlignmentDirectional.topStart : Alignment.center,
                      child: Icon(icon, size: 18, color: t.mut)),
                ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: error == null ? null : Icon(LucideIcons.circleAlert, size: 18, color: t.danger),
        ),
      ),
    ]);
  }
}

/// Dokununca seçici açan alan (tarih/saat/liste): metin alanı görünümünde, etiketi üstte.
class AkadPicker extends StatelessWidget {
  const AkadPicker({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.value,
    this.hint,
    this.compact = false,
    this.leading,
    this.bold = false,
    this.error = false,
    this.requiredMark = false,
  });

  final bool requiredMark;
  final String label;
  final IconData icon; // sondaki simge
  final IconData? leading; // baştaki simge
  final bool compact;
  final bool bold; // değer kalın (saat alanları)
  final bool error; // kırmızı çerçeve
  final String? value, hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final shown = value ?? hint ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AkadFieldLabel(label, color: error ? t.danger : null, trailing: requiredMark ? const _Star() : null),
      Semantics(
        button: true,
        label: label,
        value: shown,
        excludeSemantics: true,
        onTap: onTap,
        child: BuPressable(
          onTap: onTap,
          haptic: BuHaptic.selection,
          scale: .98,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.sf2,
              borderRadius: BuRadius.bMd,
              border: error ? Border.all(color: t.danger, width: 1.5) : null,
            ),
            child: Row(children: [
              if (leading != null) ...[Icon(leading, size: 18, color: t.mut), const SizedBox(width: 10)],
              Expanded(
                child: Text(shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.bodyLarge!.copyWith(color: value == null ? t.mut : t.ink, fontWeight: bold && value != null ? FontWeight.w700 : null)),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: error ? t.danger : t.mut),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// Yuvarlak köşeli simge karosu (kart başlarında).
class AkadIconTile extends StatelessWidget {
  const AkadIconTile({super.key, required this.icon, required this.bg, required this.fg, this.size = 48, this.radius = 14, this.iconSize});

  final IconData icon;
  final Color bg, fg;
  final double size, radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
          child: Icon(icon, size: iconSize ?? size * .46, color: fg),
        ),
      );
}

/// Kart içi ortalı boş durum kutusu: yuvarlak simge + başlık + açıklama (+ eylem).
class AkadEmptyBox extends StatelessWidget {
  const AkadEmptyBox({super.key, required this.icon, required this.title, this.message, this.action, this.iconColor});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
      child: Column(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: iconColor ?? t.mut),
        ),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink))),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(message!, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut)),
        ],
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    );
  }
}

// Anahtar satırı (başlık + isteğe bağlı alt yazı + temalı Switch).
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

/// Üstte tam genişlik kehribar şerit ("Güncellenemedi, son veriler gösteriliyor.").
class AkadStaleStrip extends StatelessWidget {
  const AkadStaleStrip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: t.warnSoft,
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 10),
        child: Row(children: [
          ExcludeSemantics(child: Icon(LucideIcons.cloudOff, size: 16, color: t.onWarnSoft)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: t.onWarnSoft))),
        ]),
      ),
    );
  }
}

/// Kehribar bilgi kartı (bakım notu): simge karosu + metin.
class AkadNoticeCard extends StatelessWidget {
  const AkadNoticeCard({super.key, required this.text, this.icon = LucideIcons.wrench});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.warnSoft, borderRadius: BuRadius.bLg),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.sf.withValues(alpha: .7), shape: BoxShape.circle),
            child: ExcludeSemantics(child: Icon(icon, size: 18, color: t.onWarnSoft)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600, color: t.onWarnSoft))),
        ]),
      ),
    );
  }
}

/// Hata kartı: kırmızı simge + başlık + açıklama + "Yeniden dene".
class AkadErrorCard extends StatelessWidget {
  const AkadErrorCard({super.key, required this.title, this.message, required this.onRetry, required this.retryLabel});

  final String title, retryLabel;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: AkadCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: ExcludeSemantics(child: Icon(LucideIcons.circleAlert, size: 20, color: t.onSoft)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: tx.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: t.ink)),
                if (message != null) ...[const SizedBox(height: 4), Text(message!, style: tx.bodyMedium!.copyWith(color: t.mut))],
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: BuButton(label: retryLabel, icon: LucideIcons.rotateCw, compact: true, onPressed: onRetry),
          ),
        ]),
      ),
    );
  }
}

/// Büyük bölüm başlığı (ör. "Günlük akış", "Derslerim [6]"): isteğe bağlı sayaç balonu ve sağda yardımcı.
class AkadTitle extends StatelessWidget {
  const AkadTitle(this.text, {super.key, this.count, this.chip, this.trailing, this.muted = false});

  final String text;
  final int? count;
  final String? chip; // başlık yanında gri hap (gün adı)
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Row(children: [
        Flexible(
          flex: 5,
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, fontSize: 20, color: muted ? t.mut : t.ink)),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: muted ? t.sf2 : t.soft, borderRadius: BuRadius.bPill),
            child: Text('$count', style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w800, color: muted ? t.mut : t.onSoft)),
          ),
        ],
        if (chip != null) ...[
          const SizedBox(width: 8),
          Flexible(flex: 4, child: AkadPill(chip!, bg: t.sf2, fg: t.mut)),
        ],
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Expanded(flex: 4, child: Align(alignment: AlignmentDirectional.centerEnd, child: trailing)),
        ] else
          const Spacer(),
      ]),
    );
  }
}
