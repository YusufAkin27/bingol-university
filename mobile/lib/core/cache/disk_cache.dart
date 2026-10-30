import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Diskten okunan önbellek kaydı.
class DiskCacheEntry {
  DiskCacheEntry(this.body, this.headers, this.cachedAt, {this.size = 0});

  /// Diskteki dosya boyutu (bellek tavanı hesabı için).
  final int size;

  final dynamic body;
  final Map<String, String> headers;
  final DateTime cachedAt;

  String? get etag => headers['etag'];
}

class _Meta {
  _Meta(this.file, this.size, this.cachedAt, this.expiresAt);

  final String file;
  final int size;
  int cachedAt; // epoch ms
  int expiresAt; // epoch ms

  Map<String, dynamic> toJson() => {'f': file, 's': size, 'c': cachedAt, 'e': expiresAt};

  static _Meta? fromJson(Object? j) {
    if (j is! Map) return null;
    final f = j['f'], s = j['s'], c = j['c'], e = j['e'];
    if (f is! String || s is! int || c is! int || e is! int) return null;
    return _Meta(f, s, c, e);
  }
}

/// Boyut sınırlı, LRU + süreli, kalıcı GET önbelleği (uygulama sandbox'ında JSON dosyaları).
///
/// - Dizin ([_index]) bellekte tutulur, ilk kullanımda tembel yüklenir; gövdeler yalnızca okunurken diskten gelir.
/// - Sınırlar: toplam [maxTotalBytes], girdi başına [maxEntryBytes], en çok [maxEntries] girdi.
///   Aşımda en eski kullanılan girdiler atılır. Süresi dolan girdi asla dönmez ve silinir.
/// - Bütün disk işlemleri tek sıraya dizilir (yarış yok); hata hiçbir zaman çağırana sızmaz.
class DiskCache {
  DiskCache({
    Future<Directory> Function()? dirProvider,
    this.maxTotalBytes = 16 * 1024 * 1024,
    this.maxEntryBytes = 512 * 1024,
    this.maxEntries = 400,
    DateTime Function()? now,
  })  : _dirProvider = dirProvider ?? _defaultDir,
        _now = now ?? DateTime.now;

  final Future<Directory> Function() _dirProvider;
  final int maxTotalBytes;
  final int maxEntryBytes;
  final int maxEntries;
  final DateTime Function() _now;

