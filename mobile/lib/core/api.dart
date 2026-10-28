import 'dart:async';
import 'dart:convert';

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

  /// Çevrimdışı sohbet metin mesajı kuyruğu (null ise yazma kuyruğu kapalı).
  Outbox? outbox;

  /// GET'te ağ/5xx hatasından sonra tek yeniden denemeden önceki bekleme.
  final Duration retryDelay;

  final http.Client _http;
  String lang = 'tr';

  Tokens? tokens;
  Future<void> Function(Tokens?)? onTokensChanged;
  void Function()? onSessionExpired;

  /// Başka cihazda giriş yapıldı (401 SESSION_REPLACED): yeniden denemeden oturum kapatılır.
  void Function()? onSessionReplaced;

  /// 403 ACCESS_BLOCKED: cihaz/ağ engeli. Oturum silinir, refresh denenmez, engel ekranı gösterilir.
  void Function()? onAccessBlocked;

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

  /// Bellek önbelleği toplam gövde tavanı (bayt); aşılınca en eski girdiler atılır.
  static const _maxCacheBytes = 6 * 1024 * 1024;

  /// Bayat yanıt hazırken ağı bekleme süresi: yavaş ağda önbelleğe hızla düşülür.
  static const _staleTimeout = Duration(seconds: 8);
  int _cacheBytes = 0;

  // ETag önbelleği (LRU, kullanıcıya özel): anahtar = dil + yetkili mi + yol.
  final _cache = <String, _CacheEntry>{}; // LinkedHashMap: ekleme sırası = LRU sırası
  DateTime? _lastNetHint;

  void clearCache() {
    _cache.clear();
    _cacheBytes = 0;
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
    return _CacheEntry(e.etag, e.body, e.headers, cachedAt: e.cachedAt);
  }

  Future<dynamic> get(String path) async => (await getResponse(path)).body;

  /// Başlıklara da ihtiyaç duyan GET'ler için (sayfalama imleci vb.).
  Future<ApiResponse> getResponse(String path) => _sendFull('GET', path);

  /// Yetkili ikili GET (ör. tek gösterimlik görsel). Önbelleğe ALINMAZ ve ağ hatasında YENİDEN DENENMEZ:
  /// ilk başarılı istek içeriği tüketebilir. Yalnız 401'de bir kez yenileyip tekrar dener (içerik henüz sunulmadı).
  /// 2xx dışında `{code,message}` gövdesinden [ApiError] fırlatır.
  Future<List<int>> getBytes(String path, {bool retried = false}) async {
    final req = http.Request('GET', Uri.parse('$apiBase$path'));
    _baseHeaders(req);
    req.headers['Accept'] = 'image/*, application/json';
    final t = tokens;
    if (t != null) req.headers['Authorization'] = 'Bearer ${t.access}';
    http.Response res;
    try {
      res = await _fetch(req);
    } catch (_) {
      connectivity.reportFailure();
      _hintNetwork(path);
      throw ApiError(0, 'NETWORK', '');
    }
    if (_checkReplaced(res)) _decode(res); // ApiError(SESSION_REPLACED) fırlatır
    if (res.statusCode == 401 && t != null && !retried) {
      try {
        await refresh();
      } on ApiError catch (e) {
        if (!e.isNetwork && e.code != 'SESSION_REPLACED' && e.code != 'ACCESS_BLOCKED') onSessionExpired?.call();
        rethrow;
      }
      return getBytes(path, retried: true);
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

  Future<ApiResponse> _sendFull(String method, String path,
      {Object? body, bool auth = true, bool retried = false, bool retriedTransient = false}) async {
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
    final etag = cached?.etag;
    if (etag != null && etag.isNotEmpty) req.headers['If-None-Match'] = etag;
    // Bayat yanıt elimizdeyse: kısa zaman aşımı, yeniden deneme yok (ağ yoksa hemen önbellek).
    final haveStale = cached != null && CachePolicy.allowsStale(path);

    http.Response res;
    try {
      res = await _fetch(req, timeout: haveStale ? _staleTimeout : _timeout);
    } catch (e) {
      if (e is ApiError) rethrow; // örn. RESPONSE_TOO_LARGE: yeniden denemenin anlamı yok
      if (isGet && !retriedTransient && !haveStale) {
        await Future<void>.delayed(retryDelay);
        return _sendFull(method, path,
            body: body, auth: auth, retried: retried, retriedTransient: true);
      }
      connectivity.reportFailure();
      _hintNetwork(path);
      if (haveStale) return _staleResponse(cached);
      if (method == 'POST') outbox?.captureRequest(path, body);
      throw ApiError(0, 'NETWORK', '');
    }
    connectivity.reportSuccess();

    if (isGet && !retriedTransient && (res.statusCode == 502 || res.statusCode == 503 || res.statusCode == 504)) {
      await Future<void>.delayed(retryDelay);
      return _sendFull(method, path, body: body, auth: auth, retried: retried, retriedTransient: true);
    }
    if (haveStale && res.statusCode >= 500) return _staleResponse(cached);

    if (_checkReplaced(res)) _decode(res); // ApiError(SESSION_REPLACED) fırlatır
    if (res.statusCode == 401 && auth && t != null && !retried) {
      // Kimliksiz 401 gövdesinde code yoktur: yalnızca HTTP durumuna bakılır.
      try {
        await refresh();
      } on ApiError catch (e) {
        if (!e.isNetwork && e.code != 'SESSION_REPLACED' && e.code != 'ACCESS_BLOCKED') onSessionExpired?.call();
        rethrow;
      }
      return _sendFull(method, path, body: body, auth: auth, retried: true, retriedTransient: retriedTransient);
    }

    if (isGet && res.statusCode == 304 && cached != null) {
      // Sunucu "değişmedi" dedi: doğrulama anı tazelenir, en yeni kullanılan sona alınır.
      final fresh = _CacheEntry(cached.etag, cached.body, cached.headers,
          cachedAt: DateTime.now(), bytes: cached.bytes);
      if (cached.etag != null) _putMemory(cacheKey, fresh);
      if (diskTtl != null) unawaited(diskCache!.touch(cacheKey, diskTtl));
      return ApiResponse(cached.body, cached.headers);
    }
    final decoded = _decode(res);
    if (isGet && res.statusCode == 200) {
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

  dynamic _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    dynamic json;
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } catch (_) {
        json = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    final retryAfter = int.tryParse((res.headers['retry-after'] ?? '').trim());
    if (json is Map && json['code'] is String) {
      final code = json['code'] as String;
      final msg = json['message'];
      if (res.statusCode == 403 && code == 'ACCESS_BLOCKED') onAccessBlocked?.call();
      throw ApiError(res.statusCode, code, msg is String ? msg : '', retryAfter: retryAfter);
    }
    throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '', retryAfter: retryAfter);
  }

  /// Refresh token tek kullanımlıktır: eşzamanlı çağrılar aynı isteği paylaşır.
  Future<Tokens> refresh() => _inflight ??= _doRefresh().whenComplete(() => _inflight = null);

  Future<Tokens> _doRefresh() async {
    final old = tokens?.refresh;
    if (old == null) throw ApiError(401, 'INVALID_REFRESH_TOKEN', '');
    final res = await _sendRaw('/auth/refresh', {'refreshToken': old});
    final t = Tokens.fromJson(res);
    await setTokens(t); // önce yeni çifti yaz
    return t;
  }

  Future<dynamic> _sendRaw(String path, Object body) => _send('POST', path, body: body, auth: false);

  Future<void> setTokens(Tokens? t) async {
    // Kullanıcı değişimi/çıkışta önbellek sızmasın (yenilemede korunur).
    if (t == null || tokens == null) {
      clearCache(); // bellek + disk
      final ob = outbox;
      if (ob != null) unawaited(ob.clear()); // bekleyen mesajlar başka hesaba sızmasın
    }
    tokens = t;
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
