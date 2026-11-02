import 'dart:convert';

import 'identifier.dart';
import 'secure_store.dart';

/// Doğrulama kodu "yeniden iste" bekleme süresi (sn): sunucudaki `app.auth.code-resend-cooldown-seconds` (180) ile aynı.
/// Sunucu TEK DOĞRU KAYNAKTIR: yanıttaki `resendAfterSeconds` / 429 `Retry-After` bu değerin yerine geçer; bu sabit yalnız
/// sunucudan süre gelmediğinde varsayılandır.
const int kCodeResendSeconds = 180;

/// Kalan saniyeyi "d:ss" (örn. 2:59) olarak yazar.
String formatResendClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Kod akışlarının (kayıt doğrulama `verify`, şifre sıfırlama `reset`, herkese açık destek `support`) bekleme bitiş
/// anlarını tutar. Uygulama kapanıp açılsa da geri sayım kaldığı yerden devam eder. Bellek önbelleği eşzamanlı
/// okunur ([peek]); kalıcı kopya güvenli depodadır. Yalnız bitiş anı saklanır (kod/şifre yok).
class ResendCooldownStore {
  ResendCooldownStore({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _persist = true;

  /// Testler için yalnız bellek.
  ResendCooldownStore.memory({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _persist = false;

  static final ResendCooldownStore instance = ResendCooldownStore();

  static const _key = 'code_resend_deadlines';

  final DateTime Function() _now;
  final bool _persist;
  final Map<String, int> _deadlines = {};
  bool _loaded = false;

  static String _k(String flow, String id) => '$flow:${normalizeIdentifier(id)}';

  /// Önbellekteki kalan saniye; kayıt yoksa null, süre dolduysa 0. Depodan yüklenmediyse null olabilir ([remaining]).
  int? peek(String flow, String id) {
    final d = _deadlines[_k(flow, id)];
    if (d == null) return null;
    final ms = d - _now().millisecondsSinceEpoch;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Depodan yükler (bir kez) ve kalan saniyeyi döner.
  Future<int?> remaining(String flow, String id) async {
    await _load();
    return peek(flow, id);
  }

  /// Beklemeyi başlatır (kod gönderildi ya da sunucu kalan süreyi bildirdi).
  Future<void> start(String flow, String id, {int seconds = kCodeResendSeconds}) async {
    await _load();
    final s = seconds <= 0 ? kCodeResendSeconds : seconds;
    _deadlines[_k(flow, id)] = _now().add(Duration(seconds: s)).millisecondsSinceEpoch;
    _prune();
    await _save();
  }

  Future<void> clear(String flow, String id) async {
    await _load();
    _deadlines.remove(_k(flow, id));
    await _save();
  }

  /// Çıkış/hesap silmede: e-posta adresine bağlı bekleme kayıtları kalmasın.
  Future<void> clearAll() async {
    _deadlines.clear();
    _loaded = true;
    await _save();
  }

  void _prune() {
    final cut = _now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    _deadlines.removeWhere((_, v) => v < cut);
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    if (!_persist) return;
    try {
      final raw = await kDeviceSecureStorage.read(key: _key);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw);
      if (m is Map) {
        m.forEach((k, v) {
          if (k is String && v is num) _deadlines.putIfAbsent(k, () => v.toInt());
        });
        _prune();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_persist) return;
    try {
      if (_deadlines.isEmpty) {
        await kDeviceSecureStorage.delete(key: _key);
      } else {
        await kDeviceSecureStorage.write(key: _key, value: jsonEncode(_deadlines));
      }
    } catch (_) {}
  }
}
