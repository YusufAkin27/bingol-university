import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../platform/video_frame.dart';
import 'image_disk_cache.dart';

/// Sunucuda kapak (poster) olmayan videolar için istemcinin ürettiği kapak karelerinin önbelleği.
///
/// Neden: sohbet videosunun posteri isteğe bağlıdır (eski mesajlar, poster üretemeyen cihazlardan gönderilenler);
/// poster yoksa kapak videonun kendisinden ÜRETİLİR (iOS `AVAssetImageGenerator`, Android `MediaMetadataRetriever`)
/// ve burada saklanır.
///
/// - Anahtar = videonun tam adresi (aynı video = aynı kapak; sunucu adresi her yüklemede yeniden üretir).
/// - Katmanlar: bellek (LRU, [memoryEntries]) -> disk ([ImageDiskCache], çıkışta zaten temizlenir) -> üretim.
/// - Aynı video için üretim TEK kez yapılır (uçuştaki iş paylaşılır); aynı anda en çok [maxConcurrent] üretim
///   (kaydırmada listeyi boğmaz). Ekrandan çıkan öğenin (hiçbir dinleyicisi kalmayan) bekleyen işi atlanır.
/// - Üretim başarısızsa [retryAfter] boyunca yeniden denenmez (yer tutucu gösterilir; çökme yok).
class VideoCoverCache {
  VideoCoverCache({
    VideoFrameSource? frames,
    ImageDiskCache? disk,
    this.maxConcurrent = 2,
    this.memoryEntries = 48,
    this.retryAfter = const Duration(minutes: 2),
  })  : _frames = frames,
        _disk = disk;

  /// Uygulama genelinde paylaşılan örnek; testler değiştirir.
  static VideoCoverCache instance = VideoCoverCache();

  final VideoFrameSource? _frames;
  final ImageDiskCache? _disk;
  final int maxConcurrent;
  final int memoryEntries;
  final Duration retryAfter;

  VideoFrameSource get _src => _frames ?? PlatformVideoFrames.instance;
  ImageDiskCache get _store => _disk ?? ImageDiskCache.instance;

  final _mem = <String, Uint8List>{}; // eklenme sırası korunur (LRU)
  final _inflight = <String, Future<Uint8List?>>{};
  final _interest = <String, List<bool Function()>>{};
  final _failedAt = <String, DateTime>{};
  final _waiters = Queue<Completer<void>>();
  int _running = 0;

  /// Kaç kez kare üretildi (testler ve tanılama).
  int generated = 0;

  static String _key(String url) => 'vcover:$url';

  /// Bellekteki kapak (yoksa null); eşzamanlıdır, ilk çizimde titreme olmasın diye.
  Uint8List? peek(String url) {
    final k = _key(url);
    final v = _mem.remove(k);
    if (v != null) _mem[k] = v;
    return v;
  }

  /// Bu adres için üretim yakın zamanda başarısız oldu mu (yer tutucu kalır).
  bool recentlyFailed(String url) {
    final at = _failedAt[_key(url)];
    return at != null && DateTime.now().difference(at) < retryAfter;
  }

  /// [url] videosunun kapağı: bellek -> disk -> üretim. [headers] yetkili adres içindir.
  /// [wanted] false dönerse (öğe ekrandan çıktı) ve bekleyen başka istek yoksa üretim başlamadan vazgeçilir (null).
  Future<Uint8List?> cover(String url, Map<String, String> headers, {bool Function()? wanted}) {
    final k = _key(url);
    final hit = peek(url);
    if (hit != null) return Future.value(hit);
    if (recentlyFailed(url)) return Future.value(null);
    if (wanted != null) (_interest[k] ??= []).add(wanted);
    return _inflight[k] ??= _load(k, url, headers).whenComplete(() {
      _inflight.remove(k);
      _interest.remove(k);
    });
  }

  bool _stillWanted(String k) {
    final list = _interest[k];
    if (list == null || list.isEmpty) return true; // dinleyici bildirmediyse vazgeçme
    return list.any((w) => w());
  }

  Future<Uint8List?> _load(String k, String url, Map<String, String> headers) async {
    try {
      final onDisk = await _store.read(k);
      if (onDisk != null) {
        _put(k, onDisk);
        return onDisk;
      }
      await _acquire();
      try {
        if (!_stillWanted(k)) return null; // ekrandan çıktı: üretme, hata da sayma
        final bytes = await _src.frame(url: url, headers: headers, positionMs: 500, maxEdge: 720);
        generated++;
        if (bytes == null || bytes.isEmpty) {
          _failedAt[k] = DateTime.now();
          return null;
        }
        _put(k, bytes);
        unawaited(_store.write(k, bytes));
        return bytes;
      } finally {
        _release();
      }
    } catch (_) {
      _failedAt[k] = DateTime.now();
      return null;
    }
  }

  void _put(String k, Uint8List bytes) {
    _mem.remove(k);
    _mem[k] = bytes;
    while (_mem.length > memoryEntries) {
      _mem.remove(_mem.keys.first);
    }
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(); // yuva doğrudan sıradakine geçer
    } else {
      _running--;
    }
  }

  /// Çıkış / hesap değişimi: bellek ve hata kayıtları atılır (disk tarafını [ImageDiskCache.clear] temizler).
  Future<void> clear() async {
    _mem.clear();
    _failedAt.clear();
  }
}
