import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Keşfet videolarını kullanıcı bakmadan ÖNCE yerel diske indiren önyükleme hattı.
///
/// Amaç: video ekrana geldiği anda indirmeye başlamasın, oynatıcı dosyadan açılsın (donma yok). Çağıran görünür alanın
/// ilerisindeki videoları yakınlık sırasıyla [plan]'a verir; hat bunları en çok [maxConcurrent] eşzamanlı indirir.
///
/// * Dosya: `<geçici dizin>/video_prefetch/<anahtar>.mp4`; yarım indirme `.part` olarak yazılır, bitince yeniden
///   adlandırılır (oynatıcı yarım dosyayı hiç görmez). Açılışta kalan `.part` dosyaları silinir.
/// * Tek dosya [maxFileBytes]'ı (içerik-uzunluğu ya da akış boyunca) aşarsa atlanır ve bir daha denenmez.
/// * Toplam tavan [maxTotalBytes]: aşılınca en az kullanılan (LRU) silinir; geçerli planın dosyaları korunur.
/// * Ölçülü (mobil) bağlantıda planın yalnız ilk [meteredLimit] videosu indirilir; Wi-Fi'de tamamı.
/// * Uygulama arka plandayken ([setForeground]) yeni indirme başlamaz, süren iptal edilir.
/// * İndirme başarısızsa [retryBackoff] (2 dk) boyunca yeniden denenmez; hata kullanıcıya hiç gösterilmez.
/// * Oturum kapanışında [clear] (yetkili, kullanıcıya özel içerik cihazda kalmasın).
/// * Aynı video iki kez indirilmez (anahtar başına tek iş).
class VideoPrefetcher {
  VideoPrefetcher({
    Future<Directory> Function()? dirProvider,
    VideoFetcher? fetcher,
    Future<bool> Function()? meteredCheck,
    this.maxConcurrent = 2,
    this.maxFileBytes = 50 * 1024 * 1024,
    this.maxTotalBytes = 300 * 1024 * 1024,
    this.meteredLimit = 2,
    this.retryBackoff = const Duration(minutes: 2),
    DateTime Function()? now,
  })  : _dirProvider = dirProvider ?? _defaultDir,
        _fetcher = fetcher ?? _httpFetch,
        _meteredCheck = meteredCheck ?? isMeteredNetwork,
        _now = now ?? DateTime.now,
        enabled = true;

  /// Diske hiç dokunmayan örnek (varsayılan; testler eklentiye dokunmaz).
  VideoPrefetcher.disabled()
      : _dirProvider = (() async => throw const FileSystemException('disabled')),
        _fetcher = _httpFetch,
        _meteredCheck = (() async => false),
        _now = DateTime.now,
        maxConcurrent = 0,
        maxFileBytes = 0,
        maxTotalBytes = 0,
        meteredLimit = 0,
        retryBackoff = Duration.zero,
        enabled = false;

  /// Uygulama genelinde tek örnek; `main` diskli örneği atar (`VideoPrefetcher.instance = VideoPrefetcher()`).
  static VideoPrefetcher instance = VideoPrefetcher.disabled();

  final bool enabled;
  final int maxConcurrent;
  final int maxFileBytes;
  final int maxTotalBytes;
  final int meteredLimit;
  final Duration retryBackoff;

  final Future<Directory> Function() _dirProvider;
  final VideoFetcher _fetcher;
  final Future<bool> Function() _meteredCheck;
  final DateTime Function() _now;

  static Future<Directory> _defaultDir() async {
    final base = await getTemporaryDirectory();
    return Directory('${base.path}${Platform.pathSeparator}video_prefetch');
  }

  /// URL'den dosya anahtarı: `/media/<id>` ise içerik kimliği (`v<id>`), değilse URL'nin SHA-1'i.
  static String keyOf(String url) {
    final m = RegExp(r'/media/(\d+)(?:[/?#]|$)').firstMatch(url);
    if (m != null) return 'v${m.group(1)}';
    return sha1.convert(utf8.encode(url)).toString();
  }

  Directory? _dir;
  Future<void>? _init;
  int _epoch = 0;
  bool _foreground = true;

