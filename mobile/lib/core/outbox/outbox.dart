import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api.dart';
import '../closed_conversations.dart';
import '../connectivity/connectivity_service.dart';
import '../secure_store.dart';

enum OutboxStatus { pending, failed }

/// Kuyruktaki mesajın yerel diske kopyalanmış tek eki (fotoğraf/video). Dosyalar `outbox_media/` altındadır;
/// yükleme yalnız bağlantı varken yapılır, `attId` yüklenince tutulur (mesaj gönderimi düşerse yeniden yüklenmez).
class OutboxMedia {
  OutboxMedia({
    required this.kind,
    required this.file,
    required this.mime,
    this.poster,
    this.width,
    this.height,
    this.durationMs,
    this.size = 0,
    this.attId,
  });

  /// `image` | `video`
  final String kind;
  final String file;
  final String mime;

  /// Video önizleme karesi dosya adı (yoksa null).
  final String? poster;
  final int? width;
  final int? height;
  final int? durationMs;
  final int size;
  int? attId;

  bool get isVideo => kind == 'video';

  Map<String, dynamic> toJson() => {
        'k': kind,
        'f': file,
        'm': mime,
        if (poster != null) 'p': poster,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
        if (durationMs != null) 'd': durationMs,
        's': size,
        if (attId != null) 'i': attId,
      };

  static OutboxMedia? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = j['k'], f = j['f'], m = j['m'];
    if (k is! String || f is! String || m is! String) return null;
    return OutboxMedia(
      kind: k,
      file: f,
      mime: m,
      poster: j['p'] is String ? j['p'] as String : null,
      width: j['w'] is int ? j['w'] as int : null,
      height: j['h'] is int ? j['h'] as int : null,
      durationMs: j['d'] is int ? j['d'] as int : null,
      size: j['s'] is int ? j['s'] as int : 0,
      attId: j['i'] is int ? j['i'] as int : null,
    );
  }
}

/// Kuyruğa alınacak ekin ham kaynağı (bellek baytı ya da var olan dosya yolu). Kuyruk bunu kendi dizinine kopyalar.
class OutboxMediaSource {
  OutboxMediaSource({
    required this.kind,
    required this.mime,
    this.bytes,
    this.path,
    this.poster,
    this.width,
    this.height,
    this.durationMs,
  }) : assert(bytes != null || path != null);

  final String kind;
  final String mime;
  final Uint8List? bytes;
  final String? path;
  final Uint8List? poster;
  final int? width;
  final int? height;
  final int? durationMs;
}

/// Kuyruktaki tek sohbet mesajı (metin ve/veya ekler). Sunucu `(konuşma, gönderen, clientId)` tekrarını yeni mesaj saymaz,
/// bu yüzden aynı öğeyi yeniden göndermek çift mesaj üretmez.
class OutboxItem {
  OutboxItem({
    required this.clientId,
    required this.conversationId,
    required this.text,
    required this.createdAt,
    this.replyToMessageId,
    this.status = OutboxStatus.pending,
    this.attempts = 0,
    this.serverFails = 0,
    this.nextAttemptAt = 0,
    this.errorCode,
    this.media = const [],
    this.viewOnce = false,
  });

  final String clientId;
  final int conversationId;
  final String text;
  final int createdAt; // epoch ms
  final int? replyToMessageId;

  /// Yerel diskteki ekler (boşsa salt metin mesajı).
  final List<OutboxMedia> media;
  final bool viewOnce;
  OutboxStatus status;

  /// Tüm başarısız denemeler (geri çekilmeyi belirler).
  int attempts;

  /// Yalnız sunucu 5xx hataları: [Outbox.maxServerFails]'te kalıcı hata sayılır (ağ yokluğu sayılmaz).
  int serverFails;
  int nextAttemptAt; // epoch ms
  String? errorCode;

  Map<String, dynamic> toJson() => {
        'c': clientId,
        'v': conversationId,
        't': text,
        'a': createdAt,
        if (replyToMessageId != null) 'r': replyToMessageId,
        's': status.index,
        'n': attempts,
        'f': serverFails,
        'x': nextAttemptAt,
        if (errorCode != null) 'e': errorCode,
        if (media.isNotEmpty) 'md': [for (final m in media) m.toJson()],
        if (viewOnce) 'o': true,
      };

