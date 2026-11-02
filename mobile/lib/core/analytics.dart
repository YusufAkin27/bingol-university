import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'analytics_screens.dart';
import 'api.dart' show ApiError;
import 'error_log.dart';
import 'session.dart';

/// Toplulaştırılmış, KİMLİKSİZ kullanım olayları (hangi ekran, hangi eylem, ne kadar süre).
///
/// Gizlilik: olay adı/ekran/özellik değerlerinde ad, e-posta, sorgu metni, mesaj içeriği ya da herhangi bir
/// kimlik YOKTUR ('@' içeren her şey olayı tümüyle düşürür). Ayarlardan kapatılabilir: kapalıyken hiçbir
/// olay kuyruğa alınmaz ve bekleyenler silinir. Oturum yokken biriktirme/gönderme yoktur.
/// Dayanıklılık: kuyruk 200 ile sınırlı, hata/429'da geri çekilme + toplu atma (olay kaybı kabul), dakikada
/// en çok [maxRequestsPerMinute] istek (sunucu sınırı 30), gönderim asenkron ve hata fırlatmaz.
class Analytics extends ChangeNotifier {
  Analytics({FlutterSecureStorage? storage, DateTime Function()? now, bool wireErrorLog = true})
      : _storage = storage ?? const FlutterSecureStorage(),
        _now = now ?? DateTime.now {
    screens = ScreenTracker(
      emit: track,
      now: _now,
      onScreen: wireErrorLog ? (k) => ErrorLog.instance.currentScreen = k : null,
    );
  }

  static final Analytics instance = Analytics();

  static const maxBatch = 50;
  static const maxQueue = 200;
  static const flushCount = 20;
  static const flushEvery = Duration(seconds: 20);
  static const maxRequestsPerMinute = 25;
  static const maxProps = 5;
  static const maxPropValue = 100;
  static const settingKey = 'usage_stats_enabled';

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  /// Ekran/sekme izleyicisi (süre ölçümü + `from` zinciri).
  late final ScreenTracker screens;

  Session? _session;
  Timer? _timer;
  final List<Map<String, dynamic>> _queue = [];
  bool _sending = false;
  bool _enabled = true;

  // Oturum süresi: ön plana gelişten arka plana geçişe.
  DateTime? _fgSince;
  bool _openSent = false;

  // Geri çekilme / hız sınırı.
  DateTime? _blockedUntil;
  int _failures = 0;
  final List<DateTime> _sentAt = [];

  static final _nameRe = RegExp(r'^[a-z0-9_]{1,40}$');
  static final _propKeyRe = RegExp(r'^[a-z0-9_]{1,30}$');

  /// Kullanıcı ayarı: kullanım istatistikleri (varsayılan açık).
  bool get enabled => _enabled;

