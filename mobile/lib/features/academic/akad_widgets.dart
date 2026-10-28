import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

/// Akademik alt sayfaların (Ak1-Ak8) ortak tasarım bileşenleri.

/// Rengin açık zemin tonu: açıkta beyaz üstüne %11, koyuda yüzey üstüne %22.
Color akadTint(BuildContext context, Color base) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? Color.alphaBlend(base.withValues(alpha: .22), context.bu.sf) : Color.alphaBlend(base.withValues(alpha: .11), Colors.white);
}

/// Ton zemini üzerindeki yazı/simge rengi (koyuda okunur olması için açılır).
Color akadOnTint(BuildContext context, Color base) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark ? Color.lerp(base, Colors.white, .5)! : base;
}

/// Büyük harfe çevirir (Türkçede i -> İ, ı -> I).
String akadUpper(BuildContext context, String s) {
  final lang = Localizations.maybeLocaleOf(context)?.languageCode;
  if (lang == 'tr') return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  return s.toUpperCase();
}

/// Bölüm başlığı (ör. YAKLAŞAN): 12/700, soluk, harf aralıklı.
class AkadSection extends StatelessWidget {
  const AkadSection(this.text, {super.key, this.padding = const EdgeInsetsDirectional.only(start: 6, bottom: 8, top: 4)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Semantics(
          header: true,
          child: Text(akadUpper(context, text),
              style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .6, color: context.bu.mut)),
        ),
      );
}

/// Çip: beyaz/çizgili; seçili: yumuşak kırmızı zemin + kırmızı çizgi. En az 44 dp, 22 yarıçap.
class AkadChip extends StatelessWidget {
  const AkadChip({super.key, required this.label, this.selected = false, this.onTap, this.expand = false, this.semanticLabel, this.fontSize = 14});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool expand; // gün çipleri gibi eşit genişlik
  final String? semanticLabel;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final chip = Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: Material(
        color: selected ? t.soft : t.sf,
        shape: StadiumBorder(side: BorderSide(color: selected ? t.pr : t.bd, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 16),
              child: Center(
                widthFactor: expand ? null : 1,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.4,
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.label.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600, color: selected ? t.danger : t.ink)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return chip;
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
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: fg))),
        ]),
      );
}

/// Kart: beyaz, 1 px çizgi, 20 yarıçap, yumuşak gölge.
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
    final r = BorderRadius.circular(20);
    return Container(
      decoration: BoxDecoration(
        color: color ?? t.sf,
        borderRadius: r,
        border: Border.all(color: borderColor ?? t.bd),
        boxShadow: shadow ? const [BoxShadow(color: Color(0x40171E33), blurRadius: 18, spreadRadius: -12, offset: Offset(0, 6))] : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Ay + gün pulu (54x58 / 50x50).
class AkadDateTile extends StatelessWidget {
  const AkadDateTile({super.key, required this.month, required this.day, required this.bg, required this.fg, this.width = 54, this.height = 58, this.daySize = 22});

  final String month;
  final int day;
  final Color bg, fg;
  final double width, height, daySize;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(akadUpper(context, String.fromCharCodes(month.runes.take(3))),
                maxLines: 1, style: BuType.micro.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
            Text('$day', style: BuType.title.copyWith(fontSize: daySize, fontWeight: FontWeight.w800, height: 1.1, color: fg)),
          ]),
        ),
      );
}

/// Alt sabit eylem çubuğu: sayfa rengine solan zemin üzerinde düğmeler.
class AkadBottomBar extends StatelessWidget {
  const AkadBottomBar({super.key, required this.children});

  final List<Widget> children;

  /// Listelerin altına bırakılacak boşluk.
  static const double reserve = 120;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(20, 28, 20, 16 + bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0.62, 1],
          colors: [t.bg, t.bg.withValues(alpha: 0)],
        ),
      ),
      child: Row(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ]),
    );
  }
}

