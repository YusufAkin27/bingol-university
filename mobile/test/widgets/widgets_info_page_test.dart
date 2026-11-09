import 'package:bu_kampus/features/widgets/widget_store.dart';
import 'package:bu_kampus/features/widgets/widget_sync_service.dart';
import 'package:bu_kampus/features/widgets/widgets_info_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

void main() {
  testWidgets('bilgi sayfasi metin gosterir, tasma yok', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(const WidgetsInfoPage()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('iPhone'), findsOneWidget);
    expect(find.textContaining('Android'), findsOneWidget);
    expect(find.textContaining('Gizlilik'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('G9: gizlilik anahtari tercihi kaydeder (kisisel widgetlari gizle)', (tester) async {
    final store = MemoryWidgetStore();
    WidgetSyncService.instance
      ..detach()
      ..store = store;
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(const WidgetsInfoPage()));
    await tester.pump(const Duration(milliseconds: 200));
    final sw = find.byKey(const ValueKey('widgets-hide-personal'));
    await tester.scrollUntilVisible(sw, 200, scrollable: find.descendant(of: find.byKey(const ValueKey('widgets-info')), matching: find.byType(Scrollable)));
    await tester.tap(sw);
    await tester.pump(const Duration(milliseconds: 200));
    expect(store.data[WidgetSyncService.privacyKey], '1');
    expect(tester.takeException(), isNull);
  });
}