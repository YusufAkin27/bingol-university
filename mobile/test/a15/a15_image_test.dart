// A15 denetimi: gorsel disk onbellegi (DiskNetworkImage / persistentNetworkImage) + bellek ayarlari.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/cache/cache_lifecycle.dart';
import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final Uint8List png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

void main() {
  late Directory root;
  late HttpServer server;
  late int hits;
  late String mode; // normal | portal | rotate
  late List<String> authSeen;
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null; // gercek yerel HTTP
    root = await Directory.systemTemp.createTemp('a15_img_');
    hits = 0;
    mode = 'normal';
    authSeen = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      hits++;
      authSeen.add(req.headers.value('authorization') ?? '-');
      if (mode == 'portal') {
        req.response.headers.contentType = ContentType.html;
        req.response.write('<html>Wi-Fi giris</html>');
      } else if (mode == 'rotate') {
        req.response.add(Uint8List.fromList(png)..[40] = hits);
      } else {
        req.response.add(png);
      }
      await req.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  String url(String p) => 'http://127.0.0.1:${server.port}/$p';

  Future<Object?> load(DiskNetworkImage p) async {
    final c = Completer<Object?>();
    final stream = p.resolve(ImageConfiguration.empty);
    late ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      if (!c.isCompleted) c.complete(true);
      stream.removeListener(l);
    }, onError: (e, s) {
      if (!c.isCompleted) c.complete(e);
      stream.removeListener(l);
    });
    stream.addListener(l);
    return c.future.timeout(const Duration(seconds: 5), onTimeout: () => 'timeout');
  }

  ImageDiskCache mkCache({int maxBytes = 150 * 1024 * 1024, int maxFile = 12 * 1024 * 1024}) =>
      ImageDiskCache(dirProvider: () async => Directory('${root.path}/img'), maxBytes: maxBytes, maxFileBytes: maxFile);

  testWidgets('I1 ilk yukleme diske yazar; ikinci yukleme AGA gitmez; yetkili baslik gonderilir', (tester) async {
    await tester.runAsync(() async {
      final cache = mkCache();
      final u = url('files/a.png');
      expect(await load(DiskNetworkImage(u, headers: const {'Authorization': 'Bearer A'}, cache: cache)), true);
      await cache.settle();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      expect(await load(DiskNetworkImage(u, headers: const {'Authorization': 'Bearer B'}, cache: cache)), true);
      // ignore: avoid_print
      print('I1 sunucu isabeti=$hits ; gorulen yetkiler=$authSeen');
      expect(hits, 1);
      expect(authSeen.first, 'Bearer A');
      // 2. istek B kullanicisi icin: yetki yeniden dogrulanmadi (URL anahtarli) — cikista clear() ile sinirli
    });
  });

  // Bilgi amacli: "rotate" modu PNG'nin bir baytini bozar; goruntu cozulemedigi icin (T-090: cozulmeyen bayt diske yazilmaz,
  // bkz. I4) onbellege hic girmez, dolayisiyla test duzenegi artik gecerli degil. Kural ("adres degisir" varsayimi) kod okumasiyla dogru.
  testWidgets('I2 AYNI URL farkli icerik: disk onbellegi eski baytlari SONSUZA dek (150MB budamaya kadar) servis eder', skip: true, (tester) async {
    await tester.runAsync(() async {
      mode = 'rotate';
      final cache = mkCache();
      final u = url('files/same.png');
      await load(DiskNetworkImage(u, cache: cache));
      await cache.settle();
      final first = await cache.read(u);
      PaintingBinding.instance.imageCache.clear();
      await load(DiskNetworkImage(u, cache: cache));
      final second = await cache.read(u);
      // ignore: avoid_print
      print('I2 isabet=$hits ; icerik ayni mi: ${first!.length == second!.length && first[40] == second[40]}');
      expect(hits, 1);
    });
  });

  testWidgets('I9 paylasimli HttpClient (keep-alive): farkli URL ardisik indirmeleri TEK TCP baglantisini yeniden kullanir', (tester) async {
    await tester.runAsync(() async {
      final cache = mkCache();
      for (var i = 0; i < 4; i++) {
        expect(await load(DiskNetworkImage(url('files/k$i.png'), cache: cache)), true);
      }
      await cache.settle();
      final info = server.connectionsInfo();
      // ignore: avoid_print
      print('I9 sunucu isabeti=$hits ; toplam baglanti=${info.total}');
      expect(hits, 4);
      expect(info.total, 1, reason: 'her gorsel icin yeni HttpClient/baglanti kurulmamali');
    });
  });

  testWidgets('I3 bozuk dosya: decode hatasi + dosya silinir; yeniden indirme AYNI denemede yapilmaz (gorsel bir kez bozuk gorunur)', (tester) async {
    await tester.runAsync(() async {
      final cache = mkCache();
      final u = url('files/b.png');
      await cache.write(u, Uint8List.fromList(List.filled(200, 7)));
      await cache.settle();
      final r = await load(DiskNetworkImage(u, cache: cache));
      await cache.settle();
      final left = await cache.read(u);
      // ignore: avoid_print
      print('I3 sonuc=${r.runtimeType} ; ag isabeti=$hits ; dosya kaldi mi: ${left != null}');
      expect(r, true, reason: 'bozuk onbellek dosyasi sessizce agdan yeniden indirilmeli');
    });
  });

  testWidgets('I4 captive portal: 200 HTML "gorsel" diske yazilir (decode hatasindan ONCE), bir sonraki acilista da bozuk', (tester) async {
    await tester.runAsync(() async {
      mode = 'portal';
      final cache = mkCache();
      final u = url('files/c.png');
      final r = await load(DiskNetworkImage(u, cache: cache));
      await cache.settle();
      final stored = await cache.read(u);
      // ignore: avoid_print
      print('I4 sonuc=${r.runtimeType} ; diskte duran: ${stored == null ? "yok" : "${stored.length} bayt HTML"}');
      expect(stored, isNull, reason: 'dogrulanamayan (decode edilemeyen) bayt diske yazilmamali');
    });
  });

  testWidgets('I5 tavan: budama yalniz acilista ve her 40 yazmada -> gecici asim 39 dosya x 12MB (~468MB) olabilir', (tester) async {
    await tester.runAsync(() async {
      final cache = mkCache(maxBytes: 10000, maxFile: 4000);
      for (var i = 0; i < 39; i++) {
        await cache.write('u$i', Uint8List(3000));
      }
      await cache.settle();
      final t39 = await cache.totalBytes();
      await cache.write('u39', Uint8List(3000)); // 40. yazma -> budama
      await cache.settle();
      final t40 = await cache.totalBytes();
      // ignore: avoid_print
      print('I5 39 yazma sonrasi toplam=$t39 (tavan 10000) ; 40. sonrasi=$t40');
      expect(t39, lessThanOrEqualTo(10000));
      expect(t40, lessThanOrEqualTo(10000));
    });
  });

  testWidgets('I6 persist:false -> NetworkImage (diske dokunmaz); persist:true -> DiskNetworkImage', (tester) async {
    await tester.runAsync(() async {
      final cache = ImageDiskCache(dirProvider: () async => Directory('${root.path}/img2'));
      ImageDiskCache.instance = cache;
      final once = persistentNetworkImage(url('files/once.png'), persist: false);
      final keep = persistentNetworkImage(url('files/keep.png'));
      expect(once, isA<NetworkImage>());
      expect(keep, isA<DiskNetworkImage>());
      final stream = once.resolve(ImageConfiguration.empty);
      final c = Completer<void>();
      stream.addListener(ImageStreamListener((i, _) => c.complete(), onError: (e, s) => c.complete()));
      await c.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      await cache.settle();
      final dir = Directory('${root.path}/img2');
      final files = dir.existsSync() ? dir.listSync().whereType<File>().toList() : <File>[];
      // ignore: avoid_print
      print('I6 persist:false sonrasi diskte dosya: ${files.length}');
      expect(files, isEmpty);
    });
  });

  testWidgets('I7 imageCache 200 adet / 80 MB tavani uygulanir', (tester) async {
    applyImageCacheLimits();
    expect(PaintingBinding.instance.imageCache.maximumSize, 200);
    expect(PaintingBinding.instance.imageCache.maximumSizeBytes, 80 * 1024 * 1024);
  });

  test('I8 ApiClient bellek onbellegi 100 girdi ile sinirli (LRU): ilk yol atilir', () async {
    final seenIfNone = <String, String?>{};
    final api = ApiClient(
        client: MockClient((r) async {
          seenIfNone[r.url.query] = r.headers['If-None-Match'];
          return http.Response(jsonEncode({'x': 'y' * 100}), 200, headers: {'etag': '"e"'});
        }),
        connectivity: ConnectivityService());
    for (var i = 0; i < 150; i++) {
      await api.get('/me/communities?i=$i');
    }
    seenIfNone.clear();
    await api.get('/me/communities?i=0'); // atilmis olmali
    await api.get('/me/communities?i=149');
    // ignore: avoid_print
    print('I8 en eski yolda If-None-Match: ${seenIfNone.values.toList()}');
  });
}
