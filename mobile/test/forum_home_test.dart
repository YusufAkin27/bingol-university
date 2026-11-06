import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/forum/data/forum_api.dart';
import 'package:bu_kampus/features/forum/data/forum_feed_controller.dart';
import 'package:bu_kampus/features/forum/data/forum_models.dart';
import 'package:bu_kampus/features/forum/presentation/pages/create_topic_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_activity_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_home_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_placeholder_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_prefs_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_saved_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_search_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/topic_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_forum.dart';

/// Forum ana sayfası (MB-A): yükleme/iskelet/boş/hata/çevrimdışı, kategori + sıralama istekleri, sayfalama,
/// beğeni iyimser + geri alma, anonim kart, koyu mod ve büyük yazı ölçeği.

Widget _page(FakeBackend b, {Brightness brightness = Brightness.light, Size? size, double textScale = 1}) {
  final s = makeSession(b);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), size: size ?? MediaQuery.of(context).size),
      child: child!,
    ),
    home: ForumHomePage(session: s),
  );
}

void main() {
  setUpAll(loadTestFonts);

  group('Forum ana sayfa', () {
    testWidgets('iskelet, sonra kartlar; baslik metni yok, ipucu satiri var; sabitlenmis ve anonim kart', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 300));
      fakeForum(b, count: 10);
      await tester.pumpWidget(_page(b));
      await tester.pump();
      expect(find.byKey(const ValueKey('forum-skeleton')), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('forum-skeleton')), findsNothing);
      expect(find.byKey(const ValueKey('forum-topic-500')), findsOneWidget);
      // Kullanıcı kuralı: sayfa başlığı metni görünmez; ipucu satırı görünür.
      expect(find.text('Kampüs Forum'), findsNothing);
      expect(find.text('Kampüste herkesin konuştuğu yer'), findsOneWidget);
      expect(find.text('Sabitlenmiş'), findsOneWidget);
      // Konu 497 (i=3) anonim: gerçek ad yok, nötr avatar.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('forum-topic-497')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: find.byKey(const ValueKey('forum-topic-497')), matching: find.textContaining('Anonim #')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('forum-topic-497')), matching: find.byKey(const ValueKey('forum-anon-avatar'))), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('ekran okuyucu etiketi korunur (gorunmez baslik)', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 3);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      expect(find.bySemanticsLabel('Kampüs Forum'), findsOneWidget);
      expect(find.bySemanticsLabel('Forumda ara'), findsOneWidget);
      expect(find.bySemanticsLabel('Yeni konu'), findsOneWidget);
      await unmount(tester);
      h.dispose();
    });

    testWidgets('bos forum: bos durum + Konu ac eylemi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 0);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-empty')), findsOneWidget);
      expect(find.text('Henüz konu yok'), findsOneWidget);
      await tester.tap(find.text('Konu aç'));
      await settle(tester);
      expect(find.byType(CreateTopicPage), findsOneWidget); // yeni konu rotası (MB-C)
      await unmount(tester);
    });

    testWidgets('sunucu hatasi: hata gorunumu, Yeniden dene ile toparlanir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 4)..failTopics = true;
      await tester.pumpWidget(_page(b));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Sunucuya şu an ulaşılamıyor. Biraz sonra tekrar dene.'), findsOneWidget);
      f.failTopics = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-topic-500')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('cevrimdisi: kisa mesaj + yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..offline = true;
      fakeForum(b, count: 4);
      await tester.pumpWidget(_page(b));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('İnternet bağlantısı yok. Bağlanınca tekrar dene.'), findsOneWidget);
      b.offline = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-topic-500')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kategori suzgeci: Tumu basta, secilince categoryId ile yeniden yuklenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 16);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-chip-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-chip-2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-chip-2')));
      await settle(tester);
      expect(f.topicQueries.last, contains('categoryId=2'));
      // Yalnız Yemekhane konuları kaldı.
      final cards = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('forum-topic-'));
      expect(cards, findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('forum-chip-all')));
      await settle(tester);
      expect(f.topicQueries.last, isNot(contains('categoryId')));
      await unmount(tester);
    });

    testWidgets('kategori bos: kategoriye ozel bos durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 1); // yalnız Gündem dolu
      await tester.pumpWidget(_page(b));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('forum-chip-2')));
      await settle(tester);
      expect(find.text('Bu kategoride konu yok'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('siralama: alt sayfadan secim sort parametresiyle istek atar, etiket guncellenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 8);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      expect(f.topicQueries.first, contains('sort=FOR_YOU'));
      expect(find.text('Sana özel'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-sort')));
      await settle(tester);
      for (final s in ['Sana özel', 'En yeni', 'Popüler', 'En çok yorumlanan', 'Takip ettiklerim']) {
        expect(find.text(s), findsWidgets);
      }
      await tester.tap(find.byKey(const ValueKey('forum-sort-POPULAR')));
      await settle(tester);
      expect(f.topicQueries.last, contains('sort=POPULAR'));
      expect(find.descendant(of: find.byKey(const ValueKey('forum-sort')), matching: find.text('Popüler')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-sort')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('forum-sort-FOLLOWING')));
      await settle(tester);
      expect(f.topicQueries.last, contains('sort=FOLLOWING'));
      expect(find.text('Takip ettiğin konu yok'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sayfalama: listenin sonuna inince imlecle sonraki sayfa gelir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 40);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      expect(f.topicQueries.length, 1);
      expect(find.byKey(const ValueKey('forum-topic-460')), findsNothing); // 41. sıra henüz yok
      final scroll = find.byKey(const ValueKey('forum-scroll'));
      for (var i = 0; i < 14 && f.topicQueries.length < 2; i++) {
        await tester.drag(scroll, const Offset(0, -900));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await settle(tester);
      expect(f.topicQueries.length, greaterThanOrEqualTo(2));
      expect(f.topicQueries[1], contains('cursor=p2'));
      await unmount(tester);
    });

    testWidgets('begeni iyimser artar, istek gider; sunucu hatasinda geri alinir ve uyari cikar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 4);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      final card = find.byKey(const ValueKey('forum-topic-500'));
      final like = find.descendant(of: card, matching: find.byKey(const ValueKey('forum-like')));
      expect(find.descendant(of: card, matching: find.byKey(const ValueKey('forum-like-count'))), findsNothing); // 0 beğeni
      await tester.tap(like);
      await tester.pump();
      // İyimser: istek gitmeden sayı 1.
      expect(find.descendant(of: card, matching: find.text('1')), findsOneWidget);
      expect(b.count('PUT /forum/topics/500/like'), 0);
      await settle(tester);
      expect(b.count('PUT /forum/topics/500/like'), 1);
      expect(f.liked, contains(500));
      expect(find.descendant(of: card, matching: find.text('1')), findsOneWidget);
      // Vazgeç: DELETE.
      await tester.tap(like);
      await settle(tester);
      expect(b.count('DELETE /forum/topics/500/like'), 1);
      expect(f.liked, isNot(contains(500)));
      // Hata: geri alma + uyarı.
      f.failWrites = true;
      await tester.tap(like);
      await tester.pump();
      expect(find.descendant(of: card, matching: find.text('1')), findsOneWidget);
      await settle(tester);
      expect(find.descendant(of: card, matching: find.byKey(const ValueKey('forum-like-count'))), findsNothing);
      expect(find.text('Beğeni kaydedilemedi'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('art arda hizli dokunus tek istekte birlesir (cift beğeni yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 3);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      final like = find.descendant(of: find.byKey(const ValueKey('forum-topic-500')), matching: find.byKey(const ValueKey('forum-like')));
      await tester.tap(like);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(like);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(like); // son durum: beğenilmiş
      await settle(tester);
      expect(b.count('PUT /forum/topics/500/like'), 1);
      expect(b.count('DELETE /forum/topics/500/like'), 0);
      await unmount(tester);
    });

    testWidgets('kaydet dugmesi iyimser; hata olursa geri alinir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 3);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('forum-save-500')));
      await settle(tester);
      expect(f.saved, contains(500));
      expect(b.count('PUT /forum/topics/500/bookmark'), 1);
      expect(find.byKey(const ValueKey('forum-save-500')), findsOneWidget);
      f.failWrites = true;
      await tester.tap(find.byKey(const ValueKey('forum-save-500'))); // kaydı kaldırma denemesi
      await settle(tester);
      expect(f.saved, contains(500)); // sunucuda değişmedi
      expect(find.text('Kaydetme işlemi yapılamadı'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('karta dokunma konu detayini acar; bildirim ve arama kisayollari rotaya gider', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 3);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('forum-title-500')));
      await settle(tester);
      expect(find.byType(TopicDetailPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('topicBack')));
      await settle(tester);
      expect(find.byType(TopicDetailPage), findsNothing);
      await tester.tap(find.byKey(const ValueKey('forum-search')));
      await settle(tester);
      expect(find.byType(ForumSearchPage), findsOneWidget); // MB-D gerçek arama sayfası
      await unmount(tester);
    });

    testWidgets('uc nokta menusu: baskasinin konusunda sikayet/engelle; engelleyince kart listeden duser', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 6);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('forum-more-499')));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-menu-copy')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-menu-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-menu-mute')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-menu-block')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-menu-block')));
      await settle(tester);
      expect(find.text('Yazar engellensin mi?'), findsOneWidget);
      await tester.tap(find.text('Engelle'));
      await settle(tester);
      expect(b.count('POST /forum/topics/499/block-author'), 1);
      expect(find.byKey(const ValueKey('forum-topic-499')), findsNothing);
      await unmount(tester);
    });

    testWidgets('anonim konuda sessize alma secenegi yok, engelle var', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 6);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('forum-more-497')), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const ValueKey('forum-more-497')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forum-more-497'))); // i=3: anonim
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-menu-mute')), findsNothing);
      expect(find.byKey(const ValueKey('forum-menu-block')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kendi konusunda yalniz kopyala/kaydet', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 3);
      f.topics[1]['mine'] = true;
      await tester.pumpWidget(_page(b));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('forum-more-499')));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-menu-report')), findsNothing);
      expect(find.byKey(const ValueKey('forum-menu-block')), findsNothing);
      expect(find.byKey(const ValueKey('forum-menu-copy')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('koyu mod + kucuk ekran + buyuk yazi olcegi: tasma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakeForum(b, count: 12);
      await tester.pumpWidget(_page(b, brightness: Brightness.dark, size: kPhoneSmall, textScale: 2));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-topic-500')), findsOneWidget);
      final scroll = find.byKey(const ValueKey('forum-scroll'));
      for (var i = 0; i < 4; i++) {
        await tester.drag(scroll, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('uc nokta: ek menu (kaydedilenler, faaliyetim, bildirim ayarlari) rotalara gider', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 2);
      await tester.pumpWidget(_page(b));
      await settle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('forum-overflow')));
        await settle(tester);
        await tester.tap(find.byKey(ValueKey('forum-more-menu-$i')));
        await settle(tester);
        // Sıra: kaydedilenler, faaliyetim, bildirim tercihleri (MB-D gerçek sayfaları).
        expect(find.byType([ForumSavedPage, ForumActivityPage, ForumPrefsPage][i]), findsOneWidget);
        await tester.tap(find.byTooltip('Geri')); // ForumPageBar: başlıksız üst çubukta geri düğmesi
        await settle(tester);
      }
      await unmount(tester);
    });
  });

  group('ForumFeedController', () {
    test('insertFirst sabitlenmislerin ardina ekler, tekrar eklemez; replace/remove/removeByAuthor', () async {
      final b = FakeBackend();
      fakeForum(b, count: 3);
      final c = ForumFeedController(ForumApi(makeSession(b)));
      await c.load();
      expect(c.items.first.pinned, isTrue);
      final created = TopicSummary.fromJson(sampleForumTopic(id: 999, mine: true));
      c.insertFirst(created);
      expect(c.items[1].id, 999);
      expect(c.justAddedId, 999);
      c.insertFirst(created);
      expect(c.items.where((e) => e.id == 999).length, 1);
      c.replace(created.copyWith(likedByMe: true, likeCount: 5));
      expect(c.items[1].likeCount, 5);
      c.removeByAuthor(12);
      expect(c.items.every((e) => e.author.userId != 12), isTrue);
      c.remove(999);
      expect(c.items.any((e) => e.id == 999), isFalse);
      c.dispose();
    });

    test('sort/kategori hizli degisince eski yanit yok sayilir (yaris)', () async {
      final b = FakeBackend(delay: const Duration(milliseconds: 50));
      fakeForum(b, count: 16);
      final c = ForumFeedController(ForumApi(makeSession(b)));
      final first = c.setCategory(2);
      final second = c.setCategory(3);
      await Future.wait([first, second]);
      expect(c.categoryId, 3);
      expect(c.items.every((e) => e.category?.id == 3), isTrue);
      c.dispose();
    });
  });
}
