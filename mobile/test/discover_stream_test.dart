import 'dart:async';
import 'dart:io';

import 'package:bu_kampus/core/cache/video_prefetch.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_video.dart';
import 'package:bu_kampus/features/reels/reels_feed.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'kesfet_ks_test.dart' show FakeVideoPlatformKs, videoPost;
import 'support/fake_app.dart';

/// Keşfet tek akış: video kutusu da fotoğraf gibi DİKEY GÖNDERİ AKIŞINI açar (tam ekran Reels açılmaz); akışta video
/// satır içi oynar, dokununca durur/sürer, ses ayrı düğme; yerel önyükleme dosyasından çalar, hazır değilse poster kalır.

class _FakePrefetch extends VideoPrefetcher {
  _FakePrefetch() : super.disabled();

  final plans = <List<String>>[];
  File? ready;
  Completer<File?>? pending;
  int ensureCalls = 0;

  @override
  void plan(List<VideoPrefetchItem> ordered) => plans.add([for (final e in ordered) e.url]);

  @override
  Future<File?> localFile(String url) async => ready;

  @override
  Future<File?> ensure(VideoPrefetchItem item, {Duration wait = const Duration(seconds: 4)}) {
    ensureCalls++;
    if (ready != null) return Future<File?>.value(ready);
    return pending?.future.timeout(wait, onTimeout: () => null) ?? Future<File?>.value(null);
  }
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

Map<String, dynamic> photo(int id, {bool liked = false, int likes = 3}) =>
    samplePost(id: id, text: 'Foto $id', media: [samplePostMedia(id: id * 10)], liked: liked, likeCount: likes);

void feedWith(FakeBackend b, List<Map<String, dynamic>> items) {
  b.on('/feed*', {'items': items, 'nextCursor': null});
  b.on('/feed/seen', null, status: 204);
  b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
  for (final p in items) {
    b.on('/posts/${p['id']}', p);
  }
}

Widget discover(FakeBackend b) => DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null));

Finder box(int id) => find.byKey(ValueKey('discover-post-$id'));

