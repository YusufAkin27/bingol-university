import 'dart:async';

import 'package:flutter/widgets.dart';

/// Uygulama arka plana giderken/kapanırken bekleyen önbellek yazımlarını (mesaj kaydı, disk önbelleği dizini)
/// toplu olarak diske boşaltır. Yazımlar normalde geciktirilir (her pakette dosya yeniden yazılmaz); bu gözlemci
/// gecikmenin bitmesini beklemeden veri kaybını önler. Zamanlayıcı/yoklama yoktur.
class CacheLifecycleFlusher with WidgetsBindingObserver {
  CacheLifecycleFlusher(this.flushers);

  final List<Future<void> Function()> flushers;
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      flushNow();
    }
  }

  /// Tüm boşaltıcıları çalıştırır (hatalar yutulur).
  Future<void> flushNow() async {
    for (final f in flushers) {
      try {
        await f();
      } catch (_) {}
    }
  }
}

/// Resim belleği tavanı: Flutter varsayılanı (1000 görsel / 100 MB) telefon için fazla; çözümlenmiş görseller
/// en çok [maxCount] adet ve [maxBytes] bayt. Aşılınca en eskiler atılır, disk önbelleği etkilenmez.
void applyImageCacheLimits({int maxCount = 200, int maxBytes = 80 * 1024 * 1024}) {
  final c = PaintingBinding.instance.imageCache;
  c.maximumSize = maxCount;
  c.maximumSizeBytes = maxBytes;
}