/// 56 yükseklikli büyük düğme (dolgulu ya da çizgili).
class AkadButton extends StatelessWidget {
  const AkadButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false, this.busy = false, this.accentOutline = false, this.tooltip});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined, busy, accentOutline;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final r = BorderRadius.circular(18);
    final fg = outlined ? (accentOutline ? t.pr : t.ink) : t.onPr;
    final enabled = onPressed != null && !busy;
    final btn = Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: outlined ? null : const [BoxShadow(color: Color(0x99C62A20), blurRadius: 26, spreadRadius: -12, offset: Offset(0, 14))],
      ),
      child: Material(
        color: outlined ? t.sf : (enabled ? t.pr : t.pr.withValues(alpha: .5)),
        shape: RoundedRectangleBorder(borderRadius: r, side: outlined ? BorderSide(color: accentOutline ? t.pr : t.bd, width: 1.5) : BorderSide.none),
        child: InkWell(
          borderRadius: r,
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Center(
              child: busy
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                        Flexible(
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.3,
                            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
                          ),
                        ),
                      ]),
                    ),
            ),
          ),
        ),
      ),
    );
    final wrapped = Semantics(button: true, enabled: enabled, container: true, child: btn);
    return tooltip == null ? wrapped : Tooltip(message: tooltip!, excludeFromSemantics: true, child: wrapped);
  }
}

/// Form etiketi (13/700, hafif içeriden).
class AkadLabel extends StatelessWidget {
  const AkadLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: context.bu.ink)),
      );
}

/// 56 yükseklikli, 16 yarıçaplı, 1.5 çizgili metin alanı biçimi.
InputDecoration akadInput(BuildContext context, {String? hint, String? error, bool tall = false}) {
  final t = context.bu;
  OutlineInputBorder b(Color c, [double w = 1.5]) => OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    errorText: error,
    counterText: '',
    filled: true,
    fillColor: t.sf,
    isDense: false,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: tall ? 14 : 17),
    border: b(t.bd),
    enabledBorder: b(t.bd),
    focusedBorder: b(t.pr),
    errorBorder: b(t.danger),
    focusedErrorBorder: b(t.danger),
  );
}

/// Etiketli metin alanı.
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
  });

  final String label;
  final TextEditingController controller;
  final String? hint, error;
  final int? maxLength;
  final TextCapitalization capitalization;
  final int? minLines, maxLines;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AkadLabel(label),
        TextField(
          controller: controller,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: capitalization,
          style: BuType.body.copyWith(fontSize: 16, color: context.bu.ink),
          decoration: akadInput(context, hint: hint, error: error, tall: (maxLines ?? 1) > 1),
        ),
      ]);
}

/// Dokununca seçici açan alan: değer solda, simge sağda (tarih/saat).
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AkadLabel(label),
      Semantics(
        button: true,
        label: label,
        value: shown,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: t.sf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.bd, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                child: Row(children: [
                  Expanded(
                      child: Text(shown,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.body.copyWith(fontSize: 16, color: value == null ? t.mut : t.ink))),
                  if (!compact) ...[const SizedBox(width: 8), Icon(icon, size: 18, color: t.mut)],
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Anahtar satırı (başlık + isteğe bağlı alt yazı + Switch).
class AkadSwitchRow extends StatelessWidget {
  const AkadSwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsetsDirectional.only(start: 16, end: 8, top: 8, bottom: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: BuType.bodyStrong.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)),
              if (subtitle != null) Text(subtitle!, style: BuType.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.mut)),
            ]),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: t.pr,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD9CFC8),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ]),
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

/// Kesikli kırmızı çizgili düğme (Başka gün ekle).
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
      child: CustomPaint(
        foregroundPainter: _DashedRRect(color: t.pr, radius: 14),
        child: Material(
          color: t.sf,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 16, color: t.pr),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: t.pr))),
                ]),
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