  static OutboxItem? fromJson(Object? j) {
    if (j is! Map) return null;
    final c = j['c'], v = j['v'], t = j['t'], a = j['a'];
    if (c is! String || v is! int || t is! String || a is! int) return null;
    final s = j['s'];
    final md = j['md'];
    return OutboxItem(
      clientId: c,
      conversationId: v,
      text: t,
      createdAt: a,
      replyToMessageId: j['r'] is int ? j['r'] as int : null,
      status: s is int && s >= 0 && s < OutboxStatus.values.length ? OutboxStatus.values[s] : OutboxStatus.pending,
      attempts: j['n'] is int ? j['n'] as int : 0,
      serverFails: j['f'] is int ? j['f'] as int : 0,
      nextAttemptAt: j['x'] is int ? j['x'] as int : 0,
      errorCode: j['e'] is String ? j['e'] as String : null,
      media: [
        if (md is List)
          for (final e in md)
            if (OutboxMedia.fromJson(e) != null) OutboxMedia.fromJson(e)!,
      ],
      viewOnce: j['o'] == true,
    );
  }
}

/// Başarıyla iletilen mesaj (ekranlar `clientId` ile balonu eşleyebilir).
class OutboxDelivery {
  OutboxDelivery(this.item, this.response);
  final OutboxItem item;
  final Object? response;
}

/// Kalıcı depo soyutlaması (testlerde bellek içi).
abstract class OutboxStore {
  Future<String?> read();
  Future<void> write(String? value);
}

/// Bozuk (ayrıştırılamayan) ham kuyruk verisini ayrı bir yere taşıyabilen depolar. [Outbox.load] bozuk JSON
/// bulursa ham değeri buraya yazar (silmez), geçerli kayıtları tek tek kurtarır. Mevcut [OutboxStore]
/// uygulamalarını bozmamak için ayrı arayüzdür.
abstract interface class CorruptBackupStore {
  Future<void> writeCorrupt(String raw);
  Future<void> clearCorrupt();
}

class MemoryOutboxStore implements OutboxStore, CorruptBackupStore {
  String? value;

  /// Son bozuk ham değer (yedek).
  String? corrupt;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
  @override
  Future<void> writeCorrupt(String raw) async => corrupt = raw;
  @override
  Future<void> clearCorrupt() async => corrupt = null;
}

/// Platformun şifreli deposu (iOS Keychain / Android Keystore): bekleyen mesaj metni düz dosyada durmaz.
/// iOS'ta kayıtlar bu cihaza özeldir ve ilk kilit açılışından sonra okunur (yedekle başka cihaza taşınmaz).
class SecureOutboxStore implements OutboxStore, CorruptBackupStore {
  const SecureOutboxStore();
  static const key = 'outbox_v1';

  /// Bozuk ham kuyruk verisinin yedeği.
  static const corruptKey = 'outbox_v1_corrupt';
  static const _s = kDeviceSecureStorage;

  @override
  Future<String?> read() => _s.read(key: key);

  @override
  Future<void> write(String? value) async {
    if (value == null) {
      await _s.delete(key: key);
    } else {
      await _s.write(key: key, value: value);
    }
  }

  @override
  Future<void> writeCorrupt(String raw) => _s.write(key: corruptKey, value: raw);

  @override
  Future<void> clearCorrupt() => _s.delete(key: corruptKey);
}

typedef OutboxSender = Future<Object?> Function(OutboxItem item);

/// Bir eki yükler; `file` yerel dosya, `poster` (video) önizleme dosyası. Ek kimliğini döner.
typedef OutboxMediaUploader = Future<int> Function(OutboxItem item, OutboxMedia media, File file, File? poster);