  static Future<Directory> _defaultDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}api_cache');
  }

  /// LinkedHashMap: ekleme sırası = LRU sırası (ilk = en eski).
  final LinkedHashMap<String, _Meta> _index = LinkedHashMap();
  Directory? _dir;
  Future<void>? _loading;
  Future<void> _queue = Future<void>.value();
  Timer? _saveTimer;
  int _total = 0;

  int get totalBytes => _total;
  int get length => _index.length;

  static String _hash(String key) => sha1.convert(utf8.encode(key)).toString();

  Future<T> _run<T>(Future<T> Function() op, T fallback) {
    final c = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        await _ensureLoaded();
        c.complete(await op());
      } catch (_) {
        c.complete(fallback);
      }
    });
    return c.future;
  }

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final dir = await _dirProvider();
    await dir.create(recursive: true);
    _dir = dir;
    final f = File('${dir.path}${Platform.pathSeparator}index.json');
    try {
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString());
        if (j is Map) {
          final now = _now().millisecondsSinceEpoch;
          for (final e in j.entries) {
            final m = _Meta.fromJson(e.value);
            if (m == null || m.expiresAt <= now) continue;
            _index['${e.key}'] = m;
            _total += m.size;
          }
        }
      }
    } catch (_) {
      _index.clear();
      _total = 0;
    }
    // Dizinde olmayan artık dosyaları temizle (çökme sonrası).
    try {
      final known = {for (final m in _index.values) m.file};
      await for (final e in dir.list()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        if (name == 'index.json' || known.contains(name)) continue;
        await e.delete();
      }
    } catch (_) {}
    await _evict();
  }

  File _file(String name) => File('${_dir!.path}${Platform.pathSeparator}$name');

  /// Geçerli (süresi dolmamış) kaydı döndürür; yoksa/bozuksa null. Kullanım LRU sırasını günceller.
  Future<DiskCacheEntry?> read(String key) => _run<DiskCacheEntry?>(() async {
        final m = _index[key];
        if (m == null) return null;
        final now = _now().millisecondsSinceEpoch;
        if (m.expiresAt <= now) {
          await _drop(key);
          return null;
        }
        try {
          final j = jsonDecode(await _file(m.file).readAsString());
          if (j is! Map) throw const FormatException();
          final h = j['h'];
          final headers = <String, String>{
            if (h is Map) for (final e in h.entries) '${e.key}': '${e.value}',
          };
          _index.remove(key);
          _index[key] = m; // en yeni kullanılan sona
          return DiskCacheEntry(j['b'], headers, DateTime.fromMillisecondsSinceEpoch(m.cachedAt), size: m.size);
        } catch (_) {
          await _drop(key); // dosya yok/bozuk
          return null;
        }
      }, null);

  /// Yazar (yoksa oluşturur). [maxEntryBytes]'ı aşan gövde yazılmaz (varsa eskisi silinir).
  Future<void> write(String key, dynamic body, Map<String, String> headers, Duration ttl) =>
      _run<void>(() async {
        final keep = <String, String>{
          for (final e in headers.entries)
            if (e.key == 'etag' || e.key.startsWith('x-')) e.key: e.value,
        };
        final bytes = utf8.encode(jsonEncode({'b': body, 'h': keep}));
        if (bytes.length > maxEntryBytes) {
          await _drop(key);
          return;
        }
        final old = _index.remove(key);
        if (old != null) _total -= old.size;
        final name = _hash(key);
        await _file(name).writeAsBytes(bytes, flush: false);
        final now = _now().millisecondsSinceEpoch;
        _index[key] = _Meta(name, bytes.length, now, now + ttl.inMilliseconds);
        _total += bytes.length;
        await _evict();
        _scheduleSave();
      }, null);

  /// 304 sonrası: gövdeyi yeniden yazmadan "doğrulandı" anını ve ömrü tazeler.
  Future<void> touch(String key, Duration ttl) => _run<void>(() async {
        final m = _index[key];
        if (m == null) return;
        final now = _now().millisecondsSinceEpoch;
        m.cachedAt = now;
        m.expiresAt = now + ttl.inMilliseconds;
        _scheduleSave();
      }, null);

  Future<void> remove(String key) => _run<void>(() => _drop(key), null);

  /// Oturum kapanışı/hesap silme: her şeyi siler.
  Future<void> clear() => _run<void>(() async {
        _saveTimer?.cancel();
        final dir = _dir!;
        _index.clear();
        _total = 0;
        try {
          await for (final e in dir.list()) {
            if (e is File) await e.delete();
          }
        } catch (_) {}
      }, null);

  /// Dizini hemen diske yazar (test/uygulama arka plana giderken).
  Future<void> flush() => _run<void>(() async {
        _saveTimer?.cancel();
        await _saveIndex();
      }, null);

  Future<void> _drop(String key) async {
    final m = _index.remove(key);
    if (m == null) return;
    _total -= m.size;
    try {
      await _file(m.file).delete();
    } catch (_) {}
    _scheduleSave();
  }

  Future<void> _evict() async {
    final now = _now().millisecondsSinceEpoch;
    // Önce süresi dolanlar.
    final expired = [for (final e in _index.entries) if (e.value.expiresAt <= now) e.key];
    for (final k in expired) {
      await _drop(k);
    }
    while (_index.isNotEmpty && (_total > maxTotalBytes || _index.length > maxEntries)) {
      await _drop(_index.keys.first);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () => unawaited(flush()));
  }

  Future<void> _saveIndex() async {
    final f = File('${_dir!.path}${Platform.pathSeparator}index.json');
    await f.writeAsString(jsonEncode({for (final e in _index.entries) e.key: e.value.toJson()}));
  }
}
