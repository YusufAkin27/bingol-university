import 'dart:async';

import '../api.dart';

/// Cihaz kaydının (FCM jetonu -> `POST /api/devices`) durumu.
enum PushRegState {
  /// Henüz denenmedi / oturum yok.
  idle,

  /// Sunucuya kaydedildi.
  registered,

  /// Son deneme başarısız; zamanlayıcı yeniden deniyor.
  retrying,

  /// Yeniden deneme hakkı bitti (bir sonraki açılış/ön plana dönüşte tekrar denenir).
  failed,
}

/// Jetonu sunucuya kaydeden ve kaydı canlı tutan küçük durum makinesi (Firebase'siz test edilir).
///
/// Neden var: eskiden kayıt tek seferdi; ağ o an yoksa sunucuda jeton hiç olmuyor ve uygulama kapalıyken
/// bildirim gelmiyordu ("bazı kullanıcılara hiç gelmiyor"). Burada: başarısızlıkta üstel bekleme ile yeniden
/// deneme, ön plana dönüşte kaydı tazeleme (`lastSeenAt` + `appVersion`/`locale`; sunucu 60 gün görülmeyen
/// jetonu siler) ve aynı jeton için gereksiz tekrar çağrıyı önleme.
class PushRegistrar {
  PushRegistrar({
    required this.send,
    this.retryDelays = const [Duration(seconds: 15), Duration(minutes: 1), Duration(minutes: 5), Duration(minutes: 15)],
    this.refreshAfter = const Duration(hours: 6),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// `POST /devices` çağrısı (oturum kontrolü çağıranda).
  final Future<void> Function(String token) send;

  /// Başarısız denemeler arasındaki bekleme; liste bitince [PushRegState.failed].
  final List<Duration> retryDelays;

  /// Başarılı kayıttan sonra bu süre geçince [register] yeniden çağrı yapar (sunucu hız sınırı 30/saat).
  final Duration refreshAfter;
  final DateTime Function() _now;

  PushRegState state = PushRegState.idle;
  String? token;
  DateTime? lastOkAt;
  Timer? _timer;
  int _attempt = 0;
  bool _disposed = false;
  bool _inFlight = false;

  /// Sunucuda kayıtlı görünüyor mu.
  bool get registered => state == PushRegState.registered;

  /// Kayıt yok/eski mi (ön plana dönüşte yenilenmeli).
  bool get needsRefresh {
    if (state != PushRegState.registered) return true;
    final t = lastOkAt;
    return t == null || _now().difference(t) >= refreshAfter;
  }

  /// Jetonu kaydeder. [force] yoksa, aynı jeton yakın zamanda kaydedildiyse çağrı atlanır.
  /// Dönüş: kayıt şu an geçerli mi.
  Future<bool> register(String newToken, {bool force = false}) async {
    if (_disposed || newToken.isEmpty) return false;
    final changed = newToken != token;
    token = newToken;
    if (!force && !changed && !needsRefresh) return true;
    if (_inFlight) return registered;
    _timer?.cancel();
    _timer = null;
    _attempt = 0;
    return _try();
  }

  Future<bool> _try() async {
    final t = token;
    if (t == null || _disposed) return false;
    _inFlight = true;
    try {
      await send(t);
      if (_disposed) return false;
      state = PushRegState.registered;
      lastOkAt = _now();
      _attempt = 0;
      return true;
    } catch (e) {
      if (_disposed) return false;
      // Kalıcı istemci hatası (doğrulama/yetki): yeniden denemek anlamsız.
      if (e is ApiError && !e.isTransient) {
        state = PushRegState.failed;
        return false;
      }
      if (_attempt < retryDelays.length) {
        state = PushRegState.retrying;
        final d = retryDelays[_attempt++];
        _timer = Timer(d, () {
          _timer = null;
          unawaited(_try());
        });
      } else {
        state = PushRegState.failed;
      }
      return false;
    } finally {
      _inFlight = false;
    }
  }

  /// Çıkışta: bekleyen yeniden denemeyi iptal eder, durumu sıfırlar.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _attempt = 0;
    token = null;
    lastOkAt = null;
    state = PushRegState.idle;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
