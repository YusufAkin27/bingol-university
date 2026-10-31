import 'package:flutter/material.dart';

import '../../core/cache/image_disk_cache.dart';
import '../../core/theme.dart';

/// Menü fotoğrafını yükler; hata olursa [builder] `photo == null` ile çağrılır
/// ve çağıran fotoğrafsız tasarıma düşer.
class MenuPhotoGate extends StatefulWidget {
  const MenuPhotoGate({super.key, required this.url, required this.builder});

  final String? url;

  /// Yalnızca testler: ağ yerine yerel görüntü sağlayıcısı.
  @visibleForTesting
  static ImageProvider Function(String url)? debugProvider;

  /// `photo`: yükleme/iskelet dahil hazır görsel katmanı; fotoğraf yok ya da bozuksa null.
  final Widget Function(BuildContext context, Widget? photo) builder;

  @override
  State<MenuPhotoGate> createState() => _MenuPhotoGateState();
}

class _MenuPhotoGateState extends State<MenuPhotoGate> {
  String? _failedUrl;

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || _failedUrl == url) return widget.builder(context, null);
    final t = context.bu;
    // Menü fotoğrafı da diske yazılır (günlük aynı görsel) ve ekran genişliğine göre küçültülerek çözülür.
    final px = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, 1400);
    final photo = Image(
      image: MenuPhotoGate.debugProvider?.call(url) ?? persistentNetworkImage(url, cacheWidth: px),
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : ColoredBox(color: t.soft),
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _failedUrl != url) setState(() => _failedUrl = url);
        });
        return ColoredBox(color: t.soft);
      },
    );
    return widget.builder(context, photo);
  }
}