  @visibleForTesting
  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);

  /// Kayıtlı ayarı okur (hata fırlatmaz; okunamazsa açık).
  Future<void> load() async {
    try {
      _enabled = (await _storage.read(key: settingKey)) != '0';
    } catch (_) {
      _enabled = true;
    }
    if (!_enabled) _queue.clear();
    notifyListeners();
  }

  /// Ayarlar anahtarı. Kapatınca bekleyen olaylar silinir ve yeni olay alınmaz.
  Future<void> setEnabled(bool v) async {
    _enabled = v;
    if (!v) _queue.clear();
    notifyListeners();
    try {
      await _storage.write(key: settingKey, value: v ? '1' : '0');
    } catch (_) {}
  }

  /// Oturum sonlanınca bekleyen olayları gönderilmeden atar; ekran izleyicisini sıfırlar.
  void discard() {
    _queue.clear();
    _openSent = false;
    _failures = 0;
    _blockedUntil = null;
    screens.reset();
  }

  void attach(Session session) {
    _session = session;
    _timer ??= Timer.periodic(flushEvery, (_) => flush());
  }

  /// '@' içeren değer kişisel veri sayılır: olay tümüyle atılır.
  static bool isSafe(Object? v) {
    if (v == null) return true;
    if (v is String) return !v.contains('@');
    if (v is Map) return v.values.every(isSafe) && v.keys.every(isSafe);
    if (v is Iterable) return v.every(isSafe);
    return true;
  }

  /// Özellikleri sunucu sözleşmesine indirger: en çok [maxProps] anahtar, anahtar `[a-z0-9_]`, değer yalnız
  /// metin (en çok [maxPropValue] karakter) / sayı / mantıksal; diğerleri düşer.
  @visibleForTesting
  static Map<String, Object>? cleanProps(Map<String, dynamic>? props) {
    if (props == null || props.isEmpty) return null;
    final out = <String, Object>{};
    for (final e in props.entries) {
      if (out.length >= maxProps) break;
      if (!_propKeyRe.hasMatch(e.key)) continue;
      final v = e.value;
      if (v is String) {
        if (v.isEmpty) continue;
        out[e.key] = v.length > maxPropValue ? v.substring(0, maxPropValue) : v;
      } else if (v is bool || v is int) {
        out[e.key] = v as Object;
      } else if (v is double && v.isFinite) {
        out[e.key] = v.round();
      }
    }
    return out.isEmpty ? null : out;
  }

  /// Bir olay kaydeder. Kapalıysa, oturum yoksa ya da ad/içerik güvensizse sessizce düşer.
  /// [screen] verilmezse o an görünen ekranın anahtarı yazılır.
  void track(String name, {String? screen, Map<String, dynamic>? props}) {
    if (!_enabled) return;
    if (!_nameRe.hasMatch(name)) return;
    if (!isSafe(name) || !isSafe(screen) || !isSafe(props)) return;
    // Oturum yokken biriktirme/gönderme yok.
    if (_session?.state != SessionState.signedIn) return;
    final sc = normalizeScreenKey(screen ?? screens.current);
    final p = cleanProps(props);
    _queue.add({
      'name': name,
      if (sc != null) 'screen': sc,
      if (p != null) 'props': p,
      'at': _now().toUtc().toIso8601String(),
    });
    if (_queue.length > maxQueue) _queue.removeRange(0, _queue.length - maxQueue);
    if (_queue.length >= flushCount) unawaited(flush());
  }

  /// Uygulama öne geldi (açılış / arka plandan dönüş): süre sayacı sürer, oturumda bir kez `app_open`.
  void appOpen() {
    _fgSince ??= _now();
    screens.resume();
    _emitOpen();
  }

  /// Oturum açıldı (giriş ya da geri yükleme): ön plandaysa `app_open` henüz gitmediyse gönderilir.
  void signedIn() {
    if (_fgSince != null) _emitOpen();
  }

  void _emitOpen() {
    if (_openSent) return;
    if (!_enabled || _session?.state != SessionState.signedIn) return;
    _openSent = true;
    track('app_open');
  }

  /// Uygulama arka plana gitti: ekran süresi durur, oturum süresi (sn) gönderilir ve kuyruk hemen boşaltılır
  /// (kapanmadan önce en iyi çaba).
  void onBackground() {
    final since = _fgSince;
    if (_openSent && since != null) {
      final sec = _now().difference(since).inSeconds;
      track('app_background', props: {'dur': sec < 0 ? 0 : sec});
    }
    _fgSince = null;
    _openSent = false;
    screens.pause();
    unawaited(flush());
  }

  void screenView(String screen) => track('screen_view', screen: screen);

  Future<void> flush() async {
    final s = _session;
    if (_sending || _queue.isEmpty || s == null || s.state != SessionState.signedIn) return;
    final now = _now();
    final until = _blockedUntil;
    if (until != null && now.isBefore(until)) return;
    _sentAt.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_sentAt.length >= maxRequestsPerMinute) return;
    _sending = true;
    _sentAt.add(now);
    final n = _queue.length < maxBatch ? _queue.length : maxBatch;
    final batch = _queue.sublist(0, n);
    _queue.removeRange(0, n);
    var ok = false;
    try {
      await s.api.post('/analytics/events', {'events': batch});
      ok = true;
      _failures = 0;
    } catch (e) {
      // Olay kaybı kabul: grup atıldı, yeniden denenmez; sonraki gönderim geri çekilmeyle ertelenir.
      _failures++;
      final int sec;
      if (e is ApiError && e.status == 429) {
        sec = (e.retryAfter ?? 60).clamp(5, 600).toInt();
      } else {
        sec = (30 * (1 << (_failures - 1).clamp(0, 4).toInt())).clamp(30, 300).toInt();
      }
      final wait = Duration(seconds: sec);
      _blockedUntil = _now().add(wait);
    } finally {
      _sending = false;
    }
    if (ok && _queue.length >= flushCount) unawaited(flush());
  }
}

