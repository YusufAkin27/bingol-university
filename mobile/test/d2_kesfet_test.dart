import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuChip;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';

/// D2: Keşfet sadeleşmesi (anket girişi yok, 4:5 sabit oran, küçük resim + tam boy, öneri şeridi akış içinde,
/// önbellekten anında ilk çizim) ve Anketler girişinin Ana Sayfa Hızlı Erişim'e taşınması.
void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

void main() {
  setUpAll(loadTestFonts);

  Widget discover(FakeBackend b) =>
      DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null));

  group('kesfet sade tasarim', () {
    testWidgets('ust alan: baslik, arama ve paylas simgesi; kapsul filtre, anket ve "Ogrenci Akisi" basligi yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Keşfet'), findsNothing); // sayfa başlığı görünmez (sadeleştirme)
      expect(find.byKey(const ValueKey('discoverSearch')), findsOneWidget);
      expect(find.byTooltip('Gönderi oluştur'), findsOneWidget);
      expect(find.byType(BuChip), findsNothing);
      expect(find.text('Senin İçin'), findsNothing);
      expect(find.byTooltip('Anketler'), findsNothing);
      expect(find.byIcon(BuIcons.vote), findsNothing);
      expect(find.text('Anketler'), findsNothing);
      expect(find.text('Öğrenci Akışı'), findsNothing);
      expect(find.textContaining('nabzını'), findsNothing); // uzun alt baslik kalkti
      noErr(tester);
    });

    testWidgets('arama simgesi arama sayfasini acar', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('discoverSearch')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(SearchPage), findsOneWidget);
      noErr(tester);
    });

    testWidgets('masonry kutusu yalniz kucuk resim yukler (tam boy yok); detay fotografi kucuk resim + tam boy', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      // Kesfet kutusu (179 dp): tam boy indirilmez, yalniz `thumbUrl` katmani vardir (bellek/veri tasarrufu).
      expect(find.byKey(const ValueKey('post-photo-999')), findsNothing);
      final thumb = find.byKey(const ValueKey('post-thumb-999'));
      expect(thumb, findsOneWidget);
      int? decodeW(Finder f) {
        final img = tester.widget<Image>(f).image;
        return img is ResizeImage ? img.width : null;
      }

      // 179 dp x dpr 1 (test) -> alt sinir 320; hicbir zaman 1080 px'i asmaz.
      expect(decodeW(thumb)!, inInclusiveRange(320, 1080));
      await tester.pumpWidget(const SizedBox());

      // Gonderi sayfasi / detay fotografi (progressive): once kucuk resim, ustunde tam boy.
      await tester.pumpWidget(buildApp(Scaffold(
        body: PostPhoto(
          session: makeSession(b),
          post: Post.fromJson(samplePost(id: 999, media: [samplePostMedia(id: 9990)])),
          progressive: true,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));
      final full = find.byKey(const ValueKey('post-photo-999'));
      expect(full, findsOneWidget);
      expect(find.byKey(const ValueKey('post-thumb-999')), findsOneWidget);
      expect(decodeW(full)!, inInclusiveRange(320, 1080));
      expect(decodeW(find.byKey(const ValueKey('post-thumb-999')))!, lessThanOrEqualTo(480));
      noErr(tester);
    });

    testWidgets('detay (PostPhoto varsayilan) tek katman: kucuk resim katmani yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(Scaffold(
        body: PostPhoto(
          session: makeSession(b),
          post: Post.fromJson(samplePost(id: 999, media: [samplePostMedia(id: 9990)])),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('post-thumb-999')), findsNothing);
      expect(find.byKey(const ValueKey('post-photo-999')), findsOneWidget);
      noErr(tester);
    });

    testWidgets('oneri seridi masonry\'nin ilk 4 kutusundan sonra tam genislik, akisin icinde (once degil)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      b.on('/users/me/follow-suggestions*', {
        'items': [
          {'id': 31, 'displayName': 'Deniz Aksoy', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
        ],
      });
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      final band = find.byKey(const ValueKey('discoverSuggestions'));
      final y = tester.getTopLeft(band).dy;
      // Akis sirasi: 1000, 999, 998, 997, [oneriler], 996 ...: ilk 4 kutu seridin ustunde (alt kenari seridin ustunde),
      // 5. kutu seridin altinda (yeni bir izgara olarak surer). Serit kenardan kenara tam genislik.
      for (final id in [1000, 999, 998, 997]) {
        final r = tester.getRect(find.byKey(ValueKey('discover-post-$id')));
        expect(r.bottom, lessThanOrEqualTo(y), reason: 'kutu $id');
      }
      final after = find.byKey(const ValueKey('discover-post-996'));
      if (after.evaluate().isNotEmpty) expect(tester.getTopLeft(after).dy, greaterThan(tester.getBottomLeft(band).dy - 1));
      expect(tester.getSize(band).width, 390);
      noErr(tester);
    });

    testWidgets('sekme gizlenip kisa surede donunce akis yeniden istenmez, uzun sure sonra ag yenilemesi yapilir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
      final s = makeSession(b);
      Widget tab(bool active) => buildApp(DiscoverTab(session: s, typeRequest: ValueNotifier<String?>(null), tabActive: active));
      await tester.pumpWidget(tab(true));
      await settle(tester, const Duration(milliseconds: 600));
      int feeds() => b.requests.where((r) => r.startsWith('GET /feed?')).length;
      final first = feeds();
      expect(first, 1);
      await tester.pumpWidget(tab(false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(tab(true));
      await settle(tester, const Duration(milliseconds: 600));
      expect(feeds(), first, reason: 'kisa suredir gizliydi: yeniden istek yok');
      expect(find.byKey(const ValueKey('discoverSkeleton')), findsNothing);
      expect(find.byType(DiscoverPostBox), findsWidgets);
      await settle(tester, const Duration(seconds: 3));
      noErr(tester);
    });

    testWidgets('1.3x yazi + 320 dp: tasma yok (ust alan, kart, iskelet)', (tester) async {
      useScreen(tester, const Size(320, 640));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final b = FakeBackend()..delay = const Duration(milliseconds: 300);
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b), size: const Size(320, 640)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('discoverSkeleton')), findsOneWidget);
      noErr(tester);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(DiscoverPostBox), findsWidgets);
      noErr(tester);
    });
  });

  group('ana sayfa hizli erisim: Anketler', () {
    testWidgets('Kulupler karosu yerine Anketler; dokununca anket listesi acilir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend()..on('/menu/today', {'date': '2026-01-01', 'items': ['Pilav']});
      fakePolls(b, count: 2);
      await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}))));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(HomeQuickGrid), findsOneWidget);
      expect(find.text('Anketler'), findsOneWidget);
      expect(find.descendant(of: find.byType(HomeQuickGrid), matching: find.text('Kulüpler')), findsNothing);
      expect(find.descendant(of: find.byType(HomeFeaturedShortcuts), matching: find.text('Kulüpler')), findsOneWidget);
      await tester.tap(find.text('Anketler'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(PollListPage), findsOneWidget);
      noErr(tester);
    });

    for (final size in [const Size(320, 640), const Size(390, 844)]) {
      testWidgets('Anketler karosu ${size.width.toInt()} dp, 1.3x yazi: tasma yok', (tester) async {
        useScreen(tester, size);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final b = FakeBackend()..on('/menu/today', {'date': '2026-01-01', 'items': ['Pilav']});
        await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {})), size: size));
        await settle(tester, const Duration(seconds: 2));
        expect(find.text('Anketler'), findsOneWidget);
        noErr(tester);
      });
    }
  });
}
