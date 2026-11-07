import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'error_log.dart';
import 'secure_store.dart';
import 'session.dart';

/// Toplulaştırılmış, kişisel veri içermeyen kullanım olayları.
///
/// Olay sözleşmesi (docs/MOBILE_API_GUIDE.md "Kullanım analizi"): her olayda `props.sid` (oturum kimliği),
/// `session_start` / `session_end`, ekran başına `screen_view` + `screen_exit {dwellMs}` ve `action {kind, target?}`.
/// Kullanıcı "Kullanım analizi" anahtarını kapatırsa hiçbir olay toplanmaz/gönderilmez ve bekleyen kuyruk silinir.
class Analytics extends ChangeNotifier {
  Analytics._()
      : _now = DateTime.now,
        _newSid = _randomSid,
        _storage = kDeviceSecureStorage,
        _useTimer = true,
        _autoFlush = true;

  /// Testler için: sahte saat/oturum kimliği, zamanlayıcısız.
  @visibleForTesting
  Analytics.forTest({DateTime Function()? now, String Function()? sid, FlutterSecureStorage? storage, bool autoFlush = false})
      : _now = now ?? DateTime.now,
        _newSid = sid ?? _randomSid,
        _storage = storage ?? kDeviceSecureStorage,
        _useTimer = false,
        _autoFlush = autoFlush;

  static final Analytics instance = Analytics._();

  static const maxBatch = 50;
  static const flushCount = 20;
  static const flushEvery = Duration(seconds: 20);

  /// Bu süre hareketsizlik (ya da arka planda kalma) oturumu bitirir.
  static const idleTimeout = Duration(minutes: 30);

  /// Süre alanlarının sunucu sınırı (24 saat).
  static const maxMs = 86400000;

  /// Kullanıcı ayarı anahtarı (güvenli depo): '0' = kapalı, yoksa/'1' = açık.
  static const settingKey = 'analytics_enabled';

  /// Sözleşmedeki izinli eylem türleri (sunucu beyaz listesiyle aynı). Listede olmayan görmezden gelinir.
  static const actionKinds = {
    'like', 'unlike', 'follow', 'unfollow', 'share', 'bookmark', 'join_club', 'leave_club', 'rsvp', 'checkin', //
    'vote', 'rate_menu', 'search_submit', 'send_message', 'post_create', 'ticket_create', 'ticket_reply',
    'profile_edit', 'notif_open', 'push_open', 'pull_refresh', 'tab_switch',
  };

  final DateTime Function() _now;
  final String Function() _newSid;
  final FlutterSecureStorage _storage;
  final bool _useTimer;
  final bool _autoFlush; // false: kuyruk kendiliğinden gönderilmez (testler kuyruğu inceler)

  Session? _session;
  Timer? _timer;
  final List<Map<String, dynamic>> _queue = [];
  bool _sending = false;
  bool _flushAgain = false;

  bool _enabled = true;
  bool _launchPending = true; // sürecin ilk oturumunda app_open da gönderilir