  List<VideoPrefetchItem> _queue = const [];
  final Map<String, _Job> _active = {};
  final Set<String> _skipped = {};
  final Map<String, DateTime> _failedUntil = {};
  final Map<String, List<Completer<File?>>> _waiters = {};
  Set<String> _protected = {};

  bool? _metered;
  DateTime? _meteredAt;
  final Set<Future<void>> _runs = {};
  Future<void> _pumpChain = Future<void>.value();

  /// Şu an indirilen iş sayısı (test/gözlem).
  int get activeCount => _active.length;

  /// Sırada bekleyen (henüz başlamamış) iş sayısı.
  int get queuedCount => _queue.where((e) => !_active.containsKey(keyOf(e.url))).length;

  Future<void> _ensure() => _init ??= () async {
        final d = await _dirProvider();
        await d.create(recursive: true);
        _dir = d;
        await for (final e in d.list()) {
          if (e is File && e.path.endsWith('.part')) {
            try {
              await e.delete();
            } catch (_) {}
          }
        }
      }();

  File _file(String key) => File('${_dir!.path}${Platform.pathSeparator}$key.mp4');

  /// Tamamlanmış yerel dosya; yoksa null. Kullanım LRU için dosyanın zamanını tazeler.
  Future<File?> localFile(String url) async {
    if (!enabled) return null;
    try {
      await _ensure();
      final f = _file(keyOf(url));
      if (!await f.exists() || await f.length() == 0) return null;
      try {
        await f.setLastModified(_now());
      } catch (_) {}
      return f;
    } catch (_) {
      return null;
    }
  }

  /// Önyükleme planı: yakınlık sırasıyla (ilk eleman en önce). Önceki plan değiştirilir; süren indirmeler bitirilir.
  void plan(List<VideoPrefetchItem> ordered) {
    if (!enabled) return;
    final seen = <String>{};
    _queue = [for (final e in ordered) if (seen.add(keyOf(e.url))) e];
    _protected = seen;
    _kick();
  }

  /// [item] için dosyayı bekler: hazırsa hemen; planda (sırada ya da iniyor) ise en öne alıp [wait] kadar bekler.
  /// Planda OLMAYAN video için (derin bağlantı, arama sonucu...) beklenmez ve indirme başlatılmaz: null döner.
  /// Dosya hazır olmazsa (zaman aşımı, hata, çok büyük, ölçülü bağlantıda planın dışında) null: çağıran ağdan oynatır.
  Future<File?> ensure(VideoPrefetchItem item, {Duration wait = const Duration(seconds: 3)}) async {
    if (!enabled) return null;
    final have = await localFile(item.url);
    if (have != null) return have;
    final key = keyOf(item.url);
    if (_skipped.contains(key)) return null;
    final until = _failedUntil[key];
    if (until != null && _now().isBefore(until)) return null;
    await _refreshMetered();
    final inPlan = _queue.indexWhere((e) => keyOf(e.url) == key);
    final running = _active.containsKey(key);
    if (!running && inPlan < 0) return null;
    // Ölçülü bağlantıda planın izin verdiği dışındaki video için indirme BAŞLATILMAZ (veri tasarrufu).
    if (!running && (_metered ?? false) && (inPlan < 0 || inPlan >= meteredLimit)) return null;
    final c = Completer<File?>();
    (_waiters[key] ??= []).add(c);
    if (!running) {
      _queue = [item, ..._queue.where((e) => keyOf(e.url) != key)];
      _protected = {..._protected, key};
      _kick();
    }
    return c.future.timeout(wait, onTimeout: () => null);
  }

  /// Uygulama ön/arka plan durumu: arka planda yeni indirme başlamaz ve süren iptal edilir.
  void setForeground(bool v) {
    if (_foreground == v) return;
    _foreground = v;
    if (!v) {
      for (final j in _active.values) {
        j.cancelled = true;
      }
    } else {
      _kick();
    }
  }

  /// Dağıtımı sıraya koyar: eşzamanlı iki dağıtım aynı videoyu iki kez başlatamaz.
  void _kick() {
    _pumpChain = _pumpChain.then((_) => _pump()).catchError((Object _) {});
  }

