import 'dart:async';

import 'post_api.dart';

/// Ekranda görünen gönderi/reel kimliklerini biriktirip toplu olarak `POST /feed/seen` ile bildirir.
///
/// Amaç: Keşfet'i yenileyen kişiye aynı gönderiler yine gelmesin. Sunucu zaten döndürdüğü sayfayı görülmüş sayar;
/// bu sınıf yedektir (ve Reels/detay akışında gerçekten görüleni işaretler). Aynı kimlik bir oturumda bir kez gider;
/// [mark] ucuzdur (build içinden çağrılabilir), ağ isteği geciktirilip birleştirilir, hata sessizce yutulur.
class FeedSeenReporter {
  FeedSeenReporter(this._api, {this.delay = const Duration(seconds: 2), this.maxRemembered = 2000});

  final PostApi _api;

  /// Son işaretten bu kadar sonra tek istekte gönderilir.
  final Duration delay;

  /// Bellekte hatırlanan en çok kimlik (sunucu sınırıyla aynı; taşınca en eskiler unutulur).
  final int maxRemembered;

  final Set<int> _sent = <int>{};
  final Set<int> _pending = <int>{};
  Timer? _timer;
  bool _disposed = false;

  /// Bu oturumda bildirilmeyi bekleyen kimlik sayısı (test/gözlem).
  int get pendingCount => _pending.length;

  void mark(int id) {
    if (_disposed || id <= 0 || _sent.contains(id) || !_pending.add(id)) return;
    _timer ??= Timer(delay, flush);
    // Bekleyen yığın 100'e varınca beklemeden gönder.
    if (_pending.length >= PostApi.kFeedSeenBatch) flush();
  }

  void markAll(Iterable<int> ids) {
    for (final id in ids) {
      mark(id);
    }
  }

  /// Bekleyenleri hemen gönderir (sayfa kapanırken/uygulama arka plana giderken).
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return;
    final ids = _pending.toList();
    _pending.clear();
    _sent.addAll(ids);
    if (_sent.length > maxRemembered) {
      final extra = _sent.length - maxRemembered;
      _sent.removeAll(_sent.take(extra).toList());
    }
    await _api.markSeen(ids);
  }

  /// Zamanlayıcıyı bırakır ve yeni işaret kabul etmez. Bekleyenler BİLEREK gönderilmez: sunucu döndürdüğü sayfayı zaten
  /// görülmüş sayar, bu bildirim yedektir; ayrıca kapanış sırasında yeni ağ isteği başlatmak sızıntı yapar.
  /// Hemen göndermek için önce [flush] çağırın.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }
}
