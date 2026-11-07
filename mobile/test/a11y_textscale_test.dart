import 'package:flutter_test/flutter_test.dart';

import 'support/a11y_screens.dart';
import 'support/fake_app.dart';

/// Buyuk yazi olcegi (1.5 / 2.0): ana ekranlarda tasma/istisna olmamali.
void main() {
  setUpAll(loadTestFonts);

  for (final e in a11yScreens.entries) {
    for (final scale in [1.5, 2.0]) {
      testWidgets('${e.key} yazi olcegi x$scale tasma yok', (tester) async {
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(a11yApp(e.value(FakeBackend()), lang: 'tr', scale: scale, size: kPhoneMedium));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  }
}