  Future<void> _refreshMetered() async {
    final at = _meteredAt;
    if (at != null && _now().difference(at) < const Duration(seconds: 30)) return;
    try {
      _metered = await _meteredCheck();
    } catch (_) {
      _metered = false;
    }
    _meteredAt = _now();
  }

  Future<void> _pump() async {
    if (!enabled) return;
    await _refreshMetered();
    if (!_foreground) return;
    try {
      await _ensure();
    } catch (_) {
      return;
    }
    final limit = (_metered ?? false) ? meteredLimit : 1 << 30;
    var rank = 0;
    for (final item in List<VideoPrefetchItem>.of(_queue)) {
      if (_active.length >= maxConcurrent) break;
      if (rank++ >= limit) break;
      final key = keyOf(item.url);
      if (_active.containsKey(key) || _skipped.contains(key)) continue;
      final until = _failedUntil[key];
      if (until != null && _now().isBefore(until)) continue;
      if (await _file(key).exists()) continue;
      _start(key, item);
    }
  }

  void _start(String key, VideoPrefetchItem item) {
    final job = _Job(_epoch);
    _active[key] = job;
    late final Future<void> run;
    run = _download(key, item, job).whenComplete(() {
      _active.remove(key);
      _runs.remove(run);
      _kick();
    });
    _runs.add(run);
  }

  Future<void> _download(String key, VideoPrefetchItem item, _Job job) async {
    final part = File('${_dir!.path}${Platform.pathSeparator}$key.part');
    IOSink? sink;
    File? result;
    try {
      final res = await _fetcher(Uri.parse(item.url), item.headers);
      try {
        if (res.statusCode != 200) throw const FileSystemException('http');
        final len = res.contentLength;
        if (len != null && len > maxFileBytes) {
          _skipped.add(key);
          return;
        }
        sink = part.openWrite();
        var count = 0;
        var tooBig = false;
        await for (final chunk in res.body) {
          if (job.cancelled || job.epoch != _epoch) break;
          count += chunk.length;
          if (count > maxFileBytes) {
            tooBig = true;
            break;
          }
          sink.add(chunk);
        }
        await sink.close();
        sink = null;
        if (tooBig) {
          _skipped.add(key);
        } else if (job.cancelled || job.epoch != _epoch) {
          // iptal: yarım dosya aşağıda silinir
        } else if (count == 0 || (len != null && count != len)) {
          throw const FileSystemException('incomplete');
        } else {
          result = await part.rename(_file(key).path);
        }
      } finally {
        await res.close();
      }
    } catch (_) {
      if (job.epoch == _epoch && !job.cancelled) _failedUntil[key] = _now().add(retryBackoff);
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      if (result == null) {
        try {
          if (await part.exists()) await part.delete();
        } catch (_) {}
      }
      final ws = _waiters.remove(key);
      if (ws != null) {
        for (final c in ws) {
          if (!c.isCompleted) c.complete(result);
        }
      }
      if (result != null) await _prune();
    }
  }

  /// Toplam tavanı uygular: en az kullanılan önce silinir; geçerli planın dosyaları ve süren indirmeler korunur.
  Future<void> _prune() async {
    try {
      final files = <(File, DateTime, int)>[];
      var total = 0;
      await for (final e in _dir!.list()) {
        if (e is! File || !e.path.endsWith('.mp4')) continue;
        final st = await e.stat();
        files.add((e, st.modified, st.size));
        total += st.size;
      }
      if (total <= maxTotalBytes) return;
      files.sort((a, b) => a.$2.compareTo(b.$2));
      for (final f in files) {
        if (total <= maxTotalBytes) break;
        final name = f.$1.uri.pathSegments.last;
        final key = name.substring(0, name.length - '.mp4'.length);
        if (_protected.contains(key)) continue;
        try {
          await f.$1.delete();
        } catch (_) {}
        total -= f.$3;
      }
    } catch (_) {}
  }

