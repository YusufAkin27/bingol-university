import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

// Anket ekranları (An1-An4) ortak görsel parçaları. Renkler yalnız belirteçlerden (context.bu), yazı TextTheme'den.

/// Kapsam tonu (zemin + yazı): Genel mavi, Kulüp su mavisi, Yemek yeşil (`BuTokens.tint`).
class AnketTone {
  const AnketTone(this.bg, this.fg);
  final Color bg;
  final Color fg;

  static AnketTone _of(BuildContext c, int i) {
    final t = c.bu.tint(i);
    return AnketTone(t.bg, t.fg);
  }

  static AnketTone general(BuildContext c) => _of(c, 1);
  static AnketTone club(BuildContext c) => _of(c, BuTintId.aqua);
  static AnketTone meal(BuildContext c) => _of(c, BuTintId.green);
}

/// Yıldız ve puan dağılımı rengi: kehribar tonun doygun hâli (her iki temada altın görünür), belirteçten türetilir.
Color anketGoldOf(BuildContext c) {
  final hsl = HSLColor.fromColor(c.bu.tint(3).fg);
  return hsl.withSaturation(.86).withLightness(.5).toColor();
}

/// Uyarı kutusu renkleri (Oyunuz gizli notu): `warn` ailesi.
({Color bg, Color bd, Color fg}) anketNoteColors(BuildContext c) {
  final t = c.bu;
  return (bg: t.warnSoft, bd: t.warn.withValues(alpha: .28), fg: t.onWarnSoft);
}

/// Eski (tasarım dönemi) metin stili yardımcısı: yeni kodda `Theme.of(context).textTheme` kullanın.
TextStyle anketText(double size, FontWeight w, Color color, {double? height, double? ls}) =>
    TextStyle(fontFamily: BuType.family, fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: ls);

/// Hap rozet (24 dp; [small] 20 dp). Yazı `labelMedium/labelSmall`.
class AnketPill extends StatelessWidget {
  const AnketPill(this.label, {super.key, required this.bg, required this.fg, this.icon, this.small = false});

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final tx = Theme.of(context).textTheme;
    final h = small ? 20.0 : 26.0;
    final style = (small ? tx.labelSmall! : tx.labelMedium!).copyWith(color: fg, fontWeight: FontWeight.w700, height: 1.2);
    return Container(
      constraints: BoxConstraints(minHeight: h),
      padding: EdgeInsetsDirectional.symmetric(horizontal: small ? 8 : 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bPill),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[ExcludeSemantics(child: Icon(icon, size: small ? 11 : 13, color: fg)), const SizedBox(width: 4)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ]),
    );
  }
}

/// Yumuşak zeminli yuvarlak köşeli simge karosu (kapsam/durum simgesi).
class AnketIconTile extends StatelessWidget {
  const AnketIconTile(this.icon, {super.key, required this.bg, required this.fg, this.size = 44});

  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .32)),
          child: Icon(icon, size: size * .5, color: fg),
        ),
      );
}

/// Bilgi/uyarı kutusu: başta simge karosu, yanında metin. [tone] verilmezse tonal gri (`sf2`).
class AnketNotice extends StatelessWidget {
  const AnketNotice({super.key, required this.icon, required this.text, this.tone, this.bordered = false});

  final IconData icon;
  final String text;
  final AnketTone? tone;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final bg = tone?.bg ?? t.sf2;
    final fg = tone?.fg ?? t.ink;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BuRadius.bMd,
        border: bordered ? Border.all(color: fg.withValues(alpha: .22)) : null,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(child: Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: tone?.fg ?? t.mut))),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: tx.bodyMedium!.copyWith(color: fg, height: 1.45))),
      ]),
    );
  }
}

/// Beyaz kart süsü: 20 dp köşe, ince çizgi, yumuşak gölge (koyu temada gölge görünmez).
BoxDecoration anketCardDeco(BuTokens t, {Color? border, double borderWidth = 1}) => BoxDecoration(
      color: t.sf,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border ?? t.bd, width: borderWidth),
      boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .1), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -12)],
    );

/// Sabit alt çubuk: üstte geçişli zemin, altta birincil düğme (An2/An4). [solid] true ise düz yüzey + üst gölge (tasarım 31/32).
class AnketBottomBar extends StatelessWidget {
  const AnketBottomBar({super.key, required this.child, this.solid = false});

  final Widget child;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bottom = MediaQuery.of(context).padding.bottom;
    if (solid) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: t.sf,
          boxShadow: [BoxShadow(color: t.shadow.withValues(alpha: .08), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Padding(padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 12 + bottom), child: child),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0.62, 1],
          colors: [t.bg, t.bg.withValues(alpha: 0)],
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 24, 20, 16 + bottom),
        child: child,
      ),
    );
  }
}

/// Tam genişlik birincil düğme (yükleniyor ve pasif durumlu). `BuButton` için ince sarmalayıcı; imza korunur.
class AnketPrimaryButton extends StatelessWidget {
  const AnketPrimaryButton({super.key, required this.label, this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => BuButton(label: label, onPressed: onPressed, busy: busy);
}

/// Seçenek satırı için kare/yuvarlak işaret (radyo ya da onay kutusu); boşken gri dolgu, seçiliyken marka renginde, geçişi yumuşak.
/// Radyo: marka halkası + iç nokta; onay kutusu: dolu marka karesi + onay işareti.
class AnketMark extends StatelessWidget {
  const AnketMark({super.key, required this.on, required this.square});

  final bool on;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final d = BuMotion.of(context, BuMotion.short);
    final fill = on ? (square ? t.pr : t.sf) : t.sf2;
    return AnimatedContainer(
      duration: d,
      curve: BuMotion.standard,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: fill,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(8) : null,
        border: on && !square ? Border.all(color: t.pr, width: 2) : null,
      ),
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: d,
        curve: Curves.easeOutBack,
        child: Center(
          child: square
              ? Icon(LucideIcons.check, size: 16, color: t.onPr)
              : DecoratedBox(
                  decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                  child: const SizedBox(width: 10, height: 10),
                ),
        ),
      ),
    );
  }
}
