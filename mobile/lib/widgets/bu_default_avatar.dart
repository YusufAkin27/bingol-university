import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bu_pressable.dart';
import '../core/theme.dart';
import '../core/icons/bu_icons.dart';

/// Varsayılan profil görseli: kullanıcının fotoğrafı YOKSA, yüklenirken ya da yüklenemezse HER avatarın yerinde
/// durur (sohbet, arama, Keşfet, takipçi, yorum, öneri, bildirim...). Baş harf çizilmez.
///
/// Tamamen vektördür ([CustomPainter]): 16 dp liste avatarından 160+ dp profil başlığına kadar her boyutta keskin,
/// varlık dosyası yok. Her ölçü KUTUYA ORANTILIDIR (sabit piksel yok). Çizim: ince dikey gradyanlı nötr zemin
/// (`sf2` -> `sf`), kutunun ~%80'ini dolduran baş + omuz siluetleri (omuz alt kenara taşar, daire/kare kırpar:
/// fotoğraf hissi). 56 dp ve üstünde yumuşak üst ışık; 24 dp altında yalnız düz siluet. Renkler yalnız `context.bu`
/// (ink/mut/sf tonları) olduğundan açık ve koyu temada uyumludur. Şekli çağıran belirler (`BuAvatar` kırpar).
///
/// [group] true: kişi değil grup/kulüp/etkinlik yedeği (aynı tasarım ailesi: arkada küçük, önde büyük iki siluet).
/// [semanticLabel] verilmezse görsel dekoratiftir (kişi adı çağıranın `Semantics`/`Text`inde durur).
class BuDefaultAvatar extends StatelessWidget {
  const BuDefaultAvatar({super.key, this.size = 48, this.group = false, this.semanticLabel});

  final double size;

  /// true: grup/kulüp/etkinlik yedek görseli (kişi avatarı değildir).
  final bool group;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final paint = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        key: const ValueKey('default-avatar-paint'),
        painter: DefaultAvatarPainter(
          base: t.sf2,
          deep: t.sf,
          figure: t.mut,
          glow: t.ink,
          group: group,
          detail: size >= 56,
          tiny: size < 24,
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: paint);
    return Semantics(image: true, label: semanticLabel, excludeSemantics: true, child: paint);
  }
}

/// Varsayılan avatar çizimi. Koordinatlar 0..1 birim kare üzerindedir ve kutu boyutuyla ölçeklenir.
class DefaultAvatarPainter extends CustomPainter {
  const DefaultAvatarPainter({
    required this.base,
    required this.deep,
    required this.figure,
    required this.glow,
    this.group = false,
    this.detail = true,
    this.tiny = false,
  });

  final Color base;
  final Color deep;
  final Color figure;
  final Color glow;
  final bool group;
  final bool detail;
  final bool tiny;