/// Ekran / sekme izleyicisi: görünen ekran değişince `screen_view` üretir (`from` = önceki ekran, `ms` = önceki
/// ekranda GEÇEN SÜRE; uygulama arka plandayken süre işlemez, üst sınır 30 dk). Rota yığını ve sekme ayrı
/// beslenir: kök rota (`/`) görünürken ekran = seçili sekme.
class ScreenTracker {
  ScreenTracker({
    required this.emit,
    DateTime Function()? now,
    this.onScreen,
  }) : _now = now ?? DateTime.now {
    _since = _now();
  }

  static const maxMs = 30 * 60 * 1000;

  final void Function(String name, {String? screen, Map<String, dynamic>? props}) emit;
  final void Function(String screen)? onScreen;
  final DateTime Function() _now;

  String? _top; // yığındaki en üst tam ekran rotanın anahtarı (kök: [kRootScreen])
  String? _tab;
  String? _current;
  int _accumMs = 0;
  DateTime? _since;
  bool _paused = false;

  /// O an görünen ekranın anahtarı (henüz yoksa null).
  String? get current => _current;

  /// Seçili alt gezinme sekmesi.
  String? get tab => _tab;

  /// Rota yığınının en üstü değişti (null: tam ekran rota yok).
  void setRoute(String? key) {
    _top = key;
    _sync();
  }

  /// Alt gezinme sekmesi değişti (sekmeler rota değil, `IndexedStack`).
  void setTab(String? tab) {
    _tab = tab;
    _sync();
  }

  /// Ekran süresi arka planda işlemez.
  void pause() {
    if (_paused) return;
    _paused = true;
    final s = _since;
    if (s != null) _accumMs += _now().difference(s).inMilliseconds;
    _since = null;
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _since = _now();
  }

  /// Oturum sonu: görünen ekran unutulur (yeni oturumda ilk ekran `from`suz başlar).
  void reset() {
    _current = null;
    _tab = null;
    _accumMs = 0;
    _since = _paused ? null : _now();
  }

  int _elapsedMs() {
    final s = _since;
    final ms = _accumMs + (s == null ? 0 : _now().difference(s).inMilliseconds);
    return ms < 0 ? 0 : (ms > maxMs ? maxMs : ms);
  }

  void _sync() {
    final eff = _top == kRootScreen ? _tab : _top;
    if (eff == null || eff == _current) return;
    final prev = _current;
    final props = <String, dynamic>{if (prev != null) 'from': prev, if (prev != null) 'ms': _elapsedMs()};
    _current = eff;
    _accumMs = 0;
    _since = _paused ? null : _now();
    onScreen?.call(eff);
    emit('screen_view', screen: eff, props: props);
  }
}

/// Tam ekran rotalardan (diyalog/alt sayfa hariç) görünen ekranı izler. Yığındaki değişiklikler aynı
/// mikro görevde birleştirilir (`popUntil` ara ekranları sahte görüntüleme üretmez).
class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver({ScreenTracker? tracker}) : _tracker = tracker;

  final ScreenTracker? _tracker;
  ScreenTracker get tracker => _tracker ?? Analytics.instance.screens;

  final List<(Route<dynamic>, String)> _stack = [];
  bool _scheduled = false;

  void _add(Route<dynamic>? r) {
    final ctx = navigator?.context;
    if (r == null || ctx == null) return;
    final k = screenKeyForRoute(r, ctx);
    if (k != null) _stack.add((r, k));
    _schedule();
  }

  void _drop(Route<dynamic>? r) {
    if (r == null) return;
    _stack.removeWhere((e) => identical(e.$1, r));
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      tracker.setRoute(_stack.isEmpty ? null : _stack.last.$2);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _add(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _drop(oldRoute);
    _add(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _drop(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _drop(route);
}
