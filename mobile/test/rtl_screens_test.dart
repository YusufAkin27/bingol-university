import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/a11y_screens.dart';
import 'support/fake_app.dart';

/// Arapca (RTL) yerel ayarla ana ekranlar: tasma/istisna yok, yon RTL.
void main() {
  setUpAll(loadTestFonts);

  for (final e in a11yScreens.entries) {
    for (final size in [kPhoneSmall, kPhoneMedium]) {
      testWidgets('${e.key} AR/RTL ${size.width.toInt()} dp', (tester) async {
        useScreen(tester, size);
        await tester.pumpWidget(a11yApp(e.value(FakeBackend()), lang: 'ar', scale: 1.0, size: size));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.rtl);
        await unmount(tester);
      });
    }
  }
}
