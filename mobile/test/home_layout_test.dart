import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/user_data.dart';
import 'package:bu_kampus/features/home/home_layout.dart';
import 'package:bu_kampus/features/home/home_layout_sheet.dart';
import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// P3-HOME (Stitch v3): özelleştirilebilir Ana Sayfa (bölüm sırası/görünürlüğü, Hızlı Erişim kısayolları, yerel kalıcılık).
void main() {
  setUpAll(loadTestFonts);
  const st = FlutterSecureStorage();

  setUp(() async {
    mockSecureStorage();
    await HomeLayoutStore.clear();
  });
  tearDown(HomeLayoutStore.clear);

  group('HomeLayout modeli', () {
    test('varsayilan: Stitch sirasi, hepsi acik, 5 kisayol', () {
      const d = HomeLayout.defaults;
      expect(d.visible, [
        HomeSection.quickAccess,
        HomeSection.menu,
        HomeSection.todayClasses,
        HomeSection.featuredNews,
        HomeSection.upcomingEvents,
        HomeSection.announcements,
      ]);
      expect(d.shortcuts, [HomeShortcut.news, HomeShortcut.menu, HomeShortcut.events, HomeShortcut.polls, HomeShortcut.schedule]);
      expect(d.isDefault, isTrue);
    });

    test('siralama: moveSection, reorderSection (onReorderItem kurali), sinirda degismez', () {
      var v = HomeLayout.defaults.moveSection(HomeSection.featuredNews, -1);
      expect(v.order.take(4), [HomeSection.quickAccess, HomeSection.menu, HomeSection.featuredNews, HomeSection.todayClasses]);
      expect(v.moveSection(HomeSection.quickAccess, -1), v, reason: 'ilk satir yukari tasinamaz');
      expect(v.moveSection(HomeSection.announcements, 1), v, reason: 'son satir asagi tasinamaz');
      v = HomeLayout.defaults.reorderSection(0, 2); // quickAccess -> 3. siraya (cikarildiktan sonraki indeks)
      expect(v.order.take(3), [HomeSection.menu, HomeSection.todayClasses, HomeSection.quickAccess]);
      expect(v.isDefault, isFalse);
    });

    test('gizle/goster', () {
      final v = HomeLayout.defaults.setVisible(HomeSection.menu, false).setVisible(HomeSection.announcements, false);
      expect(v.isVisible(HomeSection.menu), isFalse);
      expect(v.visible, isNot(contains(HomeSection.announcements)));
      expect(v.setVisible(HomeSection.menu, true).isVisible(HomeSection.menu), isTrue);
    });

    test('kisayol: en cok 5, son acik kapatilamaz, kapatilan havuza doner, siralama', () {
      var v = HomeLayout.defaults.setShortcut(HomeShortcut.chat, true);
      expect(v.shortcuts.length, 5, reason: '6. kisayol eklenemez');
      expect(v.shortcuts, isNot(contains(HomeShortcut.chat)));
      v = v.setShortcut(HomeShortcut.polls, false).setShortcut(HomeShortcut.chat, true);
      expect(v.shortcuts.last, HomeShortcut.chat, reason: 'yeni secilen sona eklenir');
      expect(v.shortcuts, isNot(contains(HomeShortcut.polls)));
      expect(v.shortcutPool, contains(HomeShortcut.polls));
      var one = HomeLayout.defaults;
      for (final s in HomeLayout.defaults.shortcuts) {
        one = one.setShortcut(s, false);
      }
      expect(one.shortcuts.length, 1, reason: 'son acik kisayol kapatilamaz');
      final r = HomeLayout.defaults.reorderShortcut(4, 0);
      expect(r.shortcuts.first, HomeShortcut.schedule);
    });

    test('json: gidis-donus, baska kullanici/bozuk/eski kayit varsayilana duser', () {
      final v = HomeLayout.defaults.moveSection(HomeSection.quickAccess, 1).setVisible(HomeSection.todayClasses, false).setShortcut(HomeShortcut.polls, false).setShortcut(HomeShortcut.chat, true);
      final j = jsonDecode(jsonEncode(v.toJson(7)));
      expect(HomeLayout.fromJson(j, 7), v);
      expect(HomeLayout.fromJson(j, 8), HomeLayout.defaults, reason: 'baska kullanicinin duzeni');
      for (final bad in <Object?>[null, 'x', 5, [], {}, {'u': 7}, {'u': 7, 'order': 'x', 'hidden': 3, 'sOn': 1}]) {
        expect(HomeLayout.fromJson(bad, 7).order.length, HomeSection.values.length, reason: '$bad');
      }
      expect(HomeLayout.fromJson('x', 7), HomeLayout.defaults);
    });

    test('bilinmeyen kimlik atilir, yeni bolum sona eklenir, tekrarlar elenir, kisayollar 5 ile sinirli', () {
      final v = HomeLayout.fromJson({
        'u': 7,
        'order': ['featuredNews', 'eskiBolum', 'menu', 'menu'],
        'hidden': ['menu', 'eskiBolum'],
        'sOn': ['chat', 'yok', 'news', 'chat', 'menu', 'events', 'polls', 'schedule', 'clubs'],
      }, 7);
      expect(v.order.take(2), [HomeSection.featuredNews, HomeSection.menu]);
      expect(v.order.toSet(), HomeSection.values.toSet());
      expect(v.order.length, HomeSection.values.length);
      expect(v.isVisible(HomeSection.menu), isFalse);
      expect(v.isVisible(HomeSection.quickAccess), isTrue, reason: 'yeni bolum varsayilan gorunur');
      expect(v.shortcuts, [HomeShortcut.chat, HomeShortcut.news, HomeShortcut.menu, HomeShortcut.events, HomeShortcut.polls]);
    });

    test('kisayol kaydi bos/gecersizse varsayilan kisayollar', () {
      final v = HomeLayout.fromJson({'u': 7, 'order': <String>[], 'hidden': <String>[], 'sOn': <String>[]}, 7);
      expect(v.shortcuts, HomeLayout.defaults.shortcuts);
    });
  });

  group('HomeLayoutStore', () {
    test('kaydet/yukle, varsayilan kayit tutmaz, kullanici degisince ayri, bozuk kayit', () async {
      final v = HomeLayout.defaults.setVisible(HomeSection.menu, false);
      await HomeLayoutStore.save(v, 7);
      expect(await HomeLayoutStore.load(7), v);
      expect(await HomeLayoutStore.load(8), HomeLayout.defaults);
      await HomeLayoutStore.save(HomeLayout.defaults, 7);
      expect(await st.read(key: HomeLayoutStore.key), isNull, reason: 'varsayilan duzen kayit tutmaz');
      await st.write(key: HomeLayoutStore.key, value: '{bozuk json');
      expect(await HomeLayoutStore.load(7), HomeLayout.defaults);
    });

    test('cikis: kullaniciya ozel duzen silinir (registerUserDataCleaners)', () async {
      final api = ApiClient();
      registerUserDataCleaners(api);
      await HomeLayoutStore.save(HomeLayout.defaults.setVisible(HomeSection.menu, false), 7);
      expect(await st.read(key: HomeLayoutStore.key), isNotNull);
      await api.setTokens(null);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await st.read(key: HomeLayoutStore.key), isNull);
    });
  });

  group('Ana Sayfa ekrani', () {
    Widget home(FakeBackend b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}));

    FakeBackend be() => FakeBackend()
      ..on('/menu/today', {
        'date': '2026-01-01',
        'items': ['Mercimek çorbası', 'Orman kebabı'],
        'dishes': [
          {'name': 'Mercimek çorbası', 'kcal': 160},
          {'name': 'Orman kebabı', 'kcal': 380},
        ],
        'totalKcal': 540,
        'kcalComplete': true,
      })
      ..on('/news?type=HABER&page=0&size=5', {
        'items': [
          {'id': 1, 'title': 'Bahar dönemi haberi', 'type': 'HABER', 'publishedDate': '2026-01-01'},
        ]
      })
      ..on('/news?type=DUYURU&page=0&size=3', {
        'items': [
          {'id': 2, 'title': 'Sınav takvimi açıklandı', 'type': 'DUYURU', 'publishedDate': '2026-01-02'},
        ]
      });

    Future<void> saved(HomeLayout v, {int uid = 1}) => HomeLayoutStore.save(v, uid);

    /// Düzenleme sayfasındaki satırın anahtarı (satır = etiketin en yakın Row atası).
    Finder rowSwitch(String label) {
      final text = find.descendant(of: find.byType(HomeLayoutPage), matching: find.text(label));
      return find.descendant(of: find.ancestor(of: text, matching: find.byType(Row)).first, matching: find.byType(Switch));
    }

    Future<void> openEditor(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Ana sayfayı düzenle'));
      await settle(tester, const Duration(milliseconds: 700));
    }

    testWidgets('varsayilan: altı bolum acik; menu/etkinlik/haber/duyuru/ders programi istenir', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(b.count('/menu/today'), 1);
      expect(b.count('/events/featured'), 1);
      expect(b.count('type=HABER'), 1);
      expect(b.count('type=DUYURU'), 1);
      expect(b.count('/timetable'), greaterThanOrEqualTo(1));
      expect(find.text('Günün menüsü'), findsOneWidget);
      expect(find.text('Hızlı erişim'), findsOneWidget);
      expect(find.text('Duyurular'), findsOneWidget);
      expect(find.text('Bugün'), findsOneWidget);
      // Varsayilan sira: Hizli erisim < menu < haberler < etkinlikler < duyurular (dersler veri yoksa cizilmez).
      double y(String s) => tester.getTopLeft(find.text(s)).dy;
      expect(y('Hızlı erişim'), lessThan(y('Günün menüsü')));
      expect(y('Günün menüsü'), lessThan(y('Öne çıkan haberler')));
      expect(y('Öne çıkan haberler'), lessThan(y('Yaklaşan etkinlikler')));
      expect(y('Yaklaşan etkinlikler'), lessThan(y('Duyurular')));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('gizli etkinlik + haber + duyuru: veri istegi atilmaz, bolum gorunmez; menu "Bugun" icin yine istenir', (tester) async {
      useScreen(tester, const Size(390, 1600));
      await saved(HomeLayout.defaults
          .setVisible(HomeSection.upcomingEvents, false)
          .setVisible(HomeSection.featuredNews, false)
          .setVisible(HomeSection.announcements, false)
          .setVisible(HomeSection.menu, false));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(b.count('/events/featured'), 0);
      expect(b.count('type=HABER'), 0);
      expect(b.count('type=DUYURU'), 0);
      expect(find.text('Günün menüsü'), findsNothing);
      expect(find.text('Yaklaşan etkinlikler'), findsNothing);
      expect(find.byType(HomeQuickGrid), findsOneWidget);
      expect(find.byType(HomeTodayCard), findsOneWidget, reason: 'Bugun yuzeyi gizlenemez');
      await unmount(tester);
    });

    testWidgets('kayitli siralama uygulanir: haberler menuden once', (tester) async {
      useScreen(tester, const Size(390, 2400));
      await saved(HomeLayout.defaults.reorderSection(3, 1));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(tester.getTopLeft(find.text('Öne çıkan haberler')).dy, lessThan(tester.getTopLeft(find.text('Günün menüsü')).dy));
      await unmount(tester);
    });

    testWidgets('baska kullanicinin kaydi ve bozuk kayit: varsayilan duzen', (tester) async {
      useScreen(tester, const Size(390, 2400));
      await saved(HomeLayout.defaults.setVisible(HomeSection.menu, false), uid: 99); // oturum kullanicisi 1
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Günün menüsü'), findsOneWidget);
      await unmount(tester);
      await st.write(key: HomeLayoutStore.key, value: 'bu json degil');
      final b2 = be();
      await tester.pumpWidget(buildApp(home(b2)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Günün menüsü'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('duzenle sayfasi: yukari/asagi dugmeleri, gizle (kalici), varsayilana don, Bitti', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      await openEditor(tester);
      expect(find.byType(HomeLayoutPage), findsOneWidget);
      expect(find.text('Bölümleri sürükleyerek sıralayın, anahtarla gösterin veya gizleyin.'), findsOneWidget);
      // a11y: yukari/asagi dugmeleri adlandirilmis; ilk satirin "yukari"si, son satirin "asagi"si pasif.
      Finder up(String name) => find.byTooltip('$name bölümünü yukarı taşı');
      Finder down(String name) => find.byTooltip('$name bölümünü aşağı taşı');
      expect(up('Hızlı erişim'), findsOneWidget);
      expect(tester.widget<InkResponse>(find.descendant(of: up('Hızlı erişim'), matching: find.byType(InkResponse))).onTap, isNull);
      expect(tester.widget<InkResponse>(find.descendant(of: down('Duyurular'), matching: find.byType(InkResponse))).onTap, isNull);
      // Menu'yu yukari tasi -> kayit: menu en basta.
      await tester.tap(up('Günün menüsü'));
      await settle(tester, const Duration(milliseconds: 600));
      final saved1 = jsonDecode((await st.read(key: HomeLayoutStore.key))!) as Map;
      expect((saved1['order'] as List).take(2), ['menu', 'quickAccess']);
      // Menu'yu gizle.
      await tester.tap(rowSwitch('Günün menüsü'));
      await settle(tester, const Duration(milliseconds: 600));
      final saved2 = jsonDecode((await st.read(key: HomeLayoutStore.key))!) as Map;
      expect(saved2['hidden'], contains('menu'));
      // Varsayilana don: kayit silinir.
      await tester.tap(find.text('Varsayılana dön'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(await st.read(key: HomeLayoutStore.key), isNull);
      await tester.tap(find.text('Bitti'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(HomeLayoutPage), findsNothing);
      expect(find.text('Günün menüsü'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('bolum gizlenince animasyonlu kaybolur (ara karede kurulu, sonunda yok); acilinca verisi o zaman istenir', (tester) async {
      useScreen(tester, const Size(390, 2400));
      await saved(HomeLayout.defaults.setVisible(HomeSection.announcements, false));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(b.count('type=DUYURU'), 0);
      await openEditor(tester);
      await tester.tap(rowSwitch('Duyurular'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('type=DUYURU'), 1);
      // Menu'yu gizle: 60 ms sonra hala kurulu, 500 ms sonra yok.
      await tester.tap(rowSwitch('Günün menüsü'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Mercimek çorbası', skipOffstage: false), findsWidgets);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Bitti'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Sınav takvimi açıklandı'), findsOneWidget);
      expect(find.text('Günün menüsü'), findsNothing);
      await unmount(tester);
    });

    testWidgets('animasyonlari azalt: gizleme aninda', (tester) async {
      useScreen(tester, const Size(390, 2400));
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Günün menüsü'), findsOneWidget);
      await openEditor(tester);
      await tester.tap(rowSwitch('Günün menüsü'));
      await tester.pump();
      await tester.tap(find.text('Bitti'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Günün menüsü'), findsNothing);
      await unmount(tester);
    });

    testWidgets('hepsi gizli: sakin bos durum + "Bolum ekle" duzenlemeyi acar; Bugun yuzeyi kalir', (tester) async {
      useScreen(tester, const Size(390, 1200));
      var v = HomeLayout.defaults;
      for (final s in HomeSection.values) {
        v = v.setVisible(s, false);
      }
      await saved(v);
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Ana sayfan boş'), findsOneWidget);
      expect(find.text('Gösterilecek bir bölüm seçmediniz.'), findsOneWidget);
      expect(find.byType(HomeTodayCard), findsOneWidget);
      expect(b.count('/events/featured'), 0);
      expect(b.count('type=HABER'), 0);
      await tester.tap(find.text('Bölüm ekle'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(HomeLayoutPage), findsOneWidget);
      await tester.tap(find.text('Varsayılana dön'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Bitti'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Ana sayfan boş'), findsNothing);
      expect(find.text('Günün menüsü'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kisayol secici: 5 doluyken havuz pasif; birini kaldirinca eklenir, Hizli erisim guncellenir', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(HomeQuickTile), findsNWidgets(5));
      await openEditor(tester);
      await tester.tap(find.text('Kısayolları seç'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('5/5'), findsOneWidget);
      expect(find.textContaining('KISAYOLLAR (SIRALAMA)'), findsOneWidget);
      Finder poolRow(String label) => find.descendant(of: find.byType(BottomSheet), matching: find.text(label)).last;
      // 5/5: havuzdaki "Sohbet" dokunulamaz (secilmez).
      await tester.tap(poolRow('Sohbet'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('5/5'), findsOneWidget);
      // "Anketler" kaldir -> 4/5; "Sohbet" ekle -> 5/5.
      await tester.tap(find.byTooltip('Kaldır: Anketler'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('4/5'), findsOneWidget);
      await tester.tap(poolRow('Sohbet'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('5/5'), findsOneWidget);
      final j = jsonDecode((await st.read(key: HomeLayoutStore.key))!) as Map;
      expect(j['sOn'], ['news', 'menu', 'events', 'schedule', 'chat']);
      await tester.tap(find.text('Bitti').last);
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.text('Bitti').last);
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(HomeQuickTile), findsNWidgets(5));
      expect(find.text('Sohbet'), findsOneWidget);
      expect(find.text('Anketler'), findsNothing);
      await unmount(tester);
    });

    testWidgets('Hizli erisim: secilen kisayol (Destek) gorunur, secilmeyen (Haberler karosu) yok', (tester) async {
      useScreen(tester, const Size(390, 2400));
      await saved(HomeLayout.defaults.setShortcut(HomeShortcut.news, false).setShortcut(HomeShortcut.support, true));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Hızlı erişim'), findsOneWidget);
      expect(find.descendant(of: find.byType(HomeQuickGrid), matching: find.text('Destek')), findsOneWidget);
      expect(find.descendant(of: find.byType(HomeQuickGrid), matching: find.text('Haberler')), findsNothing);
      await unmount(tester);
    });
  });

  group('Duzenleme sayfasi + secici: tasma (320 dp x1.3, 3 dil, acik+koyu)', () {
    for (final lang in ['tr', 'en', 'ar']) {
      for (final dark in [false, true]) {
        testWidgets('sayfa + secici $lang ${dark ? 'koyu' : 'acik'}', (tester) async {
          useScreen(tester, const Size(320, 900));
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final c = HomeLayoutController(uid: 1);
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: BuTheme.light(),
            darkTheme: BuTheme.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            locale: Locale(lang),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: HomeLayoutPage(controller: c),
          ));
          await settle(tester, const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          expect(find.byType(Switch), findsNWidgets(HomeSection.values.length));
          final ctx = tester.element(find.byType(Switch).first);
          showHomeShortcutsSheet(ctx, c);
          await settle(tester, const Duration(milliseconds: 700));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });
}
