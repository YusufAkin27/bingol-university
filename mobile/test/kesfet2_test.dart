import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_box.dart';
import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/discover/masonry_layout.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_routes.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';

// KESFET2-MB: Stitch v3 kesfet2 A (masonry Kesfet + kaydirmali gonderi sayfasi) davranis testleri.
// Olculer: redesign/kesfet2_birebir_test.dart.

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

const _sizes = [(1080, 1350), (1080, 1080), (1080, 1620), (1920, 1080), (1080, 2400)];

/// `count` gonderilik akis: her gonderide fotograf (boyutlar [_sizes] dongusu), farkli yazar, kisa metin.
FakePosts feed(FakeBackend b, {int count = 40, int pageSize = 12}) {
  final fp = fakePosts(b, count: count, pageSize: pageSize);
  for (var i = 0; i < fp.posts.length; i++) {
    final p = fp.posts[i];
    final id = p['id'] as int;
    final s = _sizes[i % _sizes.length];
    p['media'] = [samplePostMedia(id: id * 10, width: s.$1, height: s.$2)];
    p['text'] = 'Metin $id';
    p['likeCount'] = 10 + i;
    p['author'] = {'id': 20 + i, 'displayName': 'Yazar $i', 'avatarUrl': null, 'department': 'Bilgisayar'};
  }
  b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
  return fp;
}

Widget discover(FakeBackend b, {ValueNotifier<String?>? req}) =>
    DiscoverTab(session: makeSession(b), typeRequest: req ?? ValueNotifier<String?>(null));

Widget localized(Widget home, {String lang = 'tr', Brightness brightness = Brightness.light, Size? size}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.forLocale(Brightness.light, lang),
    darkTheme: BuTheme.forLocale(Brightness.dark, lang),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(lang),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: size == null
        ? null
        : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(size: size),
              child: Align(alignment: Alignment.topLeft, child: SizedBox(width: size.width, height: size.height, child: child)),
            ),
    home: home,
  );
}

double scrollPixels(WidgetTester tester, Finder scrollView) =>
    tester.state<ScrollableState>(find.descendant(of: scrollView, matching: find.byType(Scrollable)).first).position.pixels;

Finder box(int id) => find.byKey(ValueKey('discover-post-$id'));

