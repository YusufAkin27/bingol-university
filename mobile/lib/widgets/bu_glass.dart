import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// "Liquid Glass" malzemesi (yalnız ALT GEZİNME ÇUBUĞU için; başka yerde kullanılmaz).
///
/// iOS 26 malzemesinin Flutter karşılığı, paketsiz ve tek geçişlidir:
///  1. arkadaki içerik bulanıklaşır ve canlanır (sigma [blurSigma], doygunluk [saturation]),
///  2. yarı saydam nötr dolgu (açıkta beyaz, koyuda koyu taban + hafif beyaz) okunurluğu garanti eder,
///  3. kenar boyunca "kırılma" bandı: kenarda bulanık iç parıltı + üst spekular şerit + alta doğru sönen rim,
///  4. dışa yumuşak gölge (yalnız şeklin DIŞINDA çizilir; saydam dolgunun içinden görünmez).
/// Renkler yalnız tasarım belirteçlerinden gelir (`onMedia` = saf beyaz, `scrim`/`shadow` = siyah, `bg`, `ink`).
/// Ayrıntı: docs/MOBILE_DESIGN_SYSTEM.md "Alt çubuk: Liquid Glass".
abstract final class BuGlass {
  /// Arka plan bulanıklığı (Apple benzeri 18–28 aralığı).
  static const double blurSigma = 22;

  /// Arka plan doygunluk çarpanı (1 = değişmez); cam arkasında içerik canlı kalır.
  static const double saturation = 1.45;

  /// Çubuk dolgusu (sözleşme: karşıtlık testi bu değerleri kullanır). Koyu: `bg` tabanı + üstten alta sönen beyaz; açık: beyaz.
  static const double darkBaseAlpha = .68, darkTintTop = .12, darkTintBottom = .04;
  static const double lightTintTop = .72, lightTintBottom = .58;

  /// Doygunluk matrisi (Rec. 709 parlaklık ağırlıklarıyla).
  static ColorFilter saturationFilter([double s = saturation]) {
    const lr = .2126, lg = .7152, lb = .0722;
    final r = lr * (1 - s), g = lg * (1 - s), b = lb * (1 - s);
    return ColorFilter.matrix(<double>[
      r + s, g, b, 0, 0, //
      r, g + s, b, 0, 0, //
      r, g, b + s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  /// Bulanıklık + doygunluk (BackdropFilter süzgeci).
  static ui.ImageFilter backdrop() => ui.ImageFilter.compose(
        outer: saturationFilter(),
        inner: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma, tileMode: TileMode.mirror),
      );
}

/// Çubuğun cam zemini: arka plan bulanıklığı + dolgu + rim + dış gölge. Üst öğenin boyutunu doldurur; ÇOCUK ALMAZ
/// (simgeler üst katmanda çizilir). Yalnız bu alan bulanıklaşır (ClipRRect) ve ayrı `RepaintBoundary`dedir.
class BuGlassBar extends StatelessWidget {
  const BuGlassBar({super.key, required this.dark, required this.white, required this.base, required this.ink, this.opaque = false, this.opaqueColor, this.opaqueBorder});

  /// Koyu malzeme mi (koyu tema ya da tam ekran video üstü).
  final bool dark;

  /// Spekular beyaz (`onMedia`), taban (`bg`), mürekkep (`ink`) belirteçleri.
  final Color white, base, ink;

  /// Saydamlığı azalt / yüksek karşıtlık / performans yedeği: bulanıklık ve rim yok, düz yüzey + kenarlık.
  final bool opaque;
  final Color? opaqueColor;
  final Color? opaqueBorder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final radius = BorderRadius.circular(c.biggest.shortestSide / 2);
      if (opaque) {
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: opaqueColor,
            shape: StadiumBorder(side: BorderSide(color: opaqueBorder ?? Colors.transparent)),
          ),
        );
      }
      return RepaintBoundary(
        child: CustomPaint(
          painter: _GlassShadowPainter(dark: dark, shadow: dark ? base : ink),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: BuGlass.backdrop(),
              child: CustomPaint(
                painter: BuGlassPainter(kind: BuGlassKind.bar, dark: dark, white: white, base: base, ink: ink),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Seçili sekme kapsülü: cam üstünde daha açık (koyuda) / hafif koyu (açıkta) cam; [energy] 0..1 basılı tutma/sürükleme
/// canlılığı (dolgu ve rim güçlenir). Kendi bulanıklığı yoktur (çubuğun bulanıklığı üstüne biner).
class BuGlassCapsule extends StatelessWidget {
  const BuGlassCapsule({super.key, required this.dark, required this.white, required this.base, required this.ink, this.energy = 0});

  final bool dark;
  final Color white, base, ink;
  final double energy;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BuGlassPainter(kind: BuGlassKind.capsule, dark: dark, white: white, base: base, ink: ink, energy: energy),
      child: const SizedBox.expand(),
    );
  }
}

enum BuGlassKind { bar, capsule }

/// Cam yüzey ressamı (çubuk ve kapsül). Tek geçiş; gölge ayrıdır ([_GlassShadowPainter]).
class BuGlassPainter extends CustomPainter {
  const BuGlassPainter({required this.kind, required this.dark, required this.white, required this.base, required this.ink, this.energy = 0});

  final BuGlassKind kind;
  final bool dark;
  final Color white, base, ink;
  final double energy;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2));
    final bar = kind == BuGlassKind.bar;
    final e = energy.clamp(0.0, 1.0);

