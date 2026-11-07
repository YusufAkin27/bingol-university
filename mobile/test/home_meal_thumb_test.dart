import 'dart:convert';

import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Ana sayfa "Bugün kampüste": menü fotoğrafı varsa öğle yemeği satırının sağında küçük görsel görünür; yoksa görünmez.

// 1x1 saydam PNG.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

FakeBackend _be({String? image}) => FakeBackend()
  ..on('/menu/today', {
    'date': '2026-01-01',
    'items': ['Mercimek çorbası', 'Orman kebabı'],
    'dishes': [
      {'name': 'Mercimek çorbası', 'kcal': 160},
      {'name': 'Orman kebabı', 'kcal': 380},
    ],
    'totalKcal': 540,
    'kcalComplete': true,
    if (image != null) 'imageUrl': image,
  })
  ..on('/events/featured', null);

Future<void> _pump(WidgetTester tester, FakeBackend be) async {
  useScreen(tester, const Size(390, 1200));
  await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: makeSession(be), onOpenTab: (i, {newsType}) {})), size: const Size(390, 1200)));
  await settle(tester, const Duration(seconds: 2));
}

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => MenuPhotoGate.debugProvider = null);

  testWidgets('menü fotoğrafı varsa "Bugün kampüste" menü satırının sağında küçük görsel çıkar', (tester) async {
    MenuPhotoGate.debugProvider = (url) => MemoryImage(_png);
    await _pump(tester, _be(image: 'https://bukampus.com.tr/files/menu/today.jpg'));
    final thumb = find.byKey(const ValueKey('home-meal-thumb'));
    expect(thumb, findsOneWidget);
    final r = tester.getRect(thumb);
    expect(r.size, const Size(56, 56));
    // Satırın sağ yarısında (metnin sağı, ok simgesinin solu).
    expect(r.center.dx, greaterThan(390 / 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('menü fotoğrafı yoksa küçük görsel yok', (tester) async {
    await _pump(tester, _be());
    expect(find.byKey(const ValueKey('home-meal-thumb')), findsNothing);
    expect(find.textContaining('Mercimek'), findsWidgets);
  });
}
