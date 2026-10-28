import 'dart:convert';

import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_models.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/menu/menu_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// 1x1 PNG
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

String _todayStr() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> _month({String? image}) {
  final n = DateTime.now();
  return [
    for (var d = 1; d <= 28; d++)
      {
        'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
        'items': ['Mercimek çorbası', 'Tavuk sote ve çok uzun bir yemek adı bu', 'Pilav'],
        if (d == n.day && image != null) 'imageUrl': image,
      },
  ];
}

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => MenuPhotoGate.debugProvider = null);


  group('MenuDay ayrıştırma', () {
    test('imageUrl yok/null/boş -> fotoğrafsız', () {
      expect(MenuDay.fromJson({'items': ['A']}).imageUrl, isNull);
      expect(MenuDay.fromJson({'items': ['A'], 'imageUrl': null}).hasPhoto, isFalse);
      expect(MenuDay.fromJson({'items': ['A'], 'imageUrl': '  '}).hasPhoto, isFalse);
      expect(MenuDay.fromJson({'items': [' A ', '', 'B']}).items, ['A', 'B']);
    });
    test('göreli yol çözülür, mutlak URL korunur', () {
      final rel = MenuDay.fromJson({'items': [], 'imageUrl': '/files/menu/1.jpg'});
      expect(rel.imageUrl, endsWith('/files/menu/1.jpg'));
      expect(rel.imageUrl, startsWith('http'));
      final abs = MenuDay.fromJson({'items': [], 'imageUrl': 'https://cdn.example/x.jpg'});
      expect(abs.imageUrl, 'https://cdn.example/x.jpg');
    });
  });

  for (final size in [const Size(320, 700), const Size(390, 844)]) {
    for (final dark in [false, true]) {
      final tag = '${size.width.toInt()}dp ${dark ? 'koyu' : 'acik'}';
      testWidgets('MenuPage fotoğraflı: fotoğraf + kalemler, taşma yok ($tag)', (tester) async {
        useScreen(tester, size);
        MenuPhotoGate.debugProvider = (_) => MemoryImage(_png);
        final b = FakeBackend()..on('/menu', _month(image: '/files/menu/today.jpg'));
                await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b)),
            brightness: dark ? Brightness.dark : Brightness.light));
        await settle(tester);
        expect(find.bySemanticsLabel(RegExp('menüsü fotoğrafı')), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(find.text('Mercimek çorbası'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('MenuPage fotoğrafsız: mevcut tasarım, fotoğraf yok', (tester) async {
    useScreen(tester, const Size(320, 700));
    final b = FakeBackend()..on('/menu', _month());
        await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b))));
    await settle(tester);
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel(RegExp('menüsü fotoğrafı')), findsNothing);
    expect(find.text('Mercimek çorbası'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MenuPage fotoğraf yüklenemezse fotoğrafsız tasarıma düşer', (tester) async {
    useScreen(tester, const Size(320, 700));
    // Testte ağ 400 döner -> errorBuilder -> hero kart.
    final b = FakeBackend()..on('/menu', _month(image: 'https://cdn.example/bozuk.jpg'));
        await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b))));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel(RegExp('menüsü fotoğrafı')), findsNothing);
    expect(find.text('Mercimek çorbası'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('Ana Sayfa menü kartı', () {
    Map<String, dynamic> today({String? image}) => {
          'date': _todayStr(),
          'items': ['Mercimek çorbası', 'Pilav', 'Ayran'],
          if (image != null) 'imageUrl': image,
        };

    Widget home(FakeBackend b) =>
        Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}));

    for (final dark in [false, true]) {
      testWidgets('fotoğraflı: arka plan fotoğrafı + metin (320 dp, ${dark ? 'koyu' : 'acik'})', (tester) async {
        useScreen(tester, const Size(320, 800));
        MenuPhotoGate.debugProvider = (_) => MemoryImage(_png);
        final b = FakeBackend()..on('/menu/today', today(image: '/files/menu/t.jpg'));
                await tester.pumpWidget(buildApp(home(b), brightness: dark ? Brightness.dark : Brightness.light));
        await settle(tester, const Duration(seconds: 2));
        expect(find.bySemanticsLabel(RegExp('menüsü fotoğrafı')), findsOneWidget);
        expect(find.textContaining('Mercimek çorbası'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('fotoğrafsız: eski tasarım', (tester) async {
      useScreen(tester, const Size(320, 800));
      final b = FakeBackend()..on('/menu/today', today());
            await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.bySemanticsLabel(RegExp('menüsü fotoğrafı')), findsNothing);
      expect(find.textContaining('Mercimek çorbası'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
