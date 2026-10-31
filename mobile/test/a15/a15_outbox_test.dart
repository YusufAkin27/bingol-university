// A15 denetimi: sessiz gonderme kuyrugu (Outbox) KAOS/FUZZ testleri. Beklenen (istenen) davranisi dogrular;
// KIRMIZI test = bulgu. Uretim koduna dokunmaz.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Bu senaryolar A15 ORTA paketidir (T-105, W2-G): Dalga 1 (W1-G) kapsamı DIŞINDA; kırmızı bulgu kanıtı olarak korunur.
const _t105 = 'T-105 / W2-G: Outbox ORTA paketi (seq, tavan, ek yeniden yükleme, yazma hatası) bu dalgada değil';

/// Okuması geçici olarak patlayabilen depo (Keystore/Keychain geçici hatası benzetimi).
class _FlakyStore implements OutboxStore {
  String? value;
  bool failReads = false;
  @override
  Future<String?> read() async {
    if (failReads) throw PlatformException(code: 'KEYSTORE', message: 'gecici');
    return value;
  }

  @override
  Future<void> write(String? v) async => value = v;
}

class _CountingStore implements OutboxStore {
  String? value;
  int writes = 0;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async {
    writes++;
    await Future<void>.delayed(const Duration(milliseconds: 5)); // gercek depo gecikmesi
    value = v;
  }
}

class FailingStore implements OutboxStore {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async {
    if (failWrites) throw const FileSystemException('ENOSPC: No space left on device');
    value = v;
  }
}

