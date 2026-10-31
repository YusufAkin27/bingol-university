import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/menu/menu_parts.dart' show MenuSkeleton;
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// DB grubu mimar cilasi: Ana Sayfa hizli erisim izgarasi, iskelet->icerik gecisi, kademeli giris,
/// bildirim satiri, yemek gun gecisi, bildirim tercihleri basligi.
void main() {
  setUpAll(loadTestFonts);

  Widget home(FakeBackend b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}));

  FakeBackend homeBe() => FakeBackend()
    ..on('/menu/today', {
      'date': '2026-01-01',
      'items': ['Mercimek çorbası', 'Orman kebabı', 'Pilav', 'Sütlaç'],
    });

  /// Kutu: karoların üst koordinatlarından satır sayısı.
  int rowCount(WidgetTester tester) {
    final tops = {
      for (final e in tester.widgetList(find.byType(HomeQuickTile)).indexed)
        tester.getTopLeft(find.byType(HomeQuickTile).at(e.$1)).dy.round(),
    };
    return tops.length;
  }

  testWidgets('hizli erisim: genis ekranda 5 karo tek satir', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(buildApp(home(homeBe())));
    await settle(tester, const Duration(seconds: 1));
    expect(find.byType(HomeQuickTile), findsNWidgets(5));
    expect(rowCount(tester), 1);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('hizli erisim: dar ekran + buyuk yazida 3+2 iki satir, tasma yok', (tester) async {
    useScreen(tester, const Size(320, 700));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(buildApp(home(homeBe())));
    await settle(tester, const Duration(seconds: 1));
    expect(find.byType(HomeQuickTile), findsNWidgets(5));
    expect(rowCount(tester), 2);
    // Karolar esit genislikte (3 sutun).
    final w = {for (var i = 0; i < 5; i++) tester.getSize(find.byType(HomeQuickTile).at(i)).width.round()};
    expect(w.length, 1);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('ana sayfa: iskelet icerige solarak gecer (BuSwapIn), kademeli giris biter', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = homeBe()..delay = const Duration(milliseconds: 300);
    await tester.pumpWidget(buildApp(home(b)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HomeSkeleton), findsOneWidget);
    expect(find.text('Hızlı Erişim'), findsNothing);
    await settle(tester, const Duration(seconds: 2));
    expect(find.byType(HomeSkeleton), findsNothing);
    expect(find.text('Hızlı Erişim'), findsOneWidget);
    expect(find.byType(BuSwapIn), findsOneWidget);
    // Kademeli giris bitti: ilk 4 blok tam gorunur (opaklik 1).
    final fades = tester.widgetList<FadeTransition>(find.byType(FadeTransition)).where((f) => f.opacity.value < 1);
    expect(fades, isEmpty);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('ana sayfa: animasyonlari azalt aciksa icerik aninda gorunur', (tester) async {
    useScreen(tester, const Size(390, 844));
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(buildApp(home(homeBe())));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Hızlı Erişim'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('bildirim: govdesiz baslik iki satira kadar okunur, govdeli tek satir', (tester) async {
    useScreen(tester, const Size(390, 844));
    final long = 'Ders ekleme-bırakma tarihleri duyuruldu ve çok uzun bir başlık deneme metni burada sürüyor';
    final b = FakeBackend()
      ..on('/notifications', {
        'unreadCount': 1,
        'nextCursor': null,
        'items': [
          {'id': 1, 'type': 'ANNOUNCEMENT', 'title': long, 'read': false, 'createdAt': DateTime.now().toIso8601String()},
          {'id': 2, 'type': 'EVENT', 'title': long, 'body': 'Ayrıntı metni', 'read': true, 'createdAt': DateTime.now().toIso8601String()},
        ],
      });
    await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b))));
    await settle(tester, const Duration(seconds: 1));
    final titles = tester.widgetList<Text>(find.text(long)).toList();
    expect(titles.length, 2);
    expect(titles[0].maxLines, 2);
    expect(titles[1].maxLines, 1);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('bildirim: tumunu okundu yap tek satir', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend()
      ..on('/notifications', {
        'unreadCount': 1,
        'nextCursor': null,
        'items': [
          {'id': 1, 'type': 'ANNOUNCEMENT', 'title': 'Duyuru', 'read': false, 'createdAt': DateTime.now().toIso8601String()},
        ],
      });
    await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b))));
    await settle(tester, const Duration(seconds: 1));
    final pill = find.text('Tümünü okundu yap');
    expect(pill, findsOneWidget);
    expect(tester.getSize(pill).height, lessThan(24)); // tek satir
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('yemek: iskelet icerige gecer (BuSwapIn)', (tester) async {
    useScreen(tester, const Size(390, 844));
    final n = DateTime.now();
    String d(int o) {
      final x = n.add(Duration(days: o));
      return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    }

    final b = FakeBackend()
      ..on('/menu', [
        {'date': d(0), 'items': ['Bugun Corbasi']},
        if (DateTime.now().add(const Duration(days: 1)).month == n.month) {'date': d(1), 'items': ['Yarin Pilavi']},
      ]);
    await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(MenuSkeleton), findsOneWidget);
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Bugun Corbasi'), findsOneWidget);
    expect(find.byType(BuSwapIn), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('bildirim tercihleri: ortak BuHeader (daire geri dugmesi) kullanir', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend()
      ..on('/notifications/preferences',
          {'news': true, 'announcements': true, 'events': true, 'communities': false, 'messages': true});
    await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(b))));
    await settle(tester, const Duration(seconds: 1));
    expect(find.byType(BuHeader), findsOneWidget);
    expect(find.byTooltip('Geri'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
