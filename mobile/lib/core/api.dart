import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;

import 'app_gate.dart' show ConnectivityHint;
import 'cache/cache_policy.dart';
import 'cache/disk_cache.dart';
import 'connectivity/connectivity_service.dart';
import 'device_identity.dart';
import 'outbox/outbox.dart';

/// Taban adres derleme anında verilir: `--dart-define=API_BASE=http://192.168.1.20:8080`.
/// Android emülatöründe bilgisayarın localhost'u 10.0.2.2'dir; gerçek iPhone için bilgisayarın LAN IP'si gerekir.
const apiOrigin = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8080');
const apiBase = '$apiOrigin/api';

/// Yerel/elden test sürümünde (`--dart-define=ALLOW_INSECURE_API=true`) http'ye izin verir.
/// Mağaza (üretim) derlemesinde verilmez; Android tarafı ayrıca cleartext'i kapalı tutar.
const allowInsecureApi = bool.fromEnvironment('ALLOW_INSECURE_API');

/// Release derlemede API adresi https olmalı (ya da bilinçli ALLOW_INSECURE_API). Debug/test'te her zaman geçerli.
bool apiConfigValid({String origin = apiOrigin, bool release = kReleaseMode, bool allowInsecure = allowInsecureApi}) {
  if (!release) return true;
  final u = Uri.tryParse(origin);
  if (u == null || u.host.isEmpty) return false;
  if (u.scheme == 'https') return true;
  return allowInsecure && u.scheme == 'http';
}

/// Sunucunun `{code,message}` hatası. Mantık `code` üzerine kurulur; `message` kullanıcıya gösterilir.
class ApiError implements Exception {
  ApiError(this.status, this.code, this.message, {this.retryAfter});

  final int status;
  final String code;
  final String message;

  /// 429/503'te sunucunun `Retry-After` başlığı (saniye); yoksa null.
  final int? retryAfter;

  /// Ağ yok / zaman aşımı: oturum bitirilmez.
  bool get isNetwork => status == 0;

  /// Geçici hata: ağ yok, zaman aşımı (408), hız sınırı (429) ya da sunucu/proxy hatası (5xx).
  /// Bu hatalar oturumu ASLA bitirmez; kısa gecikmeyle yeniden denenir ya da çevrimdışı moda düşülür.
  bool get isTransient => status == 0 || status == 408 || status == 429 || status >= 500;

  /// Sunucu oturumu/refresh belirtecini KESİN olarak reddetti: 401 (SESSION_REPLACED ve ACCESS_BLOCKED hariç,
  /// onların kendi yolu var) ya da 400/403 + oturumu bitiren kod. Yalnızca bu durumda yerel oturum silinir.
  bool get isAuthRejected {
    if (code == 'SESSION_REPLACED' || code == 'ACCESS_BLOCKED') return false;
    if (status == 401) return true;
    return (status == 400 || status == 403) && _sessionEndingCodes.contains(code);
  }

  static const _sessionEndingCodes = {
    'INVALID_REFRESH_TOKEN',
    'TOKEN_REUSED',
    'SESSION_REVOKED',
    'ACCOUNT_SUSPENDED',
    'ACCOUNT_DELETED',
  };

  @override
  String toString() => 'ApiError($status, $code)';
}

/// Gövde + yanıt başlıkları (örn. X-Next-Cursor, X-Truncated, Retry-After).
class ApiResponse {
  ApiResponse(this.body, this.headers, {this.fromCache = false, this.cachedAt});

  final dynamic body;
  final Map<String, String> headers;

  /// true: ağ yok/sunucu yanıt vermedi, yanıt önbellekten (bayat) dönüyor; [cachedAt] sunucudan alındığı an.
  final bool fromCache;
  final DateTime? cachedAt;
}

/// JWT `sub` (kullanıcı kimliği); imza doğrulanmaz (yalnız çevrimdışı açılışta "mesaj benim mi" kararı için). Çözülemezse null.
int? jwtSubjectId(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    final json = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final sub = json is Map ? json['sub'] : null;
    return sub is num ? sub.toInt() : int.tryParse('$sub');
  } catch (_) {
    return null;
  }
}

class Tokens {
  Tokens(this.access, this.refresh);

