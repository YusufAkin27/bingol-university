import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

Widget discover(FakeBackend b, [ValueNotifier<String?>? req]) =>
    DiscoverTab(session: makeSession(b), typeRequest: req ?? ValueNotifier<String?>(null));

void main() {
  setUpAll(loadTestFonts);

  group('kesfet masonry', () {
    testWidgets('yalniz gonderi akisi: /feed istenir, haber/kapsam yok, iki sutun kart', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.contains('/feed') && r.contains('scope=latest')), isTrue);
      expect(b.requests.any((r) => r.contains('/news')), isFalse);
      expect(find.byType(DiscoverPostCard), findsWidgets);
      expect(find.text('Keşfet'), findsOneWidget);
      // Kategori/segment yok.
      expect(find.text('Haberler'), findsNothing);
      expect(find.text('Popüler'), findsNothing);
      // Iki sutun: kartlar iki farkli sol kenara dizilir.
      final lefts = {
        for (final e in tester.elementList(find.byType(DiscoverPostCard))) tester.getTopLeft(find.byWidget(e.widget)).dx.round()
      };
      expect(lefts.length, 2);
      noErr(tester);
    });

    testWidgets('gorselsiz gonderi renkli metin karti, gorselli gonderi gorsel karti', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('discoverQuote')), findsWidgets);
      expect(find.text('Gönderi 1000'), findsOneWidget);
      expect(find.byKey(const ValueKey('discoverImgError')), findsWidgets);
      noErr(tester);
    });

    testWidgets('begeni: PUT atilir, sayi guncellenir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      final like = find.byKey(const ValueKey('discover-like')).first;
      final before = int.parse((tester.widget(find.byKey(const ValueKey('discover-like-count')).first) as Text).data!);
      // 44 px dokunma alani.
      expect(tester.getSize(like).height, greaterThanOrEqualTo(44));
      await tester.tap(like);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.contains('PUT') && r.contains('/like')), isTrue, reason: b.requests.join(' | '));
      final after = int.parse((tester.widget(find.byKey(const ValueKey('discover-like-count')).first) as Text).data!);
      expect(after, before + 1);
      noErr(tester);
    });

    testWidgets('karta dokununca gonderi detayi acilir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Gönderi 1000'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(PostDetailPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(PostDetailPage))).pop();
      await settle(tester, const Duration(milliseconds: 400));
      noErr(tester);
    });

    testWidgets('arama kutusu ve + dugmesi gorunur; typeRequest tuketilip null olur', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final r = ValueNotifier<String?>('HABER');
      addTearDown(r.dispose);
      await tester.pumpWidget(buildApp(discover(b, r)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.value, isNull);
      expect(find.byKey(const ValueKey('discoverSearch')), findsOneWidget);
      expect(find.byTooltip('Gönderi oluştur'), findsOneWidget);
      r.value = 'DUYURU';
      expect(r.value, isNull);
      noErr(tester);
    });

    testWidgets('yukleniyor iskeleti -> dolu', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend()..delay = const Duration(milliseconds: 200);
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('discoverSkeleton')), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('discoverSkeleton')), findsNothing);
      expect(find.byType(DiscoverPostCard), findsWidgets);
      noErr(tester);
    });

    testWidgets('bos akis: bos metin; hata: yeniden dene veriyi getirir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, empty: true);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(DiscoverPostCard), findsNothing);
      expect(find.textContaining('Henüz gönderi yok'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      final b2 = FakeBackend();
      final fp = fakePosts(b2)..failFeed = true;
      await tester.pumpWidget(buildApp(discover(b2)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Yeniden dene'), findsWidgets);
      fp.failFeed = false;
      await tester.tap(find.text('Yeniden dene').first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(DiscoverPostCard), findsWidgets);
      noErr(tester);
    });

    testWidgets('sayfalama: sonuna kaydirinca sonraki imlec istenir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, count: 40, pageSize: 12);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.where((r) => r.contains('/feed')).length, 1);
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -2500));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.contains('/feed') && r.contains('cursor=p2')), isTrue);
      noErr(tester);
    });

    for (final size in [const Size(320, 640), const Size(390, 844), const Size(430, 932)]) {
      for (final br in Brightness.values) {
        for (final rtl in [false, true]) {
          testWidgets('${size.width.toInt()} ${br.name} ${rtl ? 'rtl' : 'ltr'}: tasma yok', (tester) async {
            useScreen(tester, size);
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            final b = FakeBackend();
            fakePosts(b);
            Widget page = discover(b);
            if (rtl) page = Directionality(textDirection: TextDirection.rtl, child: page);
            await tester.pumpWidget(buildApp(page, brightness: br, size: size));
            await settle(tester, const Duration(milliseconds: 600));
            expect(find.byType(DiscoverPostCard), findsWidgets);
            noErr(tester);
          });
        }
      }
    }
  });

  group('kesfet kart yuksekligi', () {
    test('gorsel orana gore 150-250 arasi, metin uzunluga gore', () {
      final tall = Post.fromJson(samplePost(id: 1, media: [samplePostMedia(width: 500, height: 1000)]));
      final wide = Post.fromJson(samplePost(id: 2, media: [samplePostMedia(width: 1600, height: 900)]));
      expect(DiscoverPostCard.heightFor(tall, 165), inInclusiveRange(150, 250));
      expect(DiscoverPostCard.heightFor(wide, 165), inInclusiveRange(150, 250));
      expect(DiscoverPostCard.heightFor(tall, 165), greaterThan(DiscoverPostCard.heightFor(wide, 165)));
      final short = Post.fromJson(samplePost(id: 3, text: 'a'));
      final long = Post.fromJson(samplePost(id: 4, text: 'a' * 300));
      expect(DiscoverPostCard.heightFor(long, 165), greaterThan(DiscoverPostCard.heightFor(short, 165)));
    });
  });
}