void main() {
  late Directory tmp;
  var nowMs = DateTime(2026, 10, 30, 12).millisecondsSinceEpoch;
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(nowMs);
  void adv(Duration d) => nowMs += d.inMilliseconds;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('a15_ob_');
    nowMs = DateTime(2026, 10, 30, 12).millisecondsSinceEpoch;
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Outbox make({OutboxStore? store, OutboxSender? sender, int maxMedia = 200 * 1024 * 1024, int maxItems = 100}) => Outbox(
        store: store ?? MemoryOutboxStore(),
        sender: sender,
        now: clock,
        autoSchedule: false,
        mediaDirProvider: () async => tmp,
        maxMediaBytes: maxMedia,
        maxItems: maxItems,
      );

  Future<void> io() => Future<void>.delayed(const Duration(milliseconds: 40));

  OutboxMediaSource photo([int n = 8]) =>
      OutboxMediaSource(kind: 'image', mime: 'image/jpeg', bytes: Uint8List.fromList(List.filled(n, 1)));

  test('S1.1 50 mesaj cevrimdisi -> baglanti gelince SIRA korunur', () async {
    final sent = <String>[];
    var online = false;
    final ob = make(sender: (i) async {
      if (!online) throw ApiError(0, 'NETWORK', '');
      sent.add(i.clientId);
      return {'id': sent.length, 'clientId': i.clientId};
    });
    for (var i = 0; i < 50; i++) {
      ob.enqueue(conversationId: 1, clientId: 'm${i.toString().padLeft(2, '0')}', text: 't$i');
      adv(const Duration(milliseconds: 5));
    }
    adv(const Duration(seconds: 3));
    await ob.drain(); // ag yok
    expect(sent, isEmpty);
    online = true;
    adv(const Duration(seconds: 10));
    await ob.nudge();
    expect(sent, [for (var i = 0; i < 50; i++) 'm${i.toString().padLeft(2, '0')}']);
    ob.dispose();
  });

  test('S1.1b AYNI milisaniyede olusan 50 mesaj uygulama yeniden acilinca (load -> sort) SIRA korunur mu', skip: _t105, () async {
    final store = MemoryOutboxStore();
    final ob = make(store: store);
    for (var i = 0; i < 50; i++) {
      ob.enqueue(conversationId: 1, clientId: 'm${i.toString().padLeft(2, '0')}', text: 't$i'); // saat sabit
    }
    await io();
    final sent = <String>[];
    final ob2 = make(store: store, sender: (i) async {
      sent.add(i.clientId);
      return {'id': sent.length};
    });
    await ob2.load();
    for (var k = 0; k < 60 && sent.length < 50; k++) {
      adv(const Duration(seconds: 10));
      await ob2.nudge();
      await io();
    }
    final want = [for (var i = 0; i < 50; i++) 'm${i.toString().padLeft(2, '0')}'];
    // ignore: avoid_print
    print('S1.1b siralama: ${sent.take(8).toList()}... ${sent == want ? "KORUNDU" : "BOZULDU"}');
    expect(sent, want, reason: 'esit createdAt: List.sort kararli degil, sira karisabilir');
    ob.dispose();
    ob2.dispose();
  });

  test('S1.1c cihaz saati geri alinirsa (mesaj 26 > mesaj 25 eski damga) yeniden aciliste sira TERSLENIR', skip: _t105, () async {
    final store = MemoryOutboxStore();
    final ob = make(store: store);
    for (var i = 0; i < 5; i++) {
      ob.enqueue(conversationId: 1, clientId: 'a$i', text: 'x');
      adv(const Duration(seconds: 1));
    }
    adv(-const Duration(hours: 2)); // kullanici saati geri aldi / saat dilimi otomatik duzeldi
    for (var i = 0; i < 3; i++) {
      ob.enqueue(conversationId: 1, clientId: 'b$i', text: 'y');
      adv(const Duration(seconds: 1));
    }
    await io();
    final sent = <String>[];
    final ob2 = make(store: store, sender: (i) async {
      sent.add(i.clientId);
      return {'id': sent.length};
    });
    await ob2.load();
    for (var k = 0; k < 6; k++) {
      adv(const Duration(seconds: 10));
      await ob2.nudge();
      await io();
    }
    // ignore: avoid_print
    print('S1.1c gonderim sirasi: $sent');
    expect(sent, ['a0', 'a1', 'a2', 'a3', 'a4', 'b0', 'b1', 'b2'], reason: 'kullanici yazma sirasi korunmali');
    ob.dispose();
    ob2.dispose();
  });

  test('S1.2 baglanti gelip giderken (flapping) CIFT TESLIM yok', () async {
    final conn = ConnectivityService();
    final api = ApiClient(client: MockClient((r) async => http.Response('{}', 200)), connectivity: conn);
    final successes = <String, int>{};
    var attempts = 0;
    final ob = make(sender: (i) async {
      attempts++;
      await Future<void>.delayed(const Duration(milliseconds: 15));
      if (attempts % 3 == 0) throw ApiError(0, 'NETWORK', ''); // her 3. istek koparsa
      successes[i.clientId] = (successes[i.clientId] ?? 0) + 1;
      return {'id': attempts};
    });
    ob.attach(api, conn);
    for (var i = 0; i < 20; i++) {
      ob.enqueue(conversationId: 1 + i % 3, clientId: 'f$i', text: 't$i');
    }
    adv(const Duration(seconds: 3));
    // firtina: baglanti olaylari + nudge + drain ayni anda
    final futs = <Future<void>>[];
    for (var k = 0; k < 40; k++) {
      conn.reconnects.value++;
      futs.add(ob.nudge());
      futs.add(ob.drain());
      await Future<void>.delayed(const Duration(milliseconds: 3));
      adv(const Duration(seconds: 6));
    }
    await Future.wait(futs);
    for (var k = 0; k < 40 && ob.pendingCount > 0; k++) {
      adv(const Duration(minutes: 6));
      await ob.nudge();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    expect(successes.length, 20, reason: 'hepsi iletilmeli');
    expect(successes.values.every((v) => v == 1), isTrue, reason: 'her clientId tek basarili teslim');
    ob.dispose();
  });

  test('S1.3 uygulama gonderim ortasinda oldurulur: sunucu mesaji ALDI ama yanit gelmedi -> yeniden acilista ayni clientId ile yeniden gonderilir (cift degil)', () async {
    final store = MemoryOutboxStore();
    final serverSaw = <String>[];
    final ob = make(store: store, sender: (i) async {
      serverSaw.add(i.clientId);
      throw ApiError(0, 'NETWORK', ''); // yanit kayboldu
    });
    ob.enqueue(conversationId: 1, clientId: 'k1', text: 'merhaba');
    adv(const Duration(seconds: 3));
    await ob.drain();
    await io();
    final ob2 = make(store: store, sender: (i) async {
      serverSaw.add(i.clientId);
      return {'id': 9, 'clientId': i.clientId};
    });
    await ob2.load();
    adv(const Duration(minutes: 1));
    await ob2.nudge();
    expect(serverSaw, ['k1', 'k1']); // sunucu clientId ile tekilleştirir
    expect(ob2.items, isEmpty);
    ob.dispose();
    ob2.dispose();
  });

  test('S1.4a depo KESIK/BOZUK JSON: acilista cokme yok ama TUM kuyruk sessizce SILINIR (kayip)', () async {
    final store = MemoryOutboxStore();
    final ob = make(store: store);
    for (var i = 0; i < 3; i++) {
      ob.enqueue(conversationId: 1, clientId: 'z$i', text: 'onemli $i');
    }
    await ob.enqueueMedia(conversationId: 1, clientId: 'zm', text: '', sources: [photo(64)]);
    await io();
    final good = store.value!;
    store.value = good.substring(0, good.length - 40); // yazma yarida kesildi
    final ob2 = make(store: store);
    await ob2.load();
    await io();
    final kept = ob2.items.length;
    // ignore: avoid_print
    print('S1.4a kesik depoda yuklenen: $kept ; depo sonrasi: ${store.value == null ? "NULL (ham veri YOK EDILDI)" : "korundu"}; medya dosyasi kaldi mi: ${tmp.listSync().length}');
    expect(store.value, isNotNull, reason: 'bozuk ham veri en azindan yedeklenmeli/korunmali, null ile ustune yazilmamali');
    expect(kept, greaterThan(0), reason: 'kismi kurtarma beklenir (ilk 3 tam kayit okunabilir)');
    expect(ob2.items.map((e) => e.clientId), ['z0', 'z1', 'z2']);
    expect(store.corrupt, good.substring(0, good.length - 40), reason: 'bozuk ham deger yedek anahtara tasinir');
    ob.dispose();
    ob2.dispose();
  });

  test('S1.4c depo OKUNAMAZSA (gecici istisna) kuyruk SILINMEZ ve yazilmaz; ikinci load kurtarir', () async {
    final store = _FlakyStore();
    final ob = make(store: store);
    for (var i = 0; i < 3; i++) {
      ob.enqueue(conversationId: 1, clientId: 'k$i', text: 'onemli $i');
    }
    await io();
    final saved = store.value;
    expect(saved, isNotNull);
    final ob2 = make(store: store);
    store.failReads = true;
    await ob2.load();
    expect(ob2.items, isEmpty, reason: 'okunamadi: bellek bos ama depo korunmali');
    ob2.enqueue(conversationId: 1, clientId: 'yeni', text: 'okuma basarisizken eklendi');
    await io();
    expect(store.value, saved, reason: 'okunamayan eski kuyrugun ustune YAZILMAZ');
    store.failReads = false;
    await ob2.load(); // ikinci deneme
    await io();
    expect(ob2.items.map((e) => e.clientId).toSet(), {'k0', 'k1', 'k2', 'yeni'});
    expect(store.value, isNotNull);
    expect(store.value!.contains('k0'), isTrue);
    expect(store.value!.contains('yeni'), isTrue);
    ob.dispose();
    ob2.dispose();
  });

  test('S1.4d bozuk JSON: artik medya dosyalari silinmez (yalniz basarili+bozulmamis yuklemeden sonra supurulur)', () async {
    final store = MemoryOutboxStore();
    final ob = make(store: store);
    await ob.enqueueMedia(conversationId: 1, clientId: 'mm', text: 'foto', sources: [photo(32)]);
    ob.enqueue(conversationId: 1, clientId: 'tt', text: 'metin');
    await io();
    final before = tmp.listSync().length;
    expect(before, greaterThan(0));
    store.value = '{bozuk json';
    final ob2 = make(store: store);
    await ob2.load();
    await io();
    expect(tmp.listSync().length, before, reason: 'bozuk depoda medya dosyalari korunur');
    ob.dispose();
    ob2.dispose();
  });

  test('S1.4b gecerli ama tek kaydi bozuk (alan tipi) liste: bozuk kayit sessizce dusurulur, geri kalan korunur', () async {
    final store = MemoryOutboxStore()
      ..value = '[{"c":"ok1","v":1,"t":"a","a":${nowMs - 1000}},{"c":"bad","v":"1","t":"b","a":${nowMs - 900}},{"c":"ok2","v":1,"t":"c","a":${nowMs - 800}}]';
    final ob = make(store: store);
    await ob.load();
    expect(ob.items.map((e) => e.clientId), ['ok1', 'ok2']);
    ob.dispose();
  });

  test('S1.5 kalici hata (4xx) sonrasi ayni konusmadaki sonraki mesajlar TIKANMAZ (head-of-line) ama SIRA terslenir', () async {
    final order = <String>[];
    final ob = make(sender: (i) async {
      if (i.clientId == 'A') throw ApiError(400, 'VALIDATION_ERROR', 'x');
      order.add(i.clientId);
      return {'id': order.length};
    });
    ob.enqueue(conversationId: 1, clientId: 'A', text: '1');
    adv(const Duration(milliseconds: 5));
    ob.enqueue(conversationId: 1, clientId: 'B', text: '2');
    ob.enqueue(conversationId: 2, clientId: 'C', text: '3');
    adv(const Duration(seconds: 3));
    await ob.drain();
    // ignore: avoid_print
    print('S1.5 1. drain: $order ; A=${ob.byClientId('A')?.status}');
    await ob.drain();
    // ignore: avoid_print
    print('S1.5 2. drain: $order');
    expect(order.contains('B'), isTrue, reason: 'B tikanmamali');
    // Sira tersleme: A basarisiz iken B gitti; kullanici A\'yi "yeniden dene" derse A, B\'den SONRA teslim olur.
    ob.dispose();
  });

  test('S1.6 sunucu 5xx (502/503 deploy) 5 denemede KALICI HATA: ~84 sn kesinti tum kuyrugu "Gonderilemedi" yapar', () async {
    final ob = make(sender: (i) async => throw ApiError(503, 'HTTP_503', ''));
    for (var i = 0; i < 5; i++) {
      ob.enqueue(conversationId: 1, clientId: 'd$i', text: 't');
    }
    // backoff: 2,5,15,60 sn; sunucu 90 sn kapali kaldi
    var elapsed = 0;
    for (var k = 0; k < 12; k++) {
      adv(const Duration(seconds: 15));
      elapsed += 15;
      await ob.drain();
      if (ob.failedCount == 5) break;
    }
    // ignore: avoid_print
    print('S1.6 ${elapsed}sn 503 sonra failed=${ob.failedCount}/5');
    expect(ob.failedCount, 0, reason: '90 sn\'lik backend yeniden baslatmasi mesajlari kalici hataya cevirmemeli');
    ob.dispose();
  });

  test('S1.7 24 saat siniri: bekleyen EXPIRED olur; 7 gun: sessizce SILINIR', () async {
    final ob = make(sender: (i) async => throw ApiError(0, 'NETWORK', ''));
    ob.enqueue(conversationId: 1, clientId: 'e1', text: 't');
    adv(const Duration(hours: 25));
    await ob.drain();
    expect(ob.byClientId('e1')?.status, OutboxStatus.failed);
    expect(ob.byClientId('e1')?.errorCode, 'EXPIRED');
    ob.dispose();
  });

  test('S1.7b cihaz saati YANLISLIKLA 8 gun ileri alinirsa bekleyen mesaj SESSIZCE silinir (saat duzelse de geri gelmez)', skip: _t105, () async {
    final store = MemoryOutboxStore();
    final ob = make(store: store, sender: (i) async => throw ApiError(0, 'NETWORK', ''));
    ob.enqueue(conversationId: 1, clientId: 'e2', text: 'cok onemli');
    await io();
    adv(const Duration(days: 8));
    await ob.drain();
    final gone = ob.byClientId('e2') == null;
    adv(-const Duration(days: 8)); // saat duzeltildi
    await ob.drain();
    // ignore: avoid_print
    print('S1.7b mesaj silindi mi: $gone ; depo: ${store.value}');
    expect(ob.byClientId('e2'), isNotNull, reason: 'saat sicramasi mesaji silmemeli (en azindan failed olarak gorunur kalmali)');
    ob.dispose();
  });

  test('S1.7c saat GERI alinirsa createdAt gelecekte kalir -> 24 saat sinirina ASLA ulasilmaz (eski bekleyen sonsuza dek)', skip: _t105, () async {
    final ob = make(sender: (i) async => throw ApiError(0, 'NETWORK', ''));
    ob.enqueue(conversationId: 1, clientId: 'e3', text: 't');
    adv(-const Duration(days: 3));
    adv(const Duration(hours: 30)); // yeni "gercek" gecen sure 30 saat ama damga -2 gun 18 sa
    await ob.drain();
    // gercekte 30 saat gecti; beklenen: EXPIRED
    expect(ob.byClientId('e3')?.status, OutboxStatus.failed);
    ob.dispose();
  });

  test('S1.8 maxItems(100) asimi: 101. mesaj eklenince EN ESKI BEKLEYEN sessizce atilir (teslim olayi YOK)', skip: _t105, () async {
    final ob = make(maxItems: 100);
    final events = <String>[];
    ob.deliveries.listen((d) => events.add(d.item.clientId));
    for (var i = 0; i < 101; i++) {
      ob.enqueue(conversationId: 1, clientId: 'q$i', text: 't');
      adv(const Duration(milliseconds: 2));
    }
    // ignore: avoid_print
    print('S1.8 q0 kuyrukta mi: ${ob.contains("q0")} ; failed: ${ob.failedCount}; toplam: ${ob.items.length}');
    expect(ob.contains('q0') || ob.byClientId('q0')?.status == OutboxStatus.failed, isTrue,
        reason: 'atilan mesaj ya failed gorunmeli ya da enqueue reddedilmeli; UI (_onOutboxChanged) kuyrukta olmayan pending balonu GONDERILDI sayar');
    ob.dispose();
  });

  test('S1.9 medya tavani: failed medya kota tutar, yeni medya reddedilir (hata nedeni yok); reddedilen dosyalar silinir', skip: _t105, () async {
    final ob = make(maxMedia: 1000);
    expect(await ob.enqueueMedia(conversationId: 1, clientId: 'v1', text: '', sources: [photo(900)]), isTrue);
    ob.byClientId('v1')!.status = OutboxStatus.failed; // kalici hata ama kota hala dolu
    final ok = await ob.enqueueMedia(conversationId: 1, clientId: 'v2', text: '', sources: [photo(300)]);
    await io();
    // ignore: avoid_print
    print('S1.9 yeni medya kabul: $ok ; diskte dosya: ${tmp.listSync().length}');
    expect(ok, isTrue, reason: 'failed ogenin tuttugu kota yeni gonderimi engellememeli (ya da kullaniciya sebep gosterilmeli)');
    ob.dispose();
  });

  test('S1.10 kayip medya dosyasi -> MEDIA_LOST kalici hata (mesaj kaybolmaz, "Gonderilemedi")', () async {
    final ob = make(sender: (i) async => {'id': 1});
    ob.uploader = (a, b, c, d) async => 5;
    await ob.enqueueMedia(conversationId: 1, clientId: 'l1', text: 'x', sources: [photo()]);
    for (final f in tmp.listSync()) {
      f.deleteSync();
    }
    adv(const Duration(seconds: 3));
    await ob.drain();
    expect(ob.byClientId('l1')?.status, OutboxStatus.failed);
    expect(ob.byClientId('l1')?.errorCode, 'MEDIA_LOST');
    ob.dispose();
  });

  test('S1.11 ATTACHMENT_INVALID kalici ise ek her denemede YENIDEN YUKLENIR (sinirsiz, 24 saate kadar)', skip: _t105, () async {
    var uploads = 0;
    final ob = make(sender: (i) async => throw ApiError(400, 'ATTACHMENT_INVALID', ''));
    ob.uploader = (a, b, c, d) async => ++uploads;
    await ob.enqueueMedia(conversationId: 1, clientId: 'u1', text: '', sources: [photo(2000)]);
    for (var k = 0; k < 40; k++) {
      adv(const Duration(minutes: 6));
      await ob.drain();
    }
    // ignore: avoid_print
    print('S1.11 40 deneme (4 saat) sonunda yukleme sayisi: $uploads ; durum: ${ob.byClientId("u1")?.status}');
    expect(uploads, lessThan(10), reason: 'kalici ATTACHMENT_* hatasi sinirsiz yeniden yukleme dongusu olmamali');
    ob.dispose();
  });

  test('S1.12 depo yazma hatasi (ENOSPC / Keychain): enqueue true doner, bellekte kalir; uygulama olurse KAYIP ve kullanici bilgilendirilmez', skip: _t105, () async {
    final store = FailingStore()..failWrites = true;
    final ob = make(store: store);
    final ok = ob.enqueue(conversationId: 1, clientId: 'w1', text: 'merhaba');
    await io();
    final ob2 = make(store: store);
    await ob2.load();
    // ignore: avoid_print
    print('S1.12 enqueue=$ok ; yeniden aciliste kuyruk: ${ob2.items.length}');
    expect(ob2.items.length, 1, reason: 'yazma basarisizsa en azindan yeniden denenmeli / bildirilmeli');
    ob.dispose();
    ob2.dispose();
  });

  test('S1.13 clear() sirasinda suren drain: ESKI HESABIN sonraki mesajlari clear SONRASI yine gonderilir', () async {
    final gate = Completer<void>();
    final sent = <String>[];
    final ob = make(sender: (i) async {
      sent.add(i.clientId);
      if (i.clientId == 'x1') await gate.future;
      return {'id': 1};
    });
    ob.enqueue(conversationId: 1, clientId: 'x1', text: 'a');
    ob.enqueue(conversationId: 1, clientId: 'x2', text: 'b');
    adv(const Duration(seconds: 3));
    final d = ob.drain();
    await io();
    await ob.clear(); // oturum kapandi
    gate.complete();
    await d;
    // ignore: avoid_print
    print('S1.13 clear sonrasi gonderilenler: $sent');
    expect(sent, ['x1'], reason: 'clear sonrasi eski hesabin x2 mesaji baska token ile gonderilmemeli');
    ob.dispose();
  });

  test('S1.18 emoji: sinir KOD NOKTASIdir; 1500 emojili metin (3000 UTF-16) cevrimdisi kuyruga alinir, 2001 alinmaz', () async {
    final store = MemoryOutboxStore();
    final ob = make(store: store);
    final emoji1500 = '😀' * 1500;
    expect(emoji1500.length, 3000);
    expect(ob.enqueue(conversationId: 1, clientId: 'em1', text: emoji1500), isTrue);
    expect(ob.enqueue(conversationId: 1, clientId: 'em2', text: '😀' * 2000), isTrue);
    expect(ob.enqueue(conversationId: 1, clientId: 'em3', text: '😀' * 2001), isFalse);
    expect(await ob.enqueueMedia(conversationId: 1, clientId: 'em4', text: '😀' * 1500, sources: [photo()]), isTrue);
    expect(await ob.enqueueMedia(conversationId: 1, clientId: 'em5', text: '😀' * 2001, sources: [photo()]), isFalse);
    await io();
    final ob2 = make(store: store);
    await ob2.load();
    expect(ob2.items.map((e) => e.clientId), ['em1', 'em2', 'em4']);
    expect(ob2.items.first.text, emoji1500);
    ob.dispose();
    ob2.dispose();
  });

  test('S1.19 yazma maliyeti: art arda 20 gonderim + ack silmeleri guvenli depoya 20+20 degil, birlesmis az sayida yazma yapar', () async {
    final store = _CountingStore();
    final ob = make(store: store);
    for (var i = 0; i < 20; i++) {
      ob.enqueue(conversationId: 1, clientId: 'w$i', text: 'm$i');
    }
    for (var i = 0; i < 20; i++) {
      unawaited(ob.remove('w$i')); // WS ack
    }
    await io();
    await io();
    // ignore: avoid_print
    print('S1.19 40 islem -> ${store.writes} depo yazimi');
    expect(store.writes, lessThanOrEqualTo(4), reason: 'bekleyen yazmalar birlesmeli');
    expect(store.value, isNull, reason: 'son durum: kuyruk bos -> depo bos');
    // tek mesaj: enqueue = 1 yazma, ack = 1 yazma (iki yazim, N degil)
    final s2 = _CountingStore();
    final ob2 = make(store: s2);
    ob2.enqueue(conversationId: 1, clientId: 'tek', text: 'x');
    await io();
    await ob2.remove('tek');
    expect(s2.writes, 2);
    ob.dispose();
    ob2.dispose();
  });

  test('S1.16 502/503/504 ve Retry-After: mesaj Gonderilemedi OLMAZ, kuyruk durur (deploy kesintisi)', () async {
    var down = true;
    final sent = <String>[];
    final ob = make(sender: (i) async {
      if (down) throw ApiError(i.clientId == 'g4' ? 504 : (i.clientId == 'g2' ? 502 : 503), 'HTTP_503', '', retryAfter: i.clientId == 'g3' ? 30 : null);
      sent.add(i.clientId);
      return {'id': sent.length};
    });
    for (var i = 1; i <= 4; i++) {
      ob.enqueue(conversationId: i, clientId: 'g$i', text: 't');
    }
    for (var k = 0; k < 60; k++) {
      adv(const Duration(seconds: 20));
      await ob.drain();
    }
    expect(ob.failedCount, 0, reason: '20 dakikalik kesinti mesajlari kalici hataya cevirmemeli');
    expect(ob.pendingCount, 4);
    down = false;
    adv(const Duration(minutes: 10));
    await ob.nudge();
    expect(sent.toSet(), {'g1', 'g2', 'g3', 'g4'});
    expect(ob.items, isEmpty);
    ob.dispose();
  });

  test('S1.17 gercek 500: 5 ardisik hata YETMEZ, mesaj 30 dakikadan eskiyse kalici hata olur', () async {
    final ob = make(sender: (i) async => throw ApiError(500, 'SERVER_ERROR', ''));
    ob.enqueue(conversationId: 1, clientId: 'h1', text: 't');
    for (var k = 0; k < 10; k++) {
      adv(const Duration(minutes: 1));
      await ob.drain();
    }
    expect(ob.byClientId('h1')?.status, OutboxStatus.pending, reason: 'ilk 10 dakikada kalici hata yok');
    for (var k = 0; k < 40; k++) {
      adv(const Duration(minutes: 1));
      await ob.drain();
    }
    expect(ob.byClientId('h1')?.status, OutboxStatus.failed);
    expect(ob.byClientId('h1')?.errorCode, 'SERVER_ERROR');
    ob.dispose();
  });

  test('S1.14 yeniden dene (retry) -> failed ogesi gonderilir; ikinci cagri cift teslim uretmez', () async {
    var calls = 0;
    final ob = make(sender: (i) async {
      calls++;
      if (calls == 1) throw ApiError(422, 'CONTENT_PROFANITY', '');
      return {'id': 2};
    });
    ob.enqueue(conversationId: 1, clientId: 'r1', text: 'a');
    adv(const Duration(seconds: 3));
    await ob.drain();
    expect(ob.byClientId('r1')?.status, OutboxStatus.failed);
    await Future.wait([ob.retry('r1'), ob.retry('r1'), ob.nudge()]);
    expect(calls, 2);
    ob.dispose();
  });

  test('S1.15 FUZZ: rastgele ag/5xx/4xx/saat karisimi, 200 mesaj: hicbir mesaj ikinci kez BASARIYLA teslim olmaz, kayip yok', () async {
    final rnd = (() {
      var s = 12345;
      return () => (s = (s * 1103515245 + 12345) & 0x7fffffff);
    })();
    final delivered = <String, int>{};
    final permFail = <String>{};
    final ob = make(maxItems: 1000, sender: (i) async {
      await Future<void>.delayed(Duration.zero);
      final r = rnd() % 10;
      if (r < 3) throw ApiError(0, 'NETWORK', '');
      if (r == 3) throw ApiError(500, 'SERVER_ERROR', '');
      if (r == 4 && i.clientId.endsWith('7')) {
        permFail.add(i.clientId);
        throw ApiError(400, 'VALIDATION_ERROR', '');
      }
      if (r == 5) throw ApiError(429, 'RATE', '', retryAfter: 1);
      delivered[i.clientId] = (delivered[i.clientId] ?? 0) + 1;
      return {'id': 1};
    });
    for (var i = 0; i < 200; i++) {
      ob.enqueue(conversationId: 1 + i % 4, clientId: 'z$i', text: 't');
      adv(const Duration(milliseconds: 3));
    }
    for (var k = 0; k < 400 && ob.pendingCount > 0; k++) {
      adv(Duration(seconds: 1 + rnd() % 90));
      await ob.drain();
    }
    final lost = [for (var i = 0; i < 200; i++) if (!delivered.containsKey('z$i') && ob.byClientId('z$i') == null) 'z$i'];
    // ignore: avoid_print
    print('S1.15 teslim=${delivered.length} failed=${ob.failedCount} pending=${ob.pendingCount} kayip=${lost.length}');
    expect(delivered.values.every((v) => v == 1), isTrue);
    expect(lost, isEmpty);
    ob.dispose();
  });
}
