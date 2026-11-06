import 'package:bu_kampus/features/forum/data/forum_api.dart';
import 'package:bu_kampus/features/forum/data/forum_category_filter.dart';
import 'package:bu_kampus/features/forum/data/forum_models.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_category_picker_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_home_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_search_page.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/compose_widgets.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_forum.dart';

/// Çok sayıda forum kategorisi (V1480): süzme/gruplama saf mantığı, aramalı kategori seçici sayfası, ana sayfa çip
/// satırı ("Tüm kategoriler"), arama sayfası süzgeci ve yeni konu kategori alanı.

ForumCategory _c(int id, String name, {String? group, int groupOrder = 0, int topics = 0, String? slug}) => ForumCategory(
      id: id,
      slug: slug ?? name.toLowerCase().replaceAll(' ', '-'),
      name: name,
      sortOrder: id * 10,
      topicCount: topics,
      groupKey: group,
      groupName: group == null ? null : group[0].toUpperCase() + group.substring(1),
      groupOrder: groupOrder,
    );

/// Sunucu gibi gruplu 24 kategori: Genel (3), Akademik (7), Kampüs (6), Hobi (8).
List<ForumCategory> _many() => [
      _c(1, 'Gündem', group: 'genel', groupOrder: 10, topics: 12),
      _c(2, 'Serbest Kürsü', group: 'genel', groupOrder: 10),
      _c(3, 'Duyurular', group: 'genel', groupOrder: 10),
      _c(4, 'Dersler', group: 'akademik', groupOrder: 20, topics: 5),
      _c(5, 'Sınavlar & Notlar', group: 'akademik', groupOrder: 20),
      _c(6, 'Çıkmış Sorular', group: 'akademik', groupOrder: 20),
      _c(7, 'Hocalar & Ders Seçimi', group: 'akademik', groupOrder: 20),
      _c(8, 'Staj', group: 'akademik', groupOrder: 20),
      _c(9, 'Erasmus & Değişim', group: 'akademik', groupOrder: 20),
      _c(10, 'Yüksek Lisans & Akademik Kariyer', group: 'akademik', groupOrder: 20),
      _c(11, 'Yemekhane', group: 'kampus', groupOrder: 30, topics: 3),
      _c(12, 'Yurtlar', group: 'kampus', groupOrder: 30),
      _c(13, 'Kütüphane', group: 'kampus', groupOrder: 30),
      _c(14, 'Ulaşım & Servis', group: 'kampus', groupOrder: 30),
      _c(15, 'İkinci El & Ücretsiz', group: 'kampus', groupOrder: 30),
      _c(16, 'Öğrenci İşleri & İdari', group: 'kampus', groupOrder: 30),
      _c(17, 'Müzik', group: 'hobi', groupOrder: 70),
      _c(18, 'Film & Dizi', group: 'hobi', groupOrder: 70),
      _c(19, 'Kitap & Okuma', group: 'hobi', groupOrder: 70),
      _c(20, 'Oyun', group: 'hobi', groupOrder: 70),
      _c(21, 'Fotoğraf', group: 'hobi', groupOrder: 70),
      _c(22, 'Seyahat', group: 'hobi', groupOrder: 70),
      _c(23, 'Anime & Manga', group: 'hobi', groupOrder: 70),
      _c(24, 'Yemek Tarifleri', group: 'hobi', groupOrder: 70),
    ];

Map<String, dynamic> _json(ForumCategory c) => {
      'id': c.id,
      'slug': c.slug,
      'name': c.name,
      'sortOrder': c.sortOrder,
      'topicCount': c.topicCount,
      'groupKey': c.groupKey,
      'groupName': c.groupName,
      'groupOrder': c.groupOrder,
    };

FakeForum _forumWith(FakeBackend b, List<ForumCategory> cats) {
  final f = fakeForum(b, count: 6, categories: false);
  f.categories
    ..clear()
    ..addAll(cats.map(_json));
  return f;
}

/// Seçici testleri için: bir düğme seçiciyi açar, dönen sonucu [ForumHarnessResult]'a yazar.
class ForumHarnessResult {
  ForumCategoryChoice? choice;
  bool returned = false;
}

Widget _app(Widget home, {Brightness brightness = Brightness.light, double textScale = 1, Locale? locale}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale ?? const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    );

Widget _opener(FakeBackend b, ForumHarnessResult out,
        {List<ForumCategory>? cats, int? selectedId, bool allowAll = true, Brightness brightness = Brightness.light, double textScale = 1, Locale? locale}) =>
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-picker'),
              onPressed: () async {
                out.choice = await openForumCategoryPicker(context,
                    api: ForumApi(makeSession(b)), categories: cats ?? const [], selectedId: selectedId, allowAll: allowAll);
                out.returned = true;
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
      brightness: brightness,
      textScale: textScale,
      locale: locale,
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-picker')));
  await settle(tester);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.descendant(of: find.byKey(const ValueKey('forum-cat-search')), matching: find.byType(TextField)), text);
  await tester.pump();
}

