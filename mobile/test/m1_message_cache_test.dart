import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/cache/cache_policy.dart';
import 'package:bu_kampus/core/cache/disk_cache.dart';
import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jr(int status, Object body, {Map<String, String> h = const {}}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8', ...h});

Map<String, dynamic> msg(int id, {String? text, Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 7,
      'senderId': 3,
      'text': text ?? 'mesaj $id',
      'createdAt': '2026-10-30T10:00:00Z',
      ...?extra,
    };

void main() {
  late Directory tmp;

  MessageCache make({int per = 20, int convs = 50, int total = 3 * 1024 * 1024}) => MessageCache(
        dirProvider: () async => tmp,
        perConversation: per,
        maxConversations: convs,
        maxTotalBytes: total,
        flushDelay: const Duration(milliseconds: 20),
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bu_msg_');
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('MessageCache', () {
    test('en cok 20 mesaj saklanir (en yeni), id ile tekillesir, yeniden acilista okunur', () async {
      final c = make();
      c.saveMessages(7, [for (var i = 1; i <= 35; i++) msg(i), msg(30, text: 'duzenlendi')]);
      await c.flush();
      final c2 = make(); // uygulama yeniden acildi
      final got = await c2.readMessages(7);
      expect(got.length, 20);
      expect(got.first['id'], 35);
      expect(got.last['id'], 16);
      expect(got.firstWhere((m) => m['id'] == 30)['text'], 'duzenlendi'); // birlesme: tek kayit
    });

    test('yerel (id yok) ve _ alanli mesajlar yazilmaz; gonderilmemis mesaj depoya girmez', () async {
      final c = make();
      c.saveMessages(7, [
        {'id': null, 'clientId': 'x', 'text': 'bekleyen', '_state': 'pending'},
        msg(5, extra: {'_bytes': Uint8List(4), '_state': null}),
      ]);
      await c.flush();
      final got = await make().readMessages(7);
      expect(got.length, 1);
      expect(got.single.keys.any((k) => k.startsWith('_')), isFalse);
      expect(jsonEncode(got), isNot(contains('bekleyen')));
    });

    test('tek gosterimlik: URL ve icerik ASLA yazilmaz, yalniz yer tutucu', () async {
      final c = make();
      c.saveMessages(7, [
        msg(9, text: 'gizli aciklama', extra: {
          'attachments': [
            {'id': 1, 'kind': 'IMAGE', 'viewOnce': true, 'viewed': false, 'url': '/files/secret.jpg', 'thumbUrl': '/files/secret-t.jpg'},
            {'id': 2, 'kind': 'IMAGE', 'url': '/files/normal.jpg'},
          ],
        }),
      ]);
      await c.flush();
      final raw = await File('${tmp.path}/c7.json').readAsString();
      expect(raw, isNot(contains('secret')));
      expect(raw, isNot(contains('gizli aciklama')));
      expect(raw, contains('normal.jpg')); // normal ek URL'si saklanir (gorsel baytlari degil)
      final got = await make().readMessages(7);
      final once = (got.single['attachments'] as List).first as Map;
      expect(once['viewOnce'], true);
      expect(once.containsKey('url'), isFalse);
      expect(got.single['text'], '');
    });

    test('silinen/kaldirilan mesajin ekleri ve icerigi yazilmaz; markGone kaydi iskelete indirir', () async {
      final c = make();
      c.saveMessages(7, [
        msg(1, extra: {'deleted': true, 'attachments': [{'id': 3, 'url': '/files/a.jpg'}], 'reactions': [{'emoji': 'x'}]}),
        msg(2, text: 'silinecek', extra: {'attachments': [{'id': 4, 'url': '/files/b.jpg'}]}),
      ]);
      await c.flush();
      var raw = await File('${tmp.path}/c7.json').readAsString();
      expect(raw, isNot(contains('a.jpg')));
      expect(raw, contains('b.jpg'));
      await c.markGone(7, 2); // STOMP "deleted" olayi
      await c.flush();
      raw = await File('${tmp.path}/c7.json').readAsString();
      expect(raw, isNot(contains('silinecek')));
      expect(raw, isNot(contains('b.jpg')));
    });

    test('upsertMessage: kaydi olan sohbete eklenir/gunceller, olmayana dokunmaz; 20 siniri korunur', () async {
      final c = make();
      await c.upsertMessage(99, msg(1)); // kaydi yok: yazilmaz
      await c.flush();
      expect(File('${tmp.path}/c99.json').existsSync(), isFalse);

      c.saveMessages(7, [for (var i = 1; i <= 20; i++) msg(i)]);
      await c.upsertMessage(7, msg(21));
      await c.upsertMessage(7, msg(21, text: 'guncel'));
      await c.flush();
      final got = await make().readMessages(7);
      expect(got.length, 20);
      expect(got.first['id'], 21);
      expect(got.first['text'], 'guncel');
      expect(got.any((m) => m['id'] == 1), isFalse); // en eski sessizce atildi
    });

    test('sohbet listesi: en cok 50 satir, okunmamis sayaci ve tek gosterimlik onizleme yazilmaz', () async {
      final c = make();
      c.saveConversations([
        for (var i = 1; i <= 60; i++)
          {
            'id': i,
            'unreadCount': 4,
            'lastMessage': i == 1
                ? {'id': 1, 'text': 'gizli', 'attachments': [{'id': 1, 'viewOnce': true, 'url': '/files/x.jpg'}]}
                : {'id': i, 'text': 'son $i'},
          },
      ]);
      await c.flush();
      final got = await make().readConversations();
      expect(got.length, 50);
      expect(got.any((r) => r.containsKey('unreadCount')), isFalse);
      final raw = jsonEncode(got);
      expect(raw, isNot(contains('gizli')));
      expect(raw, isNot(contains('x.jpg')));
    });

    test('sohbet dosyasi sayisi tavani: en eski degisen dosyalar silinir', () async {
      final c = make(convs: 3);
      for (var i = 1; i <= 6; i++) {
        c.saveMessages(i, [msg(i, text: 'c$i')]);
        await c.flush();
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
      final files = tmp.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).where((n) => n.startsWith('c')).toList();
      expect(files.length, lessThanOrEqualTo(3));
      expect(files, contains('c6.json'));
      expect(files, isNot(contains('c1.json')));
    });

    test('toplam boyut tavani asilinca eski dosyalar atilir', () async {
      final c = make(total: 2000);
      for (var i = 1; i <= 4; i++) {
        c.saveMessages(i, [msg(i, text: 'x' * 900)]);
        await c.flush();
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
      var total = 0;
      for (final f in tmp.listSync().whereType<File>()) {
        if (f.uri.pathSegments.last.startsWith('c')) total += f.lengthSync();
      }
      expect(total, lessThanOrEqualTo(2000));
    });

    test('yazma geciktirilir ve toplanir: 100 kayit tek dosya yazimina iner', () async {
      final c = MessageCache(dirProvider: () async => tmp, flushDelay: const Duration(milliseconds: 80));
      for (var i = 1; i <= 100; i++) {
        c.saveMessages(7, [msg(i)]);
      }
      expect(File('${tmp.path}/c7.json').existsSync(), isFalse); // gecikme dolmadan disk yok
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await c.settle();
      expect(File('${tmp.path}/c7.json').existsSync(), isTrue);
    });

    test('clear (cikis/hesap silme): bellek ve disk tumuyle silinir', () async {
      final c = make();
      c.saveMessages(7, [msg(1)]);
      c.saveConversations([
        {'id': 7}
      ]);
      await c.flush();
      expect(tmp.listSync().whereType<File>(), isNotEmpty);
      await c.clear();
      expect(tmp.listSync().whereType<File>(), isEmpty);
      expect(await c.readMessages(7), isEmpty);
      expect(await c.readConversations(), isEmpty);
      expect(await make().readMessages(7), isEmpty);
    });

    test('bozuk dosya sessizce yok sayilir', () async {
      await File('${tmp.path}/c7.json').writeAsString('{bozuk');
      expect(await make().readMessages(7), isEmpty);
    });

    test('removeConversation (engelleme/ayrilma): kayit silinir', () async {
      final c = make();
      c.saveMessages(7, [msg(1)]);
      await c.flush();
      await c.removeConversation(7);
      expect(await make().readMessages(7), isEmpty);
    });

    test('ApiClient.setTokens(null) kullanici verisi temizleme kancalarini calistirir', () async {
      final api = ApiClient(client: MockClient((r) async => jr(200, {})), retryDelay: Duration.zero)..tokens = Tokens('A', 'R');
      var cleared = 0;
      api.onUserDataCleared.add(() async => cleared++);
      await api.setTokens(Tokens('B', 'R2')); // yenileme: temizlenmez
      expect(cleared, 0);
      await api.setTokens(null);
      await Future<void>.delayed(Duration.zero);
      expect(cleared, 1);
    });
  });

  test('engelleme (POST /users/{id}/block) mesaj kaydi temizleme kancasini calistirir', () async {
    final api = ApiClient(client: MockClient((r) async => jr(204, {})), retryDelay: Duration.zero)..tokens = Tokens('A', 'R');
    var n = 0;
    api.onBlockedUser.add(() async => n++);
    await api.post('/users/9/block');
    await api.post('/users/9/follow');
    await Future<void>.delayed(Duration.zero);
    expect(n, 1);
  });

  test('jwtSubjectId: access token sub alanindan kullanici kimligi (cevrimdisi acilis icin)', () {
    String enc(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    expect(jwtSubjectId('${enc({'alg': 'HS256'})}.${enc({'sub': '42', 'role': 'USER'})}.imza'), 42);
    expect(jwtSubjectId('bozuk'), isNull);
    expect(jwtSubjectId('a.b.c'), isNull);
  });

  group('ImageDiskCache', () {
    ImageDiskCache img({int max = 1000}) => ImageDiskCache(dirProvider: () async => tmp, maxBytes: max, maxFileBytes: 600);

    test('yazar, okur; yeniden acilista korunur', () async {
      final c = img();
      await c.write('https://x/a.jpg', Uint8List.fromList(List.filled(100, 7)));
      await c.settle();
      final got = await img().read('https://x/a.jpg');
      expect(got, isNotNull);
      expect(got!.length, 100);
      expect(await img().read('https://x/yok.jpg'), isNull);
    });

    test('tek dosya siniri: buyuk dosya yazilmaz', () async {
      final c = img();
      await c.write('https://x/big.jpg', Uint8List(601));
      expect(await c.read('https://x/big.jpg'), isNull);
    });

    test('toplam tavan: asilinca en eski dosyalar silinir (LRU)', () async {
      final c = img(max: 1000);
      // _pruneEvery (40) yazimda budama: tavani asan 40 dosya x 100 bayt (4000 > 1000) -> %90 hedefe iner
      for (var i = 0; i < 40; i++) {
        await c.write('https://x/$i.jpg', Uint8List.fromList(List.filled(100, i)));
        if (i % 5 == 0) await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await c.settle();
      expect(await c.totalBytes(), lessThanOrEqualTo(1000));
    });

    test('clear: oturum kapaninca tum gorseller silinir', () async {
      final c = img();
      await c.write('https://x/a.jpg', Uint8List.fromList([1, 2, 3]));
      await c.clear();
      expect(await c.read('https://x/a.jpg'), isNull);
    });
  });

  group('Taze onbellek penceresi (gereksiz yeniden cekim yok)', () {
    ApiClient api(MockClient c, {DiskCache? d}) => ApiClient(client: c, retryDelay: Duration.zero, diskCache: d);

    test('sabit veri (katalog) ve gunluk veri (menu/haber) taze iken aga HIC gidilmez; force gider', () async {
      var n = 0;
      final a = api(MockClient((r) async {
        n++;
        return jr(200, {'n': n}, h: {'etag': '"e$n"'});
      }));
      await a.get('/catalog/faculties');
      await a.get('/catalog/faculties');
      await a.get('/news?type=0');
      await a.get('/news?type=0');
      await a.get('/menu/today');
      await a.get('/menu/today');
      expect(n, 3); // 3 farkli yol, her biri bir kez
      await a.get('/news?type=0', force: true);
      expect(n, 4);
    });

    test('canli uclar (sohbet, bildirim, ozet) her seferinde dogrulanir', () async {
      var n = 0;
      final a = api(MockClient((r) async {
        n++;
        return jr(200, {'n': n}, h: {'etag': '"e"'});
      }))
        ..tokens = Tokens('A', 'R');
      await a.get('/conversations?size=30');
      await a.get('/conversations?size=30');
      await a.get('/me/summary');
      await a.get('/me/summary');
      expect(n, 4);
    });

    test('yazma istegi (RSVP) ilgili kaynagin taze suresini sifirlar', () async {
      var n = 0;
      final a = api(MockClient((r) async {
        n++;
        return r.method == 'GET' ? jr(200, {'n': n}, h: {'etag': '"e$n"'}) : jr(200, {'ok': true});
      }))
        ..tokens = Tokens('A', 'R');
      await a.get('/events');
      await a.get('/events');
      expect(n, 1);
      await a.post('/events/5/rsvp');
      expect(n, 2);
      await a.get('/events'); // artik dogrulanir
      expect(n, 3);
    });

    test('suresi dolmus (diskte dunden kalan) veri If-None-Match ile dogrulanir, 304te govde tasinmaz', () async {
      final old = DateTime.now().subtract(const Duration(days: 1, hours: 2));
      final d1 = DiskCache(dirProvider: () async => tmp, now: () => old);
      await d1.write('tr|a|/menu/today', {'eski': 1}, {'etag': '"m1"'}, const Duration(days: 7));
      await d1.flush();
      final seen = <String?>[];
      final a = api(MockClient((r) async {
        seen.add(r.headers['If-None-Match']);
        return http.Response('', 304);
      }), d: DiskCache(dirProvider: () async => tmp));
      expect(await a.get('/menu/today'), {'eski': 1});
      expect(seen, ['"m1"']);
      // 304 sonrasi tazelendi: ikinci cagri ag istemez
      await a.get('/menu/today');
      expect(seen.length, 1);
    });

    test('canli olmayan ama gunluk veri: dunku kayit bugun ag ile dogrulanir (menu gun degisimi)', () {
      expect(CachePolicy.freshFor('/menu/today'), CachePolicy.dailyFresh);
      expect(CachePolicy.freshFor('/catalog/faculties'), CachePolicy.staticFresh);
      expect(CachePolicy.freshFor('/conversations'), isNull);
      expect(CachePolicy.freshFor('/notifications'), isNull);
      expect(CachePolicy.freshFor('/legal/acceptance-status'), isNull); // yeniden onay kontrolu canli
      expect(CachePolicy.freshFor('/legal/TERMS'), CachePolicy.staticFresh);
    });

    test('buyuk yanit (256 KB ustu) ayri izolatta cozulur ve dogru doner', () async {
      final big = {'items': List.generate(6000, (i) => {'i': i, 's': 'metin $i ' * 3})};
      expect(utf8.encode(jsonEncode(big)).length, greaterThan(ApiClient.isolateDecodeBytes));
      final a = api(MockClient((r) async => jr(200, big)));
      final res = await a.get('/x') as Map;
      expect((res['items'] as List).length, 6000);
    });
  });
}
