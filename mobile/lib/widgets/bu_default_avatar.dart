import 'package:flutter/material.dart';

/// Varsayılan profil görseli (N4): fotoğraf yokken / yüklenirken / yüklenemediğinde HER avatarın altında durur.
/// Baş harf yerine yumuşak gradyan zemin + sade, yüzsüz, cinsiyetsiz kişi silueti (omuz + baş) çizilir.
/// Tümü vektörel (varlık dosyası yok): her boyutta net, 24 dp'de de okunur.
///
/// Renk [seed]'den (genelde kişi/grup adı) KARARLI seçilir: aynı kişi her yerde aynı rengi alır.
/// Altı marka uyumlu varyant vardır ([variantCount]). Görsel dekoratiftir (anlamsal etiketi yok).
/// Yuvarlak/yuvarlatılmış kırpmayı çağıran yapar (`BuAvatar`/`ChatlistAvatar`); kare tam taşar.
class BuDefaultAvatar extends StatelessWidget {
  const BuDefaultAvatar(
      {super.key, this.seed, this.size = 48, this.group = false, this.variant});

  /// Renk varyantını belirleyen metin/sayı (ad, kimlik). Boşsa varyant 0.
  final Object? seed;
  final double size;

  /// true: üç kişilik grup silueti (grup/kulüp/etkinlik).
  final bool group;

  /// Verilirse seed yerine bu varyant (0..[variantCount]-1) kullanılır (test/galeri).
  final int? variant;

  static const int variantCount = 6;

  /// [seed] için kararlı varyant (FNV-1a; `String.hashCode`'a bağlı değil).
  static int variantFor(Object? seed) {
    final s = (seed ?? '').toString().trim().toLowerCase();
    if (s.isEmpty) return 0;
    var h = 0x811c9dc5;
    for (final r in s.runes) {
      h = ((h ^ r) * 0x01000193) & 0x7fffffff;
    }
    return h % variantCount;
  }

  @override
  Widget build(BuildContext context) {
    final v = (variant ?? variantFor(seed)) % variantCount;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _AvatarPainter(v, group)),
      ),
    );
  }
}

/// Üst renk, alt renk (gradyan) ve siluet rengi. Tümü marka paletinden türetilmiştir.
class _Palette {
  const _Palette(this.top, this.bottom, this.glow);
  final Color top;
  final Color bottom;
  final Color glow;
}

const _palettes = <_Palette>[
  _Palette(Color(0xFFFF9A8C), Color(0xFFD9332A),
      Color(0xFFFFD2CB)), // marka kırmızısı
  _Palette(Color(0xFF4A5C94), Color(0xFF171E33), Color(0xFF9FB0E6)), // lacivert
  _Palette(
      Color(0xFFE8C9A0), Color(0xFFB9855A), Color(0xFFFFEFD9)), // krem / kum
  _Palette(Color(0xFF6FCBC0), Color(0xFF1D7A82), Color(0xFFC6F3EC)), // turkuaz
  _Palette(Color(0xFFA99BEA), Color(0xFF5A44B5), Color(0xFFDDD5FF)), // mor
  _Palette(Color(0xFF86B8F7), Color(0xFF2B63C2), Color(0xFFD3E5FF)), // mavi
];

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter(this.variant, this.group);

  final int variant;
  final bool group;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _palettes[variant];
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    // Zemin: köşegen gradyan.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.top, p.bottom],
        ).createShader(rect),
    );
    // Sol üstten yumuşak ışık (derinlik).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.55, -.65),
          radius: .95,
          colors: [p.glow.withValues(alpha: .42), p.glow.withValues(alpha: 0)],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRect(rect);
    if (group) {
      // Arkada iki yan kişi (daha küçük, daha saydam), önde orta kişi.
      _person(canvas, w, h,
          cx: .20,
          headY: .45,
          headR: .115,
          shoulderTop: .64,
          halfW: .20,
          alpha: .55);
      _person(canvas, w, h,
          cx: .80,
          headY: .45,
          headR: .115,
          shoulderTop: .64,
          halfW: .20,
          alpha: .55);
      _person(canvas, w, h,
          cx: .50,
          headY: .38,
          headR: .155,
          shoulderTop: .60,
          halfW: .30,
          alpha: .96);
    } else {
      _person(canvas, w, h,
          cx: .50,
          headY: .385,
          headR: .175,
          shoulderTop: .66,
          halfW: .37,
          alpha: .96);
    }
    canvas.restore();
  }

  /// Tek kişi silueti: yuvarlak baş + kubbe omuz. Koordinatlar birim kareye göredir.
  void _person(Canvas canvas, double w, double h,
      {required double cx,
      required double headY,
      required double headR,
      required double shoulderTop,
      required double halfW,
      required double alpha}) {
    final x = cx * w;
    final shoulders = Path()
      ..moveTo(x - halfW * w, h * 1.05)
      ..cubicTo(x - halfW * w, h * (shoulderTop + .17), x - halfW * w * .62,
          h * shoulderTop, x, h * shoulderTop)
      ..cubicTo(x + halfW * w * .62, h * shoulderTop, x + halfW * w,
          h * (shoulderTop + .17), x + halfW * w, h * 1.05)
      ..close();
    final bounds = Rect.fromLTWH(x - halfW * w, h * shoulderTop, halfW * w * 2,
        h * (1.05 - shoulderTop));
    canvas.drawPath(
      shoulders,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: alpha),
            Colors.white.withValues(alpha: alpha * .86)
          ],
        ).createShader(bounds),
    );
    final c = Offset(x, h * headY);
    final r = headR * w;
    final head = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: alpha),
            Colors.white.withValues(alpha: alpha * .88)
          ],
        ).createShader(head),
    );
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.variant != variant || old.group != group;
}