  /// Beklenmeyen/bozuk gövdede [ApiError] (status 0, BAD_RESPONSE) fırlatır; TypeError sızmaz.
  factory Tokens.fromJson(Object? j) {
    if (j is Map) {
      final a = j['accessToken'];
      final r = j['refreshToken'];
      if (a is String && a.isNotEmpty && r is String && r.isNotEmpty) return Tokens(a, r);
    }
    throw ApiError(0, 'BAD_RESPONSE', '');
  }

  final String access;
  final String refresh;
}

/// Tek HTTP katmanı: Accept-Language, Bearer, 401'de tek uçuşlu refresh + bir kez tekrar.
class ApiClient {
  ApiClient({
    http.Client? client,
    this.retryDelay = const Duration(milliseconds: 400),
    this.diskCache,
    ConnectivityService? connectivity,
  })  : _http = client ?? http.Client(),
        connectivity = connectivity ?? ConnectivityService.instance;

  /// Kalıcı (diske yazılan, boyut sınırlı) önbellek; null ise yalnız bellek önbelleği çalışır.
  final DiskCache? diskCache;

  /// Bağlantı durumu: her yanıt/ağ hatası buraya bildirilir.
  final ConnectivityService connectivity;

  /// Çevrimdışı sohbet mesajı kuyruğu (null ise yazma kuyruğu kapalı).
  Outbox? outbox;

  /// Kullanıcıya özel yerel veri temizliği (çıkış/hesap değişimi): mesaj kaydı, görsel önbelleği vb. buraya
  /// eklenir. Hatalar yutulur.
  final List<Future<void> Function()> onUserDataCleared = [];

  /// Bir kullanıcı engellendi (`POST /users/{id}/block`): engellenenin mesajları cihazda kalmasın diye yerel
  /// mesaj kaydı bu kancayla silinir (sohbetler bir sonraki açılışta sunucudan, engel süzgeciyle dolar).
  final List<Future<void> Function()> onBlockedUser = [];

  /// GET'te ağ/5xx hatasından sonra tek yeniden denemeden önceki bekleme.
  final Duration retryDelay;

  final http.Client _http;
  String lang = 'tr';

  Tokens? _tokens;

  /// Oturum nesli: çıkış / ilk giriş (belirteç yok <-> var geçişi) her seferinde artar, belirteç YENİLEMEDE artmaz.
  /// Her istek başlangıçta nesli yakalar; yanıt geldiğinde nesil değiştiyse (çıkış, hesap değişimi) yanıt önbelleğe
  /// yazılmaz ve çağırana `SESSION_CHANGED` hatası döner (önceki kullanıcının verisi yeni hesaba sızmasın).
  int _gen = 0;

  /// Geçerli oturum nesli (testler ve yarış korumaları için).
  int get sessionGen => _gen;

  Tokens? get tokens => _tokens;
  set tokens(Tokens? v) {
    if ((v == null) != (_tokens == null)) _gen++;
    _tokens = v;
  }

  Future<void> Function(Tokens?)? onTokensChanged;
  void Function()? onSessionExpired;

  /// Başka cihazda giriş yapıldı (401 SESSION_REPLACED): yeniden denemeden oturum kapatılır.
  void Function()? onSessionReplaced;

  /// 403 ACCESS_BLOCKED: cihaz/ağ engeli. Oturum silinir, refresh denenmez, engel ekranı gösterilir.
  void Function()? onAccessBlocked;

  /// 403 LEGAL_REACCEPT_REQUIRED: yeni sözleşme sürümü onaylanmadan yazma isteği reddedildi.
  /// Parametre: yanıttaki `requiresAcceptance` listesi (yoksa null). Hata yine çağırana iletilir.
  void Function(Object? requiresAcceptance)? onLegalReaccept;

  Future<Tokens>? _inflight;

  static const _timeout = Duration(seconds: 20);

  /// Bundan büyük JSON yanıtı işlenmez (bellek koruması).
  static const maxResponseBytes = 20 * 1024 * 1024;

  /// Cihaz kimliği başlıkları + dil; her isteğe eklenir.
  void _baseHeaders(http.Request req) {
    req.headers.addAll(DeviceIdentity.instance.httpHeaders);
    req.headers['Accept-Language'] = lang;
  }