  // Oturum durumu.
  String? _sid;
  bool _foreground = true;
  int _activeMs = 0; // kapanmış ön plan dilimlerinin toplamı
  DateTime? _segmentStart; // açık ön plan diliminin başı (arka plandayken null)
  DateTime? _backgroundAt;
  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);
  int _screens = 0;

  // Ekran durumu: gerçek ekran = açık rota adı, yoksa seçili sekme.
  String? _routeScreen;
  String? _tab;
  String? _screen;
  DateTime? _screenSince; // geçerli ekranın ön plan dilimi başı

  /// Kullanıcı ayarı (varsayılan açık).
  bool get enabled => _enabled;

  /// Etkin oturum kimliği (yoksa null). Testler için.
  @visibleForTesting
  String? get sid => _sid;

  @visibleForTesting
  String? get screen => _screen;

  @visibleForTesting
  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);

  /// Kayıtlı ayarı okur (hata fırlatmaz).
  Future<void> init() async {
    try {
      _enabled = (await _storage.read(key: settingKey)) != '0';
    } catch (_) {
      _enabled = true;
    }
    notifyListeners();
  }

  /// "Kullanım analizi" anahtarı: kapatınca olay toplama/gönderme durur ve bekleyen kuyruk + açık oturum silinir.
  Future<void> setEnabled(bool v) async {
    if (v != _enabled) {
      _enabled = v;
      if (!v) {
        discard();
      } else if (_ready && _foreground) {
        _startSession(_now());
      }
      notifyListeners();
    }
    try {
      await _storage.write(key: settingKey, value: v ? '1' : '0');
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }

  /// Oturum sonlanınca bekleyen olayları gönderilmeden atar ve açık oturumu bırakır (ekran adı korunur).
  void discard() {
    _queue.clear();
    _sid = null;
    _activeMs = 0;
    _screens = 0;
    _segmentStart = null;
    _screenSince = null;
    _backgroundAt = null;
  }

  void attach(Session session) {
    _session?.removeListener(_onSessionChanged);
    _session = session;
    session.addListener(_onSessionChanged);
    if (_useTimer) {
      _timer ??= Timer.periodic(flushEvery, (_) {
        _checkIdle(_now());
        flush();
      });
    }
  }

  bool get _ready => _enabled && _session?.state == SessionState.signedIn;

  /// Giriş yapılınca oturum başlar; çıkış/oturum düşünce bırakılır.
  void _onSessionChanged() {
    if (_ready) {
      if (_foreground && _sid == null) _startSession(_now());
    } else if (_session?.state != SessionState.signedIn) {
      discard();
    }
  }

  /// '@' içeren değer kişisel veri sayılır: olay tümüyle atılır.
  static bool isSafe(Object? v) {
    if (v == null) return true;
    if (v is String) return !v.contains('@');
    if (v is Map) return v.values.every(isSafe) && v.keys.every(isSafe);
    if (v is Iterable) return v.every(isSafe);
    return true;
  }

  static String _randomSid() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final r = math.Random.secure();
    return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static int _ms(Duration d) => math.min(math.max(d.inMilliseconds, 0), maxMs);

  /// Genel olay ekleme (oturum yokken/ayar kapalıyken no-op). Açık oturum varsa `sid` eklenir.
  void track(String name, {String? screen, Map<String, dynamic>? props}) => _emit(name, screen: screen, props: props);

  void _emit(String name, {String? screen, Map<String, dynamic>? props, DateTime? at}) {
    if (!_ready) return;
    final p = <String, dynamic>{...?props, if (_sid != null) 'sid': _sid};
    if (!isSafe(name) || !isSafe(screen) || !isSafe(p)) return;
    _queue.add({
      'name': name,
      if (screen != null) 'screen': screen,
      if (p.isNotEmpty) 'props': p,
      'at': (at ?? _now()).toUtc().toIso8601String(),
    });
    if (_queue.length > 200) _queue.removeRange(0, _queue.length - 200);
    if (_autoFlush && _queue.length >= flushCount) flush();
  }

  void appOpen() {
    if (_ready) _launchPending = false; // oturum yokken (açılışta) düşer; ilk oturum başlayınca app_open gider
    track('app_open');
  }

  void screenView(String screen) => track('screen_view', screen: screen);
  void search() => track('search');

  // ---------------------------------------------------------------- oturum

  /// Yeni oturum: session_start; açık ekran varsa onun screen_view'i (giriş ekranı) da eklenir.
  void _startSession(DateTime now) {
    _sid = _newSid();
    _activeMs = 0;
    _screens = 0;
    _segmentStart = now;
    _backgroundAt = null;
    _lastActivity = now;
    _screenSince = null;
    _emit('session_start', at: now);
    if (_launchPending) {
      _launchPending = false;
      _emit('app_open', at: now);
    }
    final s = _screen;
    if (s != null) {
      _emit('screen_view', screen: s, at: now);
      _screens++;
      _screenSince = now;
    }
  }

  /// Açık ekranı kapatır (screen_exit + dwellMs). Arka planda geçen süre sayılmaz (dilim yoksa olay yok).
  void _closeScreen(DateTime at) {
    final s = _screen, since = _screenSince;
    _screenSince = null;
    if (s == null || since == null) return;
    _emit('screen_exit', screen: s, props: {'dwellMs': _ms(at.difference(since))}, at: at);
  }

  /// session_end. `background`: aynı oturum 30 dk içinde dönüşte sürebilir (süre ön plan toplamıdır, kümülatif);
  /// `timeout`/`exit`: oturum kapanır.
  void _endSession(String reason, DateTime at) {
    if (_sid == null) return;
    _closeScreen(at);
    final seg = _segmentStart;
    final active = math.min(_activeMs + (seg == null ? 0 : _ms(at.difference(seg))), maxMs);
    _emit('session_end', props: {'durationMs': active, 'screens': _screens, 'reason': reason}, at: at);
    _segmentStart = null;
    _activeMs = active;
    if (reason != 'background') {
      _sid = null;
      _activeMs = 0;
      _screens = 0;
    }
  }

  /// Ön plandayken 30 dk etkinlik yoksa oturum 'timeout' ile biter (bitiş = son etkinlik anı).
  void _checkIdle(DateTime now) {
    if (_sid == null || _segmentStart == null) return;
    if (now.difference(_lastActivity) >= idleTimeout) _endSession('timeout', _lastActivity);
  }

  /// Kullanıcı etkinliği: gerekirse eski oturumu kapatır, oturum yoksa başlatır.
  void _activity(DateTime now) {
    _checkIdle(now);
    if (!_foreground) return;
    if (_sid == null) {
      _startSession(now);
    } else {
      _lastActivity = now;
    }
  }

  /// Ekrana dokunuş: yalnız etkinlik zamanını/oturumu günceller (olay üretmez, oturum yoksa başlatır).
  void touch() {
    if (!_ready) return;
    _activity(_now());
  }

  /// AppGate'ten: yaşam döngüsü. Arka plana atılınca oturum biter ve olaylar hemen gönderilir.
  void onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _onBackground('background');
      case AppLifecycleState.detached:
        _onBackground('exit');
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onResumed() {
    _foreground = true;
    if (!_ready) return;
    final now = _now();
    if (_sid != null) {
      if (_segmentStart != null) {
        _lastActivity = now; // zaten ön plan
        return;
      }
      final bg = _backgroundAt;
      if (bg == null || now.difference(bg) < idleTimeout) {
        // Kısa ayrılık: aynı oturum sürer (session_start yok), ekran süresi yeniden işler.
        _segmentStart = now;
        _lastActivity = now;
        _backgroundAt = null;
        if (_screen != null) _screenSince = now;
        return;
      }
      _sid = null; // uzun ayrılık: eski oturum zaten 'background' ile bitmişti
    }
    _startSession(now);
  }

  void _onBackground(String reason) {
    _foreground = false;
    if (!_ready || _sid == null) return;
    final now = _now();
    if (_segmentStart != null) {
      _endSession(reason, now);
      _backgroundAt = now;
      if (_autoFlush) unawaited(flush(all: true));
    } else if (reason == 'exit') {
      _sid = null;
    }
  }

  // ----------------------------------------------------------------- ekran

  /// Alt gezinme sekmesi (ör. `tab_home`). Üstte açık rota yokken geçerli ekran budur.
  void setTab(String? name) {
    _tab = name;
    _apply();
    if (_useTimer && _routeScreen == null && name != null) ErrorLog.instance.currentScreen = name; // çökme raporunda sekme adı
  }

  /// Gezgin: üstteki sayfa rotasının adı (null = kök, yani sekme).
  void setRouteScreen(String? name, {bool force = true}) {
    _routeScreen = name;
    _apply(force: force);
  }

  void _apply({bool force = false}) => setScreen(_routeScreen ?? _tab, force: force);

  /// Geçerli ekran değişti: öncekine screen_exit {dwellMs}, yenisine screen_view.
  void setScreen(String? name, {bool force = false}) {
    if (name == _screen && !force) return;
    final now = _now();
    _checkIdle(now);
    if (_sid != null) _closeScreen(now);
    _screen = name;
    if (!_ready) return;
    if (_sid == null) {
      if (_foreground) _startSession(now); // ekran varsa screen_view'i de ekler
      return;
    }
    if (name != null) {
      _emit('screen_view', screen: name, at: now);
      _screens++;
      _screenSince = _foreground ? now : null;
    }
    if (_foreground) _lastActivity = now;
  }

  /// Sekme geçişi: önceki ekranda `tab_switch` eylemi, sonra yeni sekme ekranı.
  void tabSwitch(String key) {
    action('tab_switch', target: key);
    setTab('tab_$key');
  }

  // ----------------------------------------------------------------- eylem

  static final _targetOk = RegExp(r'^[a-z0-9_]{1,24}$');

  /// Kullanıcı eylemi (beğeni, takip, katılma...). `kind` beyaz listede olmalı; `target` kısa küçük harf enum.
  void action(String kind, {String? target}) {
    if (!actionKinds.contains(kind) || !_ready) return;
    final now = _now();
    _activity(now);
    _emit('action', screen: _screen, props: {'kind': kind, if (target != null && _targetOk.hasMatch(target)) 'target': target}, at: now);
  }

  /// `RefreshIndicator.onRefresh` sarmalayıcısı: çekip yenilemede `pull_refresh` eylemi.
  static Future<void> Function() pullRefresh(FutureOr<void> Function() onRefresh) => () async {
        instance.action('pull_refresh');
        await onRefresh();
      };

  // ------------------------------------------------------------- gönderim

  /// [all]: kuyruk bitene kadar (arka plana atılırken). Gönderim hatası sessizce atılır.
  Future<void> flush({bool all = false}) async {
    final s = _session;
    if (_queue.isEmpty || s == null || s.state != SessionState.signedIn) return;
    if (_sending) {
      if (all) _flushAgain = true;
      return;
    }
    _sending = true;
    final n = _queue.length < maxBatch ? _queue.length : maxBatch;
    final batch = _queue.sublist(0, n);
    _queue.removeRange(0, n);
    try {
      await s.api.post('/analytics/events', {'events': batch});
    } catch (_) {
      // Sessizce at.
    } finally {
      _sending = false;
    }
    final again = _flushAgain || all;
    _flushAgain = false;
    if (_queue.isNotEmpty && (again || _queue.length >= flushCount)) unawaited(flush(all: again));
  }
}

