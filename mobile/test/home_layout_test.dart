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

/// P3-HOME: özelleştirilebilir Ana Sayfa (bölüm sırası/görünürlüğü, Hızlı Erişim kısayolları, yerel kalıcılık).
void main() {
  setUpAll(loadTestFonts);
  const st = FlutterSecureStorage();

  setUp(() async {
    mockSecureStorage();
    await HomeLayoutStore.clear();
  });
  tearDown(HomeLayoutStore.clear);

  group('HomeLayout modeli', () {
    test('varsayilan = bugunku duzen (4 bolum, ilk 5 kisayol)', () {
      const d = HomeLayout.defaults;
      expect(d.visible, [HomeSection.menu, HomeSection.quickAccess, HomeSection.featuredNews, HomeSection.upcomingEvents]);
      expect(d.shortcuts, [HomeShortcut.news, HomeShortcut.menu, HomeShortcut.events, HomeShortcut.polls, HomeShortcut.schedule]);
      expect(d.isDefault, isTrue);
    });

    test('siralama: moveSection, reorderSection (onReorderItem kurali), sinirda degismez', () {
      var v = HomeLayout.defaults.moveSection(HomeSection.featuredNews, -1);
      expect(v.order.take(3), [HomeSection.menu, HomeSection.featuredNews, HomeSection.quickAccess]);
      expect(v.moveSection(HomeSection.menu, -1), v, reason: 'ilk satir yukari tasinamaz');
      expect(v.moveSection(HomeSection.todayClasses, 1), v, reason: 'son satir asagi tasinamaz');
      v = HomeLayout.defaults.reorderSection(0, 2); // menu -> 3. siraya (cikarildiktan sonraki indeks)
      expect(v.order.take(3), [HomeSection.quickAccess, HomeSection.featuredNews, HomeSection.menu]);
      expect(v.isDefault, isFalse);
    });

    test('gizle/goster', () {
      final v = HomeLayout.defaults.setVisible(HomeSection.menu, false).setVisible(HomeSection.announcements, true);
      expect(v.isVisible(HomeSection.menu), isFalse);
      expect(v.visible, contains(HomeSection.announcements));
      expect(v.setVisible(HomeSection.menu, true).isVisible(HomeSection.menu), isTrue);
    });

    test('kisayol: en cok 5, son acik kapatilamaz, siralama', () {
      var v = HomeLayout.defaults.setShortcut(HomeShortcut.chat, true);
      expect(v.shortcuts.length, 5, reason: '6. kisayol eklenemez');
      expect(v.shortcuts, isNot(contains(HomeShortcut.chat)));
      v = v.setShortcut(HomeShortcut.polls, false).setShortcut(HomeShortcut.chat, true);
      expect(v.shortcuts, contains(HomeShortcut.chat));
      expect(v.shortcuts, isNot(contains(HomeShortcut.polls)));
      var one = HomeLayout.defaults;
      for (final s in HomeLayout.defaults.shortcuts) {
        one = one.setShortcut(s, false);
      }
      expect(one.shortcuts.length, 1, reason: 'son acik kisayol kapatilamaz');
      final r = HomeLayout.defaults.reorderShortcut(4, 0);
      expect(r.shortcuts.first, HomeShortcut.schedule);
    });

    test('json: gidis-donus, baska kullanici/bozuk/eski kayit varsayilana duser', () {
      final v = HomeLayout.defaults.moveSection(HomeSection.quickAccess, 1).setVisible(HomeSection.todayClasses, true).setShortcut(HomeShortcut.polls, false).setShortcut(HomeShortcut.chat, true);
      final j = jsonDecode(jsonEncode(v.toJson(7)));
      expect(HomeLayout.fromJson(j, 7), v);
      expect(HomeLayout.fromJson(j, 8), HomeLayout.defaults, reason: 'baska kullanicinin duzeni');
      for (final bad in <Object?>[null, 'x', 5, [], {}, {'u': 7}, {'u': 7, 'order': 'x', 'hidden': 3, 'sOrder': {}, 'sOn': 1}]) {
        expect(HomeLayout.fromJson(bad, 7).visible.length, greaterThanOrEqualTo(0), reason: '$bad');
      }
      expect(HomeLayout.fromJson('x', 7), HomeLayout.defaults);
      expect(HomeLayout.fromJson({'u': 7, 'order': 'x', 'hidden': 3}, 7).order.length, HomeSection.values.length);
    });

    test('bilinmeyen kimlik atilir, yeni bolum sona (varsayilan gorunurlukle) eklenir, tekrarlar elenir', () {
      final v = HomeLayout.fromJson({
        'u': 7,
        'order': ['featuredNews', 'eskiBolum', 'menu', 'menu'],
        'hidden': ['menu', 'eskiBolum'],
        'sOrder': ['chat', 'yok', 'news'],
        'sOn': ['chat', 'yok'],
      }, 7);
      expect(v.order.take(2), [HomeSection.featuredNews, HomeSection.menu]);
      expect(v.order.toSet(), HomeSection.values.toSet());
      expect(v.order.length, HomeSection.values.length);
      expect(v.isVisible(HomeSection.menu), isFalse);
      expect(v.isVisible(HomeSection.quickAccess), isTrue, reason: 'yeni bolum varsayilan gorunur');
      expect(v.isVisible(HomeSection.announcements), isFalse, reason: 'varsayilan kapali bolum kapali gelir');
      expect(v.shortcutOrder.first, HomeShortcut.chat);
      expect(v.shortcutOrder.length, HomeShortcut.values.length);
      expect(v.shortcuts, [HomeShortcut.chat]);
    });

    test('kisayol kaydi bos/gecersizse varsayilan kisayollar', () {
      final v = HomeLayout.fromJson({'u': 7, 'order': <String>[], 'hidden': <String>[], 'sOrder': <String>[], 'sOn': <String>[]}, 7);
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
      ..on('/menu/today', {'date': '2026-01-01', 'items': ['Mercimek çorbası', 'Orman kebabı']})
      ..on('/news?type=HABER&page=0&size=5', {
        'items': [
          {'id': 1, 'title': 'Bahar dönemi duyurusu', 'type': 'HABER', 'publishedDate': '2026-01-01'},
        ]
      })
      ..on('/news?type=DUYURU&page=0&size=3', {
        'items': [
          {'id': 2, 'title': 'Sınav takvimi açıklandı', 'type': 'DUYURU', 'publishedDate': '2026-01-02'},
        ]
      });

    Future<void> saved(HomeLayout v, {int uid = 1}) => HomeLayoutStore.save(v, uid);

    /// Alt sayfadaki satirin anahtari (satir = etiketin en yakin Row atasi).
    Finder rowSwitch(String label) {
      final text = find.descendant(of: find.byType(BottomSheet), matching: find.text(label));
      return find.descendant(of: find.ancestor(of: text, matching: find.byType(Row)).first, matching: find.byType(Switch));
    }

    testWidgets('varsayilan: menu ve etkinlik istenir; duyuru ve dersler ISTENMEZ', (tester) async {
      useScreen(tester, const Size(390, 1200));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(b.count('/menu/today'), 1);
      expect(b.count('/events/featured'), 1);
      expect(b.count('type=HABER'), 1);
      expect(b.count('type=DUYURU'), 0);
      expect(b.count('/timetable'), 0);
      expect(find.text('Günün Yemek Menüsü'), findsOneWidget);
      expect(find.text('Duyurular'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('gizli menu + etkinlik: veri istegi atilmaz, bolum gorunmez', (tester) async {
      useScreen(tester, const Size(390, 1200));
      await saved(HomeLayout.defaults.setVisible(HomeSection.menu, false).setVisible(HomeSection.upcomingEvents, false));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(b.count('/menu/today'), 0);
      expect(b.count('/events/featured'), 0);
      expect(find.text('Günün Yemek Menüsü'), findsNothing);
      expect(find.text('Bugün için liste yok'), findsNothing);
      expect(find.byType(HomeQuickGrid), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kayitli siralama uygulanir: haberler menuden once', (tester) async {
      useScreen(tester, const Size(390, 1600));
      await saved(HomeLayout.defaults.reorderSection(2, 0));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(tester.getTopLeft(find.text('Öne Çıkan Haberler')).dy, lessThan(tester.getTopLeft(find.text('Günün Yemek Menüsü')).dy));
      await unmount(tester);
    });

    testWidgets('baska kullanicinin kaydi ve bozuk kayit: varsayilan duzen', (tester) async {
      useScreen(tester, const Size(390, 1200));
      await saved(HomeLayout.defaults.setVisible(HomeSection.menu, false), uid: 99); // oturum kullanicisi 1
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Günün Yemek Menüsü'), findsOneWidget);
      await unmount(tester);
      await st.write(key: HomeLayoutStore.key, value: 'bu json degil');
      final b2 = be();
      await tester.pumpWidget(buildApp(home(b2)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Günün Yemek Menüsü'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('duzenle sheet: yukari/asagi dugmeleri, gizle (kalici), varsayilana don', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      await tester.tap(find.byTooltip('Ana sayfayı düzenle'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Ana sayfayı düzenle'), findsWidgets);
      // a11y: yukari/asagi dugmeleri adlandirilmis; ilk satirin "yukari"si, son satirin "asagi"si pasif.
      expect(find.byTooltip('Günün Menüsü bölümünü yukarı taşı'), findsOneWidget);
      expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip('Günün Menüsü bölümünü yukarı taşı'), matching: find.byType(IconButton)).first).onPressed, isNull);
      expect(tester.widget<IconButton>(find.ancestor(of: find.byTooltip('Bugünkü dersler bölümünü aşağı taşı'), matching: find.byType(IconButton)).first).onPressed, isNull);
      // Hizli Erisim'i yukari tasi -> menunun ustune cikar (arkadaki sayfa canli degisir).
      await tester.tap(find.byTooltip('Hızlı Erişim bölümünü yukarı taşı'));
      await settle(tester, const Duration(milliseconds: 600));
      final saved1 = jsonDecode((await st.read(key: HomeLayoutStore.key))!) as Map;
      expect((saved1['order'] as List).take(2), ['quickAccess', 'menu']);
      // Menu'yu gizle.
      await tester.tap(rowSwitch('Günün Menüsü'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Günün Yemek Menüsü'), findsNothing);
      final saved2 = jsonDecode((await st.read(key: HomeLayoutStore.key))!) as Map;
      expect(saved2['hidden'], contains('menu'));
      // Varsayilana don: kayit silinir, menu geri gelir.
      await tester.tap(find.text('Varsayılana dön'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(await st.read(key: HomeLayoutStore.key), isNull);
      expect(find.text('Günün Yemek Menüsü'), findsOneWidget);
      await tester.tap(find.text('Bitti'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('gizli bolum acilinca verisi o zaman istenir (duyurular)', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(b.count('type=DUYURU'), 0);
      await tester.tap(find.byTooltip('Ana sayfayı düzenle'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(rowSwitch('Duyurular'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count('type=DUYURU'), 1);
      await tester.tap(find.text('Bitti'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Sınav takvimi açıklandı'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hepsi gizli: sakin bos durum + "Bolum ekle" duzenlemeyi acar', (tester) async {
      useScreen(tester, const Size(390, 1000));
      var v = HomeLayout.defaults;
      for (final s in HomeSection.values) {
        v = v.setVisible(s, false);
      }
      await saved(v);
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Ana sayfan boş'), findsOneWidget);
      expect(b.count('/menu/today'), 0);
      expect(b.count('/events/featured'), 0);
      expect(b.count('type=HABER'), 0);
      await tester.tap(find.text('Bölüm ekle'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Varsayılana dön'), findsOneWidget);
      await tester.tap(find.text('Varsayılana dön'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Bitti'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Ana sayfan boş'), findsNothing);
      expect(find.text('Günün Yemek Menüsü'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kisayol secici: 5 doluyken kapalilar pasif; birini kapatinca eklenir ve Hizli Erisim degisir', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(HomeQuickTile), findsNWidgets(5));
      await tester.tap(find.byTooltip('Ana sayfayı düzenle'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('5 kısayol'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('En çok 5 kısayol seçebilirsin.'), findsOneWidget);
      Switch sw(String label) => tester.widget<Switch>(rowSwitch(label));
      expect(sw('Sohbet').onChanged, isNull, reason: '5 dolu');
      expect(sw('Haberler').onChanged, isNotNull);
      await tester.tap(rowSwitch('Anketler'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(sw('Sohbet').onChanged, isNotNull);
      await tester.tap(rowSwitch('Sohbet'));
      await settle(tester, const Duration(milliseconds: 600));
      final j = jsonDecode((await st.read(key: HomeLayoutStore.key))!) as Map;
      expect(j['sOn'], containsAll(['chat']));
      expect(j['sOn'], isNot(contains('polls')));
      await tester.tap(find.text('Bitti').last);
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Bitti').last);
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(HomeQuickTile), findsNWidgets(5));
      expect(find.text('Sohbet'), findsOneWidget);
      expect(find.text('Anketler'), findsNothing);
      await unmount(tester);
    });

    testWidgets('animasyonlari azalt: gizleme aninda (AnimatedSwitcher gecisi yok)', (tester) async {
      useScreen(tester, const Size(390, 1400));
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byTooltip('Ana sayfayı düzenle'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(rowSwitch('Günün Menüsü'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Günün Yemek Menüsü'), findsNothing);
      await unmount(tester);
    });

    testWidgets('gizleme animasyonlu: ara karede bolum hala kurulu, sonunda yok', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      await tester.tap(find.byTooltip('Ana sayfayı düzenle'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(rowSwitch('Günün Menüsü'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Günün Yemek Menüsü'), findsOneWidget, reason: 'solma sürüyor');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Günün Yemek Menüsü'), findsNothing);
      await unmount(tester);
    });

    testWidgets('Hizli Erisim: baslik satiri yok, kapsayici etiketi var; secilen kisayol (Destek) acar', (tester) async {
      useScreen(tester, const Size(390, 1200));
      await saved(HomeLayout.defaults.setShortcut(HomeShortcut.news, false).setShortcut(HomeShortcut.support, true));
      final b = be();
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Hızlı Erişim'), findsNothing);
      expect(find.bySemanticsLabel('Hızlı Erişim'), findsOneWidget);
      expect(find.text('Destek'), findsOneWidget);
      expect(find.text('Haberler'), findsNothing);
      await unmount(tester);
    });
  });

  group('Duzenleme sheet: tasma (320 dp x1.3, 3 dil, acik+koyu)', () {
    for (final lang in ['tr', 'en', 'ar']) {
      for (final dark in [false, true]) {
        testWidgets('sheet + secici $lang ${dark ? 'koyu' : 'acik'}', (tester) async {
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
            home: Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showHomeLayoutSheet(context, c), child: const Text('ac'))))),
          ));
          await tester.tap(find.text('ac'));
          await settle(tester, const Duration(milliseconds: 700));
          expect(tester.takeException(), isNull);
          expect(find.byType(Switch), findsNWidgets(HomeSection.values.length));
          // Tum bolumleri ac: en uzun adli satirlar da tasmasin.
          c.update((v) => v.setVisible(HomeSection.announcements, true).setVisible(HomeSection.todayClasses, true));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
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