void main() {
  setUpAll(loadTestFonts);

  group('masonry yerlesimi (birim)', () {
    test('acgozlu: her kutu en kisa sutuna; ilk sutun esitlikte; ofsetler azalmaz', () {
      final p = masonryPlace(const <double>[238.5, 179, 268.5, 223.75, 179, 238.5]);
      expect([for (final e in p) e.column], [0, 1, 1, 0, 1, 0]);
      expect(p[0].top, 0);
      expect(p[1].top, 0);
      expect(p[2].top, 179 + 8);
      expect(p[3].top, 238.5 + 8);
      expect(p[4].top, 179 + 8 + 268.5 + 8);
      expect(p[5].top, 238.5 + 8 + 223.75 + 8);
      for (var i = 1; i < p.length; i++) {
        expect(p[i].top, greaterThanOrEqualTo(p[i - 1].top));
      }
    });

    test('sutun genisligi: 366 dp icerik -> 179; 360 dp ekran -> 164', () {
      expect(masonryColumnWidth(390 - 24), 179);
      expect(masonryColumnWidth(360 - 24), 164);
    });

    test('foto orani 1:1 .. 2:3 araligina kistirilir; bilinmeyen 4:5; fotografsiz kare', () {
      Post p(int? w, int? h) => Post.fromJson(samplePost(id: 1, media: [
            {...samplePostMedia(id: 1), 'width': w, 'height': h}
          ]));
      expect(discoverBoxRatio(p(1920, 1080)), 1.0); // yatay -> 1:1 kirpilir
      expect(discoverBoxRatio(p(1000, 1000)), 1.0);
      expect(discoverBoxRatio(p(1080, 1350)), closeTo(.8, 1e-9));
      expect(discoverBoxRatio(p(1080, 1620)), closeTo(2 / 3, 1e-9));
      expect(discoverBoxRatio(p(1080, 3000)), closeTo(2 / 3, 1e-9)); // cok dik -> 2:3
      expect(discoverBoxRatio(p(null, null)), .8);
      expect(discoverBoxRatio(p(0, 100)), .8);
      expect(discoverBoxRatio(Post.fromJson(samplePost(id: 2))), 1.0);
    });

    test('bolme noktasi: ilk 4 kutudan sonra, sutunlar dengeliyse; degilse <=10 icinde farki en kucuk nokta', () {
      // 1:1, 4:5, 4:5, 1:1 -> 179/224/224/179: 4 kutudan sonra fark 0.
      expect(masonrySplitIndex(const <double>[179, 224, 224, 179, 179, 179]), 4);
      // Dengesiz: 4. kutuda fark > 16, 5. kutuda dengelenir.
      final h = <double>[268.5, 179, 179, 179, 179, 179, 179, 179];
      final k = masonrySplitIndex(h);
      expect(k, greaterThanOrEqualTo(4));
      expect(masonryColumnDiff(h, k), lessThanOrEqualTo(masonryColumnDiff(h, 4)));
      // Az kutu: bant sonda.
      expect(masonrySplitIndex(const <double>[179, 224]), 2);
      expect(masonrySplitIndex(const <double>[179, 224, 224, 179]), 4);
      expect(masonrySplitIndex(const <double>[]), 0);
    });
  });

  group('masonry tembel izgara', () {
    testWidgets('500 kutu: yalniz gorunenler kurulur; yerlesim oracle ile ayni; sonuna kaydirinca son kutu gelir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final ratios = [for (var i = 0; i < 500; i++) const [0.8, 1.0, 2 / 3, 1.0, 0.8][i % 5]];
      final built = <int>{};
      final c = ScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomScrollView(controller: c, slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: MasonryGridDelegate(ratios: ratios),
                delegate: SliverChildBuilderDelegate((_, i) {
                  built.add(i);
                  return DecoratedBox(key: ValueKey('t$i'), decoration: const BoxDecoration(color: Colors.grey));
                }, childCount: ratios.length),
              ),
            ),
          ]),
        ),
      ));
      expect(built.length, lessThan(40), reason: 'tembel: ${built.length} kutu kuruldu');
      final oracle = masonryPlace([for (final r in ratios) 179 / r]);
      for (final i in built.where((i) => find.byKey(ValueKey('t$i')).evaluate().isNotEmpty)) {
        final r = tester.getRect(find.byKey(ValueKey('t$i')));
        expect(r.top, closeTo(oracle[i].top, .01), reason: 'kutu $i');
        expect(r.left, oracle[i].column == 0 ? 12 : 199);
        expect(r.width, 179);
        expect(r.height, closeTo(oracle[i].height, .01));
      }
      c.jumpTo(c.position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('t499')), findsOneWidget);
      expect(c.position.maxScrollExtent, closeTo(oracle.map((e) => e.bottom).reduce((a, b) => a > b ? a : b) - 844, 1));
      // Ortada bir noktaya atla: oradaki kutular dogru konumda.
      c.jumpTo(c.position.maxScrollExtent / 2);
      await tester.pump();
      await tester.pump();
      for (final i in List.generate(500, (i) => i).where((i) => find.byKey(ValueKey('t$i')).evaluate().isNotEmpty)) {
        expect(tester.getRect(find.byKey(ValueKey('t$i'))).top, closeTo(oracle[i].top - c.offset, .01), reason: 'kutu $i');
      }
      noErr(tester);
    });

    testWidgets('RTL: ilk kutu sagda (baslangic kenari), ikinci sutun solda', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: MasonryGridDelegate(ratios: const [.8, 1, 1]),
                  delegate: SliverChildBuilderDelegate((_, i) => DecoratedBox(key: ValueKey('r$i'), decoration: const BoxDecoration(color: Colors.grey)),
                      childCount: 3),
                ),
              ),
            ]),
          ),
        ),
      ));
      expect(tester.getRect(find.byKey(const ValueKey('r0'))).right, 378); // 390 - 12
      expect(tester.getRect(find.byKey(const ValueKey('r1'))).left, 12);
      noErr(tester);
    });
  });

  group('kesfet masonry', () {
    testWidgets('kutular oranlarina gore dizilir (yatay 1:1, cok dik 2:3), yerlesim oracle ile ayni; oneri yokken kesintisiz tek izgara', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend();
      feed(b, count: 10);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      final ids = [for (var i = 0; i < 10; i++) 1000 - i];
      final first = tester.getTopLeft(box(1000));
      final ratios = [for (var i = 0; i < 10; i++) _ratio(_sizes[i % _sizes.length])];
      final oracle = masonryPlace([for (final r in ratios) 179 / r]);
      for (var i = 0; i < 10; i++) {
        final r = tester.getRect(box(ids[i]));
        expect(r.width, 179);
        expect(r.height, closeTo(oracle[i].height, .5), reason: 'kutu $i yukseklik');
        expect(r.top - first.dy, closeTo(oracle[i].top, .5), reason: 'kutu $i ust');
        expect(r.left, oracle[i].column == 0 ? 12 : 199, reason: 'kutu $i sutun');
      }
      // Yatay (1920x1080) 1:1 -> 179; en dik (1080x2400) 2:3 -> 268,5.
      expect(tester.getSize(box(997)).height, closeTo(179, .5));
      expect(tester.getSize(box(996)).height, closeTo(268.5, .5));
      noErr(tester);
    });

    testWidgets('oneri bandi: ilk 4 kutudan sonra tam genislik, masonry yeni izgara olarak surer; oneri yoksa band yok', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      feed(b, count: 12);
      b.on('/users/me/follow-suggestions*', {
        'items': [
          {'id': 31, 'displayName': 'Deniz Aksoy', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
        ],
      });
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      final band = find.byKey(const ValueKey('discoverSuggestions'));
      expect(band, findsOneWidget);
      expect(tester.getSize(band).width, 390);
      final y = tester.getTopLeft(band).dy;
      final ratios = [for (var i = 0; i < 12; i++) _ratio(_sizes[i % _sizes.length])];
      final k = masonrySplitIndex([for (final r in ratios) 179 / r]);
      expect(k, greaterThanOrEqualTo(4));
      for (var i = 0; i < k; i++) {
        expect(tester.getRect(box(1000 - i)).bottom, lessThanOrEqualTo(y), reason: 'kutu $i bandin ustunde');
      }
      for (var i = k; i < 12; i++) {
        expect(tester.getRect(box(1000 - i)).top, greaterThanOrEqualTo(tester.getRect(band).bottom - 1), reason: 'kutu $i bandin altinda');
      }
      noErr(tester);
    });

    testWidgets('az gonderi (3): bant sonda; oneri bos gelince bant ve bolme kalkar (tek izgara)', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend();
      feed(b, count: 3);
      b.on('/users/me/follow-suggestions*', {
        'items': [
          {'id': 31, 'displayName': 'Deniz Aksoy', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
        ],
      });
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      final band = find.byKey(const ValueKey('discoverSuggestions'));
      expect(tester.getTopLeft(band).dy, greaterThanOrEqualTo(tester.getRect(box(998)).bottom));
      noErr(tester);
    });

    testWidgets('yazar adina dokunma yazarin PROFILINI acar; kutuya degil', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 6);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('discover-author-1000')), matching: find.text('Yazar 0')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(UserProfilePage), findsOneWidget);
      expect(find.byType(PostDetailPage), findsNothing);
      expect(b.requests.any((r) => r.contains('/users/20')), isTrue, reason: b.requests.join('|'));
      noErr(tester);
    });

    testWidgets('yazar satiri dokunma alani en az 44 dp yuksekligi; ad tek satir ellipsis; kalp+sayi kirpilmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = feed(b, count: 4);
      fp.posts[0]['author'] = {'id': 20, 'displayName': 'Cok Uzun Bir Yazar Adi Soyadi Burada', 'avatarUrl': null, 'department': 'x'};
      fp.posts[0]['likeCount'] = 12345;
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      final author = find.byKey(const ValueKey('discover-author-1000'));
      expect(tester.getSize(author).height, greaterThanOrEqualTo(44));
      final name = tester.widget<Text>(find.descendant(of: author, matching: find.textContaining('Cok Uzun')));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      // Sayi tam gorunur (kalp+sayi kutu icinde).
      final count = find.descendant(of: box(1000), matching: find.byKey(const ValueKey('like-count')));
      expect(tester.widget<Text>(count).data, '12345');
      expect(tester.getRect(count).right, lessThanOrEqualTo(tester.getRect(box(1000)).right));
      expect(tester.getRect(author).right, lessThanOrEqualTo(tester.getRect(find.descendant(of: box(1000), matching: find.byKey(const ValueKey('like-heart')))).left));
      noErr(tester);
    });

    testWidgets('begeni: iyimser +1 hemen; sunucu hatasinda geri alinir + uyari; beglenmis kalp dolu', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 4);
      b.handlers.insert(0, (req, path) => req.method == 'PUT' && path == '/posts/1000/like'
          ? const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500)
          : null);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      String count(int id) => tester.widget<Text>(find.descendant(of: box(id), matching: find.byKey(const ValueKey('like-count')))).data!;
      expect(count(1000), '10');
      expect(find.descendant(of: box(1000), matching: find.byIcon(BuIcons.heart)), findsOneWidget);
      // Beğenmemiş: BOS cizgi kalp, beyaz DEGIL (acik yuzey hapi uzerinde ink).
      final outline = tester.widget<Icon>(find.descendant(of: box(1000), matching: find.byIcon(BuIcons.heart)));
      expect(outline.color, BuTokens.light.ink);
      expect(outline.color, isNot(BuTokens.light.onMedia));
      await tester.tap(find.descendant(of: box(1000), matching: find.byKey(const ValueKey('like-heart'))));
      await tester.pump(const Duration(milliseconds: 60));
      expect(count(1000), '11'); // iyimser
      expect(find.descendant(of: box(1000), matching: find.byIcon(BuIcons.heartFilled)), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 900));
      expect(count(1000), '10'); // hata: geri alindi
      expect(find.descendant(of: box(1000), matching: find.byIcon(BuIcons.heart)), findsOneWidget);
      expect(find.text('Beğeni kaydedilemedi'), findsOneWidget);
      // Basarili beğeni: DOLU KIRMIZI kalp (pr), beyaz degil.
      await tester.tap(find.descendant(of: box(999), matching: find.byKey(const ValueKey('like-heart'))));
      await settle(tester, const Duration(milliseconds: 900));
      final icon = tester.widget<Icon>(find.descendant(of: box(999), matching: find.byIcon(BuIcons.heartFilled)));
      expect(icon.color, BuTokens.light.heart);
      expect(icon.color, isNot(BuTokens.light.onMedia));
      noErr(tester);
    });

    testWidgets('uzun basma: kendi gonderide Duzenle/Sil, baskasinda Profili gor/Sikayet/Engelle (kutuda menu dugmesi yok)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = feed(b, count: 4);
      fp.posts[0]['mine'] = true;
      fp.posts[0]['canEdit'] = true;
      fp.posts[0]['canDelete'] = true;
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('post-menu-button')), findsNothing);
      await tester.longPress(box(1000));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('post-act-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-report')), findsNothing);
      await tester.tapAt(const Offset(20, 100)); // sheet disina dokun: kapat
      await settle(tester, const Duration(milliseconds: 500));
      await tester.longPress(box(999));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('post-act-profile')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-block')), findsOneWidget);
      expect(find.byType(PostDetailPage), findsNothing);
      noErr(tester);
    });

    testWidgets('kendi gonderisinde islem yetkisi yoksa uzun basma menusu acilmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = feed(b, count: 3);
      fp.posts[0]['mine'] = true;
      fp.posts[0]['canEdit'] = false;
      fp.posts[0]['canDelete'] = false;
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.longPress(box(1000));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('post-act-edit')), findsNothing);
      expect(find.byKey(const ValueKey('post-act-profile')), findsNothing);
      noErr(tester);
    });

    testWidgets('kaydirma konumu: gonderi sayfasindan geri donunce masonry ayni yerde', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 40);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      final list = find.byType(CustomScrollView).first;
      await tester.drag(list, const Offset(0, -600));
      await settle(tester, const Duration(milliseconds: 600));
      final before = scrollPixels(tester, list);
      expect(before, greaterThan(300));
      // Gorunen bir kutuyu ac.
      final visible = [for (var i = 0; i < 12; i++) 1000 - i].firstWhere((id) {
        if (box(id).evaluate().isEmpty) return false;
        final r = tester.getRect(box(id));
        return r.top > 150 && r.bottom < 780;
      });
      await tester.tapAt(tester.getCenter(box(visible)));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(PostDetailPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('postBack')));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(PostDetailPage), findsNothing);
      expect(scrollPixels(tester, find.byType(CustomScrollView).first), before);
      noErr(tester);
    });
  });

  group('gonderi sayfasi (dikey akis)', () {
    Finder stream() => find.byKey(const ValueKey('postStream'));

    testWidgets('kutuya dokunma: tiklanan gonderi akisin ortasinda ekranin basinda; ustunde onceki, altinda sonrakiler; 20 dp kenar, 4:5 foto, ayirici', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 20);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      // 3. kutu (998) tiklanir: akis ORTADA 998; ustunde 999 ve 1000 (yukari kaydirinca), altinda 997, 996 ...
      await tester.tapAt(tester.getCenter(box(998)));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(PostDetailPage), findsOneWidget);
      expect(find.text('Gönderi'), findsNothing); // ust cubukta baslik metni yok (sadelestirme)
      expect(find.byKey(const ValueKey('postBack')), findsOneWidget);
      expect(find.text('Metin 998'), findsOneWidget);
      final y998 = tester.getTopLeft(find.byKey(const ValueKey('stream-post-998'))).dy;
      expect(y998, lessThan(130), reason: 'tiklanan gonderi ust cubugun hemen altinda baslar');
      expect(y998, greaterThanOrEqualTo(56));
      final y997 = tester.getTopLeft(find.byKey(const ValueKey('stream-post-997'))).dy;
      expect(y997, greaterThan(y998));
      // Ustteki gonderiler: baslangicta ekranin disinda; yukari kaydirinca (parmak asagi) 999 sonra 1000 gorunur.
      expect(find.text('Metin 1000'), findsNothing);
      await tester.drag(stream(), const Offset(0, 700));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('stream-post-999')), findsOneWidget);
      await tester.drag(stream(), const Offset(0, 800));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('stream-post-1000')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const ValueKey('stream-post-1000'))).dy,
          lessThan(tester.getTopLeft(find.byKey(const ValueKey('stream-post-999'))).dy));
      // Gonderi arasi: 1 dp bd ayirici (20 dp kenar) + 24 dp bosluk.
      final div = find.byKey(const ValueKey('postStreamDivider')).first;
      expect(tester.getSize(div).height, 1);
      expect(tester.getSize(div).width, 350);
      expect(tester.getTopLeft(div).dx, 20);
      // Foto 4:5, 20 dp kenar (350 x 437,5).
      final photo = tester.getSize(find.descendant(of: find.byKey(const ValueKey('stream-post-1000')), matching: find.byKey(const ValueKey('post-photo-1000'))));
      expect(photo.width, 350);
      expect(photo.height, closeTo(437.5, 1));
      expect(tester.getTopLeft(find.byKey(const ValueKey('stream-post-1000'))).dx, 0);
      noErr(tester);
    });

    testWidgets('sonsuz kaydirma: masonry imleci aynen surer (cursor=p2 bir kez), sayfa sonunda iskelet, liste bitince ek metin yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 30, pageSize: 12);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.requests.where((r) => r.contains('cursor=')).length, 0);
      await tester.tapAt(tester.getCenter(box(1000)));
      await settle(tester, const Duration(milliseconds: 900));
      // Masonry'nin 12 gonderisi tohum; sayfa sonuna yaklasinca sonraki sayfa istenir.
      for (var i = 0; i < 12; i++) {
        await tester.drag(stream(), const Offset(0, -1500));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester, const Duration(milliseconds: 800));
      // Izgaranin sonundan sonra akis YENI oturum (imlecsiz) ile surer; ardindan imlec zinciri (p2, p3) aynen izlenir.
      final feeds = b.requests.where((r) => r.startsWith('GET /feed?')).toList();
      expect(feeds.length, greaterThanOrEqualTo(3), reason: feeds.join('|'));
      expect(feeds[1].contains('cursor='), isFalse, reason: 'ilk sayfalama imlecsiz (yeni tohum): ${feeds.join('|')}');
      expect(b.requests.any((r) => r.contains('cursor=p2')), isTrue);
      expect(b.requests.any((r) => r.contains('cursor=p3')), isTrue);
      noErr(tester);
    });

    testWidgets('sayfa sonu iskeleti: sonraki sayfa yuklenirken PostCardSkeleton gorunur', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 30, pageSize: 12);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tapAt(tester.getCenter(box(1000)));
      await settle(tester, const Duration(milliseconds: 900));
      b.delay = const Duration(seconds: 3);
      for (var i = 0; i < 14 && find.byKey(const ValueKey('postStreamSkeleton')).evaluate().isEmpty; i++) {
        await tester.drag(stream(), const Offset(0, -1500));
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byKey(const ValueKey('postStreamSkeleton')), findsOneWidget);
      b.delay = Duration.zero;
      await settle(tester, const Duration(seconds: 20));
      expect(find.byKey(const ValueKey('postStreamSkeleton')), findsNothing);
      noErr(tester);
    });

    testWidgets('akis hatasi: sayfa sonunda Yeniden dene; dokununca devam eder', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 30, pageSize: 12);
      var down = false;
      b.handlers.insert(0, (req, path) => down && path == '/feed' && req.url.queryParameters['cursor'] != null
          ? const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500)
          : null);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tapAt(tester.getCenter(box(1000)));
      await settle(tester, const Duration(milliseconds: 900));
      down = true;
      for (var i = 0; i < 12; i++) {
        await tester.drag(stream(), const Offset(0, -1500));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Yeniden dene'), findsOneWidget);
      down = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Yeniden dene'), findsNothing);
      noErr(tester);
    });

    testWidgets('ust cubuk sabit: baslik + geri dugmesi kaydirinca da yerinde; geri doner', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 20);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tapAt(tester.getCenter(box(1000)));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Gönderi'), findsNothing);
      final backAt = tester.getCenter(find.byKey(const ValueKey('postBack')));
      expect(tester.getSize(find.byKey(const ValueKey('postBack'))), const Size(48, 48));
      await tester.drag(stream(), const Offset(0, -900));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Gönderi'), findsNothing); // baslik yok
      expect(tester.getCenter(find.byKey(const ValueKey('postBack'))), backAt); // sabit
      await tester.tap(find.byKey(const ValueKey('postBack')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(PostDetailPage), findsNothing);
      noErr(tester);
    });

    testWidgets('akistaki gonderide begeni masonry kutusuna yansir (geri donunce)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 20);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      String count(int id) =>
          tester.widget<Text>(find.descendant(of: box(id), matching: find.byKey(const ValueKey('like-count')))).data!;
      final before = count(999);
      await tester.tapAt(tester.getCenter(box(1000)));
      await settle(tester, const Duration(milliseconds: 900));
      // 2. gonderiyi (999) akis icinde begen.
      final heart = find.descendant(of: find.byKey(const ValueKey('stream-post-999')), matching: find.byKey(const ValueKey('like-heart')));
      await tester.drag(stream(), const Offset(0, -500));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(heart);
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('postBack')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(count(999), '${int.parse(before) + 1}');
      noErr(tester);
    });

    testWidgets('akistaki gonderi silinince sayfadan ve masonry\'den kalkar', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = feed(b, count: 12);
      fp.posts[1]['mine'] = true;
      fp.posts[1]['canEdit'] = true;
      fp.posts[1]['canDelete'] = true;
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tapAt(tester.getCenter(box(1000)));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.drag(stream(), const Offset(0, -500));
      await settle(tester, const Duration(milliseconds: 400));
      final menu = find.descendant(of: find.byKey(const ValueKey('stream-post-999')), matching: find.byKey(const ValueKey('post-menu-button')));
      expect(menu, findsOneWidget);
      await tester.tap(menu);
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('post-act-delete')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('post-dialog-confirm')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.requests.any((r) => r.startsWith('DELETE') && r.contains('/posts/999')), isTrue, reason: b.requests.join('|'));
      expect(find.byKey(const ValueKey('stream-post-999')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('postBack')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(box(999), findsNothing);
      expect(box(1000), findsOneWidget);
      noErr(tester);
    });

    testWidgets('derin baglanti/push: gonderi ilk sirada, altinda akis devam eder; akistaki ayni gonderi tekrarlanmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 20);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 997, stream: const PostStreamSeed.fresh())));
      await settle(tester, const Duration(milliseconds: 1000));
      // Once tekil gonderi, sonra akis.
      final iPost = b.requests.indexWhere((r) => r.contains('/posts/997'));
      final iFeed = b.requests.indexWhere((r) => r.contains('/feed'));
      expect(iPost, greaterThanOrEqualTo(0));
      expect(iFeed, greaterThan(iPost), reason: b.requests.join('|'));
      expect(find.byKey(const ValueKey('stream-post-997')), findsOneWidget);
      final ys = tester.getTopLeft(find.byKey(const ValueKey('stream-post-997'))).dy;
      expect(ys, lessThan(120));
      await tester.drag(find.byKey(const ValueKey('postStream')), const Offset(0, -1800));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('stream-post-997')), findsNothing); // ustte kaldi
      expect(find.byKey(const ValueKey('stream-post-1000')), findsNothing); // 997'den once degil (akis basindan: 1000..)
      noErr(tester);
    });

    testWidgets('akis alinamazsa yalniz tek gonderi gosterilir (hata yok)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = feed(b, count: 5)..failFeed = true;
      expect(fp.failFeed, isTrue);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 998, stream: const PostStreamSeed.fresh())));
      await settle(tester, const Duration(milliseconds: 1000));
      expect(find.byKey(const ValueKey('stream-post-998')), findsOneWidget);
      expect(find.text('Yeniden dene'), findsNothing);
      expect(find.byKey(const ValueKey('postStreamSkeleton')), findsNothing);
      expect(find.byKey(const ValueKey('postStream')), findsOneWidget);
      noErr(tester);
    });

    testWidgets('gonderi bulunamadi (404): tek gonderi bilgi karti, geri dugmesi var', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 3);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 99999, stream: const PostStreamSeed.fresh())));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('postNotFound')), findsOneWidget);
      expect(find.byKey(const ValueKey('postBack')), findsOneWidget);
      expect(b.requests.any((r) => r.contains('/feed')), isFalse);
      noErr(tester);
    });

    testWidgets('openPostDetail: donus degeri acilan gonderinin guncel hali', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      feed(b, count: 6);
      Post? result;
      await tester.pumpWidget(buildApp(Builder(builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await openPostDetail(context, makeSession(b), 999, stream: const PostStreamSeed(items: [], hasMore: false));
                },
                child: const Text('ac'),
              ),
            ),
          ))));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('postBack')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(result?.id, 999);
      noErr(tester);
    });
  });

  group('tr/en/ar, acik/koyu, 390 + 320 dp, x1.0 ve x1.3: tasma yok', () {
    for (final lang in ['tr', 'en', 'ar']) {
      for (final size in [const Size(390, 844), const Size(320, 640)]) {
        for (final br in Brightness.values) {
          for (final scale in [1.0, 1.3]) {
          testWidgets('$lang ${size.width.toInt()} ${br.name} x$scale: masonry + gonderi sayfasi', (tester) async {
            useScreen(tester, size);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
            addTearDown(() => LocaleController.current = null);
            final b = FakeBackend();
            final fp = feed(b, count: 14);
            fp.posts[0]['author'] = {'id': 20, 'displayName': 'Cok Uzun Bir Yazar Adi Soyadi Burada', 'avatarUrl': null, 'department': 'Bilgisayar ve Ogretim Teknolojileri Egitimi'};
            fp.posts[0]['likeCount'] = 12345;
            b.on('/users/me/follow-suggestions*', {
              'items': [
                {'id': 31, 'displayName': 'Deniz Aksoy', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
                {'id': 32, 'displayName': 'Ece Yılmaz', 'department': 'İktisat', 'followedByMe': false},
              ],
            });
            b.delay = const Duration(milliseconds: 250);
            final session = makeSession(b)..api.lang = lang;
            await tester.pumpWidget(localized(DiscoverTab(session: session, typeRequest: ValueNotifier<String?>(null)), lang: lang, brightness: br, size: size));
            await tester.pump(const Duration(milliseconds: 60));
            expect(find.byKey(const ValueKey('discoverSkeleton')), findsOneWidget);
            noErr(tester);
            await settle(tester, const Duration(milliseconds: 1500));
            expect(find.byType(DiscoverPostBox), findsWidgets);
            noErr(tester);
            await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -500));
            await settle(tester, const Duration(milliseconds: 400));
            noErr(tester);
            await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 900));
            await settle(tester, const Duration(milliseconds: 400));
            await tester.tapAt(tester.getCenter(find.byType(DiscoverPostBox).first));
            await settle(tester, const Duration(milliseconds: 1500));
            expect(find.byType(PostDetailPage), findsOneWidget);
            noErr(tester);
            await tester.drag(find.byKey(const ValueKey('postStream')), const Offset(0, -900));
            await settle(tester, const Duration(milliseconds: 400));
            noErr(tester);
          });
          }
        }
      }
    }
  });
}

double _ratio((int, int) s) => (s.$1 / s.$2).clamp(2 / 3, 1.0);
