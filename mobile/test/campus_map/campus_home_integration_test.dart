import 'package:bu_kampus/features/campus_map/campus_home_card.dart';
import 'package:bu_kampus/features/campus_map/campus_location.dart';
import 'package:bu_kampus/features/campus_map/campus_map_page.dart';
import 'package:bu_kampus/features/home/home_layout.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'campus_fixtures.dart';

/// Ana Sayfa entegrasyonu: kart Hızlı Erişim'in altında, AĞ İSTEĞİ YOK; dokununca harita açılır ve veri o zaman istenir.
void main() {
  setUpAll(loadTestFonts);
  setUp(() async {
    mockSecureStorage();
    await HomeLayoutStore.clear();
    CampusLocationService.instance = FakeCampusLocationService(perm: CampusPerm.deniedForever);
  });
  tearDown(HomeLayoutStore.clear);

  FakeBackend be() => FakeBackend()
    ..on('/menu/today', {'date': '2026-01-01', 'items': ['Mercimek çorbası', 'Pilav']})
    ..on('/campus/map', campusMapJson())
    ..on('/campus/places?limit=500', campusPlacesJson());

  Widget home(FakeBackend b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}));

  testWidgets('kart varsayılan düzende Hızlı Erişim ile haberler arasında; ana sayfa /campus isteği ATMAZ', (tester) async {
    useScreen(tester, const Size(390, 2400));
    final b = be();
    await tester.pumpWidget(buildApp(home(b)));
    await settle(tester, const Duration(seconds: 2));
    expect(find.byType(CampusHomeCard), findsOneWidget);
    final quick = tester.getTopLeft(find.text('Hızlı erişim')).dy;
    final card = tester.getTopLeft(find.byType(CampusHomeCard)).dy;
    final news = tester.getTopLeft(find.text('Öne çıkan haberler')).dy;
    expect(card, greaterThan(quick));
    expect(card, lessThan(news));
    expect(b.count('/campus'), 0, reason: 'kart statik önizleme: harita açılmadan ağ isteği yok');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('kart gizlenebilir (düzen düzenleme): gizliyken kart yok', (tester) async {
    useScreen(tester, const Size(390, 2400));
    await HomeLayoutStore.save(HomeLayout.defaults.setVisible(HomeSection.campusMap, false), 1);
    final b = be();
    await tester.pumpWidget(buildApp(home(b)));
    await settle(tester, const Duration(seconds: 2));
    expect(find.byType(CampusHomeCard), findsNothing);
    await unmount(tester);
  });

  testWidgets('çip dokununca harita açılır, kategori seçili gelir ve veri o zaman istenir', (tester) async {
    useScreen(tester, const Size(390, 2400));
    final b = be();
    await tester.pumpWidget(buildApp(home(b)));
    await settle(tester, const Duration(seconds: 2));
    await tester.ensureVisible(find.text('Yemekhane'));
    await tester.tap(find.text('Yemekhane'));
    await settle(tester, const Duration(seconds: 2));
    expect(find.byType(CampusMapPage), findsOneWidget);
    expect(b.count('/campus/map'), 1);
    expect(b.count('/campus/places'), 1);
    // "Yemekhane" kategorisi seçili: panelde tek yer
    expect(find.text('1 yer'), findsOneWidget);
    await unmount(tester);
  });
}
