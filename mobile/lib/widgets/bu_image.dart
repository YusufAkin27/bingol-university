import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/theme/bu_motion.dart';
import 'bu_widgets.dart';

/// Ağ görseli: çözümleme boyutu = düzen genişliği x DPR (tam çözünürlük belleğe açılmaz), yer tutucu renk,
/// yüklenince yumuşak belirme, hata yedeği. `/files/...` göreli yolları tam adrese çevrilir.
/// Dış kaynaklı (haber) ve sunucu görselleri için `Image.network` yerine bunu kullanın.
class BuImage extends StatelessWidget {
  const BuImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.headers,
    this.semanticLabel,
    this.placeholderIcon = LucideIcons.image,
    this.maxDecodeWidth = 1600,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Köşe yarıçapı (dp); 0 ise kırpma yok.
  final double radius;

  /// Yetkili uçlar için istek başlıkları.
  final Map<String, String>? headers;

  /// Ekran okuyucu etiketi; null ise görsel dekoratif sayılır.
  final String? semanticLabel;
  final IconData placeholderIcon;

  /// Genişlik bilinmiyorsa en çok bu piksel genişliğinde çözülür.
  final int maxDecodeWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget placeholder() => SizedBox(
          width: width,
          height: height,
          child: ColoredBox(color: t.sf2, child: Center(child: Icon(placeholderIcon, size: 24, color: t.mut.withValues(alpha: .6)))),
        );
    final full = fileUrl(url);
    Widget child;
    if (full == null) {
      child = placeholder();
    } else {
      final w = width != null && width!.isFinite ? width! : MediaQuery.sizeOf(context).width;
      final px = (w * dpr).ceil().clamp(1, maxDecodeWidth);
      child = Image.network(
        full,
        headers: headers,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: px,
        gaplessPlayback: true,
        excludeFromSemantics: semanticLabel == null,
        semanticLabel: semanticLabel,
        frameBuilder: (context, img, frame, sync) => sync
            ? img
            : Stack(
                fit: StackFit.passthrough,
                children: [
                  if (frame == null) placeholder(),
                  AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: BuMotion.of(context, BuMotion.medium), curve: BuMotion.decelerate, child: img),
                ],
              ),
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }
    if (radius <= 0) return child;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), clipBehavior: Clip.hardEdge, child: child);
  }
}
