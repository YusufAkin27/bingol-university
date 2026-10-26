import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_gate.dart' show ConnectivityHint;

/// Taban adres derleme anında verilir: `--dart-define=API_BASE=http://192.168.1.20:8080`.
/// Android emülatöründe bilgisayarın localhost'u 10.0.2.2'dir; gerçek iPhone için bilgisayarın LAN IP'si gerekir.
const apiOrigin = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8080');
const apiBase = '$apiOrigin/api';

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
  ApiResponse(this.body, this.headers);

  final dynamic body;
  final Map<String, String> headers;
}

class Tokens {
  Tokens(this.access, this.refresh);

  factory Tokens.fromJson(Map<String, dynamic> j) =>
      Tokens(j['accessToken'] as String, j['refreshToken'] as String);

  final String access;
  final String refresh;
}

/// Tek HTTP katmanı: Accept-Language, Bearer, 401'de tek uçuşlu refresh + bir kez tekrar.
class ApiClient {
  ApiClient({http.Client? client, this.retryDelay = const Duration(milliseconds: 400)})
      : _http = client ?? http.Client();

  /// GET'te ağ/5xx hatasından sonra tek yeniden denemeden önceki bekleme.
  final Duration retryDelay;

  final http.Client _http;
  String lang = 'tr';

  Tokens? tokens;
  Future<void> Function(Tokens?)? onTokensChanged;
  void Function()? onSessionExpired;

  Future<Tokens>? _inflight;

  static const _timeout = Duration(seconds: 20);
  static const _maxCache = 100;

  // ETag önbelleği (LRU, kullanıcıya özel): anahtar = dil + yetkili mi + yol.
  final _cache = LinkedHashMap<String, _CacheEntry>();
  DateTime? _lastNetHint;

  void clearCache() => _cache.clear();

  Future<dynamic> get(String path) async => (await getResponse(path)).body;

  /// Başlıklara da ihtiyaç duyan GET'ler için (sayfalama imleci vb.).
  Future<ApiResponse> getResponse(String path) => _sendFull('GET', path);

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
    req.headers['Accept-Language'] = lang;
    req.headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }
    final t = tokens;
    if (auth && t != null) req.headers['Authorization'] = 'Bearer ${t.access}';

    final cacheKey = '$lang|${auth && t != null ? 'u' : 'a'}|$path';
    final cached = isGet ? _cache[cacheKey] : null;
    if (cached != null) req.headers['If-None-Match'] = cached.etag;

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } catch (_) {
      if (isGet && !retriedTransient) {
        await Future<void>.delayed(retryDelay);
        return _sendFull(method, path,
            body: body, auth: auth, retried: retried, retriedTransient: true);
      }
      _hintNetwork(path);
      throw ApiError(0, 'NETWORK', '');
    }

    if (isGet && !retriedTransient && (res.statusCode == 502 || res.statusCode == 503 || res.statusCode == 504)) {
      await Future<void>.delayed(retryDelay);
      return _sendFull(method, path, body: body, auth: auth, retried: retried, retriedTransient: true);
    }

    if (res.statusCode == 401 && auth && t != null && !retried) {
      // Kimliksiz 401 gövdesinde code yoktur: yalnızca HTTP durumuna bakılır.
      try {
        await refresh();
      } on ApiError catch (e) {
        if (!e.isNetwork) onSessionExpired?.call();
        rethrow;
      }
      return _sendFull(method, path, body: body, auth: auth, retried: true, retriedTransient: retriedTransient);
    }

    if (isGet && res.statusCode == 304 && cached != null) {
      _cache.remove(cacheKey);
      _cache[cacheKey] = cached; // en yeni kullanılan sona
      return ApiResponse(cached.body, cached.headers);
    }
    final decoded = _decode(res);
    if (isGet && res.statusCode == 200) {
      final etag = res.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        _cache.remove(cacheKey);
        _cache[cacheKey] = _CacheEntry(etag, decoded, res.headers);
        while (_cache.length > _maxCache) {
          _cache.remove(_cache.keys.first);
        }
      } else {
        _cache.remove(cacheKey);
      }
    }
    return ApiResponse(decoded, res.headers);
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
    final text = utf8.decode(res.bodyBytes);
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
      throw ApiError(res.statusCode, json['code'] as String, (json['message'] as String?) ?? '',
          retryAfter: retryAfter);
    }
    throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '', retryAfter: retryAfter);
  }

  /// Refresh token tek kullanımlıktır: eşzamanlı çağrılar aynı isteği paylaşır.
  Future<Tokens> refresh() => _inflight ??= _doRefresh().whenComplete(() => _inflight = null);

  Future<Tokens> _doRefresh() async {
    final old = tokens?.refresh;
    if (old == null) throw ApiError(401, 'INVALID_REFRESH_TOKEN', '');
    final res = await _sendRaw('/auth/refresh', {'refreshToken': old});
    final t = Tokens.fromJson(res as Map<String, dynamic>);
    await setTokens(t); // önce yeni çifti yaz
    return t;
  }

  Future<dynamic> _sendRaw(String path, Object body) => _send('POST', path, body: body, auth: false);

  Future<void> setTokens(Tokens? t) async {
    // Kullanıcı değişimi/çıkışta önbellek sızmasın (yenilemede korunur).
    if (t == null || tokens == null) _cache.clear();
    tokens = t;
    await onTokensChanged?.call(t);
  }
}

class _CacheEntry {
  _CacheEntry(this.etag, this.body, this.headers);
  final String etag;
  final dynamic body;
  final Map<String, String> headers;
}
