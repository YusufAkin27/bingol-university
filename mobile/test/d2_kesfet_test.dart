import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuChip, LucideIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

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
    testWidgets('ust alan: baslik, arama ve paylas simgesi, Tumu/Populer BuChip; anket ve "Ogrenci Akisi" basligi yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Keşfet'), findsOneWidget);
      expect(find.byKey(const ValueKey('discoverSearch')), findsOneWidget);
      expect(find.byTooltip('Gönderi oluştur'), findsOneWidget);
      expect(find.byType(BuChip), findsNWidgets(2));
      expect(find.byTooltip('Anketler'), findsNothing);
      expect(find.byIcon(LucideIcons.vote), findsNothing);
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

    testWidgets('fotograf: kucuk resim katmani + tam boy, cozumleme genisligi ekrana gore sinirli', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      final full = find.byKey(const ValueKey('post-photo-999'));
      final thumb = find.byKey(const ValueKey('post-thumb-999'));
      expect(full, findsOneWidget);
      expect(thumb, findsOneWidget);
      int? decodeW(Finder f) {
        final img = tester.widget<Image>(f).image;
        return img is ResizeImage ? img.width : null;
      }

      // 338 dp x dpr 1 (test) -> alt sinir 320; hicbir zaman 1080 px'i asmaz.
      expect(decodeW(full)!, inInclusiveRange(320, 1080));
      expect(decodeW(thumb)!, lessThanOrEqualTo(480));
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

    testWidgets('oneri seridi 3. gonderiden sonra akisin icinde (once degil)', (tester) async {
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
      await tester.scrollUntilVisible(find.text('Tanıyor Olabilirsin'), 300, scrollable: find.byType(Scrollable).first);
      await settle(tester, const Duration(milliseconds: 600));
      final y = tester.getTopLeft(find.byKey(const ValueKey('discoverSuggestions'))).dy;
      // Akis sirasi: 1000, 999, 998, [oneriler], 997 ...: 4. gonderi seridin altinda, 3. gonderi ustunde ya da ekran disinda.
      expect(tester.getTopLeft(find.byKey(const ValueKey('discover-post-997'))).dy, greaterThan(y));
      expect(find.byKey(const ValueKey('discover-post-998')).evaluate().isEmpty ||
          tester.getTopLeft(find.byKey(const ValueKey('discover-post-998'))).dy < y, isTrue);
      noErr(tester);
    });

    testWidgets('onbellekteki kapsam aninda cizilir: Tumu -> Populer -> Tumu iskelet gostermez, arka planda dogrular',
        (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      // Sunucu ETag verir: yanit oturum onbellegine (ETag LRU) girer.
      b.on(
          '/feed*',
          {
            'items': [
              for (var i = 0; i < 3; i++)
                samplePost(id: 700 - i, text: 'Onbellek ', media: [samplePostMedia(id: 70 + i)]),
            ],
            'nextCursor': null,
            'hint': null,
          },
          headers: {'etag': '"f1"'});
      b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('discoverChipPopular')));
      await settle(tester, const Duration(milliseconds: 600));
      b.delay = const Duration(seconds: 2);
      final before = b.requests.where((r) => r.contains('/feed')).length;
      await tester.tap(find.byKey(const ValueKey('discoverChipAll')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // Ag yaniti 2 sn sonra gelecek; liste yine de simdi gorunur (onbellekten), iskelet yok.
      expect(find.byKey(const ValueKey('discoverSkeleton')), findsNothing);
      expect(find.byType(DiscoverPostCard), findsWidgets);
      await settle(tester, const Duration(seconds: 3));
      expect(b.requests.where((r) => r.contains('/feed')).length, greaterThan(before)); // arka planda dogrulandi
      expect(find.byType(DiscoverPostCard), findsWidgets);
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
      expect(find.byType(DiscoverPostCard), findsWidgets);
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
      expect(find.text('Kulüpler'), findsNothing);
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
