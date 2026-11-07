import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Ana sayfa: "Katıldığım etkinlikler" satırı etkinlik bölümünde görünür ve Etkinliklerim > Katılacaklarım'ı açar.

void main() {
  setUpAll(loadTestFonts);

  testWidgets('ana sayfada "Katıldığım etkinlikler" satırı var ve Etkinliklerim sayfasını açar', (tester) async {
    useScreen(tester, const Size(390, 1400));
    final be = FakeBackend()..on('/events/featured', null);
    await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: makeSession(be), onOpenTab: (i, {newsType}) {})), size: const Size(390, 1400)));
    await settle(tester, const Duration(seconds: 2));
    final row = find.byKey(const ValueKey('home-joined-events'));
    expect(row, findsOneWidget);
    expect(find.text('Katıldığım etkinlikler'), findsOneWidget);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.byType(MyEventsPage), findsOneWidget);
    expect(tester.widget<MyEventsPage>(find.byType(MyEventsPage)).initialSub, 1, reason: 'Katılacaklarım sekmesi');
  });
}