  /// İsteği gönderir; gönderme VE gövde okuma zaman aşımına tabidir, aşırı büyük yanıt reddedilir.
  Future<http.Response> _fetch(http.Request req, {Duration timeout = _timeout}) async {
    final streamed = await _http.send(req).timeout(timeout);
    final len = streamed.contentLength;
    if (len != null && len > maxResponseBytes) {
      unawaited(streamed.stream.listen((_) {}).cancel());
      throw ApiError(0, 'RESPONSE_TOO_LARGE', '');
    }
    return http.Response.fromStream(streamed).timeout(timeout);
  }
  static const _maxCache = 100;

  /// Bellek önbelleği toplam gövde tavanı (bayt); aşılınca en eski girdiler atılır (diskte kalır).
  static const _maxCacheBytes = 3 * 1024 * 1024;

  /// Bu boyuttan büyük JSON gövdesi ana izolatı yormasın diye ayrı izolatta çözülür.
  static const isolateDecodeBytes = 256 * 1024;

  /// Bayat yanıt hazırken ağı bekleme süresi: yavaş ağda önbelleğe hızla düşülür.
  static const _staleTimeout = Duration(seconds: 8);
  int _cacheBytes = 0;

  // ETag önbelleği (LRU, kullanıcıya özel): anahtar = dil + yetkili mi + yol.
  final _cache = <String, _CacheEntry>{}; // LinkedHashMap: ekleme sırası = LRU sırası
  DateTime? _lastNetHint;

  /// Yazma isteği (POST/PUT/PATCH/DELETE) sonrası ilgili kaynak grubunun "taze" sayılma anı sıfırlanır
  /// (ilk yol parçası: `/events/5/rsvp` -> `events`); yeni GET ağdan doğrulanır.
  final _invalidatedAt = <String, DateTime>{};

  static String _segment(String path) {
    final p = path.startsWith('/') ? path.substring(1) : path;
    final end = p.indexOf(RegExp(r'[/?]'));
    return end < 0 ? p : p.substring(0, end);
  }

  /// [CachePolicy.freshFor] süresi içindeki ve aynı takvim gününe ait (menü/etkinlik "bugün" kayıtları) yanıt.
  bool _isFresh(String path, _CacheEntry c) {
    final ttl = CachePolicy.freshFor(path);
    if (ttl == null) return false;
    final now = DateTime.now();
    if (now.difference(c.cachedAt) >= ttl || c.cachedAt.isAfter(now)) return false;
    if (ttl == CachePolicy.dailyFresh) {
      final a = c.cachedAt.toLocal(), b = now;
      if (a.year != b.year || a.month != b.month || a.day != b.day) return false;
    }
    final inv = _invalidatedAt[_segment(path)];
    return inv == null || c.cachedAt.isAfter(inv);
  }

  void clearCache() {
    _cache.clear();
    _cacheBytes = 0;
    _invalidatedAt.clear();
    final d = diskCache;
    if (d != null) unawaited(d.clear());
  }

  String _cacheKey(String path, bool authed) => '$lang|${authed ? 'u' : 'a'}|$path';

  void _putMemory(String key, _CacheEntry e) {
    final old = _cache.remove(key);
    if (old != null) _cacheBytes -= old.bytes;
    _cache[key] = e;
    _cacheBytes += e.bytes;
    while (_cache.length > _maxCache || (_cacheBytes > _maxCacheBytes && _cache.length > 1)) {
      final k = _cache.keys.first;
      _cacheBytes -= _cache.remove(k)!.bytes;
    }
  }

  /// Önbellekteki (bayat olabilir) yanıtı AĞ İSTEĞİ ATMADAN döner; yoksa null. Ekranlar anlık ilk çizim için kullanır.
  Future<ApiResponse?> peekCache(String path) async {
    final c = await _lookup(_cacheKey(path, tokens != null), path);
    return c == null ? null : ApiResponse(c.body, c.headers, fromCache: true, cachedAt: c.cachedAt);
  }

  /// Stale-while-revalidate: varsa önce [onCached] ile eski veriyi hemen verir, sonra ağdan yeniler.
  Future<ApiResponse> getSwr(String path, {void Function(ApiResponse cached)? onCached}) async {
    if (onCached != null) {
      final c = await peekCache(path);
      if (c != null) onCached(c);
    }
    return getResponse(path);
  }

