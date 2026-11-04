import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Ana Sayfa (Stitch home-v5): 4 tek tonlu kısayol karosu, Bugün kartı, fotoğraflı/yer tutuculu menü kartı +
/// menü puanlama + "Bakiye yükle" bağlantısı, etkinlik satırı ("Düzenleyen: kulüp"), haber kartı rozeti.
void main() {
  setUpAll(loadTestFonts);

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
    ..on('/events/featured', {
      'id': 12,
      'source': 'USER',
      'title': 'Yapay Zeka ve Kariyer Sohbeti',
      'startsAt': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      'location': 'Merkez Kütüphane Önü',
      'communityName': 'Bilişim Kulübü',
    })
    ..on('/news?type=HABER&page=0&size=5', {
      'items': [
        {'id': 1, 'title': 'Bahar dönemi haberi', 'type': 'HABER', 'publishedDate': '2026-01-01'},
      ]
    });

  Widget home(FakeBackend b, [void Function(int, {String? newsType})? open]) =>
      Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: open ?? (i, {newsType}) {}));

  testWidgets('4 kisayol karosu (tek tonlu) ve Kulupler sekmeye gecirir', (tester) async {
    useScreen(tester, const Size(390, 844));
    final opened = <int>[];
    await tester.pumpWidget(buildApp(home(be(), (i, {newsType}) => opened.add(i))));
    await settle(tester, const Duration(seconds: 2));
    final bar = find.byType(HomeFeaturedShortcuts);
    expect(bar, findsOneWidget);
    for (final l in ['Ders', 'Programı', 'Yemek', 'Menüsü', 'Kütüphane', 'Kulüpler']) {
      expect(find.descendant(of: bar, matching: find.text(l)), findsOneWidget, reason: l);
    }
    await tester.tap(find.descendant(of: bar, matching: find.text('Kulüpler')));
    expect(opened, [3]);
    // "Bugün kampüste" karosu başlığından önce, Hızlı erişim'den önce gelir.
    expect(tester.getTopLeft(find.byType(HomeFeaturedShortcuts)).dy, lessThan(tester.getTopLeft(find.text('Bugün kampüste')).dy));
    expect(tester.getTopLeft(find.text('Bugün kampüste')).dy, lessThan(tester.getTopLeft(find.text('Hızlı erişim')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu karti: fotografsiz yer tutucu, toplam rozeti, anket yoksa puan satiri yok, Bakiye yukle baglantisi', (tester) async {
    useScreen(tester, const Size(390, 1600));
    await tester.pumpWidget(buildApp(home(be())));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('Yeni görsel bekliyor'), findsOneWidget);
    expect(find.text('Toplam 540 kcal'), findsOneWidget);
    expect(find.text('Menüyü puanla'), findsNothing, reason: 'menü anketi yok (204)');
    expect(find.text('Bakiye yükle · yukle.al'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu karti: menu anketi varsa 5 yildiz; dokununca oy gider', (tester) async {
    useScreen(tester, const Size(390, 1600));
    final b = be();
    final polls = fakePolls(b, count: 0)
      ..menuPoll = samplePoll(id: 50, title: 'Menu', type: 'RATING', communityId: null, communityName: null);
    await tester.pumpWidget(buildApp(home(b)));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('Menüyü puanla'), findsOneWidget);
    expect(polls.menuPoll, isNotNull);
    await tester.tap(find.byIcon(BuIcons.star).at(3));
    await settle(tester, const Duration(milliseconds: 600));
    expect(b.count('POST /polls/50/vote'), 1);
    expect(find.byIcon(BuIcons.starFilled), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('etkinlik satiri: tarih blogu, Duzenleyen: kulup, saat ve yer', (tester) async {
    useScreen(tester, const Size(390, 2400));
    await tester.pumpWidget(buildApp(home(be())));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('Düzenleyen: Bilişim Kulübü'), findsOneWidget);
    expect(find.text('Merkez Kütüphane Önü'), findsOneWidget);
    expect(find.text('Yapay Zeka ve Kariyer Sohbeti'), findsWidgets);
    expect(find.byType(HomeEventList), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('haber seridi: tur rozeti ve takvimli tarih; 320 dp + 1.3x yazi tasma yok', (tester) async {
    useScreen(tester, const Size(320, 2400));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(buildApp(home(be()), size: const Size(320, 2400)));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('Haber'), findsWidgets);
    expect(find.byType(HomeNewsCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