/// Sessiz çevrimdışı gönderme kuyruğu: metin (yanıt dahil) ve fotoğraf/video mesajları.
///
/// Kullanıcıya hiçbir "bekliyor/kuyrukta" bilgisi verilmez: mesaj normal "gönderiliyor" görünür, bağlantı gelince
/// (bağlantı dinleyicisi, STOMP yeniden bağlanma, uygulama öne gelme) kendiliğinden gider ve tik olur. Yalnız KALICI
/// başarısızlıkta ([OutboxStatus.failed]: 4xx, [maxServerFails] sunucu hatası, [maxAge] aşımı) balonda "Gönderilemedi".
///
/// - Kalıcı (uygulama kapansa da kalır), en çok [maxItems] öğe; [maxAge]'den eski bekleyenler `failed` olur,
///   [dropAfter]'dan eskiler silinir. Ekler `outbox_media/` altında diskte, toplam [maxMediaBytes] ile sınırlıdır.
/// - Gönderim sırası korunur; ağ hatasında kuyruğun başında durur (sıra bozulmaz), üstel geri çekilmeyle tekrar dener.
/// - 4xx (doğrulama vb.) kalıcı hata: öğe `failed` olur, elle [retry]/[remove] beklenir.
/// - Periyodik yoklama yok: yalnızca "bir sonraki deneme" zamanlayıcısı ve bağlantı geri geldiğinde tetikleme.
class Outbox extends ChangeNotifier {
  Outbox({
    OutboxStore? store,
    this.maxItems = 100,
    this.maxAge = const Duration(hours: 24),
    this.dropAfter = const Duration(days: 7),
    this.maxServerFails = 5,
    this.serverFailWindow = const Duration(minutes: 30),
    this.maxTextLength = 2000,
    this.maxMediaBytes = 200 * 1024 * 1024,
    Future<Directory> Function()? mediaDirProvider,
    DateTime Function()? now,
    this.autoSchedule = true,
    OutboxSender? sender,
  })  : _store = store ?? const SecureOutboxStore(),
        _now = now ?? DateTime.now,
        _mediaDirProvider = mediaDirProvider ?? _defaultMediaDir,
        _sender = sender;

