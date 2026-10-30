import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Sohbet mesajlarının cihazdaki küçük yerel kaydı (çevrimdışı okuma için).
///
/// - Her sohbet için yalnız en yeni [perConversation] mesaj (varsayılan 20) ve sohbet listesinin ilk
///   [maxListItems] satırı (50) saklanır; daha eskisi için ağ gerekir.
/// - Sohbet başına ayrı küçük dosya (`c<id>.json`): bir mesaj gelince tüm depo yeniden yazılmaz. Yazma
///   [flushDelay] kadar geciktirilir ve toplu yapılır; uygulama arka plana giderken [flush] çağrılır.
/// - Tek gösterimlik ekin URL'si/içeriği ASLA yazılmaz (yalnız yer tutucu alanlar); silinen/yönetici kaldırması
///   mesajların içeriği yazılmaz. Yerel (gönderilmemiş) mesajlar zaten kalıcı kuyrukta (Outbox) durur, buraya girmez.
/// - Dosyalar uygulama sandbox'ındadır (cihaz diski). Oturum kapanışı/hesap silmede [clear] her şeyi siler.
/// - Tüm disk işlemleri tek sıraya dizilir; hata çağırana sızmaz (çevrimdışı önbellek olmazsa uygulama aynı çalışır).
class MessageCache {
  MessageCache({
    Future<Directory> Function()? dirProvider,
    this.perConversation = 20,
    this.maxConversations = 50,
    this.maxListItems = 50,
    this.maxTotalBytes = 3 * 1024 * 1024,
    this.flushDelay = const Duration(milliseconds: 1500),
  }) : _dirProvider = dirProvider ?? _defaultDir;

  /// Yalnız bellekte çalışan örnek (diske yazmaz/okumaz); testler [instance]'a atar.
  factory MessageCache.memoryOnly() =>
      MessageCache(dirProvider: () async => throw const FileSystemException('memory only')).._memoryOnly = true;

  /// Uygulama genelinde tek örnek. Varsayılan YALNIZ BELLEK (testler diske/eklentiye dokunmaz); uygulama açılışında
  /// `main` diskli örneği atar (`MessageCache.instance = MessageCache()`).
  static MessageCache instance = MessageCache.memoryOnly();

  final Future<Directory> Function() _dirProvider;
  final int perConversation;
  final int maxConversations;
  final int maxListItems;
  final int maxTotalBytes;
  final Duration flushDelay;

