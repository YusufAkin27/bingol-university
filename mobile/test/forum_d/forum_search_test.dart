import 'package:bu_kampus/features/forum/data/forum_recent_searches.dart';
import 'package:bu_kampus/features/forum/data/forum_search_text.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_search_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_extras.dart';
import '../support/forum_d_harness.dart';

const _field = ValueKey('forum-search-field');

void main() {
  late FakeBackend b;
  late FakeForum f;
  late FakeForumExtras x;

  setUp(() async {
    b = FakeBackend();
    f = fakeForum(b, count: 30);
    x = fakeForumExtras(f);
    makeSession(b); // secure storage taklidi
    await ForumRecentSearches.clear();
  });

  group('metin yardimcilari', () {
    test('normalizeForumQuery + etkin sorgu (>= 2 karakter)', () {
      expect(normalizeForumQuery('  kantin   fiyat  '), 'kantin fiyat');
      expect(forumQueryActive('k'), isFalse);
      expect(forumQueryActive(' k '), isFalse);
      expect(forumQueryActive('ka'), isTrue);
    });

    test('vurgu: buyuk/kucuk harf ve Turkce I/i farki yok sayilir, indeksler kaymaz', () {
      expect(splitForumHighlight('Kantin menüsü', 'kantin'), [const ForumTextSegment('Kantin', true), const ForumTextSegment(' menüsü', false)]);
      expect(splitForumHighlight('ILIK su', 'ılık'), [const ForumTextSegment('ILIK', true), const ForumTextSegment(' su', false)]);
      expect(splitForumHighlight('İstanbul yolu', 'istanbul'), [const ForumTextSegment('İstanbul', true), const ForumTextSegment(' yolu', false)]);
    });

    test('vurgu: birden cok sozcuk, kisa terim yok sayilir, eslesme yoksa tek parca', () {
      final s = splitForumHighlight('yurt odası ve yemek', 'yurt yemek');
      expect(s.where((e) => e.highlight).map((e) => e.text), ['yurt', 'yemek']);
      expect(splitForumHighlight('abc', 'a'), [const ForumTextSegment('abc', false)]);
      expect(splitForumHighlight('abc', 'zz'), [const ForumTextSegment('abc', false)]);
      expect(splitForumHighlight('', 'zz'), isEmpty);
    });

    test('vurgu: ardisik eslesmeler birlesir', () {
      final s = splitForumHighlight('kantinkantin', 'kantin');
      expect(s, [const ForumTextSegment('kantinkantin', true)]);
    });
  });

  group('son aramalar deposu', () {
    test('en yeni basta, yinelenen birlesir, en cok 10, tek tek ve hepsini sil', () async {
      expect(await ForumRecentSearches.load(), isEmpty);
      await ForumRecentSearches.add('kantin');
      await ForumRecentSearches.add('yurt');
      var r = await ForumRecentSearches.add('KANTIN');
      expect(r, ['KANTIN', 'yurt']);
      await ForumRecentSearches.add('x'); // < 2 karakter eklenmez
      expect(await ForumRecentSearches.load(), ['KANTIN', 'yurt']);
      for (var i = 0; i < 14; i++) {
        await ForumRecentSearches.add('terim $i');
      }
      r = await ForumRecentSearches.load();
      expect(r.length, ForumRecentSearches.max);
      expect(r.first, 'terim 13');
      r = await ForumRecentSearches.remove('terim 13');
      expect(r.contains('terim 13'), isFalse);
      await ForumRecentSearches.clear();
      expect(await ForumRecentSearches.load(), isEmpty);
    });
  });

  group('arama sayfasi', () {
    Future<void> open(WidgetTester tester, {RouteLog? log, Brightness brightness = Brightness.light, double scale = 1, Size size = kPhoneMedium}) async {
      useScreen(tester, size);
      await tester.pumpWidget(forumDApp(ForumSearchPage(session: makeSession(b)), log: log, brightness: brightness, textScale: scale));
      await settle(tester, const Duration(milliseconds: 300));
    }

    testWidgets('ardisik yazim TEK istek atar (350 ms bekleme); 1 karakterde istek yok', (tester) async {
      await open(tester);
      await typeInto(tester, _field, 'k');
      await tester.pump(const Duration(milliseconds: 600));
      expect(x.searchQueries, isEmpty);
      expect(find.byKey(const ValueKey('forum-search-min')), findsOneWidget);

      await typeInto(tester, _field, 'ko');
      await tester.pump(const Duration(milliseconds: 100));
      await typeInto(tester, _field, 'kon');
      await tester.pump(const Duration(milliseconds: 100));
      await typeInto(tester, _field, 'konu');
      await tester.pump(const Duration(milliseconds: 200));
      expect(x.searchQueries, isEmpty, reason: '350 ms dolmadan istek gitmemeli');
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester, const Duration(milliseconds: 300));
      expect(x.searchQueries.length, 1);
      expect(x.searchQueries.single, contains('q=konu'));
      expect(x.searchQueries.single, contains('sort=RELEVANCE'));
      expectNoException(tester);
    });

    testWidgets('sonuc kartlari: eslesme etiketi + vurgulu baslik (kalin degil); karta dokununca konu acilir', (tester) async {
      f.topics[2]['title'] = 'Kantin fiyatları çok arttı';
      final id = f.topics[2]['id'] as int;
      final log = RouteLog();
      await open(tester, log: log);
      await typeInto(tester, _field, 'kantin');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(milliseconds: 400));
      final tile = find.byKey(ValueKey('forum-hit-$id'));
      expect(tile, findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('Başlıkta')), findsOneWidget);
      final title = tester.widget<Text>(find.descendant(of: tile, matching: find.byKey(const ValueKey('forum-tile-title'))));
      final spans = (title.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.first.text, 'Kantin');
      expect(spans.first.style!.fontWeight, FontWeight.w400);
      expect(spans.first.style!.color, isNot(equals(title.style!.color)));

      await tester.tap(tile);
      await settle(tester, const Duration(milliseconds: 400));
      expect(log.count('forum_topic'), 1);
      // Dokunulan sonuc son aramalara yazilir.
      expect(await ForumRecentSearches.load(), ['kantin']);
    });

    testWidgets('yorum eslesmesi: kesit gosterilir, etiket "Yorumda"', (tester) async {
      x.searchOverride = [
        {...sampleForumTopic(id: 700, title: 'Yurt sorunları'), 'matchedIn': 'COMMENT', 'snippet': 'Kantin yemekleri çok iyi'},
      ];
      await open(tester);
      await typeInto(tester, _field, 'kantin');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Yorumda'), findsOneWidget);
      final preview = tester.widget<Text>(find.byKey(const ValueKey('forum-tile-preview')));
      expect((preview.textSpan! as TextSpan).toPlainText(), 'Kantin yemekleri çok iyi');
    });

    testWidgets('bos sonuc ekrani sorguyu gosterir', (tester) async {
      await open(tester);
      await typeInto(tester, _field, 'zzzzqq');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('forum-search-empty')), findsOneWidget);
      expect(find.textContaining('zzzzqq'), findsWidgets);
    });

    testWidgets('sunucu hatasi: hata ekrani + yeniden dene sonuclari getirir', (tester) async {
      x.failSearch = true;
      await open(tester);
      await typeInto(tester, _field, 'konu');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(BuErrorState), findsOneWidget);
      x.failSearch = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(BuErrorState), findsNothing);
      expect(find.byKey(const ValueKey('forum-hit-500')), findsOneWidget);
    });

    testWidgets('cevrimdisi: baglanti yok gorunumu', (tester) async {
      await open(tester);
      b.offline = true;
      await typeInto(tester, _field, 'konu');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(BuErrorState), findsOneWidget);
    });

    testWidgets('kategori ve siralama istege yansir', (tester) async {
      await open(tester);
      await typeInto(tester, _field, 'konu');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('forum-search-categories')), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('forum-search-categories')), matching: find.text('Yemekhane')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(x.searchQueries.last, contains('categoryId=2'));
      await tester.tap(find.text('En yeni'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(x.searchQueries.last, contains('sort=NEWEST'));
      expect(x.searchQueries.last, contains('categoryId=2'));
      await tester.tap(find.text('Popüler').last);
      await settle(tester, const Duration(milliseconds: 400));
      expect(x.searchQueries.last, contains('sort=POPULAR'));
    });

    testWidgets('imecli sayfalama: sona inince sonraki sayfa istenir', (tester) async {
      await open(tester);
      await typeInto(tester, _field, 'konu');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(milliseconds: 400));
      expect(x.searchQueries.length, 1);
      for (var i = 0; i < 4 && x.searchQueries.length < 2; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -2500));
        await settle(tester, const Duration(milliseconds: 400));
      }
      expect(x.searchQueries.length, greaterThanOrEqualTo(2));
      expect(x.searchQueries[1], contains('cursor=p2'));
    });

    testWidgets('son aramalar: submit kaydeder, kalici, tek tek ve hepsini sil', (tester) async {
      await open(tester);
      await typeInto(tester, _field, 'kantin');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester, const Duration(milliseconds: 400));
      expect(await ForumRecentSearches.load(), ['kantin']);

      // Yeniden ac: kutu bos, son arama gorunur.
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester);
      expect(find.byKey(const ValueKey('forum-recent-kantin')), findsOneWidget);
      // Dokununca arar.
      await tester.tap(find.byKey(const ValueKey('forum-recent-kantin')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(x.searchQueries.last, contains('q=kantin'));

      // Temizle ile bosalt (arama modundan cik).
      await typeInto(tester, _field, '');
      await settle(tester, const Duration(milliseconds: 300));
      await ForumRecentSearches.add('yurt');
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester);
      expect(find.byKey(const ValueKey('forum-recent-yurt')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-recent-remove-yurt')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('forum-recent-yurt')), findsNothing);
      expect(find.byKey(const ValueKey('forum-recent-kantin')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-recent-clear')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(await ForumRecentSearches.load(), isEmpty);
      expect(find.byKey(const ValueKey('forum-recent-kantin')), findsNothing);
    });

    testWidgets('kutu bosken populer konular listelenir ve acilir', (tester) async {
      x.popular = [sampleForumTopic(id: 801, title: 'Haftanın tartışması'), sampleForumTopic(id: 802, title: 'Yurt servisleri')];
      final log = RouteLog();
      await open(tester, log: log);
      expect(find.byKey(const ValueKey('forum-popular-801')), findsOneWidget);
      expect(find.text('Haftanın tartışması'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-popular-802')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(log.count('forum_topic'), 1);
    });

    testWidgets('populer yok + son arama yok: baslangic ekrani; populer hatasi tekrar dene satiri', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('forum-search-start')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      x.failPopular = true;
      await open(tester);
      expect(find.text('Yeniden dene'), findsOneWidget);
    });

    testWidgets('koyu tema + buyuk yazi + dar ekran: tasma ve istisna yok', (tester) async {
      f.topics[0]['title'] = 'Çok uzun bir konu başlığı ${'kantin ' * 12}';
      await open(tester, brightness: Brightness.dark, scale: 2.0, size: kPhoneSmall);
      await typeInto(tester, _field, 'kantin');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(milliseconds: 500));
      expectNoException(tester);
      expect(find.byKey(const ValueKey('forum-search-categories')), findsOneWidget);
    });
  });
}
