import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// iPhone SE (1. nesil) benzeri en kucuk ekran.
const kSe = Size(320, 568);

/// Ekrani ve (istege bagli) home indicator payini ayarlar.
double _safe = 0;

void setupScreen(WidgetTester tester, Size size, {double bottomSafe = 0}) {
  useScreen(tester, size);
  _safe = bottomSafe;
  if (bottomSafe > 0) {
    tester.view.padding = FakeViewPadding(bottom: bottomSafe);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomSafe);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  }
}

/// Ekran klavyesini [h] dp yukseklikte acar (0 = kapali) ve animasyonu tamamlar.
Future<void> setKeyboard(WidgetTester tester, double h) async {
  tester.view.viewInsets = FakeViewPadding(bottom: h);
  // Gercek cihazlarda klavye acikken `padding.bottom` (home indicator payi) 0'a duser; viewPadding sabit kalir.
  if (_safe > 0) tester.view.padding = FakeViewPadding(bottom: h > 0 ? 0 : _safe);
  addTearDown(tester.view.resetViewInsets);
  await tester.pump(const Duration(milliseconds: 350));
}

/// Yazi olcegi uygulayan sarmalayici (MaterialApp altina).
Widget scaled(Widget child, double scale) => Builder(
      builder: (c) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child),
    );

/// [finder] ogesinin alt kenari klavyenin ustunde ve ekran icinde mi?
void expectAboveKeyboard(WidgetTester tester, Finder finder, Size screen, double kb) {
  final r = tester.getRect(finder);
  expect(r.bottom, lessThanOrEqualTo(screen.height - kb + 0.5), reason: 'oge klavyenin arkasinda: $r');
  expect(r.top, greaterThanOrEqualTo(0));
}

/// Ogenin merkezine dokunuldugunda hit-test yolu OGENIN KENDISINE (ya da alt agacina) ulasiyor mu?
/// (Ustte baska bir katman/klavye payi varsa ulasmaz.)
void expectHittable(WidgetTester tester, Finder finder) {
  final target = tester.renderObject(finder);
  final path = tester.hitTestOnBinding(tester.getCenter(finder)).path.map((e) => e.target);
  final ok = path.any((t) {
    RenderObject? p = t is RenderObject ? t : null;
    while (p != null) {
      if (identical(p, target)) return true;
      p = p.parent;
    }
    return false;
  });
  expect(ok, isTrue, reason: 'dokunma noktasi hedefe ulasmiyor (ustte baska oge var)');
}