void main() {
  setUpAll(loadTestFonts);

  late FakeVideoPlatformKs plat;
  late _FakePrefetch prefetch;

  setUp(() {
    plat = FakeVideoPlatformKs();
    final prev = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = plat;
    prefetch = _FakePrefetch();
    final prevPrefetch = VideoPrefetcher.instance;
    VideoPrefetcher.instance = prefetch;
    postVideoMuted.value = true;
    addTearDown(() {
      VideoPlayerPlatform.instance = prev;
      VideoPrefetcher.instance = prevPrefetch;
      postVideoMuted.value = true;
    });
  });

  group('video kutusu -> dikey akis', () {
    testWidgets('video kutusuna basinca tam ekran Reels ACILMAZ: dikey gonderi akisi, tiklanan ortada, ustte onceki', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feedWith(b, [photo(11), videoPost(id: 12), photo(13), videoPost(id: 14)]);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tapAt(tester.getCenter(box(12)));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(PostDetailPage), findsOneWidget);
      expect(find.byType(ReelsFeed), findsNothing);
      expect(b.count('/feed/reels'), 0);
      // Tiklanan video gonderi ustte (ust cubugun hemen altinda), altinda 13, ustunde 11.
      final y12 = tester.getTopLeft(find.byKey(const ValueKey('stream-post-12'))).dy;
      expect(y12, inInclusiveRange(56, 130));
      expect(tester.getTopLeft(find.byKey(const ValueKey('stream-post-13'))).dy, greaterThan(y12));
      await tester.drag(find.byKey(const ValueKey('postStream')), const Offset(0, 600));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('stream-post-11')), findsOneWidget);
      // Populerlik puani / sayaci yok.
      expect(find.textContaining('Popülerlik'), findsNothing);
      expect(find.textContaining('/ 100'), findsNothing);
      noErr(tester);
    });

    testWidgets('fotograf kutusu da ayni akisi acar; video kutusunda orta oynat diski yok, sade sure hapi var', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feedWith(b, [photo(11), videoPost(id: 12)]);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.descendant(of: box(12), matching: find.byKey(const ValueKey('videoDuration'))), findsOneWidget);
      expect(find.descendant(of: box(11), matching: find.byKey(const ValueKey('videoDuration'))), findsNothing);
      await tester.tapAt(tester.getCenter(box(11)));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(PostDetailPage), findsOneWidget);
      expect(find.byType(ReelsFeed), findsNothing);
      noErr(tester);
    });
  });

  group('akista video', () {
    Future<void> openVideo(WidgetTester tester, FakeBackend b) async {
      feedWith(b, [videoPost(id: 12), photo(13), photo(14)]);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tapAt(tester.getCenter(box(12)));
      await settle(tester, const Duration(milliseconds: 1200));
    }

    testWidgets('ekranda %60+ gorunurken kendiliginden SESSIZ oynar; dokununca durur, tekrar dokununca surer; ikon kisa gorunup solar',
        (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      await openVideo(tester, b);
      expect(plat.created, isNotEmpty);
      expect(plat.calls, contains('play'));
      expect(plat.volumes.last, 0); // varsayilan sessiz
      final video = find.byKey(const ValueKey('postVideo'));
      expect(video, findsOneWidget);
      // Dokunus -> duraklat (cift dokunus gecikmesi 300 ms).
      final playsBefore = plat.calls.where((c) => c == 'play').length;
      await tester.tap(video);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));
      expect(plat.calls.last, 'pause');
      expect(find.byKey(const ValueKey('postVideoFlash')), findsOneWidget); // ikon gorunur
      expect(find.byIcon(BuIcons.pauseFilled), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('postVideoFlash')), findsNothing); // sondu
      // Tekrar dokunus -> devam.
      await tester.tap(video);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));
      expect(plat.calls.where((c) => c == 'play').length, greaterThan(playsBefore));
      expect(plat.calls.last, 'play');
      expect(find.byIcon(BuIcons.playFilled), findsWidgets);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('postVideoFlash')), findsNothing);
      // Duraklatma kalici disk/ikon birakmaz; tam ekran dugmesi yok.
      expect(find.byKey(const ValueKey('postVideoFullscreen')), findsNothing);
      noErr(tester);
    });

    testWidgets('ses dugmesi: varsayilan sessiz; dokununca ses acilir ve tercih oturum boyunca kalir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      await openVideo(tester, b);
      expect(postVideoMuted.value, isTrue);
      final before = plat.calls.where((c) => c == 'play' || c == 'pause').length;
      await tester.tap(find.byKey(const ValueKey('postVideoSound')).first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(postVideoMuted.value, isFalse);
      expect(plat.volumes.last, 1);
      // Ses dugmesi oynatmayi durdurmaz.
      expect(plat.calls.where((c) => c == 'play' || c == 'pause').length, before);
      await tester.tap(find.byKey(const ValueKey('postVideoSound')).first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(postVideoMuted.value, isTrue);
      expect(plat.volumes.last, 0);
      noErr(tester);
    });

    testWidgets('ekrandan cikinca durur ve oynatici atilir (bellek); geri gelince yeniden oynar', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      await openVideo(tester, b);
      expect(plat.created.length, 1);
      await tester.drag(find.byKey(const ValueKey('postStream')), const Offset(0, -1400));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(plat.disposed, isNotEmpty);
      await tester.drag(find.byKey(const ValueKey('postStream')), const Offset(0, 1400));
      await settle(tester, const Duration(milliseconds: 900));
      expect(plat.created.length, 2);
      expect(plat.calls.last, 'play');
      noErr(tester);
    });

    testWidgets('yerel dosya HAZIRSA oynatici dosyadan kurulur (ag adresi degil)', (tester) async {
      useScreen(tester, const Size(390, 844));
      prefetch.ready = File('C:/tmp/video_prefetch/v12.mp4');
      final b = FakeBackend();
      await openVideo(tester, b);
      expect(plat.created, isNotEmpty);
      final ds = plat.created.first;
      expect(ds.sourceType, DataSourceType.file);
      expect(ds.uri, contains('v12.mp4'));
      expect(plat.calls, contains('play'));
      noErr(tester);
    });

    testWidgets('dosya HAZIR DEGILKEN poster gorunur, oynatici KURULMAZ (donma yok); gelince kesintisiz baslar', (tester) async {
      useScreen(tester, const Size(390, 844));
      prefetch.pending = Completer<File?>();
      final b = FakeBackend();
      await openVideo(tester, b);
      expect(prefetch.ensureCalls, greaterThan(0));
      expect(plat.created, isEmpty, reason: 'dosya gelene dek oynatici kurulmaz');
      expect(find.byKey(const ValueKey('post-poster-12')), findsOneWidget); // poster hemen gorunur
      // Indirme tamamlanir -> dosyadan baslar.
      prefetch.pending!.complete(File('C:/tmp/video_prefetch/v12.mp4'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(plat.created.length, 1);
      expect(plat.created.first.sourceType, DataSourceType.file);
      expect(plat.calls, contains('play'));
      noErr(tester);
    });

    testWidgets('dosya gelmezse (zaman asimi/hata) kisa beklemeden sonra agdan oynar', (tester) async {
      useScreen(tester, const Size(390, 844));
      prefetch.pending = Completer<File?>(); // hic tamamlanmaz
      final b = FakeBackend();
      await openVideo(tester, b);
      expect(plat.created, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester, const Duration(milliseconds: 600));
      expect(plat.created.length, 1);
      expect(plat.created.first.sourceType, DataSourceType.network);
      expect(plat.calls, contains('play'));
      noErr(tester);
    });
  });

  group('onyukleme sirasi', () {
    testWidgets('sayfa gelince gorunur alanin ilerisindeki videolar yakinlik sirasiyla planlanir (en cok 6)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feedWith(b, [
        photo(1),
        for (var i = 0; i < 8; i++) videoPost(id: 100 + i),
        photo(2),
      ]);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      expect(prefetch.plans, isNotEmpty);
      final last = prefetch.plans.last;
      expect(last.length, lessThanOrEqualTo(6));
      // Sira akis sirasidir (yakin olan once): 100, 101, 102 ...
      final ids = [for (final u in last) int.parse(RegExp(r'/media/(\d+)').firstMatch(u)!.group(1)!)];
      expect(ids, [for (var i = 0; i < ids.length; i++) ids.first + i]);
      expect(ids.first, greaterThanOrEqualTo(100));
      noErr(tester);
    });
  });

  group('kalp', () {
    testWidgets('kutu: beğenmemis BOS cizgi kalp (beyaz degil), beğenmis DOLU KIRMIZI; dokununca PUT/DELETE; >=44 dp hedef', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feedWith(b, [photo(21, liked: true, likes: 7), photo(22, liked: false, likes: 2)]);
      b.on('/posts/21/like', {'liked': false, 'likeCount': 6});
      b.on('/posts/22/like', {'liked': true, 'likeCount': 3});
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      const t = BuTokens.light;
      final liked = tester.widget<Icon>(find.descendant(of: box(21), matching: find.byIcon(BuIcons.heartFilled)));
      expect(liked.color, t.pr);
      expect(find.descendant(of: box(21), matching: find.byIcon(BuIcons.heart)), findsNothing);
      final empty = tester.widget<Icon>(find.descendant(of: box(22), matching: find.byIcon(BuIcons.heart)));
      expect(empty.color, t.ink);
      expect(empty.color, isNot(t.onMedia));
      // Dokunma hedefi >= 44 dp.
      final target = find.ancestor(of: find.descendant(of: box(22), matching: find.byKey(const ValueKey('like-heart'))), matching: find.byType(GestureDetector)).first;
      expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
      await tester.tap(find.descendant(of: box(22), matching: find.byKey(const ValueKey('like-heart'))));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.requests.where((r) => r == 'PUT /posts/22/like').length, 1);
      final nowLiked = tester.widget<Icon>(find.descendant(of: box(22), matching: find.byIcon(BuIcons.heartFilled)));
      expect(nowLiked.color, t.pr);
      await tester.tap(find.descendant(of: box(21), matching: find.byKey(const ValueKey('like-heart'))));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.requests.where((r) => r == 'DELETE /posts/21/like').length, 1);
      expect(find.descendant(of: box(21), matching: find.byIcon(BuIcons.heart)), findsOneWidget);
      noErr(tester);
    });

    testWidgets('akista beğenilen gonderi geri donunce kutuda kirmizi dolu kalp olur (paylasilan durum)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feedWith(b, [photo(31), photo(32)]);
      b.on('/posts/31/like', {'liked': true, 'likeCount': 4});
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tapAt(tester.getCenter(box(32)));
      await settle(tester, const Duration(milliseconds: 900));
      // 32 ortada, 31 ustunde: yukari kaydir, 31'i begen.
      await tester.drag(find.byKey(const ValueKey('postStream')), const Offset(0, 600));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('stream-post-31')), matching: find.byKey(const ValueKey('like-heart'))));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('postBack')));
      await settle(tester, const Duration(milliseconds: 800));
      final icon = tester.widget<Icon>(find.descendant(of: box(31), matching: find.byIcon(BuIcons.heartFilled)));
      expect(icon.color, BuTokens.light.pr);
      noErr(tester);
    });
  });

  group('sekme donusu', () {
    testWidgets('masonry state: DiscoverMasonryFeed tabActive gizlenip 3 dk+ sonra donunce imlecsiz yenileme yapar', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feedWith(b, [photo(41), photo(42)]);
      final s = makeSession(b);
      Widget tab(bool a) => buildApp(Scaffold(body: DiscoverMasonryFeed(session: s, tabActive: a)));
      await tester.pumpWidget(tab(true));
      await settle(tester, const Duration(milliseconds: 800));
      final first = b.count('GET /feed?');
      expect(first, greaterThanOrEqualTo(1));
      var clock = DateTime(2026, 11, 5, 12);
      DiscoverMasonryFeed.debugNow = () => clock;
      addTearDown(() => DiscoverMasonryFeed.debugNow = DateTime.now);
      await tester.pumpWidget(tab(false));
      await tester.pump();
      // 3 dakikadan uzun gizli kalma: saati ilerlet.
      clock = clock.add(const Duration(minutes: 4));
      await tester.pumpWidget(tab(true));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.count('GET /feed?'), greaterThan(first));
      expect(b.requests.where((r) => r.startsWith('GET /feed?')).every((r) => !r.contains('cursor=')), isTrue);
      noErr(tester);
    });
  });

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    for (final br in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('akis ${size.width.toInt()} ${br.name} ${rtl ? 'rtl' : 'ltr'} x1.3: tasma yok (foto + video)', (tester) async {
          useScreen(tester, size);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final b = FakeBackend();
          feedWith(b, [photo(51), videoPost(id: 52), photo(53)]);
          Widget page = discover(b);
          if (rtl) page = Directionality(textDirection: TextDirection.rtl, child: page);
          await tester.pumpWidget(buildApp(page, brightness: br, size: size));
          await settle(tester, const Duration(milliseconds: 800));
          await tester.tapAt(tester.getCenter(box(52)));
          await settle(tester, const Duration(milliseconds: 900));
          expect(find.byType(PostDetailPage), findsOneWidget);
          noErr(tester);
          await tester.drag(find.byKey(const ValueKey('postStream')), const Offset(0, -700));
          await settle(tester, const Duration(milliseconds: 400));
          noErr(tester);
        });
      }
    }
  }
}