  static Future<Directory> _defaultDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}${Platform.pathSeparator}msg_cache');
  }

  // Bellek: yüklenmiş anlık görüntüler (sohbet kimliği -> en yeni başta mesajlar) ve kirli küme.
  final Map<int, List<Map<String, dynamic>>> _mem = {};
  List<Map<String, dynamic>>? _list;
  final Set<int> _dirty = {};
  bool _listDirty = false;
  bool _cleared = false;
  Timer? _timer;
  // Tembel: kurucu anında Future üretilmez (testlerde setUp bölgesi ile FakeAsync bölgesi karışmasın).
  Future<void>? _queue;
  Directory? _dir;

  Future<T> _run<T>(Future<T> Function() op, T fallback) {
    final c = Completer<T>();
    _queue = (_queue ?? Future<void>.value()).then((_) async {
      try {
        _dir ??= await _dirProvider();
        await _dir!.create(recursive: true);
        c.complete(await op());
      } catch (_) {
        c.complete(fallback);
      }
    });
    return c.future;
  }

  File _file(String name) => File('${_dir!.path}${Platform.pathSeparator}$name');

  // ---------- Temizleme (sızdırmama) ----------

  /// Tek bir alanı yerel kayda uygun hâle getirir; null: bu mesaj hiç yazılmaz.
  static Map<String, dynamic>? sanitizeMessage(Map<String, dynamic> m) {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return null; // yerel bekleyen/hatalı mesaj: kuyrukta durur
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (k.startsWith('_')) return; // yerel alanlar (bayt, durum...)
      out[k] = v;
    });
    final gone = m['deleted'] == true || m['removed'] == true;
    if (gone) {
      // Silinen/kaldırılan: yalnız iskelet (içerik, ek, alıntı, tepki yazılmaz).
      out
        ..remove('attachments')
        ..remove('replyTo')
        ..remove('reactions')
        ..remove('myReaction');
      return out;
    }
    final atts = m['attachments'];
    var once = false;
    if (atts is List) {
      out['attachments'] = [
        for (final a in atts)
          if (a is Map)
            if (a['viewOnce'] == true)
              () {
                once = true;
                // Tek gösterimlik: kimlik/tür/durum dışında hiçbir şey (URL, küçük resim) yazılmaz.
                return <String, dynamic>{
                  'id': a['id'],
                  'kind': a['kind'],
                  'viewOnce': true,
                  'viewed': a['viewed'] == true,
                };
              }()
            else
              Map<String, dynamic>.from(a),
      ];
    }
    if (once) out['text'] = '';
    final r = m['replyTo'];
    if (r is Map && (r['viewOnce'] == true || r['deleted'] == true)) {
      out['replyTo'] = {'id': r['id'], 'senderId': r['senderId'], 'text': '', 'deleted': r['deleted'] == true};
    }
    return out;
  }

  // ---------- Mesajlar ----------

  /// Sohbetin kayıtlı en yeni mesajları (en yeni başta); yoksa boş liste.
  Future<List<Map<String, dynamic>>> readMessages(int cid) async {
    final mem = _mem[cid];
    if (mem != null) return [for (final m in mem) Map<String, dynamic>.from(m)];
    final loaded = await _run<List<Map<String, dynamic>>?>(() => _loadConv(cid), null);
    if (loaded == null) return const [];
    _mem.putIfAbsent(cid, () => loaded);
    return [for (final m in _mem[cid]!) Map<String, dynamic>.from(m)];
  }

  Future<List<Map<String, dynamic>>?> _loadConv(int cid) async {
    final f = _file('c$cid.json');
    if (!await f.exists()) return null;
    try {
      final j = jsonDecode(await f.readAsString());
      final raw = j is Map ? j['m'] : null;
      if (raw is! List) return null;
      return [
        for (final e in raw)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      try {
        await f.delete();
      } catch (_) {}
      return null;
    }
  }

  static int _id(Map<String, dynamic> m) => (m['id'] as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> _normalize(Iterable<Map<String, dynamic>> msgs) {
    final byId = <int, Map<String, dynamic>>{};
    for (final m in msgs) {
      final s = sanitizeMessage(m);
      if (s != null) byId[_id(s)] = s;
    }
    final list = byId.values.toList()..sort((a, b) => _id(b).compareTo(_id(a)));
    return list.length > perConversation ? list.sublist(0, perConversation) : list;
  }

  /// Ekrandaki mesajlardan (en yeni başta) sohbetin kaydını günceller; yazma geciktirilir.
  void saveMessages(int cid, Iterable<Map<String, dynamic>> msgs) {
    final list = _normalize(msgs);
    _cleared = false;
    _mem[cid] = list;
    _dirty.add(cid);
    _schedule();
  }

  /// Gelen/gönderilen tek mesajı (STOMP) kaydı olan bir sohbete ekler/günceller. Kaydı olmayan sohbete
  /// dokunmaz (yalnız açılmış sohbetler saklanır).
  Future<void> upsertMessage(int cid, Map<String, dynamic> msg) async {
    var cur = _mem[cid];
    if (cur == null) {
      final loaded = await _run<List<Map<String, dynamic>>?>(() => _loadConv(cid), null);
      if (loaded == null) return;
      cur = _mem.putIfAbsent(cid, () => loaded);
    }
    _mem[cid] = _normalize([...cur, msg]);
    _dirty.add(cid);
    _schedule();
  }

  /// Mesaj herkes için silindi/gizlendi: kayıttaki içerik hemen iskelete indirilir.
  Future<void> markGone(int cid, int messageId) async {
    var cur = _mem[cid];
    if (cur == null) {
      final loaded = await _run<List<Map<String, dynamic>>?>(() => _loadConv(cid), null);
      if (loaded == null) return;
      cur = _mem.putIfAbsent(cid, () => loaded);
    }
    var changed = false;
    final next = <Map<String, dynamic>>[];
    for (final m in cur) {
      if (_id(m) == messageId && m['deleted'] != true) {
        changed = true;
        next.add({'id': m['id'], 'conversationId': m['conversationId'], 'senderId': m['senderId'], 'createdAt': m['createdAt'], 'deleted': true, 'text': ''});
      } else {
        next.add(m);
      }
    }
    if (!changed) return;
    _mem[cid] = next;
    _dirty.add(cid);
    _schedule();
  }

  /// Bir sohbetin kaydını siler (engelleme, ayrılma, sohbet silme).
  Future<void> removeConversation(int cid) async {
    _mem.remove(cid);
    _dirty.remove(cid);
    await _run<void>(() async {
      final f = _file('c$cid.json');
      if (await f.exists()) await f.delete();
    }, null);
  }

  // ---------- Sohbet listesi ----------

  Future<List<Map<String, dynamic>>> readConversations() async {
    final mem = _list;
    if (mem != null) return [for (final m in mem) Map<String, dynamic>.from(m)];
    final loaded = await _run<List<Map<String, dynamic>>?>(() async {
      final f = _file('list.json');
      if (!await f.exists()) return null;
      try {
        final j = jsonDecode(await f.readAsString());
        final raw = j is Map ? j['m'] : null;
        if (raw is! List) return null;
        return [
          for (final e in raw)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
      } catch (_) {
        return null;
      }
    }, null);
    if (loaded == null) return const [];
    _list ??= loaded;
    return [for (final m in _list!) Map<String, dynamic>.from(m)];
  }

  /// Listenin ilk [maxListItems] satırını saklar. Son mesaj önizlemesi mesajlarla aynı kurallarla temizlenir.
  void saveConversations(Iterable<Map<String, dynamic>> items) {
    final out = <Map<String, dynamic>>[];
    for (final c in items) {
      if (out.length >= maxListItems) break;
      final row = <String, dynamic>{};
      c.forEach((k, v) {
        if (!k.startsWith('_')) row[k] = v;
      });
      row.remove('unreadCount'); // okunmamış sayacı cihazdan değil sunucudan gelir
      final last = c['lastMessage'];
      if (last is Map) {
        final l = <String, dynamic>{};
        last.forEach((k, v) {
          if (!'$k'.startsWith('_')) l['$k'] = v;
        });
        final atts = l['attachments'];
        if (atts is List && atts.any((a) => a is Map && a['viewOnce'] == true)) {
          l['text'] = '';
          l['attachments'] = [
            for (final a in atts)
              if (a is Map) {'id': a['id'], 'kind': a['kind'], 'viewOnce': true, 'viewed': a['viewed'] == true}
          ];
        } else if (l['deleted'] == true || l['removed'] == true) {
          l.remove('attachments');
        }
        row['lastMessage'] = l;
      }
      out.add(row);
    }
    _cleared = false;
    _list = out;
    _listDirty = true;
    _schedule();
  }

  // ---------- Yazma / temizlik ----------

  bool _memoryOnly = false;

  void _schedule() {
    if (_memoryOnly) return; // diske yazılacak bir şey yok: zamanlayıcı da yok
    _timer?.cancel();
    _timer = Timer(flushDelay, () => unawaited(flush()));
  }

  /// Bekleyen değişiklikleri hemen yazar (uygulama arka plana giderken, testler).
  Future<void> flush() {
    _timer?.cancel();
    if (_dirty.isEmpty && !_listDirty) return _queue ?? Future<void>.value();
    final cids = _dirty.toList();
    _dirty.clear();
    final writeList = _listDirty;
    _listDirty = false;
    // Anlık görüntüler kuyruk çalışırken değişebilir: yazı anında bellekteki en yeni hâl alınır.
    return _run<void>(() async {
      if (_cleared) return;
      for (final cid in cids) {
        final snap = _mem[cid];
        if (snap == null) continue;
        await _atomicWrite('c$cid.json', jsonEncode({'v': 1, 't': DateTime.now().millisecondsSinceEpoch, 'm': snap}));
      }
      if (writeList && _list != null) {
        await _atomicWrite('list.json', jsonEncode({'v': 1, 't': DateTime.now().millisecondsSinceEpoch, 'm': _list}));
      }
      await _prune();
    }, null);
  }

  Future<void> _atomicWrite(String name, String content) async {
    final tmp = _file('$name.tmp');
    await tmp.writeAsString(content, flush: false);
    await tmp.rename(_file(name).path);
  }

  /// Sohbet dosyası sayısı ve toplam boyut tavanı: en eski değişen dosyalar silinir.
  Future<void> _prune() async {
    final files = <(File, DateTime, int)>[];
    var total = 0;
    await for (final e in _dir!.list()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (!name.startsWith('c') || !name.endsWith('.json')) continue;
      final st = await e.stat();
      files.add((e, st.modified, st.size));
      total += st.size;
    }
    files.sort((a, b) => a.$2.compareTo(b.$2)); // en eski başta
    var count = files.length;
    for (final f in files) {
      if (count <= maxConversations && total <= maxTotalBytes) break;
      try {
        await f.$1.delete();
      } catch (_) {}
      final name = f.$1.uri.pathSegments.last;
      final id = int.tryParse(name.substring(1, name.length - 5));
      if (id != null) _mem.remove(id);
      total -= f.$3;
      count--;
    }
  }

  /// Çıkış/hesap silme/oturum iptali: bellek + disk tümüyle silinir.
  Future<void> clear() {
    _timer?.cancel();
    _cleared = true;
    _mem.clear();
    _list = null;
    _dirty.clear();
    _listDirty = false;
    return _run<void>(() async {
      try {
        await for (final e in _dir!.list()) {
          if (e is File) await e.delete();
        }
      } catch (_) {}
    }, null);
  }

  /// Testler: bekleyen işlemlerin bitmesini bekler.
  Future<void> settle() => _queue ?? Future<void>.value();
}
