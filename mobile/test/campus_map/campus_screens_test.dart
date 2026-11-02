import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/features/campus_map/campus_category_page.dart';
import 'package:bu_kampus/features/campus_map/campus_home_card.dart';
import 'package:bu_kampus/features/campus_map/campus_local_store.dart';
import 'package:bu_kampus/features/campus_map/campus_location.dart';
import 'package:bu_kampus/features/campus_map/campus_map_controller.dart';
import 'package:bu_kampus/features/campus_map/campus_map_page.dart';
import 'package:bu_kampus/features/campus_map/campus_place_page.dart';
import 'package:bu_kampus/features/campus_map/campus_search_page.dart';
import 'package:bu_kampus/features/campus_map/campus_states.dart';
import 'package:bu_kampus/features/campus_map/campus_widgets.dart' show CampusPin, CampusClusterPin;
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show FlutterMap;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../redesign/p00_support.dart';
import '../support/fake_app.dart';
import 'campus_fixtures.dart';

const _inside = LatLng(38.8991, 40.4861);

/// Sayfa/ekranı gerçek tema + 3 dil delegeleriyle sarar.
Widget app(Widget child, {bool dark = false, String lang = 'tr'}) => p00App(child, scaffold: false, dark: dark, lang: lang);

Future<void> pumpMs(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<CampusMapController> ready(FakeCampusRepo repo, FakeCampusLocationService loc) async {
  final c = CampusMapController(repo: repo, location: loc);
  await c.start();
  return c;
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() async {
    mockSecureStorage();
    await CampusLocalStore.clear();
  });

  Widget mapPage(CampusMapController c, FakeCampusRepo repo) => CampusMapPage(repository: repo, controller: c, tileProvider: NoTiles());

  group('ana ekran (Harita - Ana)', () {
    testWidgets('başlık, arama çubuğu, kampüs içi çipi, kategori çipleri, panel ve atıf görünür', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      expect(find.text('Harita'), findsOneWidget);
      expect(find.text('BU KAMPÜS'), findsOneWidget);
      expect(find.text('Kampüste ara'), findsOneWidget);
      expect(find.text('Yalnızca kampüs içi yerler'), findsOneWidget);
      for (final s in ['Tümü', 'Fakülteler', 'Yemekhane', 'Kütüphane']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(find.text('Kampüste yerler'), findsOneWidget, reason: 'konum yokken "yakınımda" denmez');
      expect(find.text('4 yer'), findsOneWidget, reason: 'uzak yerleşke panel sayısına girmez');
      expect(find.text('Tümünü Gör'), findsOneWidget);
      expect(find.text('© OpenStreetMap katkıda bulunanları'), findsOneWidget, reason: 'harita üzerinde atıf zorunlu');
      expect(find.byIcon(BuIcons.layers), findsNothing, reason: 'uydu karosu yoksa katman düğmesi gizli');
      expect(find.byIcon(BuIcons.plus), findsOneWidget);
      expect(find.byIcon(BuIcons.minus), findsOneWidget);
      expect(find.byIcon(BuIcons.locateFixed), findsWidgets);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('uydu karosu sunucudan gelirse katman düğmesi çıkar ve çalışır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo(config: sampleConfig(satellite: true));
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      expect(find.byIcon(BuIcons.layers), findsOneWidget);
      await tester.tap(find.byIcon(BuIcons.layers));
      await pumpMs(tester);
      expect(find.text('Sat'), findsOneWidget, reason: 'uydu atfı gösterilir');
      c.dispose();
    });

    testWidgets('kategori çipi listeyi süzer', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      await tester.tap(find.text('Yemekhane').first);
      await pumpMs(tester);
      expect(c.category, 'food');
      expect(find.text('1 yer'), findsOneWidget);
      await tester.tap(find.text('Tümü').first);
      await pumpMs(tester);
      expect(find.text('4 yer'), findsOneWidget);
      c.dispose();
    });

    testWidgets('alt panel 3 aşamalı: yarım -> tam (sürükle) -> kısık (tutamaç döngüsü)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      double h() => tester.getSize(find.byKey(const ValueKey('campus-panel'))).height;
      final half = h();
      expect(half, greaterThan(200));
      // tutamaç: yarım -> tam
      await tester.tap(find.bySemanticsLabel('Yer listesi paneli'));
      await pumpMs(tester, 1000);
      final full = h();
      expect(full, greaterThan(half + 150), reason: 'tam aşama yarımdan belirgin büyük');
      // tutamaç: tam -> kısık
      await tester.tap(find.bySemanticsLabel('Yer listesi paneli'));
      await pumpMs(tester, 1000);
      final peek = h();
      expect(peek, lessThan(half - 100), reason: 'kısık aşama yalnız başlık');
      expect(find.text('Kampüste yerler'), findsOneWidget);
      // sürükleyerek kısıktan yarıma
      await tester.drag(find.bySemanticsLabel('Yer listesi paneli'), const Offset(0, -200));
      await pumpMs(tester, 1000);
      expect(h(), greaterThan(peek + 100));
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('uzak yerleşke: panelde "Diğer yerleşkeler" grubu, haritada iğne yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      await tester.tap(find.bySemanticsLabel('Yer listesi paneli'));
      await pumpMs(tester, 1000);
      await tester.dragUntilVisible(find.text('Hayvan Hastanesi'), find.byType(CustomScrollView), const Offset(0, -150));
      expect(find.text('DİĞER YERLEŞKELER'), findsOneWidget);
      expect(find.text('Hayvan Hastanesi'), findsOneWidget);
      final pins = find.byType(CampusPin).evaluate().length + tester.widgetList<CampusClusterPin>(find.byType(CampusClusterPin)).fold<int>(0, (a, w) => a + w.count);
      expect(pins, 4, reason: 'yalnız ana yerleşkedeki 4 yerin iğnesi/kümesi var');
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('yükleniyor -> iskelet, sonra hazır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo(delay: const Duration(milliseconds: 500));
      await tester.pumpWidget(app(CampusMapPage(repository: repo, tileProvider: NoTiles())));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BuSkeleton), findsWidgets);
      expect(find.text('Kampüste ara'), findsNothing);
      await pumpMs(tester, 1500);
      expect(find.text('Kampüste ara'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hata kartı + Yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo(error: networkError());
      await tester.pumpWidget(app(CampusMapPage(repository: repo, tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.text('Harita yüklenemedi. Bağlantınızı kontrol edin.'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      repo.error = null;
      await tester.tap(find.text('Yeniden dene'));
      await pumpMs(tester, 1000);
      expect(find.text('Kampüste ara'), findsOneWidget);
      expect(find.text('Harita yüklenemedi. Bağlantınızı kontrol edin.'), findsNothing);
    });

    testWidgets('bakım durumu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo(error: ApiError(503, 'MAINTENANCE', ''));
      await tester.pumpWidget(app(CampusMapPage(repository: repo, tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.text('Kampüs haritası şu an bakımda'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
    });

    testWidgets('yer listesi boşken boş durum metni', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo(places: const []);
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      expect(find.text('Henüz kampüs yeri eklenmemiş.'), findsOneWidget);
      c.dispose();
    });

    testWidgets('karolar yüklenemiyorsa açıklayıcı bant (boş gri yüzey yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      for (var i = 0; i < CampusMapController.tileErrorThreshold; i++) {
        c.noteTileError();
      }
      await pumpMs(tester);
      expect(find.text('Harita parçaları yüklenemiyor. Bağlantınızı kontrol edin.'), findsOneWidget);
      c.clearTileErrors();
      await pumpMs(tester);
      expect(find.text('Harita parçaları yüklenemiyor. Bağlantınızı kontrol edin.'), findsNothing);
      c.dispose();
    });

    testWidgets('iğneye dokunma: seçili yer kartı (Detay / Yol tarifi), kapat düğmesi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      c.select(2);
      await pumpMs(tester, 800);
      expect(find.text('Detay'), findsOneWidget);
      expect(find.text('Yol tarifi'), findsOneWidget);
      await tester.tap(find.byTooltip('Yer kartını kapat'));
      await pumpMs(tester);
      expect(c.selectedId, isNull);
      expect(find.text('Detay'), findsNothing);
      c.dispose();
    });
  });

  group('konum durumları (ekran)', () {
    testWidgets('izin kartı: "Şimdi değil" kartı kaldırır, harita çalışır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final loc = FakeCampusLocationService(perm: CampusPerm.denied);
      final c = await ready(repo, loc);
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      expect(find.text('Konumunuzu kullanalım mı?'), findsOneWidget, reason: 'izin hiç sorulmadıysa açılışta kart (alt sayfa)');
      expect(find.textContaining('Konumunuz yalnızca cihazınızda kullanılır ve paylaşılmaz.'), findsOneWidget);
      expect(find.text('Cihazda kalır'), findsOneWidget);
      expect(find.text('İzin ver'), findsOneWidget);
      await tester.tap(find.text('Şimdi değil'));
      await pumpMs(tester, 800);
      expect(find.text('Konumunuzu kullanalım mı?'), findsNothing);
      expect(loc.requests, 0, reason: 'sistem istemi çıkmadı');
      expect(c.loc, CampusLocState.denied);
      expect(await CampusLocalStore.loadPromptDismissed(), isTrue, reason: 'tekrar tekrar sorulmaz');
      expect(find.text('Kampüste ara'), findsOneWidget, reason: 'harita konumsuz da çalışır');
      expect(find.text('Konum kapalı'), findsNothing, reason: '"Şimdi değil" sonrası uyarı bandı dayatılmaz');
      c.dispose();
    });

    testWidgets('izin ver -> konum gelir -> panel "Kampüste yakınımda" + mesafeler', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final loc = FakeCampusLocationService(perm: CampusPerm.denied, fix: const CampusFix(_inside, accuracy: 15));
      final c = await ready(repo, loc);
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      await tester.tap(find.text('İzin ver'));
      await pumpMs(tester, 1200);
      expect(loc.requests, 1);
      expect(find.text('Konumunuzu kullanalım mı?'), findsNothing);
      expect(find.text('Kampüste yakınımda'), findsOneWidget);
      expect(find.byIcon(BuIcons.navigation), findsWidgets, reason: 'mesafe işareti');
      expect(find.textContaining(' m'), findsWidgets);
      c.dispose();
    });

    testWidgets('kalıcı ret: "Konum kapalı" bandı + Ayarları aç', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final loc = FakeCampusLocationService(perm: CampusPerm.deniedForever);
      final prev = CampusLocationService.instance;
      CampusLocationService.instance = loc;
      addTearDown(() => CampusLocationService.instance = prev);
      final c = await ready(repo, loc);
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      expect(find.text('Konum kapalı'), findsOneWidget);
      await tester.tap(find.text('Ayarları aç'));
      await pumpMs(tester);
      expect(loc.settingsOpened, 1);
      expect(find.text('Kampüste ara'), findsOneWidget, reason: 'harita yine çalışır');
      c.dispose();
    });

    testWidgets('cihaz konum servisi kapalı kartı', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final loc = FakeCampusLocationService(perm: CampusPerm.granted, enabled: false);
      final prev = CampusLocationService.instance;
      CampusLocationService.instance = loc;
      addTearDown(() => CampusLocationService.instance = prev);
      final c = await ready(repo, loc);
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      expect(find.text('Konum Servisi Devre Dışı'), findsOneWidget);
      expect(find.text('Kapalı'), findsOneWidget);
      await tester.tap(find.text('Ayarları aç'));
      await pumpMs(tester);
      expect(loc.locationSettingsOpened, 1);
      c.dispose();
    });

    testWidgets('kampüs dışındayken bilgi bandı', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final loc = FakeCampusLocationService(perm: CampusPerm.granted, fix: const CampusFix(LatLng(38.98, 40.6)));
      final c = await ready(repo, loc);
      await pumpMs(tester, 200);
      await tester.pumpWidget(app(mapPage(c, repo)));
      await pumpMs(tester);
      expect(find.text('Şu an kampüsün dışındasınız.'), findsOneWidget);
      expect(find.text('Kampüste yerler'), findsOneWidget, reason: 'kampüs dışında "yakınımda" denmez');
      c.dispose();
    });

    testWidgets('izin kartı bileşeni tr/en/ar x açık/koyu x 1.3x yazı: taşma yok', (tester) async {
      await p00Matrix(
        tester,
        () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(children: [
            CampusPermissionCard(onAllow: _noop, onLater: _noop),
            SizedBox(height: 12),
            CampusServiceOffCard(onOpenSettings: _noop),
            SizedBox(height: 12),
            CampusLocationBand(state: CampusLocState.deniedForever, onOpenSettings: _noop, onRetry: _noop),
            SizedBox(height: 12),
            CampusTilesBand(onRetry: _noop),
          ]),
        ),
      );
    });
  });

  group('arama ekranı (Harita - Arama)', () {
    testWidgets('"mü" -> kategori grubu başlığı, sonuç sayısı, vurgulu eşleşme; sonuç yoksa not', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusSearchPage(controller: c, tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.text('Yalnızca kampüs içi yerler'), findsOneWidget);
      expect(find.text('Kampüs dışındaki yerler aranamaz.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'mü');
      await pumpMs(tester);
      expect(find.text('FAKÜLTELER'), findsOneWidget);
      expect(find.text('1 Sonuç'), findsOneWidget);
      expect(find.text('Mühendislik Fakültesi', findRichText: true), findsOneWidget);
      // vurgulanan parça "Mü" marka renginde
      final rich = tester.widget<RichText>(find.descendant(of: find.byType(CampusSearchPage), matching: find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == 'Mühendislik Fakültesi')).first);
      final root = (rich.text as TextSpan).children!.single as TextSpan;
      final spans = root.children!.cast<TextSpan>();
      expect(spans[1].text, 'Mü');
      expect(spans[1].style!.color, BuTheme.light().extension<BuTokens>()!.pr, reason: 'eşleşen parça marka renginde');
      await tester.enterText(find.byType(TextField), 'zzzz');
      await pumpMs(tester);
      expect(find.text('Kampüs içinde sonuç bulunamadı. Farklı bir ad deneyin.'), findsOneWidget);
      expect(find.text('Kampüs dışındaki yerler aranamaz.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('uzak yerleşke aramada "Diğer yerleşkeler" grubunda çıkar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusSearchPage(controller: c, tileProvider: NoTiles())));
      await pumpMs(tester);
      await tester.enterText(find.byType(TextField), 'hayvan');
      await pumpMs(tester);
      expect(find.text('DİĞER YERLEŞKELER'), findsOneWidget);
      expect(find.text('Hayvan Hastanesi', findRichText: true), findsOneWidget);
      c.dispose();
    });

    testWidgets('aksan duyarsız: "kutuphane" Kütüphane\'yi bulur; birim adıyla da bulunur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusSearchPage(controller: c, tileProvider: NoTiles())));
      await pumpMs(tester);
      await tester.enterText(find.byType(TextField), 'KUTUPHANE');
      await pumpMs(tester);
      expect(find.text('KÜTÜPHANE'), findsOneWidget, reason: 'grup başlığı');
      expect(find.text('Merkez Kütüphane', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bilgisayar');
      await pumpMs(tester);
      expect(find.text('Mühendislik Fakültesi', findRichText: true), findsOneWidget);
      c.dispose();
    });

    testWidgets('son aramalar: yerel, silinebilir, Temizle hepsini siler', (tester) async {
      useScreen(tester, kPhoneMedium);
      await CampusLocalStore.saveRecent(['Kütüphane', 'Yemekhane']);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusSearchPage(controller: c, tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.text('SON ARAMALAR'), findsOneWidget);
      expect(find.byTooltip('Aramayı sil'), findsNWidgets(2));
      expect(find.text('Yemekhane'), findsWidgets);
      expect(find.text('Temizle'), findsOneWidget);
      await tester.tap(find.byTooltip('Aramayı sil').first);
      await pumpMs(tester);
      expect(find.byTooltip('Aramayı sil'), findsOneWidget);
      expect(await CampusLocalStore.loadRecent(), ['Yemekhane']);
      await tester.tap(find.text('Temizle'));
      await pumpMs(tester);
      expect(find.text('SON ARAMALAR'), findsNothing);
      expect(await CampusLocalStore.loadRecent(), isEmpty);
      c.dispose();
    });

    testWidgets('gönderilen arama son aramalara yazılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusSearchPage(controller: c, tileProvider: NoTiles())));
      await pumpMs(tester);
      await tester.enterText(find.byType(TextField), 'fen');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpMs(tester);
      expect(await CampusLocalStore.loadRecent(), ['fen']);
      c.dispose();
    });

    testWidgets('konum varken "HIZLI ROTA / En yakın yer / Başlat" kartı', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final loc = FakeCampusLocationService(perm: CampusPerm.granted, fix: const CampusFix(_inside));
      final c = await ready(repo, loc);
      await pumpMs(tester, 200);
      await tester.pumpWidget(app(CampusSearchPage(controller: c, tileProvider: NoTiles())));
      await pumpMs(tester);
      await tester.enterText(find.byType(TextField), 'fak');
      await pumpMs(tester);
      expect(find.text('HIZLI ROTA'), findsOneWidget);
      expect(find.text('En yakın yer'), findsOneWidget);
      expect(find.text('Başlat'), findsOneWidget);
      c.dispose();
    });

    testWidgets('arama ekranı: tr/en/ar x açık/koyu x 1.3x: taşma yok', (tester) async {
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await CampusLocalStore.saveRecent(['Kütüphane']);
      await p00Matrix(tester, () => CampusSearchPage(controller: c, tileProvider: NoTiles()), scaffold: false, settleMs: 300);
      c.dispose();
    });
  });

  group('yer detayı (Harita - Yer detayı)', () {
    testWidgets('Konum / Birimler / Yürüyerek süre + eylemler; konum yokken süre yerine ipucu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusPlacePage(controller: c, place: c.places.first, tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.text('Bina Detayı'), findsOneWidget);
      expect(find.text('Mühendislik Fakültesi'), findsOneWidget);
      expect(find.text('Fakülteler'), findsOneWidget, reason: 'kategori çipi');
      expect(find.text('KONUM'), findsOneWidget);
      expect(find.text('Ana kampüs'), findsOneWidget);
      expect(find.text('BİRİMLER'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği, İnşaat Mühendisliği, Makine Mühendisliği'), findsOneWidget);
      expect(find.text('YÜRÜYEREK SÜRE'), findsOneWidget);
      expect(find.text('Konum açık değil'), findsOneWidget);
      await tester.ensureVisible(find.text('Paylaş'));
      await pumpMs(tester, 300);
      expect(find.text('Yol tarifi'), findsOneWidget);
      expect(find.text('Haritada aç'), findsOneWidget);
      expect(find.text('Paylaş'), findsOneWidget);
      expect(find.text('© OpenStreetMap katkıda bulunanları'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('konum varken yürüme süresi istemcide: "N dk (M m)"', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final loc = FakeCampusLocationService(perm: CampusPerm.granted, fix: const CampusFix(LatLng(38.8981, 40.4870)));
      final c = await ready(repo, loc);
      await pumpMs(tester, 200);
      final far = c.places.firstWhere((p) => p.id == 3); // Yemekhane ~ 300 m
      await tester.pumpWidget(app(CampusPlacePage(controller: c, place: far, tileProvider: NoTiles())));
      await pumpMs(tester);
      final d = c.distanceTo(far)!;
      expect(find.textContaining('dk ('), findsOneWidget);
      expect(find.text('${(d / 80).ceil()} dk (${d < 100 ? d.round() : (d / 10).round() * 10} m)'), findsOneWidget);
      c.dispose();
    });

    testWidgets('favori kalbi yerel: ekle/çıkar, semantik etiket değişir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusPlacePage(controller: c, place: c.places.first, tileProvider: NoTiles())));
      await pumpMs(tester);
      await tester.tap(find.byTooltip('Favorilere ekle'));
      await pumpMs(tester);
      expect(c.isFavorite(1), isTrue);
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
      expect(find.byIcon(BuIcons.heartFilled), findsOneWidget);
      expect(await CampusLocalStore.loadFavorites(), {1});
      await tester.tap(find.byTooltip('Favorilerden çıkar'));
      await pumpMs(tester);
      expect(c.isFavorite(1), isFalse);
      expect(await CampusLocalStore.loadFavorites(), isEmpty);
      c.dispose();
    });

    testWidgets('Paylaş: ad + bağlantı panoya kopyalanır', (tester) async {
      useScreen(tester, kPhoneMedium);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusPlacePage(controller: c, place: c.places.first, tileProvider: NoTiles())));
      await pumpMs(tester);
      await tester.ensureVisible(find.text('Paylaş'));
      await pumpMs(tester, 300);
      await tester.tap(find.text('Paylaş'));
      await pumpMs(tester);
      expect(copied, contains('Mühendislik Fakültesi'));
      expect(copied, contains('https://www.openstreetmap.org/'));
      expect(copied, contains('mlat=38.899'));
      expect(find.text('Yer bilgisi ve bağlantı kopyalandı'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      c.dispose();
    });

    testWidgets('birim sayfası bağlantısı: yalnız webUrl varsa; bölümler satırı departments yoksa gizli', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusPlacePage(controller: c, place: c.places.first, tileProvider: NoTiles())));
      await pumpMs(tester);
      await tester.ensureVisible(find.textContaining('Birim sayfası'));
      expect(find.text('Birim sayfası · muh.bingol.edu.tr'), findsOneWidget);
      // webUrl'siz + bölümsüz yer
      await tester.pumpWidget(app(CampusPlacePage(controller: c, place: c.places.firstWhere((p) => p.id == 2), tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.textContaining('Birim sayfası'), findsNothing);
      expect(find.text('BİRİMLER'), findsNothing, reason: 'departments boşsa satır gizli');
      c.dispose();
    });

    testWidgets('uzak yerleşke detayı: harita ve yürüme süresi yok, "Haritada aç" + birim sayfası var', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      final far = c.places.firstWhere((p) => p.id == 5);
      await tester.pumpWidget(app(CampusPlacePage(controller: c, place: far, tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.byType(FlutterMap), findsNothing, reason: 'kamera ana yerleşkeye kilitli; uzak yer haritada gösterilmez');
      expect(find.text('YÜRÜYEREK SÜRE'), findsNothing);
      expect(find.text('Diğer yerleşkeler'), findsOneWidget);
      await tester.ensureVisible(find.text('Haritada aç'));
      expect(find.text('Haritada aç'), findsOneWidget);
      expect(find.text('Birim sayfası · hayvanhastanesi.bingol.edu.tr'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('detay: tr/en/ar x açık/koyu x 1.3x: taşma yok', (tester) async {
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await p00Matrix(tester, () => CampusPlacePage(controller: c, place: c.places.first, tileProvider: NoTiles()), scaffold: false, settleMs: 300);
      c.dispose();
    });
  });

  group('kategori listesi (Harita - Kategori listesi)', () {
    testWidgets('Fakülteler: 2 satır, sayı, "Aradığınız yeri bulamadınız mı?" kartı + not', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusCategoryPage(controller: c, category: 'faculty', tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.text('Fakülteler'), findsWidgets);
      expect(find.text('2 yer'), findsOneWidget);
      expect(find.text('Mühendislik Fakültesi'), findsOneWidget);
      expect(find.text('Fen Edebiyat Fakültesi'), findsOneWidget);
      expect(find.text('Merkez Kütüphane'), findsNothing, reason: 'başka kategori');
      await tester.scrollUntilVisible(find.text('Aradığınız yeri bulamadınız mı?'), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('Yalnızca kampüs içi yerler gösterilmektedir.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('konum varken mesafe hapları ve yakınlığa göre sıra; Ad sıralaması', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo();
      final loc = FakeCampusLocationService(perm: CampusPerm.granted, fix: const CampusFix(LatLng(38.8842, 40.4961)));
      final c = await ready(repo, loc);
      await pumpMs(tester, 200);
      await tester.pumpWidget(app(CampusCategoryPage(controller: c, category: 'faculty', tileProvider: NoTiles())));
      await pumpMs(tester);
      double y(String s) => tester.getTopLeft(find.text(s)).dy;
      expect(y('Fen Edebiyat Fakültesi'), lessThan(y('Mühendislik Fakültesi')), reason: 'yakın olan üstte');
      await tester.tap(find.text('Ad'));
      await pumpMs(tester);
      expect(y('Fen Edebiyat Fakültesi'), lessThan(y('Mühendislik Fakültesi')), reason: 'alfabetik: Fen < Mühendislik');
      c.dispose();
    });

    testWidgets('kategori boşsa boş durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      final repo = FakeCampusRepo(places: samplePlaces().where((p) => p.category != 'library').toList());
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await tester.pumpWidget(app(CampusCategoryPage(controller: c, category: 'library', tileProvider: NoTiles())));
      await pumpMs(tester);
      expect(find.text('Bu kategoride yer yok.'), findsOneWidget);
      c.dispose();
    });

    testWidgets('kategori listesi: tr/en/ar x açık/koyu x 1.3x: taşma yok', (tester) async {
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await p00Matrix(tester, () => CampusCategoryPage(controller: c, category: 'faculty', tileProvider: NoTiles()), scaffold: false, settleMs: 300);
      c.dispose();
    });
  });

  group('tüm ana ekran matrisi', () {
    testWidgets('ana ekran: tr/en/ar x açık/koyu x 1.3x x 320/390: taşma yok', (tester) async {
      final repo = FakeCampusRepo();
      final c = await ready(repo, FakeCampusLocationService(perm: CampusPerm.deniedForever));
      await p00Matrix(tester, () => CampusMapPage(repository: repo, controller: c, tileProvider: NoTiles()), scaffold: false, settleMs: 400);
      c.dispose();
    });
  });

  group('Ana Sayfa kartı', () {
    testWidgets('kart: başlık, arama şeridi, 3 hızlı çip; dokunuşlar doğru geri çağrıyı çalıştırır', (tester) async {
      useScreen(tester, kPhoneMedium);
      var opened = 0, searched = 0;
      final chips = <String>[];
      await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: CampusHomeCard(onOpen: () => opened++, onSearch: () => searched++, onChip: chips.add),
        ),
      )));
      await pumpMs(tester);
      expect(find.text('Kampüs Haritası'), findsOneWidget);
      expect(find.text('Haritayı aç'), findsOneWidget);
      expect(find.text('Kampüste ara'), findsOneWidget);
      for (final s in ['Yemekhane', 'Kütüphane', 'Fakülteler']) {
        expect(find.text(s), findsOneWidget);
      }
      await tester.tap(find.text('Haritayı aç'));
      await tester.tap(find.text('Kampüste ara'));
      await tester.tap(find.text('Yemekhane'));
      await tester.tap(find.text('Fakülteler'));
      await pumpMs(tester);
      expect([opened, searched], [1, 1]);
      expect(chips, ['Yemekhane', 'Fakülteler']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kart: tr/en/ar x açık/koyu x 1.3x x 320/390: taşma yok', (tester) async {
      await p00Matrix(
        tester,
        () => SingleChildScrollView(padding: const EdgeInsets.all(20), child: CampusHomeCard(onOpen: () {}, onSearch: () {}, onChip: (_) {})),
      );
    });

    testWidgets('kart dokunma hedefleri >= 48 dp ve etiketli', (tester) async {
      useScreen(tester, kPhoneMedium);
      final h = tester.ensureSemantics();
      await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: CampusHomeCard(onOpen: () {}, onSearch: () {}, onChip: (_) {})),
      )));
      await pumpMs(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });
  });
}

void _noop() {}