  /// Bellek, sonra (uygun uçlarda) disk.
  Future<_CacheEntry?> _lookup(String key, String path) async {
    final m = _cache[key];
    if (m != null) return m;
    final d = diskCache;
    if (d == null || CachePolicy.diskTtl(path) == null) return null;
    final e = await d.read(key);
    if (e == null) return null;
    return _CacheEntry(e.etag, e.body, e.headers, cachedAt: e.cachedAt, bytes: e.size);
  }

  /// [force]: kullanıcı çekip yeniledi; taze önbellek süresi yok sayılıp ağdan doğrulanır (ETag/304 yine geçerli).
  Future<dynamic> get(String path, {bool force = false}) async => (await getResponse(path, force: force)).body;

  /// Uçuştaki GET'ler (tek uçuş): aynı oturum nesli + dil + yol için eşzamanlı çağrılar tek ağ isteğini paylaşır
  /// (açılışta kabuk ve ana sayfa aynı `/me/summary`'yi iki kez çekmesin). `force` ayrı istektir.
  final _flightGets = <String, Future<ApiResponse>>{};

  /// Başlıklara da ihtiyaç duyan GET'ler için (sayfalama imleci vb.).
  Future<ApiResponse> getResponse(String path, {bool force = false}) {
    if (force) return _sendFull('GET', path, force: true);
    final key = '$_gen|${_cacheKey(path, _tokens != null)}';
    final shared = _flightGets[key];
    if (shared != null) return shared;
    late Future<ApiResponse> f;
    f = _sendFull('GET', path).whenComplete(() {
      if (identical(_flightGets[key], f)) _flightGets.remove(key);
    });
    return _flightGets[key] = f;
  }

