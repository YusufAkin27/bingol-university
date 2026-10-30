import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tmp;
  var nowMs = DateTime(2026, 10, 30, 12).millisecondsSinceEpoch;
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(nowMs);
  void due() => nowMs += const Duration(minutes: 10).inMilliseconds;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bu_ob_');
    nowMs = DateTime(2026, 10, 30, 12).millisecondsSinceEpoch;
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Outbox make({MemoryOutboxStore? store, OutboxSender? sender, int maxMedia = 200 * 1024 * 1024}) => Outbox(
        store: store ?? MemoryOutboxStore(),
        sender: sender,
        now: clock,
        autoSchedule: false,
        mediaDirProvider: () async => tmp,
        maxMediaBytes: maxMedia,
      );

  Future<void> settleIo() => Future<void>.delayed(const Duration(milliseconds: 30));

  OutboxMediaSource photo([int n = 8]) =>
      OutboxMediaSource(kind: 'image', mime: 'image/jpeg', bytes: Uint8List.fromList(List.filled(n, 1)));

  group('sessiz gonderme kuyrugu: medya', () {
    test('fotograf diske kopyalanir, kalici depoya yazilir, uygulama yeniden acilinca geri yuklenir', () async {
      final store = MemoryOutboxStore();
      final ob = make(store: store);
      final ok = await ob.enqueueMedia(conversationId: 3, clientId: 'p-1', text: 'aciklama', sources: [photo(), photo(12)]);
      expect(ok, isTrue);
      expect(ob.pendingCount, 1);
      expect(ob.items.single.media.length, 2);
      expect(tmp.listSync().whereType<File>().length, 2);
      expect(store.value, contains('p-1'));
      // uygulama olduruldu ve yeniden acildi
      final ob2 = make(store: store);
      await ob2.load();
      expect(ob2.items.single.clientId, 'p-1');
      expect(ob2.items.single.media.length, 2);
      expect(await ob2.mediaFileOf(ob2.items.single.media.first), isNotNull);
      ob.dispose();
      ob2.dispose();
    });

    test('baglanti gelince once ekler yuklenir, sonra mesaj attachmentIds + ayni clientId ile gider; dosyalar silinir', () async {
      final calls = <String>[];
      Map<String, dynamic>? posted;
      final ob = make(sender: (i) async {
        calls.add('post');
        posted = {'clientId': i.clientId, 'ids': [for (final m in i.media) m.attId], 'viewOnce': i.viewOnce};
        return {'id': 90, 'clientId': i.clientId};
      });
      ob.uploader = (item, media, file, poster) async {
        calls.add('up:${media.file}');
        return 100 + calls.length;
      };
      await ob.enqueueMedia(conversationId: 3, clientId: 'p-2', text: '', sources: [photo(), photo()], viewOnce: true);
      final delivered = <OutboxDelivery>[];
      ob.deliveries.listen(delivered.add);
      due();
      await ob.drain();
      await settleIo();
      expect(calls.length, 3);
      expect(calls.first.startsWith('up:'), isTrue);
      expect(calls.last, 'post');
      expect(posted!['clientId'], 'p-2');
      expect(posted!['ids'], hasLength(2));
      expect(posted!['viewOnce'], true);
      expect(ob.items, isEmpty);
      expect(delivered.single.item.clientId, 'p-2');
      expect(tmp.listSync().whereType<File>(), isEmpty); // gonderilen eklerin yerel kopyalari silindi
      ob.dispose();
    });

    test('yukleme ag hatasiyla kesilirse mesaj kuyrukta kalir (hata gostergesi yok); yuklenen ek yeniden yuklenmez', () async {
      var up = 0;
      var down = true;
      final ob = make(sender: (i) async => {'id': 1, 'clientId': i.clientId});
      ob.uploader = (item, media, file, poster) async {
        up++;
        if (down && up == 2) throw ApiError(0, 'NETWORK', '');
        return up;
      };
      await ob.enqueueMedia(conversationId: 3, clientId: 'p-3', text: '', sources: [photo(), photo()]);
      due();
      await ob.drain();
      expect(ob.pendingCount, 1); // hala bekliyor, failed degil
      expect(ob.failedCount, 0);
      expect(ob.items.single.media.first.attId, 1); // ilk ek yuklendi, kimligi tutuldu
      down = false;
      due();
      await ob.drain();
      expect(up, 3); // yalniz 2. ek yeniden yuklendi
      expect(ob.items, isEmpty);
      ob.dispose();
    });

    test('kalici hata (413/4xx): yalniz o zaman failed; elle retry calisir', () async {
      var fail = true;
      final ob = make(sender: (i) async => {'id': 1});
      ob.uploader = (item, media, file, poster) async {
        if (fail) throw ApiError(413, 'VIDEO_TOO_LARGE', 'x');
        return 5;
      };
      await ob.enqueueMedia(conversationId: 3, clientId: 'v-1', text: '', sources: [photo()]);
      due();
      await ob.drain();
      expect(ob.failedCount, 1);
      expect(ob.items.single.errorCode, 'VIDEO_TOO_LARGE');
      fail = false;
      await ob.retry('v-1');
      expect(ob.items, isEmpty);
      ob.dispose();
    });

    test('yerel dosya kaybolduysa (MEDIA_LOST) kalici hata', () async {
      final ob = make(sender: (i) async => {'id': 1});
      ob.uploader = (item, media, file, poster) async => 1;
      await ob.enqueueMedia(conversationId: 3, clientId: 'm-1', text: '', sources: [photo()]);
      for (final f in tmp.listSync().whereType<File>()) {
        f.deleteSync();
      }
      due();
      await ob.drain();
      expect(ob.items.single.status, OutboxStatus.failed);
      expect(ob.items.single.errorCode, 'MEDIA_LOST');
      ob.dispose();
    });

    test('disk tavani asilirsa kuyruga alinmaz (false) ve artik dosya birakmaz', () async {
      final ob = make(maxMedia: 10);
      final ok = await ob.enqueueMedia(conversationId: 3, clientId: 'b-1', text: '', sources: [photo(8), photo(8)]);
      expect(ok, isFalse);
      expect(ob.items, isEmpty);
      await settleIo();
      expect(tmp.listSync().whereType<File>(), isEmpty);
      ob.dispose();
    });

    test('cikis (clear): bekleyen mesaj ve ek dosyalari silinir', () async {
      final ob = make();
      await ob.enqueueMedia(conversationId: 3, clientId: 'c-1', text: '', sources: [photo()]);
      await ob.clear();
      await settleIo();
      expect(ob.items, isEmpty);
      expect(tmp.listSync().whereType<File>(), isEmpty);
      ob.dispose();
    });
  });

  group('sessiz gonderme kuyrugu: zaman asimi ve tetikleyiciler', () {
    test('24 saati gecen bekleyen mesaj kalici hata olur (Gonderilemedi); 7 gunden eski silinir', () async {
      final store = MemoryOutboxStore();
      final a = make(store: store);
      a.enqueue(conversationId: 1, clientId: 'old', text: 'x');
      await Future<void>.delayed(Duration.zero);
      nowMs += const Duration(hours: 25).inMilliseconds;
      final b = make(store: store);
      await b.load();
      expect(b.items.single.status, OutboxStatus.failed);
      expect(b.items.single.errorCode, 'EXPIRED');
      nowMs += const Duration(days: 8).inMilliseconds;
      final c = make(store: store);
      await c.load();
      expect(c.items, isEmpty);
    });

    test('nudge (uygulama one geldi / STOMP baglandi): geri cekilme atlanir, hemen gonderilir', () async {
      var net = false;
      final sent = <String>[];
      final ob = make(sender: (i) async {
        if (!net) throw ApiError(0, 'NETWORK', '');
        sent.add(i.text);
        return {'id': 1};
      });
      ob.enqueue(conversationId: 1, clientId: 'a', text: 'bir');
      due();
      await ob.drain(); // ag yok: geri cekilme 2 sn
      expect(sent, isEmpty);
      net = true;
      await ob.drain(); // geri cekilme dolmadi: bekler
      expect(sent, isEmpty);
      await ob.nudge();
      expect(sent, ['bir']);
      ob.dispose();
    });

    test('offline -> normal gorunum -> baglanti gelince otomatik gonderim (ApiClient + connectivity)', () async {
      final bodies = <Map>[];
      var down = true;
      final cs = ConnectivityService();
      final api = ApiClient(
          client: MockClient((r) async {
            if (down) throw http.ClientException('yok');
            if (r.method == 'POST') bodies.add(jsonDecode(r.body) as Map);
            return http.Response('{"id":5}', 201, headers: {'content-type': 'application/json'});
          }),
          retryDelay: Duration.zero,
          connectivity: cs)
        ..tokens = Tokens('A', 'R');
      final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false, mediaDirProvider: () async => tmp);
      api.outbox = ob;
      ob.attach(api, cs);
      // iki mesaj arka arkaya: sira korunur
      for (final t in ['bir', 'iki']) {
        await expectLater(api.post('/conversations/3/messages', {'text': t, 'clientId': 'k-$t'}), throwsA(isA<ApiError>()));
      }
      expect(ob.pendingCount, 2);
      expect(ob.failedCount, 0);
      down = false;
      await api.get('/news'); // herhangi bir istek basarili -> reconnects -> drain
      for (var i = 0; i < 20 && ob.pendingCount > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(bodies.map((b) => b['text']).toList(), ['bir', 'iki']);
      expect(bodies.map((b) => b['clientId']).toList(), ['k-bir', 'k-iki']);
      ob.dispose();
    });
  });
}
