import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Ağ görsellerinin ham baytları için boyut sınırlı disk önbelleği (çevrimdışıyken görseller görünsün).
///
/// - Dosya adı = URL'nin SHA-1'i; içerik yalnız görsel baytları (başlık/kimlik saklanmaz).
/// - Toplam tavan [maxBytes] (varsayılan 150 MB): aşılınca en eski değişen dosyalar silinir. Budama zamanlayıcıyla
///   değil, açılışta bir kez ve her [_pruneEvery] yazmada yapılır (arka planda iş yok).
/// - Tek dosya [maxFileBytes]'ı aşarsa yazılmaz (yine de gösterilir). Hata hiçbir zaman çağırana sızmaz.
/// - Oturum kapanışında [clear] (kullanıcıya özel yetkili görseller cihazda kalmasın).
class ImageDiskCache {
  ImageDiskCache({
    Future<Directory> Function()? dirProvider,
    this.maxBytes = 150 * 1024 * 1024,
    this.maxFileBytes = 12 * 1024 * 1024,
  }) : _dirProvider = dirProvider ?? _defaultDir;

  /// Diske hiç yazmayan/okumayan örnek (varsayılan; testler eklentiye dokunmaz).
  factory ImageDiskCache.disabled() => ImageDiskCache(dirProvider: () async => throw const FileSystemException('disabled'));

  /// Uygulama genelinde tek örnek; `main` diskli örneği atar (`ImageDiskCache.instance = ImageDiskCache()`).
  static ImageDiskCache instance = ImageDiskCache.disabled();

  final Future<Directory> Function() _dirProvider;
  final int maxBytes;
  final int maxFileBytes;

  static const _pruneEvery = 40;

  static Future<Directory> _defaultDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}img_cache');
  }

  Directory? _dir;
  Future<void>? _init;
  int _writes = 0;
  Future<void>? _queue;

  static String keyOf(String url) => sha1.convert(utf8.encode(url)).toString();

  Future<void> _ensure() => _init ??= () async {
        final d = await _dirProvider();
        await d.create(recursive: true);
        _dir = d;
        unawaited(_enqueuePrune());
      }();

  Future<T> _serial<T>(Future<T> Function() op, T fallback) {
    final c = Completer<T>();
    _queue = (_queue ?? Future<void>.value()).then((_) async {
      try {
        await _ensure();
        c.complete(await op());
      } catch (_) {
        c.complete(fallback);
      }
    });
    return c.future;
  }

  /// Diskteki baytlar; yoksa null.
  Future<Uint8List?> read(String url) async {
    try {
      await _ensure();
      final f = File('${_dir!.path}${Platform.pathSeparator}${keyOf(url)}');
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String url, Uint8List bytes) => _serial<void>(() async {
        if (bytes.isEmpty || bytes.length > maxFileBytes) return;
        final f = File('${_dir!.path}${Platform.pathSeparator}${keyOf(url)}');
        await f.writeAsBytes(bytes, flush: false);
        if (++_writes % _pruneEvery == 0) await _prune();
      }, null);

  Future<void> remove(String url) => _serial<void>(() async {
        final f = File('${_dir!.path}${Platform.pathSeparator}${keyOf(url)}');
        if (await f.exists()) await f.delete();
      }, null);

  Future<void> _enqueuePrune() => _serial<void>(_prune, null);

  /// Toplam boyut tavanını uygular (en eski değişen önce).
  Future<void> _prune() async {
    final files = <(File, DateTime, int)>[];
    var total = 0;
    await for (final e in _dir!.list()) {
      if (e is! File) continue;
      final st = await e.stat();
      files.add((e, st.modified, st.size));
      total += st.size;
    }
    if (total <= maxBytes) return;
    files.sort((a, b) => a.$2.compareTo(b.$2));
    final target = (maxBytes * 0.9).floor(); // bir kerede %10 boşluk açılır, her yazmada budama olmaz
    for (final f in files) {
      if (total <= target) break;
      try {
        await f.$1.delete();
      } catch (_) {}
      total -= f.$3;
    }
  }

  Future<int> totalBytes() => _serial<int>(() async {
        var total = 0;
        await for (final e in _dir!.list()) {
          if (e is File) total += (await e.stat()).size;
        }
        return total;
      }, 0);

  Future<void> clear() => _serial<void>(() async {
        await for (final e in _dir!.list()) {
          if (e is File) await e.delete();
        }
      }, null);

  /// Testler: bekleyen disk işlerinin bitmesini bekler.
  Future<void> settle() => _queue ?? Future<void>.value();
}

/// Önce diske bakan, yoksa ağdan indirip diske yazan ağ görseli. `Image.network` yerine geçer
/// (aynı başlık/hata davranışı). Çözümleme boyutu için `ResizeImage` ile sarın.
@immutable
class DiskNetworkImage extends ImageProvider<DiskNetworkImage> {
  const DiskNetworkImage(this.url, {this.headers, this.scale = 1.0, this.cache});

  final String url;
  final Map<String, String>? headers;
  final double scale;

  /// Testlerde özel önbellek; null ise [ImageDiskCache.instance].
  final ImageDiskCache? cache;

  @override
  Future<DiskNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture<DiskNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(DiskNetworkImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[DiagnosticsProperty<ImageProvider>('Image provider', this)],
    );
  }

  Future<ui.Codec> _load(DiskNetworkImage key, ImageDecoderCallback decode) async {
    final store = key.cache ?? ImageDiskCache.instance;
    Uint8List? bytes = await store.read(key.url);
    var fromNet = false;
    if (bytes == null) {
      bytes = await _download(key);
      fromNet = true;
    }
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // Bozuk dosya diskte kalmasın.
      if (!fromNet) unawaited(store.remove(key.url));
      rethrow;
    }
  }

  Future<Uint8List> _download(DiskNetworkImage key) async {
    HttpClient? client;
    assert(() {
      if (debugNetworkImageHttpClientProvider != null) client = debugNetworkImageHttpClientProvider!();
      return true;
    }());
    client ??= HttpClient()..connectionTimeout = const Duration(seconds: 15);
    final resolved = Uri.base.resolve(key.url);
    final req = await client!.getUrl(resolved);
    key.headers?.forEach(req.headers.add);
    final res = await req.close();
    if (res.statusCode != HttpStatus.ok) {
      await res.drain<void>();
      throw NetworkImageLoadException(statusCode: res.statusCode, uri: resolved);
    }
    final bytes = await consolidateHttpClientResponseBytes(res);
    if (bytes.lengthInBytes == 0) throw Exception('NetworkImage is an empty file: $resolved');
    unawaited((key.cache ?? ImageDiskCache.instance).write(key.url, bytes));
    return bytes;
  }

  @override
  bool operator ==(Object other) =>
      other is DiskNetworkImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => 'DiskNetworkImage("$url", scale: $scale)';
}