  /// Yetkili ikili GET (ör. tek gösterimlik görsel). Önbelleğe ALINMAZ ve ağ hatasında YENİDEN DENENMEZ:
  /// ilk başarılı istek içeriği tüketebilir. Yalnız 401'de bir kez yenileyip tekrar dener (içerik henüz sunulmadı).
  /// 2xx dışında `{code,message}` gövdesinden [ApiError] fırlatır.
  Future<List<int>> getBytes(String path, {bool retried = false, int? gen}) async {
    await _deviceReady();
    final g = gen ?? _gen;
    _ensureGen(g);
    final req = http.Request('GET', Uri.parse('$apiBase$path'));
    _baseHeaders(req);
    req.headers['Accept'] = 'image/*, application/json';
    final t = tokens;
    if (t != null) req.headers['Authorization'] = 'Bearer ${t.access}';
    http.Response res;
    try {
      res = await _fetch(req);
    } catch (_) {
      _ensureGen(g);
      connectivity.reportFailure();
      _hintNetwork(path);
      throw ApiError(0, 'NETWORK', '');
    }
    _ensureGen(g); // çıkış / hesap değişimi sırasında dönen yanıt yeni oturuma verilmez
    if (_checkReplaced(res)) _decode(res); // ApiError(SESSION_REPLACED) fırlatır
    if (res.statusCode == 401 && t != null && !retried) {
      try {
        await refresh();
      } on ApiError catch (e) {
        handleRefreshFailure(e);
        rethrow;
      }
      return getBytes(path, retried: true, gen: g);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    _decode(res); // hata gövdesinden ApiError fırlatır
    throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '');
  }

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, [Object? body]) => _send('DELETE', path, body: body);

  Future<dynamic> post(String path, [Object? body, bool auth = true]) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> _send(String method, String path, {Object? body, bool auth = true}) async =>
      (await _sendFull(method, path, body: body, auth: auth)).body;

  /// Oturum nesli [g]'den farklıysa (çıkış / hesap değişimi) isteği iptal eder: yanıt yeni oturuma verilmez.
  void _ensureGen(int g) {
    if (g != _gen) throw ApiError(0, 'SESSION_CHANGED', '');
  }

  /// Cihaz kimliği açılışta okunurken (main) ilk istek atılmasın; hazırsa hiç beklemez.
  Future<void> _deviceReady() => DeviceIdentity.instance.isReady ? Future<void>.value() : DeviceIdentity.instance.ready;

  Future<ApiResponse> _sendFull(String method, String path,
      {Object? body,
      bool auth = true,
      bool retried = false,
      bool retriedTransient = false,
      bool force = false,
      int? gen}) async {
    if (!DeviceIdentity.instance.isReady) await DeviceIdentity.instance.ready;
    final g = gen ?? _gen;
    _ensureGen(g);
    final isGet = method == 'GET';
    final req = http.Request(method, Uri.parse('$apiBase$path'));
    _baseHeaders(req);
    req.headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }
    final t = tokens;
    if (auth && t != null) req.headers['Authorization'] = 'Bearer ${t.access}';

    final authed = auth && t != null;
    final cacheKey = _cacheKey(path, authed);
    final diskTtl = isGet && diskCache != null ? CachePolicy.diskTtl(path) : null;
    final cached = isGet ? await _lookup(cacheKey, path) : null;
    _ensureGen(g);
    // Taze önbellek: ağa hiç gidilmez (günlük/sabit veri her ekran açılışında yeniden çekilmesin).
    if (isGet && !force && cached != null && _isFresh(path, cached)) {
      _putMemory(cacheKey, cached); // LRU'da en yeni
      return ApiResponse(cached.body, cached.headers);
    }
    final etag = cached?.etag;
    if (etag != null && etag.isNotEmpty) req.headers['If-None-Match'] = etag;
    // Bayat yanıt elimizdeyse: kısa zaman aşımı, yeniden deneme yok (ağ yoksa hemen önbellek).
    final haveStale = cached != null && CachePolicy.allowsStale(path);

    http.Response res;
    try {
      res = await _fetch(req, timeout: haveStale ? _staleTimeout : _timeout);
    } catch (e) {
      if (e is ApiError) rethrow; // örn. RESPONSE_TOO_LARGE: yeniden denemenin anlamı yok
      _ensureGen(g);
      if (isGet && !retriedTransient && !haveStale) {
        await Future<void>.delayed(retryDelay);
        return _sendFull(method, path,
            body: body, auth: auth, retried: retried, retriedTransient: true, gen: g);
      }
      connectivity.reportFailure();
      _hintNetwork(path);
      if (haveStale) return _staleResponse(cached);
      if (method == 'POST') outbox?.captureRequest(path, body);
      throw ApiError(0, 'NETWORK', '');
    }
    // Çıkış / hesap değişimi sırasında dönen yanıt: önbelleğe yazılmaz, yeni oturuma verilmez.
    _ensureGen(g);

    if (isGet && !retriedTransient && (res.statusCode == 502 || res.statusCode == 503 || res.statusCode == 504)) {
      await Future<void>.delayed(retryDelay);
      return _sendFull(method, path, body: body, auth: auth, retried: retried, retriedTransient: true, gen: g);
    }
    if (haveStale && res.statusCode >= 500) return _staleResponse(cached);

    if (_checkReplaced(res)) _decode(res); // ApiError(SESSION_REPLACED) fırlatır
    if (res.statusCode == 401 && auth && t != null && !retried) {
      // Kimliksiz 401 gövdesinde code yoktur: yalnızca HTTP durumuna bakılır.
      try {
        await refresh();
      } on ApiError catch (e) {
        handleRefreshFailure(e);
        rethrow;
      }
      return _sendFull(method, path,
          body: body, auth: auth, retried: true, retriedTransient: retriedTransient, gen: g);
    }

    if (isGet && res.statusCode == 304 && cached != null) {
      connectivity.reportSuccess();
      // Sunucu "değişmedi" dedi: doğrulama anı tazelenir, en yeni kullanılan sona alınır.
      final fresh = _CacheEntry(cached.etag, cached.body, cached.headers,
          cachedAt: DateTime.now(), bytes: cached.bytes);
      if (cached.etag != null) _putMemory(cacheKey, fresh);
      if (diskTtl != null) unawaited(diskCache!.touch(cacheKey, diskTtl));
      return ApiResponse(cached.body, cached.headers);
    }
    final dynamic decoded;
    try {
      decoded = res.statusCode == 200 && res.bodyBytes.length > isolateDecodeBytes
          ? await _decodeLarge(res)
          : _decode(res);
    } on ApiError catch (e) {
      // 4xx: sunucuya ulaşıldı (JSON hata gövdesi). Ağ geçidi / 5xx / portal HTML'i "çevrimiçi" sayılmaz.
      if (e.status >= 400 && e.status < 500 && !_isHtml(res)) connectivity.reportSuccess();
      rethrow;
    }
    _ensureGen(g); // büyük gövde ayrı izolatta çözülürken oturum değişmiş olabilir
    connectivity.reportSuccess();
    if (!isGet && res.statusCode >= 200 && res.statusCode < 300) {
      _invalidatedAt[_segment(path)] = DateTime.now();
      if (method == 'POST' && RegExp(r'^/users/\d+/block$').hasMatch(path)) {
        for (final f in List.of(onBlockedUser)) {
          unawaited(f().catchError((Object _) {}));
        }
      }
    }
    // Boş (null) gövde önbelleğe yazılmaz: yalnız çözülmüş JSON saklanır.
    if (isGet && res.statusCode == 200 && decoded != null) {
      final tag = res.headers['etag'];
      if (tag != null && tag.isNotEmpty) {
        _putMemory(cacheKey, _CacheEntry(tag, decoded, res.headers,
            cachedAt: DateTime.now(), bytes: res.bodyBytes.length));
      } else {
        final old = _cache.remove(cacheKey);
        if (old != null) _cacheBytes -= old.bytes;
      }
      // Diske yalnız beyaz listedeki uçlar (CachePolicy); hata yutulur, ana akış beklemez.
      if (diskTtl != null) unawaited(diskCache!.write(cacheKey, decoded, res.headers, diskTtl));
    }
    return ApiResponse(decoded, res.headers);
  }

  ApiResponse _staleResponse(_CacheEntry c) {
    connectivity.reportStale(c.cachedAt);
    return ApiResponse(c.body, c.headers, fromCache: true, cachedAt: c.cachedAt);
  }

  /// 401 + SESSION_REPLACED: oturum varsa (token tutuluyorsa) bildirir; refresh yanıtı da buraya düşer.
  /// true dönerse çağıran ApiError fırlatır (refresh denenmez).
  bool _checkReplaced(http.Response res) {
    if (res.statusCode != 401 || tokens == null) return false;
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
      if (j is Map && j['code'] == 'SESSION_REPLACED') {
        onSessionReplaced?.call();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Bağlantı kapısına haber verir; /status yoklaması döngü yaratmasın diye hariç, 5 sn'de en çok bir kez.
  void _hintNetwork(String path) {
    if (path.startsWith('/status')) return;
    final now = DateTime.now();
    final last = _lastNetHint;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) return;
    _lastNetHint = now;
    ConnectivityHint.reportNetworkError();
  }

  /// Büyük gövde: JSON çözümü ayrı izolatta (ana izolat kare atlamasın). Hata olursa ana izolatta dener.
  Future<dynamic> _decodeLarge(http.Response res) async {
    final bytes = res.bodyBytes;
    try {
      return await Isolate.run(() => _parseJson(bytes));
    } catch (_) {
      return _decode(res);
    }
  }

  static dynamic _parseJson(List<int> bytes) => jsonDecode(utf8.decode(bytes, allowMalformed: true));

  /// Captive portal / proxy HTML sayfası (200 ile gelse de API yanıtı değildir).
  static bool _isHtml(http.Response res) => (res.headers['content-type'] ?? '').toLowerCase().contains('text/html');

  dynamic _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    final success = res.statusCode >= 200 && res.statusCode < 300;
    dynamic json;
    var parsed = text.isEmpty;
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
        parsed = true;
      } catch (_) {
        json = null;
      }
    }
    if (success) {
      // JSON olmayan 2xx gövde (captive portal, proxy, bozuk yanıt) başarı sayılmaz ve önbelleğe girmez.
      if (!parsed || _isHtml(res)) throw ApiError(0, 'BAD_RESPONSE', '');
      return json;
    }
    final retryAfter = int.tryParse((res.headers['retry-after'] ?? '').trim());
    if (json is Map && json['code'] is String) {
      final code = json['code'] as String;
      final msg = json['message'];
      if (res.statusCode == 403 && code == 'ACCESS_BLOCKED') onAccessBlocked?.call();
      if (res.statusCode == 403 && code == 'LEGAL_REACCEPT_REQUIRED') onLegalReaccept?.call(json['requiresAcceptance']);
      throw ApiError(res.statusCode, code, msg is String ? msg : '', retryAfter: retryAfter);
    }
    throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '', retryAfter: retryAfter);
  }

  /// Yenileme başarısız oldu: oturum YALNIZ kesin yetki hatasında ([ApiError.isAuthRejected]) kapanır.
  /// Geçici hatalarda (5xx, 429, 408, ağ) belirteçler korunur; çağırana hata iletilir.
  void handleRefreshFailure(ApiError e) {
    if (e.isAuthRejected) onSessionExpired?.call();
  }

  /// Geçici yenileme hatasında ek deneme sayısı (kısa, artan gecikmeyle).
  static const _refreshRetries = 2;

  /// Refresh token tek kullanımlıktır: eşzamanlı çağrılar aynı isteği paylaşır. Çıkış / hesap değişiminde uçuştaki
  /// yenileme bırakılır (yeni oturum eskisine bağlanmaz).
  Future<Tokens> refresh() {
    final existing = _inflight;
    if (existing != null) return existing;
    late Future<Tokens> f;
    f = _doRefresh().whenComplete(() {
      if (identical(_inflight, f)) _inflight = null;
    });
    return _inflight = f;
  }

  Future<Tokens> _doRefresh() async {
    final old = tokens?.refresh;
    if (old == null) throw ApiError(401, 'INVALID_REFRESH_TOKEN', '');
    final g = _gen;
    dynamic res;
    for (var attempt = 0;; attempt++) {
      try {
        res = await _sendRaw('/auth/refresh', {'refreshToken': old}, gen: g);
        break;
      } on ApiError catch (e) {
        // Yalnız sunucu tarafı geçici hatalar (5xx/429/408) yeniden denenir; ağ hatası zaten
        // çevrimdışı akışına düşer, kesin ret ise hemen iletilir.
        if (e.isNetwork || !e.isTransient || attempt >= _refreshRetries) rethrow;
        final ra = e.retryAfter;
        final wait = ra != null && ra > 0 && ra <= 5 ? Duration(seconds: ra) : retryDelay * (attempt + 1);
        await Future<void>.delayed(wait);
      }
    }
    final t = Tokens.fromJson(res);
    // Yenileme sürerken çıkış / hesap değişimi olduysa sonuç atılır: çıkış yapılmış oturum geri yazılmaz.
    _ensureGen(g);
    if (_tokens == null) throw ApiError(0, 'SESSION_CHANGED', '');
    await setTokens(t); // önce yeni çifti yaz
    return t;
  }

  Future<dynamic> _sendRaw(String path, Object body, {int? gen}) async =>
      (await _sendFull('POST', path, body: body, auth: false, gen: gen)).body;

  Future<void> setTokens(Tokens? t) async {
    // Kullanıcı değişimi/çıkışta önbellek sızmasın (yenilemede korunur).
    if (t == null || _tokens == null) {
      if (t != null || _tokens != null) _gen++; // gerçek oturum geçişi: uçuştaki istekler/yenilemeler yok sayılır
      _inflight = null;
      _flightGets.clear();
      clearCache(); // bellek + disk
      final ob = outbox;
      if (ob != null) unawaited(ob.clear()); // bekleyen mesajlar başka hesaba sızmasın
      for (final f in List.of(onUserDataCleared)) {
        unawaited(f().catchError((Object _) {})); // mesaj kaydı, görsel önbelleği, arama geçmişi...
      }
    }
    _tokens = t;
    await onTokensChanged?.call(t);
  }
}

class _CacheEntry {
  _CacheEntry(this.etag, this.body, this.headers, {DateTime? cachedAt, this.bytes = 0})
      : cachedAt = cachedAt ?? DateTime.now();
  final String? etag;
  final dynamic body;
  final Map<String, String> headers;
  final DateTime cachedAt;

  /// Yanıt gövdesinin ham boyutu (bellek tavanı için).
  final int bytes;
}