  static Future<Directory> _defaultMediaDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}outbox_media');
  }

  static final RegExp _messagesPath = RegExp(r'^/conversations/(\d+)/messages$');

  final OutboxStore _store;
  final DateTime Function() _now;
  final int maxItems;
  final Duration maxAge;
  final Duration dropAfter;
  final int maxMediaBytes;
  final Future<Directory> Function() _mediaDirProvider;
  final int maxServerFails;

  /// Ardışık 5xx hataları öğeyi yalnız mesaj bu süreden (oluşturulmadan itibaren) eskiyse kalıcı hataya çevirir:
  /// kısa bir deploy / yeniden başlatma kesintisi bekleyen mesajları "Gönderilemedi" yapmasın.
  final Duration serverFailWindow;
  final int maxTextLength;
  final bool autoSchedule;
  OutboxSender? _sender;

  /// Ek yükleyici (main bağlar): dosyayı `POST /conversations/{id}/media` ile yükler, ek kimliğini döner.
  /// null ise ekli öğeler gönderilmez (bekler).
  OutboxMediaUploader? uploader;

  final List<OutboxItem> _items = [];
  final _deliveries = StreamController<OutboxDelivery>.broadcast();
  Timer? _timer;
  bool _draining = false;
  bool _loaded = false;

  /// Depo okuması başarısız oldu (yazma, okunamayan eski kuyruğun üstüne yazılmasın diye askıda).
  bool _readFailed = false;
  Future<void>? _loading;
  Timer? _loadRetry;
  int _loadFails = 0;

  /// Kuşak: [clear] her çağrıda artar; süren [drain] bu sayede eski oturumun kalan mesajlarını göndermez.
  int _epoch = 0;
  Future<void>? _saveTail;
  ConnectivityService? _connectivity;

  /// Geri çekilme: 2 sn, 5 sn, 15 sn, 1 dk, sonra 5 dk.
  static Duration backoff(int attempts) {
    const steps = [2, 5, 15, 60, 300];
    return Duration(seconds: steps[(attempts - 1).clamp(0, steps.length - 1)]);
  }

  Stream<OutboxDelivery> get deliveries => _deliveries.stream;
  List<OutboxItem> get items => List.unmodifiable(_items);
  int get pendingCount => _items.where((e) => e.status == OutboxStatus.pending).length;
  int get failedCount => _items.where((e) => e.status == OutboxStatus.failed).length;
  bool contains(String clientId) => _items.any((e) => e.clientId == clientId);

  OutboxItem? byClientId(String clientId) {
    for (final e in _items) {
      if (e.clientId == clientId) return e;
    }
    return null;
  }

  /// ApiClient'a bağlar: gönderim `POST /conversations/{id}/messages`, bağlantı gelince tetiklenir.
  void attach(ApiClient api, ConnectivityService connectivity) {
    _connectivity?.reconnects.removeListener(_onReconnect);
    _connectivity = connectivity;
    connectivity.reconnects.addListener(_onReconnect);
    _sender ??= (i) => api.post('/conversations/${i.conversationId}/messages', {
          'text': i.text,
          'clientId': i.clientId,
          if (i.replyToMessageId != null) 'replyToMessageId': i.replyToMessageId,
          if (i.media.isNotEmpty) 'attachmentIds': [for (final m in i.media) m.attId],
          if (i.media.isNotEmpty && i.viewOnce) 'viewOnce': true,
        });
  }

  /// Uygulama öne geldi / STOMP yeniden bağlandı: geri çekilmeyi atlayıp hemen dener (olay tabanlı; yoklama yok).
  Future<void> nudge() {
    for (final e in _items) {
      if (e.status == OutboxStatus.pending) e.nextAttemptAt = 0;
    }
    if (!_loaded && _readFailed) unawaited(load()); // depo daha önce okunamadı: bu fırsatta yeniden dene
    return drain();
  }

  void _onReconnect() {
    for (final e in _items) {
      if (e.status == OutboxStatus.pending) e.nextAttemptAt = 0;
    }
    if (!_loaded && _readFailed) unawaited(load());
    unawaited(drain());
  }

  /// Diskten yükler (açılışta bir kez); eski öğeleri atar.
  ///
  /// - Depo OKUNAMAZSA (Keystore/Keychain geçici hatası) hiçbir şey silinmez ve yazılmaz: `_loaded` false kalır,
  ///   yükleme sonra yeniden denenir ([nudge], bağlantı dönüşü, zamanlayıcı).
  /// - JSON BOZUKSA ham değer yedek anahtara taşınır ([CorruptBackupStore]) ve tam kayıtlar tek tek kurtarılır.
  /// - Artık medya dosyaları yalnızca başarılı ve bozulmamış bir yüklemeden sonra süpürülür.
  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _doLoad().whenComplete(() => _loading = null);
  }

  Future<void> _doLoad() async {
    final epoch = _epoch;
    String? raw;
    try {
      raw = await _store.read();
    } catch (_) {
      _readFailed = true;
      _scheduleLoadRetry();
      return;
    }
    if (epoch != _epoch) return; // yükleme sürerken oturum kapandı (clear): eski kuyruk geri gelmesin
    var corrupt = false;
    if (raw != null && raw.isNotEmpty) {
      List<dynamic> records = const [];
      try {
        final j = jsonDecode(raw);
        if (j is List) {
          records = j;
        } else {
          corrupt = true;
        }
      } catch (_) {
        corrupt = true;
        records = salvageRecords(raw);
      }
      if (corrupt) {
        final s = _store;
        if (s is CorruptBackupStore) {
          try {
            await (s as CorruptBackupStore).writeCorrupt(raw);
          } catch (_) {}
        }
      }
      for (final e in records) {
        final it = OutboxItem.fromJson(e);
        if (it != null && !contains(it.clientId)) _items.add(it);
      }
    }
    _loaded = true;
    _readFailed = false;
    _loadFails = 0;
    _loadRetry?.cancel();
    _items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _prune();
    await _saveNow();
    if (!corrupt) unawaited(_sweepOrphanFiles());
    notifyListeners();
    unawaited(drain());
  }

  void _scheduleLoadRetry() {
    if (!autoSchedule) return;
    _loadRetry?.cancel();
    _loadFails++;
    const steps = [5, 30, 120, 600];
    final sec = steps[(_loadFails - 1).clamp(0, steps.length - 1)];
    _loadRetry = Timer(Duration(seconds: sec), () => unawaited(load()));
  }

  /// Kesik/bozuk bir JSON dizisinden TAM üst düzey nesneleri tek tek kurtarır (ayrıştırılabilenler döner).
  @visibleForTesting
  static List<dynamic> salvageRecords(String raw) {
    final out = <dynamic>[];
    var depth = 0;
    var inStr = false;
    var esc = false;
    var start = -1;
    for (var i = 0; i < raw.length; i++) {
      final ch = raw.codeUnitAt(i);
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (ch == 0x5C) {
          esc = true;
        } else if (ch == 0x22) {
          inStr = false;
        }
        continue;
      }
      if (ch == 0x22) {
        inStr = true;
      } else if (ch == 0x7B) {
        if (depth == 0) start = i;
        depth++;
      } else if (ch == 0x7D && depth > 0) {
        depth--;
        if (depth == 0 && start >= 0) {
          try {
            out.add(jsonDecode(raw.substring(start, i + 1)));
          } catch (_) {}
          start = -1;
        }
      }
    }
    return out;
  }

  void _prune() {
    final now = _now().millisecondsSinceEpoch;
    final drop = now - dropAfter.inMilliseconds;
    final expire = now - maxAge.inMilliseconds;
    final gone = _items.where((e) => e.createdAt < drop).toList();
    for (final e in gone) {
      _items.remove(e);
      _deleteFiles(e);
    }
    // 24 saati geçen bekleyen mesaj artık gönderilmez: kalıcı hata (kullanıcı "Gönderilemedi" görür).
    for (final e in _items) {
      if (e.status == OutboxStatus.pending && e.createdAt < expire) {
        e.status = OutboxStatus.failed;
        e.errorCode = 'EXPIRED';
      }
    }
    while (_items.length > maxItems) {
      // Önce kalıcı hatalı en eskiyi, yoksa en eski bekleyeni at.
      final i = _items.indexWhere((e) => e.status == OutboxStatus.failed);
      final removed = _items.removeAt(i >= 0 ? i : 0);
      _deleteFiles(removed);
    }
  }

  // ---------- Ek dosyaları ----------

  Directory? _mediaDir;

  Future<Directory> _ensureMediaDir() async {
    final d = _mediaDir ??= await _mediaDirProvider();
    await d.create(recursive: true);
    return d;
  }

  File _mediaFile(Directory d, String name) => File('${d.path}${Platform.pathSeparator}$name');

  void _deleteFiles(OutboxItem it) {
    if (it.media.isEmpty) return;
    unawaited(() async {
      try {
        final d = await _ensureMediaDir();
        for (final m in it.media) {
          for (final n in [m.file, if (m.poster != null) m.poster!]) {
            final f = _mediaFile(d, n);
            if (await f.exists()) await f.delete();
          }
        }
      } catch (_) {}
    }());
  }

  /// Kuyrukta olmayan artık dosyaları siler (çökme sonrası).
  Future<void> _sweepOrphanFiles() async {
    try {
      final d = await _ensureMediaDir();
      final known = <String>{
        for (final it in _items)
          for (final m in it.media) ...[m.file, if (m.poster != null) m.poster!],
      };
      await for (final e in d.list()) {
        if (e is! File) continue;
        if (!known.contains(e.uri.pathSegments.last)) await e.delete();
      }
    } catch (_) {}
  }

  /// Kuyruktaki ek dosyalarının toplam boyutu.
  int get mediaBytes => _items.fold<int>(0, (a, e) => a + e.media.fold<int>(0, (b, m) => b + m.size));

  /// Öğenin ek dosyası (önizleme/geri yükleme için); yoksa null.
  Future<File?> mediaFileOf(OutboxMedia m, {bool poster = false}) async {
    final name = poster ? m.poster : m.file;
    if (name == null) return null;
    try {
      final f = _mediaFile(await _ensureMediaDir(), name);
      return await f.exists() ? f : null;
    } catch (_) {
      return null;
    }
  }

  /// Fotoğraf/video mesajını kuyruğa alır: ekler uygulama diskine kopyalanır (galeri/önbellek dosyası silinse de
  /// kalır). Disk tavanı ([maxMediaBytes]) aşılırsa ya da kopyalama başarısızsa false (mesaj "Gönderilemedi" olur).
  Future<bool> enqueueMedia({
    required int conversationId,
    required String clientId,
    required String text,
    required List<OutboxMediaSource> sources,
    int? replyToMessageId,
    bool viewOnce = false,
  }) async {
    if (sources.isEmpty || contains(clientId) || text.length > maxTextLength) return false;
    final written = <OutboxMedia>[];
    try {
      final d = await _ensureMediaDir();
      var add = 0;
      for (var i = 0; i < sources.length; i++) {
        final s = sources[i];
        final ext = s.kind == 'video' ? 'mp4' : (s.mime == 'image/png' ? 'png' : (s.mime == 'image/webp' ? 'webp' : 'jpg'));
        final name = '${clientId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_$i.$ext';
        final f = _mediaFile(d, name);
        if (s.bytes != null) {
          await f.writeAsBytes(s.bytes!, flush: true);
        } else {
          await File(s.path!).copy(f.path);
        }
        final size = await f.length();
        add += size;
        String? posterName;
        if (s.poster != null && s.poster!.isNotEmpty) {
          posterName = '${name}_p.jpg';
          await _mediaFile(d, posterName).writeAsBytes(s.poster!, flush: true);
        }
        written.add(OutboxMedia(
          kind: s.kind,
          file: name,
          mime: s.mime,
          poster: posterName,
          width: s.width,
          height: s.height,
          durationMs: s.durationMs,
          size: size,
        ));
      }
      if (mediaBytes + add > maxMediaBytes) throw const FileSystemException('quota');
    } catch (_) {
      _deleteFiles(OutboxItem(clientId: clientId, conversationId: conversationId, text: '', createdAt: 0, media: written));
      return false;
    }
    final now = _now().millisecondsSinceEpoch;
    _items.add(OutboxItem(
      clientId: clientId,
      conversationId: conversationId,
      text: text,
      createdAt: now,
      replyToMessageId: replyToMessageId,
      media: written,
      viewOnce: viewOnce,
      nextAttemptAt: now + backoff(1).inMilliseconds,
    ));
    _prune();
    unawaited(_save());
    notifyListeners();
    _scheduleNext();
    return true;
  }

  /// Yazmalar tek sıraya dizilir ve her yazma çalıştığı anki EN GÜNCEL listeyi yazar: eski bir anlık görüntü
  /// sonradan bitip yenisinin üstüne yazamaz. Yükleme sürüyorsa onu bekler (okunmamış kuyruğun üstüne yazılmasın).
  Future<void> _save() async {
    final l = _loading;
    if (l != null) await l;
    return _saveNowQueued();
  }

  Future<void> _saveNowQueued() {
    final prev = _saveTail;
    late Future<void> f;
    // Boştaysa yazma HEMEN (aynı senkron adımda) başlar; doluysa sıraya girer.
    f = (prev == null ? _saveNow() : prev.then((_) => _saveNow())).whenComplete(() {
      if (identical(_saveTail, f)) _saveTail = null;
    });
    return _saveTail = f;
  }

  Future<void> _saveNow() async {
    if (_readFailed) return; // okunamayan eski kuyruğun üstüne yazma
    try {
      await _store.write(_items.isEmpty ? null : jsonEncode([for (final e in _items) e.toJson()]));
    } catch (_) {}
  }

  /// ApiClient'ın ağ hatasında çağırdığı kanca: yalnız metin mesajı POST'u kuyruğa alınır.
  /// Öğe alındıysa true.
  bool captureRequest(String path, Object? body) {
    final m = _messagesPath.firstMatch(path);
    if (m == null || body is! Map) return false;
    final text = body['text'], cid = body['clientId'];
    if (text is! String || text.trim().isEmpty || cid is! String || cid.isEmpty || cid.length > 64) return false;
    final att = body['attachmentIds'];
    if ((att is List && att.isNotEmpty) || body['viewOnce'] == true) return false; // medya: kuyruğa alınmaz
    final reply = body['replyToMessageId'];
    return enqueue(
      conversationId: int.parse(m.group(1)!),
      clientId: cid,
      text: text,
      replyToMessageId: reply is int ? reply : null,
    );
  }

  bool enqueue({required int conversationId, required String clientId, required String text, int? replyToMessageId}) {
    if (text.length > maxTextLength || contains(clientId)) return false;
    _items.add(OutboxItem(
      clientId: clientId,
      conversationId: conversationId,
      text: text,
      createdAt: _now().millisecondsSinceEpoch,
      replyToMessageId: replyToMessageId,
      nextAttemptAt: _now().millisecondsSinceEpoch + backoff(1).inMilliseconds,
    ));
    _prune();
    unawaited(_save());
    notifyListeners();
    _scheduleNext();
    return true;
  }

  /// Kalıcı hatalı öğeyi yeniden denemeye alır.
  Future<void> retry(String clientId) async {
    final it = byClientId(clientId);
    if (it == null) return;
    it.status = OutboxStatus.pending;
    it.serverFails = 0;
    it.errorCode = null;
    it.nextAttemptAt = 0;
    await _save();
    notifyListeners();
    await drain();
  }

  Future<void> remove(String clientId) async {
    final it = byClientId(clientId);
    if (it != null) _deleteFiles(it);
    _items.removeWhere((e) => e.clientId == clientId);
    await _save();
    notifyListeners();
  }

  /// Oturum kapanışı/hesap silme: bütün bekleyen mesajlar silinir.
  Future<void> clear() async {
    _timer?.cancel();
    _loadRetry?.cancel();
    _epoch++; // süren drain / yükleme eski oturumun mesajlarını artık göndermez / geri getirmez
    final old = List.of(_items);
    _items.clear();
    for (final e in old) {
      _deleteFiles(e);
    }
    // Yetkili silme: okunamamış olsa bile depo boşaltılır; bozuk-ham yedek de silinir.
    _loaded = true;
    _readFailed = false;
    _loading = null;
    await _saveNowQueued();
    final s = _store;
    if (s is CorruptBackupStore) {
      try {
        await (s as CorruptBackupStore).clearCorrupt();
      } catch (_) {}
    }
    notifyListeners();
    unawaited(_sweepOrphanFiles());
  }

  /// Bekleyenleri sırayla göndermeyi dener (eşzamanlı çağrılar tek çalışmaya birleşir).
  Future<void> drain() async {
    final send = _sender;
    if (send == null || _draining) return;
    _draining = true;
    final epoch = _epoch;
    try {
      final failedBefore = failedCount;
      _prune(); // 24 saati geçenler kalıcı hata olur
      if (failedCount != failedBefore) {
        await _save();
        notifyListeners();
      }
      final blocked = <int>{}; // sırası bozulmasın: sorunlu konuşmanın sonraki mesajları beklesin
      for (final it in List.of(_items)) {
        if (epoch != _epoch) break; // oturum kapandı (clear): eski hesabın kalan mesajları gönderilmez
        if (!_items.any((x) => x.clientId == it.clientId)) continue; // iptal edildi / silindi
        if (it.status != OutboxStatus.pending || blocked.contains(it.conversationId)) continue;
        if (it.nextAttemptAt > _now().millisecondsSinceEpoch) {
          blocked.add(it.conversationId);
          continue;
        }
        try {
          final res = await _deliver(it, send);
          _items.removeWhere((e) => e.clientId == it.clientId);
          _deleteFiles(it);
          _deliveries.add(OutboxDelivery(it, res));
          await _save();
          notifyListeners();
        } on ApiError catch (e) {
          if (!_items.any((x) => x.clientId == it.clientId)) continue; // iptal/oturum kapandı
          final stop = _onError(it, e);
          await _save();
          notifyListeners();
          if (stop) break; // ağ yok: geri kalanı denemenin anlamı yok
          blocked.add(it.conversationId);
        } catch (_) {
          it.attempts++;
          it.nextAttemptAt = _now().millisecondsSinceEpoch + backoff(it.attempts).inMilliseconds;
          blocked.add(it.conversationId);
        }
      }
    } finally {
      _draining = false;
      _scheduleNext();
    }
  }

  /// Ekleri (varsa) yükler, sonra mesajı gönderir. Yükleme kimliği kalıcı yazılır: gönderim düşerse yeniden yüklenmez.
  Future<Object?> _deliver(OutboxItem it, OutboxSender send) async {
    for (final m in it.media) {
      if (m.attId != null) continue;
      final up = uploader;
      final d = await _ensureMediaDir();
      final f = _mediaFile(d, m.file);
      if (up == null || !await f.exists()) {
        throw ApiError(400, 'MEDIA_LOST', ''); // dosya yok: kalıcı hata
      }
      final p = m.poster == null ? null : _mediaFile(d, m.poster!);
      m.attId = await up(it, m, f, p != null && await p.exists() ? p : null);
      await _save();
    }
    try {
      return await send(it);
    } on ApiError catch (e) {
      // Sunucu yüklenmiş eki artık tanımıyor (yetim temizliği): bir sonraki denemede yeniden yüklenir.
      if ((e.status == 400 || e.status == 404 || e.status == 410) && e.code.startsWith('ATTACHMENT')) {
        for (final m in it.media) {
          m.attId = null;
        }
        throw ApiError(0, 'NETWORK', '');
      }
      rethrow;
    }
  }

  /// true: ağ sorunu (drain'i durdur).
  bool _onError(OutboxItem it, ApiError e) {
    final now = _now().millisecondsSinceEpoch;
    it.attempts++;
    if (e.isNetwork) {
      it.nextAttemptAt = now + backoff(it.attempts).inMilliseconds;
      return true;
    }
    // Engel bilgisi sızdırılmaz (sohbet ekranındaki davranışla aynı): sessizce kuyruktan çıkar.
    if (e.code == 'BLOCKED' || e.code == 'USER_BLOCKED') {
      _items.removeWhere((x) => x.clientId == it.clientId);
      return false;
    }
    if (e.status == 429 || e.status == 408 || e.status == 401) {
      final wait = e.retryAfter != null ? Duration(seconds: e.retryAfter!) : backoff(it.attempts);
      it.nextAttemptAt = now + wait.inMilliseconds;
      return e.status == 401; // 401: oturum yenilenemedi; oturum kapanışı kuyruğu zaten temizler
    }
    // Ağ geçidi / bakım yanıtları (502, 503, 504 ya da Retry-After'lı 5xx): sunucu o an ulaşılamaz demektir
    // (deploy, yeniden başlatma). Ağ yokluğu gibi ele alınır: mesaj "Gönderilemedi"ye düşmez, kuyruk durur.
    if (e.status == 502 || e.status == 503 || e.status == 504 || (e.status >= 500 && e.retryAfter != null)) {
      final wait = e.retryAfter != null ? Duration(seconds: e.retryAfter!) : Duration.zero;
      final step = backoff(it.attempts);
      it.nextAttemptAt = now + (wait > step ? wait : step).inMilliseconds;
      return true;
    }
    if (e.status >= 500) {
      // Gerçek sunucu hatası (500...): beş ardışık hata VE mesaj yeterince eskiyse (varsayılan 30 dk) kalıcı hata.
      it.serverFails++;
      final old = now - it.createdAt >= serverFailWindow.inMilliseconds;
      if (it.serverFails >= maxServerFails && old) {
        it.status = OutboxStatus.failed;
        it.errorCode = e.code;
      } else {
        it.nextAttemptAt = now + backoff(it.attempts).inMilliseconds;
      }
      return false;
    }
    // Diğer 4xx: kalıcı hata (içerik/izin); kullanıcı elle yeniden dener ya da siler.
    // 409 CONVERSATION_CLOSED (P08): yönetici sohbeti kapattı; ekranlar yazma alanını kapatır.
    if (e.code == 'CONVERSATION_CLOSED') ClosedConversations.instance.markClosed(it.conversationId);
    it.status = OutboxStatus.failed;
    it.errorCode = e.code;
    return false;
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!autoSchedule || _sender == null) return;
    int? next;
    for (final e in _items) {
      if (e.status != OutboxStatus.pending) continue;
      if (next == null || e.nextAttemptAt < next) next = e.nextAttemptAt;
    }
    if (next == null) return;
    final ms = next - _now().millisecondsSinceEpoch;
    _timer = Timer(Duration(milliseconds: ms < 1000 ? 1000 : ms), () => unawaited(drain()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivity?.reconnects.removeListener(_onReconnect);
    _deliveries.close();
    super.dispose();
  }
}