/// Sayfa rotalarından ekran süresi/görünümü üretir. Yalnız [PageRoute]'lar sayılır: diyalog/alt sayfa/menü
/// (PopupRoute) ekran değildir. Ekran adı rota adıdır (`RouteSettings.name`, küçük harf/alt çizgi); adsız
/// rota `other` olur. Kök rota (`/`) sekme ekranıdır ([Analytics.setTab]). Not: sınıf adı kullanılmaz
/// (`--obfuscate` ile `runtimeType` anlamsızlaşır), bu yüzden rotalar açıkça adlandırılır.
class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver({Analytics? analytics}) : _a = analytics ?? Analytics.instance;

  final Analytics _a;
  final List<({Route<dynamic> route, String? name})> _stack = [];

  /// Rota adını ekran adına çevirir (null = kök/sekme).
  @visibleForTesting
  static String? screenName(Route<dynamic> r) {
    final n = r.settings.name;
    if (n == null || n.isEmpty) return 'other';
    if (n == '/') return null;
    final s = n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty) return 'other';
    return s.length > 40 ? s.substring(0, 40) : s;
  }

  void _sync() {
    final top = _stack.isEmpty ? null : _stack.last.name;
    _a.setRouteScreen(top);
    final shown = top ?? _a.screen;
    if (shown != null) ErrorLog.instance.currentScreen = shown;
  }

  int _indexOf(Route<dynamic> r) => _stack.indexWhere((e) => identical(e.route, r));

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _stack.add((route: route, name: screenName(route)));
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final i = _indexOf(route);
    if (i < 0) return;
    _stack.removeAt(i);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => didPop(route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _indexOf(oldRoute);
    if (i >= 0) _stack.removeAt(i);
    if (newRoute is PageRoute) {
      final e = (route: newRoute as Route<dynamic>, name: screenName(newRoute));
      if (i >= 0) {
        _stack.insert(i, e);
      } else {
        _stack.add(e);
      }
    }
    _sync();
  }
}
