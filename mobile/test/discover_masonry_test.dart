import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
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

  group('kesfet akis', () {
    testWidgets('yalniz gonderi akisi: /feed istenir, haber/kapsam yok, iki sutun kart', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.contains('/feed') && r.contains('scope=top')), isTrue);
      expect(b.requests.any((r) => r.contains('/news')), isFalse);
      expect(find.byType(DiscoverPostCard), findsWidgets);
      expect(find.text('Keşfet'), findsOneWidget);
      // Haber/kategori yok; yalniz Tumu + Populer cipleri.
      expect(find.text('Haberler'), findsNothing);
      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('Popüler'), findsOneWidget);
      // Tek sutun: kartlar ayni sol kenarda (16) ve tam genislikte.
      final lefts = {
        for (final e in tester.elementList(find.byType(DiscoverPostCard))) tester.getTopLeft(find.byWidget(e.widget)).dx.round()
      };
      expect(lefts, {16});
      expect(tester.getSize(find.byType(DiscoverPostCard).first).width, 358);
      // Yorum/kaydet/paylas yok.
      for (final i in [Icons.bookmark_border, Icons.mode_comment_outlined, Icons.send, Icons.share]) {
        expect(find.byIcon(i), findsNothing);
      }
      noErr(tester);
    });

    testWidgets('Populer cipi akisi scope=popular ile bastan yukler', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('discoverChipPopular')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.contains('/feed') && r.contains('scope=popular')), isTrue);
      expect(find.byType(DiscoverPostCard), findsWidgets);
      noErr(tester);
    });

    testWidgets('Tanıyor Olabilirsin: oneriler gelince serit gorunur, Takip Et istegi atar; oneri yoksa bolum gizli',
        (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      b.on('/users/me/follow-suggestions*', {
        'items': [
          {'id': 31, 'displayName': 'Deniz Aksoy', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
          {'id': 32, 'displayName': 'Ece Yılmaz', 'department': 'İktisat', 'followedByMe': false},
        ],
      });
      b.on('/users/31/follow', {'following': true, 'followerCount': 3});
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Tanıyor Olabilirsin'), findsOneWidget);
      expect(find.text('Deniz Aksoy'), findsOneWidget);
      expect(find.text('Takip Et'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('discover-follow-31')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.startsWith('POST') && r.contains('/users/31/follow')), isTrue, reason: b.requests.join('|'));
      expect(find.text('Takiptesin'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      final b2 = FakeBackend();
      fakePosts(b2);
      b2.on('/users/me/follow-suggestions*', {'items': <Object>[]});
      await tester.pumpWidget(buildApp(discover(b2)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('discoverSuggestions')), findsNothing);
      noErr(tester);
    });

    testWidgets('kart: yazar adi + metin alt yazisi; gorselli gonderi 4:3 tam genislik fotograf', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Gönderi 1000'), findsOneWidget);
      expect(find.textContaining('Ayşe Yılmaz'), findsWidgets);
      final photo = find.byKey(const ValueKey('post-photo-999')); // i=1: gorselli
      expect(photo, findsOneWidget);
      final card = tester.getSize(find.byKey(const ValueKey('discover-post-999')));
      final ph = tester.getSize(find.ancestor(of: photo, matching: find.byType(AspectRatio)).first);
      expect(ph.width, card.width);
      expect((ph.width / ph.height - 4 / 3).abs(), lessThan(0.01));
      noErr(tester);
    });

    testWidgets('begeni: PUT atilir, sayi guncellenir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      final card = find.byKey(const ValueKey('discover-post-999'));
      final like = find.descendant(of: card, matching: find.byKey(const ValueKey('like-heart')));
      int count() => int.parse((tester.widget(find.descendant(of: card, matching: find.byKey(const ValueKey('like-count')))) as Text).data!.split(' ').first);
      final before = count();
      expect((tester.widget(find.descendant(of: card, matching: find.byKey(const ValueKey('like-count')))) as Text).data, endsWith('beğeni'));
      // 44 px dokunma alani.
      expect(tester.getSize(like).height, greaterThanOrEqualTo(44));
      await tester.ensureVisible(like);
      await tester.pump();
      await tester.tap(like);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.contains('PUT') && r.contains('/like')), isTrue, reason: b.requests.join(' | '));
      expect(count(), before + 1);
      noErr(tester);
    });

    testWidgets('karta dokununca gonderi detayi acilir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.textContaining('Gönderi 1000'));
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
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -2500));
        await tester.pump();
      }
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

  group('kesfet scope=top imlec zinciri', () {
    Map<String, dynamic> post(int id) => samplePost(id: id, text: 'Top $id');

    FakeBackend topBackend(List<FakeResult? Function(Uri u)> script, List<Uri> seen) {
      final b = FakeBackend();
      b.handlers.add((req, path) {
        if (path != '/feed') return null;
        seen.add(req.url);
        for (final f in script) {
          final r = f(req.url);
          if (r != null) return r;
        }
        return null;
      });
      return b;
    }

    testWidgets('size=12, nextCursor opak aynen geri gider, son sayfada durur', (tester) async {
      useScreen(tester, const Size(390, 844));
      final seen = <Uri>[];
      final b = topBackend([
        (u) => u.queryParameters['cursor'] == null
            ? FakeResult.json({'items': [for (var i = 1; i <= 12; i++) post(i)], 'nextCursor': 'Ab-_c9==x', 'hint': null})
            : null,
        (u) => u.queryParameters['cursor'] == 'Ab-_c9==x'
            ? FakeResult.json({'items': [post(13), post(14)], 'nextCursor': null, 'hint': null})
            : null,
      ], seen);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(seen.first.queryParameters['scope'], 'top');
      expect(seen.first.queryParameters['size'], '12');
      await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 600));
      expect(seen.length, 2);
      expect(seen[1].queryParameters['cursor'], 'Ab-_c9==x');
      await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 600));
      expect(seen.length, 2); // nextCursor null: yeni istek yok
      noErr(tester);
    });

    testWidgets('hint=RANK_REFRESHED: ayni id ikinci kez eklenmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      final seen = <Uri>[];
      final b = topBackend([
        (u) => u.queryParameters['cursor'] == null
            ? FakeResult.json({'items': [post(1), post(2)], 'nextCursor': 'c1', 'hint': null})
            : FakeResult.json({'items': [post(2), post(3)], 'nextCursor': null, 'hint': 'RANK_REFRESHED'}),
      ], seen);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 600));
      expect(seen.length, 2);
      expect(find.byType(DiscoverPostCard), findsNWidgets(3));
      noErr(tester);
    });

    testWidgets('400 POST_CURSOR_INVALID: akis imlecsiz bastan yuklenir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final seen = <Uri>[];
      final b = topBackend([
        (u) => u.queryParameters['cursor'] == null
            ? FakeResult.json({'items': [post(1), post(2)], 'nextCursor': 'bad', 'hint': null})
            : const FakeResult.json({'code': 'POST_CURSOR_INVALID', 'message': 'x'}, status: 400),
      ], seen);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 800));
      // 1) ilk sayfa, 2) bozuk imleç, 3) imlecsiz yeniden yukleme
      expect(seen.length, greaterThanOrEqualTo(3));
      expect(seen.last.queryParameters.containsKey('cursor'), isFalse);
      expect(find.byType(DiscoverPostCard), findsNWidgets(2));
      noErr(tester);
    });

    testWidgets('cekip yenileme imleci sifirlar', (tester) async {
      useScreen(tester, const Size(390, 844));
      final seen = <Uri>[];
      final b = topBackend([
        (u) => FakeResult.json({'items': [post(1), post(2)], 'nextCursor': u.queryParameters['cursor'] == null ? 'c1' : null, 'hint': null}),
      ], seen);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -3000));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.fling(find.byType(CustomScrollView).last, const Offset(0, 600), 2000);
      await settle(tester, const Duration(milliseconds: 1500));
      expect(seen.where((u) => !u.queryParameters.containsKey('cursor')).length, greaterThanOrEqualTo(2));
      noErr(tester);
    });
  });
}
