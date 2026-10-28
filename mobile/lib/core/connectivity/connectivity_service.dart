import 'package:flutter/foundation.dart';

/// Bağlantı durumu: ek paket yok; gerçek HTTP sonuçlarından türetilir.
/// ApiClient bir yanıt alınca [reportSuccess], ağ hatası/zaman aşımında [reportFailure] çağırır.
/// Periyodik yoklama BURADA yoktur (AppGate'in mevcut /status yoklaması sonuçları aynı kanaldan besler).
class ConnectivityService extends ChangeNotifier {
  ConnectivityService();

  static final ConnectivityService instance = ConnectivityService();

  bool _online = true;
  DateTime? _lastStaleAt;

  /// Çevrimdışıdan çevrimiçine her geçişte artar: kuyruk boşaltma/bayat veri yenileme tetikleyicisi.
  final ValueNotifier<int> reconnects = ValueNotifier<int>(0);

  /// Son HTTP denemesi sonuca göre erişilebilir miydi (başlangıçta iyimser: true).
  bool get online => _online;

  /// Son kez önbellekten (bayat) veri sunulduğunda o verinin alınma anı; yoksa null.
  DateTime? get lastStaleAt => _lastStaleAt;

  void reportSuccess() {
    if (_online && _lastStaleAt == null) return;
    final wasOffline = !_online;
    _online = true;
    _lastStaleAt = null;
    if (wasOffline) reconnects.value++;
    notifyListeners();
  }

  void reportFailure() {
    if (!_online) return;
    _online = false;
    notifyListeners();
  }

  /// Ağ yokken önbellekten veri verildi (ekranlar "Son güncelleme" etiketi gösterebilir).
  void reportStale(DateTime cachedAt) {
    final prev = _lastStaleAt;
    if (prev != null && !cachedAt.isBefore(prev)) {
      // En eski bayat veriyi göster: kullanıcı en kötü durumu görsün.
      return;
    }
    _lastStaleAt = cachedAt;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _online = true;
    _lastStaleAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    reconnects.dispose();
    super.dispose();
  }
}
