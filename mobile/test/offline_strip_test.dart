import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/widgets/bu_stale_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Ortak "Çevrimdışı · son güncelleme" şeridi: bağlantı yokken / önbellekten bayat veri sunulunca görünür,
// çevrimiçi olunca kaybolur.

void main() {
  setUpAll(loadTestFonts);

  test('shouldShow: çevrimiçi ve taze iken gizli; çevrimdışı ya da bayat veride görünür', () {
    final c = ConnectivityService();
    expect(BuStaleStrip.shouldShow(c), isFalse);
    c.reportStale(DateTime.now().subtract(const Duration(hours: 3)));
    expect(BuStaleStrip.shouldShow(c), isTrue);
    c.reportSuccess();
    expect(BuStaleStrip.shouldShow(c), isFalse);
    c.reportFailure();
    expect(BuStaleStrip.shouldShow(c), isTrue);
    c.reportSuccess();
    expect(BuStaleStrip.shouldShow(c), isFalse);
  });

  testWidgets('şerit bağlantı değişince çıkar ve kaybolur', (tester) async {
    final c = ConnectivityService();
    await tester.pumpWidget(buildApp(Scaffold(body: BuStaleStrip(connectivity: c))));
    expect(find.byKey(const ValueKey('stale-strip')), findsNothing);

    c.reportFailure();
    await tester.pump();
    expect(find.byKey(const ValueKey('stale-strip')), findsOneWidget);
    expect(find.text('Çevrimdışı · kayıtlı veriler gösteriliyor'), findsOneWidget);

    c.reportStale(DateTime.now().subtract(const Duration(hours: 2)));
    await tester.pump();
    expect(find.textContaining('Çevrimdışı · son güncelleme'), findsOneWidget);

    c.reportSuccess();
    await tester.pump();
    expect(find.byKey(const ValueKey('stale-strip')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menü sayfası: bayat veri şerit gösterir, çevrimiçi olunca kaybolur', (tester) async {
    useScreen(tester, kPhoneMedium);
    ConnectivityService.instance.reset();
    addTearDown(ConnectivityService.instance.reset);
    final n = menuToday();
    final be = FakeBackend()
      ..on('/menu', [
        {'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}', 'items': ['Mercimek']},
      ]);
    await tester.pumpWidget(buildApp(MenuPage(session: makeSession(be)), size: kPhoneMedium));
    await settle(tester);
    expect(find.byKey(const ValueKey('stale-strip')), findsNothing);

    ConnectivityService.instance.reportStale(DateTime.now().subtract(const Duration(minutes: 30)));
    await tester.pump();
    expect(find.byKey(const ValueKey('stale-strip')), findsOneWidget);
    expect(find.textContaining('Çevrimdışı · son güncelleme'), findsOneWidget);

    ConnectivityService.instance.reportSuccess();
    await tester.pump();
    expect(find.byKey(const ValueKey('stale-strip')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
