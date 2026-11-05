import 'dart:async';
import 'dart:io';

import 'package:bu_kampus/core/cache/video_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keşfet video önyükleme hattı: kuyruk önceliği, eşzamanlılık, LRU, .part temizliği, mobil veri kuralı, çift indirme yok.

class _Fetch {
  final calls = <String>[];
  final gates = <String, Completer<void>>{};
  final sizes = <String, int>{};
  final failing = <String>{};
  int running = 0;
  int maxRunning = 0;

  Completer<void> gate(String url) => gates.putIfAbsent(url, Completer<void>.new);

  Future<VideoFetchResponse> call(Uri uri, Map<String, String> headers) async {
    final url = uri.toString();
    calls.add(url);
    running++;
    if (running > maxRunning) maxRunning = running;
    try {
      if (gates.containsKey(url)) await gates[url]!.future;
      if (failing.contains(url)) return VideoFetchResponse(statusCode: 500, body: const Stream<List<int>>.empty());
      final n = sizes[url] ?? 1000;
      return VideoFetchResponse(
        statusCode: 200,
        contentLength: n,
        body: Stream<List<int>>.fromIterable([List.filled(n ~/ 2, 7), List.filled(n - n ~/ 2, 7)]),
      );
    } finally {
      running--;
    }
  }
}

String u(int id) => 'https://x/api/posts/media/$id';
VideoPrefetchItem it(int id) => VideoPrefetchItem(u(id), const {'Authorization': 'Bearer t'});