  /// Toplam önyükleme dosyası boyutu (test/gözlem).
  Future<int> totalBytes() async {
    if (!enabled) return 0;
    try {
      await _ensure();
      var total = 0;
      await for (final e in _dir!.list()) {
        if (e is File) total += (await e.stat()).size;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Oturum kapanışı: süren indirmeleri iptal eder, sırayı boşaltır, dosyaları siler.
  Future<void> clear() async {
    if (!enabled) return;
    _epoch++;
    for (final j in _active.values) {
      j.cancelled = true;
    }
    _queue = const [];
    _protected = {};
    _skipped.clear();
    _failedUntil.clear();
    try {
      await Future.wait(List<Future<void>>.of(_runs));
    } catch (_) {}
    for (final ws in _waiters.values) {
      for (final c in ws) {
        if (!c.isCompleted) c.complete(null);
      }
    }
    _waiters.clear();
    try {
      await _ensure();
      await for (final e in _dir!.list()) {
        if (e is File) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Testler: süren indirmelerin bitmesini bekler.
  Future<void> settle() async {
    for (var i = 0; i < 40; i++) {
      final chain = _pumpChain;
      await chain;
      if (_runs.isNotEmpty) await Future.wait(List<Future<void>>.of(_runs));
      await Future<void>.delayed(Duration.zero);
      if (_active.isEmpty && _runs.isEmpty && identical(chain, _pumpChain)) break;
    }
  }
}

class _Job {
  _Job(this.epoch);

  final int epoch;
  bool cancelled = false;
}

/// Önyüklenecek video: adres + yetkili başlıklar.
@immutable
class VideoPrefetchItem {
  const VideoPrefetchItem(this.url, this.headers);

  final String url;
  final Map<String, String> headers;
}

/// İndirme yanıtı (testlerde sahte).
class VideoFetchResponse {
  VideoFetchResponse({required this.statusCode, required this.body, this.contentLength, Future<void> Function()? onClose})
      : _onClose = onClose;

  final int statusCode;
  final int? contentLength;
  final Stream<List<int>> body;
  final Future<void> Function()? _onClose;

  Future<void> close() async => _onClose?.call();
}

typedef VideoFetcher = Future<VideoFetchResponse> Function(Uri uri, Map<String, String> headers);

Future<VideoFetchResponse> _httpFetch(Uri uri, Map<String, String> headers) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 5);
  try {
    final req = await client.getUrl(uri);
    headers.forEach(req.headers.add);
    final res = await req.close();
    final len = res.contentLength;
    return VideoFetchResponse(
      statusCode: res.statusCode,
      contentLength: len >= 0 ? len : null,
      body: res,
      onClose: () async => client.close(force: true),
    );
  } catch (_) {
    client.close(force: true);
    rethrow;
  }
}

/// Ölçülü (mobil veri) bağlantı mı? Ek paket yok: etkin ağ arayüzlerinin adlarına bakılır. Wi-Fi/Ethernet arayüzü
/// (Android `wlan*`/`eth*`, iOS `en*`) varsa ölçülü DEĞİL; yalnızca hücresel arayüz (`rmnet*`, `ccmni*`, `pdp_ip*`,
/// `v4-rmnet*`) varsa ölçülü. Belirlenemezse ölçülü sayılmaz.
Future<bool> isMeteredNetwork() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return false;
  try {
    final ifs = await NetworkInterface.list(includeLoopback: false, includeLinkLocal: false);
    var wifi = false;
    var cell = false;
    for (final i in ifs) {
      final n = i.name.toLowerCase();
      if (n.startsWith('wlan') || n.startsWith('eth') || (Platform.isIOS && n.startsWith('en'))) wifi = true;
      if (n.contains('rmnet') || n.startsWith('ccmni') || n.startsWith('pdp_ip')) cell = true;
    }
    return cell && !wifi;
  } catch (_) {
    return false;
  }
}

/// Uygulama ön/arka plana geçince önyükleme hattını durdurur/sürdürür (arka planda indirme yok).
class VideoPrefetchLifecycle with WidgetsBindingObserver {
  VideoPrefetchLifecycle._();

  static final VideoPrefetchLifecycle instance = VideoPrefetchLifecycle._();
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    VideoPrefetcher.instance.setForeground(state == AppLifecycleState.resumed);
  }
}
