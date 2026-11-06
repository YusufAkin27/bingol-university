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
}
