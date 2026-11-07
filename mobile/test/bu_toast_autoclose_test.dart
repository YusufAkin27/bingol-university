import 'package:bu_kampus/widgets/bu_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Geçici mesajlar 2 sn sonra kapanır; eylem düğmeli SnackBar da KALICI olmaz (Flutter 3.29+ persist varsayılanı).

Widget _host({bool action = false, bool error = false, Duration? duration}) => Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: ElevatedButton(
            key: const ValueKey('go'),
            onPressed: () => BuToast.show(c, 'Etkinliklerime eklendi',
                kind: error ? BuToastKind.error : BuToastKind.success,
                actionLabel: action ? 'Etkinliklerim' : null,
                onAction: action ? () {} : null,
                duration: duration ?? BuToast.defaultDuration),
            child: const Text('go'),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadTestFonts);

  test('varsayılan süre 2 saniye', () {
    expect(BuToast.defaultDuration, const Duration(seconds: 2));
  });

  for (final action in [false, true]) {
    testWidgets('${action ? "eylem düğmeli" : "düz"} toast 2 sn sonra kendiliğinden kapanır', (tester) async {
      await tester.pumpWidget(buildApp(_host(action: action), size: kPhoneMedium));
      await tester.tap(find.byKey(const ValueKey('go')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Etkinliklerime eklendi'), findsOneWidget);
      // 1 sn: hâlâ görünür
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Etkinliklerime eklendi'), findsOneWidget);
      // süre + çıkış animasyonu sonrası yok
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Etkinliklerime eklendi'), findsNothing, reason: 'toast ekranda takılı kalmamalı');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('erişilebilirlik kipi (screen reader) açıkken de eylemli toast kapanır', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(buildApp(_host(action: true), size: kPhoneMedium));
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Etkinliklerime eklendi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Etkinliklerime eklendi'), findsNothing);
  });

  testWidgets('arka arkaya iki toast: ikincisi birincisini değiştirir, ikisi de kapanır', (tester) async {
    await tester.pumpWidget(buildApp(_host(), size: kPhoneMedium));
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Etkinliklerime eklendi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Etkinliklerime eklendi'), findsNothing);
  });
}
