import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';
import '../../widgets/bu_widgets.dart';

/// Etkinlik kapağı: ağdan yükler (küçültülmüş çözümleme), yüklenirken/hatada yumuşak yer tutucu gösterir,
/// yüklenince solarak belirir. [url] boşsa hiçbir şey çizmez; çağıran kendi yer tutucusunu kullanır.
class EventCoverImage extends StatelessWidget {
  const EventCoverImage({super.key, required this.url, this.cacheWidth = 800, this.fit = BoxFit.cover});

  /// Mutlak adres (`fileUrl` ile çevrilmiş).
  final String url;
  final int cacheWidth;
  final BoxFit fit;

  /// Yalnız testte: ağ yerine bellekten görsel verir (görsel denetim için).
  @visibleForTesting
  static ImageProvider Function(String url)? debugProvider;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget holder() => ColoredBox(
          color: t.soft,
          child: Center(child: Icon(LucideIcons.image, size: 26, color: t.onSoft.withValues(alpha: .6))),
        );
    final dbg = debugProvider;
    if (dbg != null) {
      return Image(image: dbg(url), fit: fit, width: double.infinity, height: double.infinity);
    }
    final fade = BuMotion.of(context, BuMotion.medium);
    return Image.network(
      url,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : Stack(fit: StackFit.expand, children: [
              if (frame == null) holder(),
              AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: BuMotion.decelerate, child: child),
            ]),
      errorBuilder: (_, __, ___) => holder(),
    );
  }
}
