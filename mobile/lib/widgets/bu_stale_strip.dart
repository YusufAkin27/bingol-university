import 'package:flutter/material.dart';

import '../core/connectivity/connectivity_service.dart';
import '../core/locale_controller.dart';
import 'bu_state.dart';
import 'common.dart' show relativeTime;

/// Ortak "Çevrimdışı · son güncelleme ..." şeridi. [ConnectivityService] bağlantı yokken ya da ağ hatası yüzünden
/// önbellekten (bayat) veri sunulduğunda görünür; çevrimiçi olunca (başarılı bir istekle) kendiliğinden kaybolur.
/// Ekranın üstüne (gövdenin başına) koyun; içerik silinmez. Bağlantı durumu yoksa hiçbir şey çizmez.
class BuStaleStrip extends StatelessWidget {
  const BuStaleStrip({super.key, this.connectivity, this.margin});

  /// Testte sahte servis; verilmezse [ConnectivityService.instance].
  final ConnectivityService? connectivity;
  final EdgeInsetsGeometry? margin;

  /// Şerit görünmeli mi (saf mantık; testte doğrudan denenir).
  static bool shouldShow(ConnectivityService c) => !c.online || c.lastStaleAt != null;

  @override
  Widget build(BuildContext context) {
    final c = connectivity ?? ConnectivityService.instance;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!shouldShow(c)) return const SizedBox.shrink();
        final l = context.l10n;
        final at = c.lastStaleAt;
        final msg = at == null
            ? l.offlineStripNoTime
            : l.offlineStripWithTime(relativeTime(at.toIso8601String(), context: context));
        return BuOfflineBanner(
          key: const ValueKey('stale-strip'),
          message: msg,
          showCachedHint: false,
          margin: margin,
        );
      },
    );
  }
}