  /// Tek kişi: baş merkezi/yarıçapı ve omuz üst çizgisi (birim kare oranları).
  static const double headY = .385, headR = .175, shoulderTop = .63;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size(s, s);
    // Zemin: üstten alta nötr gradyan (gradyan uçları birbirine yakın: sakin, premium).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base, tiny ? base : Color.lerp(base, deep, .75)!],
        ).createShader(rect),
    );
    if (detail) {
      // Yumuşak üst ışık (glow): yalnız büyük boyutta, çok düşük opaklık.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -.55),
            radius: .85,
            colors: [glow.withValues(alpha: .07), glow.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }
    // Opak karışım: örtüşen siluetlerde yarı saydam dikiş izi oluşmaz.
    final fig = Paint()..color = Color.lerp(base, figure, .62)!;
    if (group) {
      // Arka siluet: solda, küçük ve daha soluk; ön siluet: ortada.
      final back = Paint()..color = Color.lerp(base, figure, .30)!;
      _person(canvas, s, fig: back, cx: .24, headCy: .44, hr: .10, top: .66, half: .19);
      _person(canvas, s, fig: back, cx: .76, headCy: .44, hr: .10, top: .66, half: .19);
      _person(canvas, s, fig: fig, cx: .5, headCy: .38, hr: .15, top: .61, half: .30);
    } else {
      _person(canvas, s, fig: fig, cx: .5, headCy: headY, hr: headR, top: shoulderTop, half: .38);
    }
  }

  /// Baş (daire) + omuz (tek Path, iki kübik yay) siluetini çizer; omuz alt kenarın dışına taşar.
  void _person(Canvas c, double s,
      {required Paint fig,
      required double cx,
      required double headCy,
      required double hr,
      required double top,
      required double half}) {
    c.drawCircle(Offset(cx * s, headCy * s), hr * s, fig);
    final l = (cx - half) * s, r = (cx + half) * s, m = cx * s, ty = top * s, by = 1.04 * s;
    final k = half * s * .55; // yay yumuşaklığı
    final p = Path()
      ..moveTo(l, by)
      ..cubicTo(l, ty + (by - ty) * .30, m - k * 1.1, ty, m, ty)
      ..cubicTo(m + k * 1.1, ty, r, ty + (by - ty) * .30, r, by)
      ..close();
    c.drawPath(p, fig);
  }

  @override
  bool shouldRepaint(DefaultAvatarPainter o) =>
      o.base != base || o.deep != deep || o.figure != figure || o.glow != glow || o.group != group || o.detail != detail || o.tiny != tiny;
}

/// Avatarın sağ-alt kenarındaki küçük eylem rozeti (kamera/düzenle). Avatar DAİRESİNİN 45 derecelik kenar noktasına
/// ortalanır (boyuta orantılı; kutudan ~%10 taşar), `bg` renkli 2 dp halka ile ayrılır. RTL'de ayna (`end`).
/// Üst `Stack` `clipBehavior: Clip.none` olmalı ve avatar kutusu ([avatarSize]) ile aynı boyutta durmalıdır.
class BuAvatarBadge extends StatelessWidget {
  const BuAvatarBadge({super.key, required this.avatarSize, this.icon, this.fill, this.iconColor, this.onTap, this.tooltip});

  final double avatarSize;
  final IconData? icon;
  final Color? fill;
  final Color? iconColor;

  /// Verilirse rozet kendi dokunma hedefidir (>= 44 dp, merkez aynı kalır) ve anlamsal düğme olur.
  final VoidCallback? onTap;
  final String? tooltip;

  /// Rozet çapı: avatarın %30'u, 24..44 dp arası (halka dahil değil).
  static double diameterFor(double avatarSize) => (avatarSize * .30).clamp(24.0, 44.0);

  /// Rozet çapı + halka.
  static double outerFor(double avatarSize) => diameterFor(avatarSize) + 4;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final d = diameterFor(avatarSize);
    final outer = d + 4;
    // Daire kenarındaki 45 derece noktası kutu köşesinden avatarSize*(1-cos45)/2 içeridedir.
    final inset = avatarSize * (1 - math.sqrt1_2) / 2;
    final hit = onTap == null ? outer : math.max(outer, 44.0);
    final off = inset - hit / 2;
    Widget badge = Container(
      key: const ValueKey('avatar-badge'),
      width: outer,
      height: outer,
      decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(color: fill ?? t.pr, shape: BoxShape.circle),
        child: Icon(icon ?? BuIcons.camera, size: d * .52, color: iconColor ?? t.onPr),
      ),
    );
    if (onTap == null) {
      badge = ExcludeSemantics(child: badge);
    } else {
      badge = SizedBox(
        width: hit,
        height: hit,
        child: Center(
          child: Tooltip(
            message: tooltip ?? '',
            child: BuPressable(onTap: onTap, haptic: BuHaptic.selection, child: badge),
          ),
        ),
      );
    }
    return PositionedDirectional(end: off, bottom: off, child: badge);
  }
}