    Shader vertical(Color a, Color b) =>
        ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [a, b]);

    // 1) Dolgu.
    if (bar) {
      if (dark) {
        canvas.drawRRect(rr, Paint()..color = base.withValues(alpha: BuGlass.darkBaseAlpha));
        canvas.drawRRect(rr, Paint()..shader = vertical(white.withValues(alpha: BuGlass.darkTintTop), white.withValues(alpha: BuGlass.darkTintBottom)));
      } else {
        canvas.drawRRect(rr, Paint()..shader = vertical(white.withValues(alpha: BuGlass.lightTintTop), white.withValues(alpha: BuGlass.lightTintBottom)));
      }
    } else if (dark) {
      canvas.drawRRect(rr, Paint()..shader = vertical(white.withValues(alpha: .22 + .08 * e), white.withValues(alpha: .10 + .06 * e)));
    } else {
      canvas.drawRRect(rr, Paint()..color = ink.withValues(alpha: .07 + .03 * e));
      canvas.drawRRect(rr, Paint()..shader = vertical(white.withValues(alpha: .60 + .15 * e), white.withValues(alpha: .18 + .10 * e)));
    }

    // 2) Kenar kırılması: kenara yakın bulanık iç parıltı + üst spekular şerit + alt iç gölge (kırpılmış).
    canvas.save();
    canvas.clipRRect(rr);
    final glowA = (dark ? .13 : .45) * (bar ? 1.0 : .8) + .10 * e;
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bar ? 9 : 7
        ..color = white.withValues(alpha: glowA.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    final bandRect = Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * .5);
    canvas.drawRect(
      bandRect,
      Paint()..shader = ui.Gradient.linear(bandRect.topCenter, bandRect.bottomCenter, [
        white.withValues(alpha: dark ? .16 : .40),
        white.withValues(alpha: 0),
      ]),
    );
    final lowRect = Rect.fromLTWH(rect.left, rect.top + rect.height * .62, rect.width, rect.height * .38);
    canvas.drawRect(
      lowRect,
      Paint()..shader = ui.Gradient.linear(lowRect.topCenter, lowRect.bottomCenter, [
        (dark ? base : ink).withValues(alpha: 0),
        (dark ? base : ink).withValues(alpha: dark ? .22 : .06),
      ]),
    );
    canvas.restore();

    // 3) Rim: dış ince çizgi (açık zeminde tanım) + köşegen spekular çizgi + dikey (üstte parlak, altta sönük) çizgi.
    canvas.drawRRect(
      rr.deflate(.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = (dark ? white : ink).withValues(alpha: dark ? .10 : .10),
    );
    final rim = rr.deflate(.9);
    final rimW = bar ? 1.3 : 1.1;
    final diagA = (dark ? .55 : 1.0) + (dark ? .15 : 0) * e;
    canvas.drawRRect(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimW
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            white.withValues(alpha: diagA.clamp(0.0, 1.0)),
            white.withValues(alpha: 0),
            white.withValues(alpha: 0),
            white.withValues(alpha: (diagA * .6).clamp(0.0, 1.0)),
          ],
          const [0, .28, .72, 1],
        ),
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimW
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [
            white.withValues(alpha: dark ? .38 : .90),
            white.withValues(alpha: 0),
            white.withValues(alpha: dark ? .16 : .55),
          ],
          const [0, .5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(BuGlassPainter old) =>
      old.kind != kind || old.dark != dark || old.white != white || old.base != base || old.ink != ink || old.energy != energy;
}

/// Dış gölge: şeklin içi kırpılır (saydam cam dolgusundan görünmesin), yalnız dışa yumuşak gölge düşer.
class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter({required this.dark, required this.shadow});

  final bool dark;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2));
    final outside = Path.combine(PathOperation.difference, Path()..addRect(rect.inflate(80)), Path()..addRRect(rr));
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawRRect(
      rr.shift(const Offset(0, 6)),
      Paint()
        ..color = shadow.withValues(alpha: dark ? .45 : .16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) => old.dark != dark || old.shadow != shadow;
}
