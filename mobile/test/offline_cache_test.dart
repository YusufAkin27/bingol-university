import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/cache/cache_policy.dart';
import 'package:bu_kampus/core/cache/disk_cache.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jr(int status, Object body, {Map<String, String> h = const {}}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8', ...h});

void main() {
  late Directory tmp;
  var clock = DateTime(2026, 10, 28, 12);

  DiskCache disk({int total = 16 * 1024 * 1024, int entry = 512 * 1024, int entries = 400}) => DiskCache(
        dirProvider: () async => tmp,
        maxTotalBytes: total,
        maxEntryBytes: entry,
        maxEntries: entries,
        now: () => clock,
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bu_cache_');
    clock = DateTime(2026, 10, 28, 12);
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('DiskCache', () {
    test('yazar, okur, yeniden acilista (indeks) korunur', () async {
      final c = disk();
      await c.write('k1', {'a': 1}, {'etag': '"v1"', 'set-cookie': 'x'}, const Duration(days: 1));
      await c.flush();
      final c2 = disk(); // yeni ornek = uygulama yeniden acildi
      final e = await c2.read('k1');
      expect(e?.body, {'a': 1});
      expect(e?.etag, '"v1"');
      expect(e?.headers.containsKey('set-cookie'), isFalse); // yalniz etag ve x-* saklanir
    });

    test('toplam tavan asilinca en eski girdi atilir (LRU)', () async {
      final c = disk(total: 600, entry: 400);
      final big = 'x' * 150;
      await c.write('a', big, {}, const Duration(days: 1));
      await c.write('b', big, {}, const Duration(days: 1));
      await c.write('c', big, {}, const Duration(days: 1));
      await c.read('a'); // a en yeni kullanilan olur, b en eski
      await c.write('d', big, {}, const Duration(days: 1));
      expect(c.totalBytes, lessThanOrEqualTo(600));
      expect(await c.read('b'), isNull);
      expect(await c.read('a'), isNotNull);
      expect(await c.read('d'), isNotNull);
    });

    test('girdi sayisi sinirlidir', () async {
      final c = disk(entries: 3);
      for (var i = 0; i < 5; i++) {
        await c.write('k$i', i, {}, const Duration(days: 1));
      }
      expect(c.length, 3);
      expect(await c.read('k0'), isNull);
      expect(await c.read('k4'), isNotNull);
    });

    test('girdi basina sinir: buyuk govde yazilmaz', () async {
      final c = disk(entry: 100);
      await c.write('k', 'y' * 500, {}, const Duration(days: 1));
      expect(await c.read('k'), isNull);
      expect(c.totalBytes, 0);
    });

    test('TTL dolan girdi donmez ve silinir', () async {
      final c = disk();
      await c.write('k', 1, {}, const Duration(hours: 24));
      clock = clock.add(const Duration(hours: 23));
      expect(await c.read('k'), isNotNull);
      clock = clock.add(const Duration(hours: 2));
      expect(await c.read('k'), isNull);
      expect(c.length, 0);
    });

    test('clear hepsini siler (disk dosyalari dahil)', () async {
      final c = disk();
      await c.write('k', 1, {}, const Duration(days: 1));
      await c.flush();
      await c.clear();
      expect(await c.read('k'), isNull);
      expect(tmp.listSync(), isEmpty);
      expect(await disk().read('k'), isNull);
    });

    test('bozuk dosya sessizce atilir', () async {
      final c = disk();
      await c.write('k', 1, {}, const Duration(days: 1));
      for (final f in tmp.listSync().whereType<File>()) {
        if (!f.path.endsWith('index.json')) await f.writeAsString('{bozuk');
      }
      expect(await c.read('k'), isNull);
    });
  });

  group('CachePolicy', () {
    test('beyaz liste: haber/menu/akademik diske, mesajlar ve auth degil', () {
      expect(CachePolicy.diskTtl('/news?type=0&page=0&size=3'), const Duration(days: 7));
      expect(CachePolicy.diskTtl('/menu/today'), const Duration(days: 2));
      expect(CachePolicy.diskTtl('/menu?month=2026-10'), const Duration(days: 7));
      expect(CachePolicy.diskTtl('/catalog/academic'), isNotNull);
      expect(CachePolicy.diskTtl('/users/me'), const Duration(days: 3));
      expect(CachePolicy.diskTtl('/communities/categories'), const Duration(days: 1));
      expect(CachePolicy.diskTtl('/conversations/7/messages?size=30'), isNull);
      expect(CachePolicy.diskTtl('/conversations?size=50'), isNull);
      expect(CachePolicy.diskTtl('/auth/me'), isNull);
      expect(CachePolicy.diskTtl('/events/5/checkin-code'), isNull);
      expect(CachePolicy.diskTtl('/support/tickets?size=10'), isNull);
      expect(CachePolicy.diskTtl('/users/me/export'), isNull);
    });

    test('bayat veri: durum/presence/auth sunulmaz', () {
      expect(CachePolicy.allowsStale('/status'), isFalse);
      expect(CachePolicy.allowsStale('/app/info'), isFalse);
      expect(CachePolicy.allowsStale('/users/9/presence'), isFalse);
      expect(CachePolicy.allowsStale('/news?page=0'), isTrue);
      expect(CachePolicy.allowsStale('/conversations?size=50'), isTrue); // yalniz bellekteki
    });
  });

  group('ApiClient onbellek', () {
    ApiClient make(MockClient c, {DiskCache? d, ConnectivityService? cs}) =>
        ApiClient(client: c, retryDelay: Duration.zero, diskCache: d, connectivity: cs ?? ConnectivityService());

    test('ag yokken bellekteki bayat yanit doner (fromCache, cachedAt) ve cevrimdisi isaretlenir', () async {
      var down = false;
      final cs = ConnectivityService();
      final api = make(MockClient((r) async {
        if (down) throw const SocketException('yok');
        return jr(200, {'a': 1}, h: {'etag': '"v1"'});
      }), cs: cs);
      expect(await api.get('/conversations?size=50'), {'a': 1});
      down = true;
      final res = await api.getResponse('/conversations?size=50');
      expect(res.body, {'a': 1});
      expect(res.fromCache, isTrue);
      expect(res.cachedAt, isNotNull);
      expect(cs.online, isFalse);
      expect(cs.lastStaleAt, isNotNull);
    });

    test('cevrimdisinda onbellek yoksa NETWORK hatasi (mevcut davranis)', () async {
      final api = make(MockClient((r) async => throw const SocketException('yok')));
      await expectLater(api.get('/news'), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'ag', true)));
    });

    test('/status ve /app/* ag yokken ASLA bayat donmez (yoklama dogru kalir)', () async {
      var down = false;
      final api = make(MockClient((r) async {
        if (down) throw const SocketException('yok');
        return jr(200, {'ok': true}, h: {'etag': '"s"'});
      }));
      await api.get('/status');
      down = true;
      await expectLater(api.get('/status'), throwsA(isA<ApiError>()));
    });

    test('yeniden aciliste diskten okunur: If-None-Match gider, 304te diskteki govde doner', () async {
      final d1 = disk();
      final api1 = make(MockClient((r) async => jr(200, {'t': 'haber'}, h: {'etag': '"n1"'})), d: d1);
      await api1.get('/news?type=0&page=0&size=3');
      await d1.flush();

      final seen = <String?>[];
      final api2 = make(MockClient((r) async {
        seen.add(r.headers['If-None-Match']);
        return http.Response('', 304);
      }), d: disk());
      expect(await api2.get('/news?type=0&page=0&size=3'), {'t': 'haber'});
      expect(seen, ['"n1"']);
    });

    test('ag yok + yeniden acilis: diskten bayat yanit, sinirli bekleme', () async {
      final d1 = disk();
      final api1 = make(MockClient((r) async => jr(200, [1, 2], h: {'etag': '"e"'})), d: d1);
      await api1.get('/menu/today');
      await d1.flush();
      final api2 = make(MockClient((r) async => throw const SocketException('yok')), d: disk());
      final res = await api2.getResponse('/menu/today');
      expect(res.body, [1, 2]);
      expect(res.fromCache, isTrue);
    });

    test('5xx ve onbellek varsa bayat doner', () async {
      var fail = false;
      final api = make(MockClient((r) async => fail ? jr(500, {'code': 'X'}) : jr(200, {'a': 2}, h: {'etag': '"1"'})));
      await api.get('/news');
      fail = true;
      final res = await api.getResponse('/news');
      expect(res.fromCache, isTrue);
      expect(res.body, {'a': 2});
    });

    test('mesaj icerigi diske yazilmaz', () async {
      final d = disk();
      final api = make(MockClient((r) async => jr(200, {'items': []}, h: {'etag': '"m"'})), d: d);
      await api.get('/conversations/7/messages?size=30');
      await api.get('/conversations?size=50');
      await api.get('/auth/me');
      await d.flush();
      expect(d.length, 0);
    });

    test('cikista (setTokens null) disk onbellegi de temizlenir', () async {
      final d = disk();
      final api = make(MockClient((r) async => jr(200, {'me': 1}, h: {'etag': '"u"'})), d: d)..tokens = Tokens('A', 'R');
      await api.get('/users/me');
      await d.flush();
      expect(d.length, 1);
      await api.setTokens(null);
      await d.flush();
      expect(d.length, 0);
      expect(await disk().read('tr|u|/users/me'), isNull);
    });

    test('getSwr: once onbellek, sonra ag', () async {
      var n = 0;
      final api = make(MockClient((r) async => jr(200, {'n': ++n}, h: {'etag': '"e$n"'})));
      await api.get('/news');
      final order = <String>[];
      final res = await api.getSwr('/news', onCached: (c) => order.add('cache:${(c.body as Map)['n']}'));
      order.add('net:${(res.body as Map)['n']}');
      expect(order, ['cache:1', 'net:2']);
    });

    test('bellek onbellegi bayt tavaniyla sinirlidir', () async {
      final big = 'z' * (1024 * 1024);
      final seen = <String?>[];
      final api = make(MockClient((r) async {
        seen.add(r.headers['If-None-Match']);
        return jr(200, {'b': big}, h: {'etag': '"b"'});
      }));
      for (var i = 0; i < 8; i++) {
        await api.get('/x$i'); // 8 x ~1MB > 6MB tavan
      }
      seen.clear();
      await api.get('/x0'); // en eski: atilmis
      await api.get('/x7'); // en yeni: duruyor
      expect(seen, [null, '"b"']);
    });
  });
}