void main() {
  late Directory dir;
  late _Fetch fetch;
  var now = DateTime(2026, 11, 5, 12);
  var metered = false;

  VideoPrefetcher make({int concurrent = 2, int maxFile = 50000, int total = 300000, int meteredLimit = 2}) => VideoPrefetcher(
        dirProvider: () async => dir,
        fetcher: fetch.call,
        meteredCheck: () async => metered,
        maxConcurrent: concurrent,
        maxFileBytes: maxFile,
        maxTotalBytes: total,
        meteredLimit: meteredLimit,
        now: () => now,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vp_test');
    fetch = _Fetch();
    now = DateTime(2026, 11, 5, 12);
    metered = false;
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('anahtar: media kimligi; diger adreslerde sha1', () {
    expect(VideoPrefetcher.keyOf(u(42)), 'v42');
    expect(VideoPrefetcher.keyOf('https://x/api/posts/media/42?thumb=true'), 'v42');
    expect(VideoPrefetcher.keyOf('https://x/y.mp4').length, 40);
  });

  test('kuyruk onceligi: yakin olan once indirilir; ayni anda en cok 2 indirme', () async {
    final p = make();
    for (var i = 1; i <= 4; i++) {
      fetch.gate(u(i));
    }
    p.plan([it(1), it(2), it(3), it(4)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fetch.calls, [u(1), u(2)]);
    expect(p.activeCount, 2);
    fetch.gates[u(1)]!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fetch.calls, [u(1), u(2), u(3)]); // siradaki
    fetch.gates[u(2)]!.complete();
    fetch.gates[u(3)]!.complete();
    fetch.gates[u(4)]!.complete();
    await p.settle();
    expect(fetch.calls, [u(1), u(2), u(3), u(4)]);
    expect(fetch.maxRunning, lessThanOrEqualTo(2));
    expect(await p.localFile(u(1)), isNotNull);
    expect(await p.localFile(u(4)), isNotNull);
  });

  test('cift indirme yok: ayni video yeniden planlanirsa bir kez iner; inen dosya tekrar istenmez', () async {
    final p = make();
    fetch.gate(u(1));
    p.plan([it(1)]);
    p.plan([it(1), it(2)]);
    p.plan([it(1), it(2)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fetch.calls.where((c) => c == u(1)).length, 1);
    fetch.gates[u(1)]!.complete();
    await p.settle();
    p.plan([it(1), it(2)]);
    await p.settle();
    expect(fetch.calls.where((c) => c == u(1)).length, 1);
    expect(fetch.calls.where((c) => c == u(2)).length, 1);
  });

  test('.part: bitince yeniden adlandirilir; yarim kalan .part acilista silinir; hata/iptalde .part kalmaz', () async {
    // Onceden kalmis yarim indirme
    await File('${dir.path}${Platform.pathSeparator}v9.part').writeAsBytes([1, 2, 3]);
    final p = make();
    fetch.failing.add(u(1));
    p.plan([it(1), it(2)]);
    await p.settle();
    final names = [for (final e in dir.listSync()) e.uri.pathSegments.last]..sort();
    expect(names, ['v2.mp4']); // v9.part silindi, v1 basarisiz (.part yok), v2 tamam
    expect(await p.localFile(u(1)), isNull);
  });

  test('basarisiz indirme 2 dk geri cekilir, sonra yeniden denenir; kullaniciya hata yansimaz', () async {
    final p = make();
    fetch.failing.add(u(1));
    p.plan([it(1)]);
    await p.settle();
    expect(fetch.calls.length, 1);
    p.plan([it(1)]);
    await p.settle();
    expect(fetch.calls.length, 1, reason: 'geri cekilme suresi dolmadi');
    now = now.add(const Duration(minutes: 3));
    fetch.failing.clear();
    p.plan([it(1)]);
    await p.settle();
    expect(fetch.calls.length, 2);
    expect(await p.localFile(u(1)), isNotNull);
  });

  test('tek dosya ust siniri: icerik-uzunlugu uzerindeyse atlanir ve bir daha denenmez', () async {
    final p = make(maxFile: 5000);
    fetch.sizes[u(1)] = 9000;
    p.plan([it(1)]);
    await p.settle();
    expect(await p.localFile(u(1)), isNull);
    expect(dir.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
    p.plan([it(1)]);
    await p.settle();
    expect(fetch.calls.length, 1);
  });

  test('LRU: toplam tavan asilinca en az kullanilan silinir, gecerli plandakiler korunur', () async {
    final p = make(total: 3500, concurrent: 1);
    for (var i = 1; i <= 3; i++) {
      p.plan([it(i)]);
      await p.settle();
      // dosya zamanlari farkli olsun
      final f = await p.localFile(u(i));
      await f!.setLastModified(DateTime(2026, 11, 5, 10, i));
    }
    expect(dir.listSync().length, 3); // 3 x 1000 <= 3500: hicbiri silinmedi
    p.plan([it(4)]);
    await p.settle();
    final names = [for (final e in dir.listSync()) e.uri.pathSegments.last]..sort();
    expect(names.contains('v4.mp4'), isTrue); // plandaki korunur
    expect(names.contains('v1.mp4'), isFalse); // en eski silindi
    expect(names.contains('v2.mp4') && names.contains('v3.mp4'), isTrue);
    expect(await p.totalBytes(), lessThanOrEqualTo(3500));
  });

  test('mobil veri: yalniz plandaki ilk 2 video indirilir; Wi-Fi\'de tamami', () async {
    metered = true;
    final p = make();
    p.plan([it(1), it(2), it(3), it(4)]);
    await p.settle();
    expect(fetch.calls, [u(1), u(2)]);

    final dir2 = await Directory.systemTemp.createTemp('vp_test2');
    addTearDown(() => dir2.delete(recursive: true));
    final f2 = _Fetch();
    final wifi = VideoPrefetcher(dirProvider: () async => dir2, fetcher: f2.call, meteredCheck: () async => false, now: () => now);
    wifi.plan([it(1), it(2), it(3), it(4)]);
    await wifi.settle();
    expect(f2.calls.length, 4);
  });

  test('ensure: hazirsa hemen dosya; planda ise bekler; zaman asiminda null (cagiran agdan oynatir)', () async {
    final p = make();
    fetch.gate(u(1));
    p.plan([it(1)]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final waiting = p.ensure(it(1), wait: const Duration(seconds: 2));
    fetch.gates[u(1)]!.complete();
    final f = await waiting;
    expect(f, isNotNull);
    expect(await f!.length(), 1000);
    // Ayni anahtar: ikinci ensure hazir dosyayi hemen verir, yeni indirme yok.
    expect(await p.ensure(it(1)), isNotNull);
    expect(fetch.calls.length, 1);

    // Zaman asimi: kapi hic acilmaz.
    fetch.gate(u(2));
    final t = await p.ensure(it(2), wait: const Duration(milliseconds: 80));
    expect(t, isNull);
    fetch.gates[u(2)]!.complete();
    await p.settle();
  });

  test('ensure mobil veride plan disindaki video icin indirme baslatmaz (veri tasarrufu)', () async {
    metered = true;
    final p = make();
    p.plan([it(1), it(2), it(3)]);
    await p.settle();
    final before = fetch.calls.length;
    expect(await p.ensure(it(7), wait: const Duration(milliseconds: 50)), isNull);
    expect(fetch.calls.length, before);
  });

  test('arka plan: yeni indirme baslamaz, one gelince surer', () async {
    final p = make();
    p.setForeground(false);
    p.plan([it(1), it(2)]);
    await p.settle();
    expect(fetch.calls, isEmpty);
    p.setForeground(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await p.settle();
    expect(fetch.calls.length, 2);
  });

  test('clear: kuyruk ve dosyalar silinir; devre disi ornek hicbir sey yapmaz', () async {
    final p = make();
    p.plan([it(1), it(2)]);
    await p.settle();
    expect(dir.listSync(), isNotEmpty);
    await p.clear();
    expect(dir.listSync(), isEmpty);
    expect(await p.localFile(u(1)), isNull);

    final off = VideoPrefetcher.disabled();
    off.plan([it(1)]);
    expect(await off.localFile(u(1)), isNull);
    expect(await off.ensure(it(1)), isNull);
    expect(off.activeCount, 0);
  });
}
