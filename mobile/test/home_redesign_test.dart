import 'dart:convert';

import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_photo.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Map<String, dynamic> _today({String? image}) => {
      'date': '2026-01-01',
      'items': ['Mercimek çorbası', 'Orman kebabı', 'Pilav', 'Sütlaç'],
      if (image != null) 'imageUrl': image,
    };

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => MenuPhotoGate.debugProvider = null);

  Widget home(FakeBackend b, [void Function(int, {String? newsType})? open]) =>
      Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: open ?? (i, {newsType}) {}));

  for (final size in [const Size(320, 700), const Size(390, 844)]) {
    for (final dark in [false, true]) {
      for (final photo in [false, true]) {
        final tag = '${size.width.toInt()}dp ${dark ? 'koyu' : 'acik'} ${photo ? 'foto' : 'duz'}';
        testWidgets('ana sayfa yeni tasarim ($tag)', (tester) async {
          useScreen(tester, size);
          if (photo) MenuPhotoGate.debugProvider = (_) => MemoryImage(_png);
          final b = FakeBackend()
            ..on('/menu/today', _today(image: photo ? '/files/menu/t.jpg' : null))
            ..on('/news?type=HABER&page=0&size=5', {
              'items': [
                {'id': 1, 'title': 'Ders ekleme-bırakma tarihleri hakkında duyuru', 'type': 'DUYURU', 'publishedDate': '2026-01-01'},
              ]
            });
          await tester.pumpWidget(buildApp(home(b), brightness: dark ? Brightness.dark : Brightness.light));
          await settle(tester, const Duration(seconds: 2));
          expect(find.text('BÜ KAMPÜS'), findsOneWidget);
          expect(find.text('Bağımsız öğrenci uygulaması'), findsOneWidget);
          expect(find.text('Hızlı Erişim'), findsOneWidget);
          expect(find.text('Yemek'), findsOneWidget);
          expect(find.text('Etkinlikler'), findsOneWidget);
          expect(find.text('Anketler'), findsOneWidget);
          expect(find.text('Kulüpler'), findsNothing); // Kulüpler alt gezinmede zaten var (bu testte kabuk yok)
          expect(find.bySemanticsLabel('Ders Programı'), findsOneWidget);
          expect(find.text('Günün Yemek Menüsü'), findsOneWidget);
          expect(find.text('11:30 – 14:00'), findsOneWidget);
          expect(find.text('Mercimek çorbası'), findsOneWidget);
          expect(find.text('Menü Detayı'), findsOneWidget);
          expect(find.textContaining('kcal'), findsNothing); // ana sayfada kalori gösterilmez
          expect(find.bySemanticsLabel(RegExp('menüsü fotoğrafı')), photo ? findsOneWidget : findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('ana sayfa ar RTL: tasma yok, duyurular basligi', (tester) async {
    useScreen(tester, const Size(320, 700));
    final b = FakeBackend()..on('/menu/today', _today());
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home(b),
    ));
    await settle(tester, const Duration(seconds: 2));
    // Bolumler arasi bosluk 24 dp: haber basligi 320x700'de ilk ekranin disinda (tembel kurulur), kaydirarak ulasilir.
    await tester.scrollUntilVisible(find.text('أبرز الأخبار'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('أبرز الأخبار'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Haber bolumu Tumu baglantisi haber listesini acar', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend()..on('/menu/today', _today());
    await tester.pumpWidget(buildApp(home(b)));
    await settle(tester, const Duration(seconds: 2));
    await tester.scrollUntilVisible(find.text('Öne Çıkan Haberler'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Tümü').first);
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byType(NewsListPage), findsOneWidget);
  });
}