void main() {
  setUpAll(loadTestFonts);

  group('Saf mantık: katlama, süzme, gruplama, çip seçimi', () {
    test('foldForumSearch Türkçe/Arapça farklarını yok sayar', () {
      expect(foldForumSearch('ÇIKMIŞ SORULAR'), foldForumSearch('cikmis sorular'));
      expect(foldForumSearch('İkinci El'), 'ikinci el');
      expect(foldForumSearch('Işık'), 'isik');
      expect(foldForumSearch('Müzik'), 'muzik');
      expect(foldForumSearch('الإعلانات'), foldForumSearch('الاعلانات'));
      expect(foldForumSearch('مَكتبة'), foldForumSearch('مكتبه'));
    });

    test('filterForumCategories: VE, ad + slug + grup adı, boş sorgu tüm liste', () {
      final all = _many();
      expect(filterForumCategories(all, '').length, all.length);
      expect(filterForumCategories(all, '   ').length, all.length);
      expect(filterForumCategories(all, 'MUZIK').map((e) => e.name), ['Müzik']);
      expect(filterForumCategories(all, 'müzik').map((e) => e.name), ['Müzik']);
      expect(filterForumCategories(all, 'cikmis').map((e) => e.name), ['Çıkmış Sorular']);
      expect(filterForumCategories(all, 'ogrenci isleri').map((e) => e.name), ['Öğrenci İşleri & İdari']);
      expect(filterForumCategories(all, 'ikinci el ucretsiz').length, 1);
      // grup adıyla
      expect(filterForumCategories(all, 'hobi').length, 8);
      // tüm sözcükler eşleşmeli
      expect(filterForumCategories(all, 'müzik yurtlar'), isEmpty);
      expect(filterForumCategories(all, 'zzzz'), isEmpty);
    });

    test('groupForumCategories: grup sırası, bölüm içi sıra, grupsuz sonda', () {
      final all = [..._many().reversed, _c(99, 'Başıboş')];
      final s = groupForumCategories(all);
      expect(s.map((e) => e.key), ['genel', 'akademik', 'kampus', 'hobi', null]);
      expect(s.first.items.map((e) => e.name), ['Gündem', 'Serbest Kürsü', 'Duyurular']);
      expect(s.last.name, isNull);
      expect(s.last.items.single.name, 'Başıboş');
      // hiç grup yoksa tek başlıksız bölüm
      final flat = groupForumCategories([_c(1, 'A'), _c(2, 'B')]);
      expect(flat.length, 1);
      expect(flat.single.name, isNull);
    });

    test('forumChipCategories: ilk 8 + seçili dışarıdaysa başa eklenir', () {
      final all = _many();
      expect(forumChipCategories(all, null).map((e) => e.id), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(forumChipCategories(all, 5).map((e) => e.id), [1, 2, 3, 4, 5, 6, 7, 8]);
      expect(forumChipCategories(all, 17).map((e) => e.id), [17, 1, 2, 3, 4, 5, 6, 7, 8]);
      expect(forumChipCategories(all.take(3).toList(), null).length, 3);
    });
  });

  group('Kategori seçici sayfası', () {
    testWidgets('gruplu liste: bölüm başlıkları, Tümü satırı, konu sayısı, seçili vurgu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      _forumWith(b, _many());
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out, cats: _many(), selectedId: 2));
      await _open(tester);
      expect(find.byKey(const ValueKey('forum-cat-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-cat-all')), findsOneWidget);
      expect(find.text('Genel'), findsOneWidget);
      expect(find.text('Akademik'), findsOneWidget);
      expect(find.byKey(const ValueKey('forumCategory1')), findsOneWidget);
      expect(find.text('12 konu'), findsOneWidget);
      // seçili satır: onay işareti
      expect(find.descendant(of: find.byKey(const ValueKey('forumCategory2')), matching: find.byIcon(BuIcons.check)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('forumCategory1')), matching: find.byIcon(BuIcons.check)), findsNothing);
      // sayfa başlığı metni yok
      expect(find.text('Kategori seçici'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('seçili kategori listenin sonundaysa açılışta görünür alana kaydırılır', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      _forumWith(b, _many());
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out, cats: _many(), selectedId: 23));
      await _open(tester);
      expect(find.byKey(const ValueKey('forumCategory23')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('forumCategory23')), matching: find.byIcon(BuIcons.check)), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('arama: büyük harf + Türkçe karakter duyarsız anlık süzme, grup başlığı korunur, temizleyince tüm liste', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      _forumWith(b, _many());
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out, cats: _many()));
      await _open(tester);
      await _type(tester, 'MUZIK');
      expect(find.byKey(const ValueKey('forumCategory17')), findsOneWidget);
      expect(find.byKey(const ValueKey('forumCategory1')), findsNothing);
      expect(find.text('Hobi'), findsOneWidget); // grup başlığı
      expect(find.text('Genel'), findsNothing);
      expect(find.byKey(const ValueKey('forum-cat-all')), findsNothing); // arama sırasında Tümü satırı yok
      await _type(tester, 'ikinci el');
      expect(find.byKey(const ValueKey('forumCategory15')), findsOneWidget);
      await _type(tester, '');
      expect(find.byKey(const ValueKey('forum-cat-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('forumCategory1')), findsOneWidget);
      // yerelde sonuç varken sunucuya q isteği gitmez
      expect(b.requests.where((r) => r.contains('q=')), isEmpty);
      await unmount(tester);
    });

    testWidgets('sonuç yok: boş durum; sunucu q araması yerelde bulunamayanı getirir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = _forumWith(b, _many());
      f.categorySearch = (q) => q.toLowerCase() == 'yeni kategori'
          ? [_json(_c(77, 'Yeni Kategori', group: 'hobi', groupOrder: 70))]
          : <Map<String, dynamic>>[];
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out, cats: _many()));
      await _open(tester);
      await _type(tester, 'zzqqx');
      await tester.pump(kForumCategoryRemoteDebounce + const Duration(milliseconds: 50));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-cat-empty')), findsOneWidget);
      expect(find.textContaining('zzqqx'), findsWidgets);
      expect(f.categoryQueries.where((q) => q.contains('q=zzqqx')), isNotEmpty);
      await _type(tester, 'yeni kategori');
      await tester.pump(kForumCategoryRemoteDebounce + const Duration(milliseconds: 50));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-cat-empty')), findsNothing);
      expect(find.byKey(const ValueKey('forumCategory77')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('seçim sonucu: kategori ve Tümü (null) döner', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      _forumWith(b, _many());
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out, cats: _many()));
      await _open(tester);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('forumCategory20')), 300, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byKey(const ValueKey('forumCategory20')));
      await settle(tester);
      expect(out.returned, isTrue);
      expect(out.choice!.category!.id, 20);
      expect(find.byKey(const ValueKey('forum-cat-search')), findsNothing); // sayfa kapandı

      out.returned = false;
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('forum-cat-all')));
      await settle(tester);
      expect(out.returned, isTrue);
      expect(out.choice!.category, isNull);
      await unmount(tester);
    });

    testWidgets('geri: vazgeçilince null döner', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      _forumWith(b, _many());
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out, cats: _many()));
      await _open(tester);
      await tester.tap(find.byIcon(BuIcons.arrowLeft));
      await settle(tester);
      expect(out.returned, isTrue);
      expect(out.choice, isNull);
      await unmount(tester);
    });

    testWidgets('allowAll=false: Tümü satırı yok (yeni konu)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      _forumWith(b, _many());
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out, cats: _many(), allowAll: false));
      await _open(tester);
      expect(find.byKey(const ValueKey('forum-cat-all')), findsNothing);
      expect(find.byKey(const ValueKey('forumCategory1')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('liste verilmezse sayfa yükler; hata -> yeniden dene; çevrimdışı mesajı', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 300))..offline = true;
      _forumWith(b, _many());
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out));
      await _open(tester);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('forum-cat-error')), findsOneWidget);
      expect(find.text('İnternet bağlantısı yok. Bağlanınca tekrar dene.'), findsOneWidget);
      b.offline = false;
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('forum-cat-error')), findsNothing);
      expect(find.byKey(const ValueKey('forumCategory1')), findsOneWidget);
      await unmount(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final scale in [1.0, 1.3]) {
        for (final dark in [false, true]) {
          testWidgets('taşma yok: ${size.width.toInt()} dp, yazı x$scale, ${dark ? 'koyu' : 'açık'}', (tester) async {
            useScreen(tester, size);
            final b = FakeBackend();
            _forumWith(b, _many());
            final out = ForumHarnessResult();
            await tester.pumpWidget(_opener(b, out,
                cats: _many(), selectedId: 7, textScale: scale, brightness: dark ? Brightness.dark : Brightness.light));
            await _open(tester);
            // En uzun ad (iki satıra sarılabilir) görünene kadar kaydır.
            await tester.scrollUntilVisible(find.byKey(const ValueKey('forumCategory10')), 200, scrollable: find.byType(Scrollable).last);
            expect(tester.takeException(), isNull);
            await _type(tester, 'yüksek');
            expect(find.byKey(const ValueKey('forumCategory10')), findsOneWidget);
            expect(tester.takeException(), isNull);
            await unmount(tester);
          });
        }
      }
    }

    testWidgets('Arapça RTL: yerel Arapça süzme + taşma yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final ar = [
        _c(1, 'المستجدات', group: 'genel', groupOrder: 10, topics: 3),
        _c(2, 'الإعلانات', group: 'genel', groupOrder: 10),
        _c(3, 'المكتبة', group: 'kampus', groupOrder: 30),
      ];
      _forumWith(b, ar);
      final out = ForumHarnessResult();
      await tester.pumpWidget(_opener(b, out, cats: ar, locale: const Locale('ar')));
      await _open(tester);
      expect(find.text('ابحث في الفئات'), findsOneWidget);
      expect(find.text('3 موضوع'), findsOneWidget);
      await _type(tester, 'الاعلانات'); // elif farkı: إ yerine ا
      expect(find.byKey(const ValueKey('forumCategory2')), findsOneWidget);
      expect(find.byKey(const ValueKey('forumCategory1')), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Ana sayfa: arama kutusu + çip satırı + Tüm kategoriler', () {
    Widget home(FakeBackend b, {double textScale = 1, Brightness brightness = Brightness.light}) =>
        _app(ForumHomePage(session: makeSession(b)), textScale: textScale, brightness: brightness);

    testWidgets('görünür arama kutusu: dokununca forum araması açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      _forumWith(b, _many());
      await tester.pumpWidget(home(b));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-search')), findsOneWidget);
      expect(find.text('Forumda ara'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('forum-search')));
      await settle(tester);
      expect(find.byType(ForumSearchPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('24 kategori: Tümü + ilk 8 + "Tüm kategoriler"; seçiciden dışarıdaki kategori seçilir ve çipte görünür', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = _forumWith(b, _many());
      await tester.pumpWidget(home(b));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-chip-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-chip-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-chip-17')), findsNothing); // 8'in dışında
      expect(find.byKey(const ValueKey('forum-chip-more')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-chip-more')));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-cat-search')), findsOneWidget);
      await _type(tester, 'muzik');
      await tester.tap(find.byKey(const ValueKey('forumCategory17')));
      await settle(tester);
      expect(f.topicQueries.last, contains('categoryId=17'));
      expect(find.byKey(const ValueKey('forum-chip-17')), findsOneWidget); // seçili kategori çipte görünür
      // Tümü'ne dönüş seçicinin Tümü satırıyla da olur
      await tester.tap(find.byKey(const ValueKey('forum-chip-more')));
      await settle(tester);
      expect(find.descendant(of: find.byKey(const ValueKey('forumCategory17')), matching: find.byIcon(BuIcons.check)), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('forum-cat-list')), const Offset(0, 3000)); // başa dön
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('forum-cat-all')));
      await settle(tester);
      expect(f.topicQueries.last, isNot(contains('categoryId')));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('8 veya daha az kategori: "Tüm kategoriler" çipi çıkmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 3);
      await tester.pumpWidget(home(b));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-chip-more')), findsNothing);
      await unmount(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      testWidgets('taşma yok: ${size.width.toInt()} dp, yazı x1.3, koyu', (tester) async {
        useScreen(tester, size);
        final b = FakeBackend();
        _forumWith(b, _many());
        await tester.pumpWidget(home(b, textScale: 1.3, brightness: Brightness.dark));
        await settle(tester);
        expect(find.byKey(const ValueKey('forum-search')), findsOneWidget);
        expect(find.byKey(const ValueKey('forum-chip-more')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });

  group('Arama sayfası süzgeci', () {
    testWidgets('çok kategori: çip satırı + Tüm kategoriler; seçici seçimi aramaya categoryId olarak yansır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      _forumWith(b, _many());
      await tester.pumpWidget(_app(ForumSearchPage(session: makeSession(b))));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('forum-search-field')), 'konu');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('forum-search-categories')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-chip-more')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forum-chip-more')));
      await settle(tester);
      await _type(tester, 'kutuphane');
      await tester.tap(find.byKey(const ValueKey('forumCategory13')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('forum-chip-13')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Yeni konu kategori alanı', () {
    testWidgets('alan aramalı seçiciyi açar (Tümü yok); seçim geri bildirilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      _forumWith(b, _many());
      ForumCategory? picked;
      await tester.pumpWidget(_app(Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: CategoryPickerRow(
            api: ForumApi(makeSession(b)),
            categories: _many(),
            selectedId: null,
            onSelected: (c) => picked = c,
          ),
        ),
      )));
      expect(find.text('Kategori seç'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forumCategoryField')));
      await settle(tester);
      expect(find.byKey(const ValueKey('forum-cat-all')), findsNothing);
      await _type(tester, 'staj');
      await tester.tap(find.byKey(const ValueKey('forumCategory8')));
      await settle(tester);
      expect(picked?.id, 8);
      await unmount(tester);
    });
  });
}
