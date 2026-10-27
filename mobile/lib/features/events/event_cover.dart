import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';

/// Etkinlik kapağı: ağdan yükler (küçültülmüş çözümleme), yüklenirken/hatada yumuşak yer tutucu gösterir.
/// [url] boşsa hiçbir şey çizmez; çağıran kendi yer tutucusunu kullanır.
class EventCoverImage extends StatelessWidget {
  const EventCoverImage({super.key, required this.url, this.cacheWidth = 800, this.fit = BoxFit.cover});

  /// Mutlak adres (`fileUrl` ile çevrilmiş).
  final String url;
  final int cacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget holder() => ColoredBox(
          color: t.soft,
          child: Center(child: Icon(LucideIcons.image, size: 28, color: t.onSoft.withValues(alpha: .6))),
        );
    return Image.network(
      url,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, p) => p == null ? child : holder(),
      errorBuilder: (_, __, ___) => holder(),
    );
  }
}
