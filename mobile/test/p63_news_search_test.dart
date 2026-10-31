import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Tur 3 (minimal) Haber + Arama: çerçevesiz satır, tür rozeti tekrarı yok, kartsız okuma detayı,
/// tür sekmeleri yalnız sonuçla görünür, bölüm başına en çok 4 satır, tek cümlelik hata.

Widget _scaled(Widget page, double scale, {bool rtl = false}) => Builder(
      builder: (c) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: page),
      ),
    );

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

FakeBackend _news() => FakeBackend()
  ..on('/news', newsPage([for (var i = 1; i <= 4; i++) newsItem(i, title: 'Kampüs genelinde ulaşım düzenlemesi yapıldı $i')]))
  ..on('/status', {
    'NEWS': {'maintenance': false},
    'MENU': {'maintenance': false},
  })
  ..on('/bookmarks/news/ids', {'ids': []});

Map<String, dynamic> _hit(int i) => {'type': 'NEWS', 'targetId': i, 'title': 'Kampüs haberi $i', 'date': '2026-10-1$i'};

FakeBackend _search(int newsCount) => FakeBackend()
  ..on('/search', {
    'groups': [
      {'type': 'NEWS', 'items': [for (var i = 1; i <= newsCount; i++) _hit(i)]},
    ],
  })
  ..on('/users/search', {'items': []});

Future<void> _type(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField).first, q);
  await tester.pump(const Duration(milliseconds: 500));
  await settle(tester);
}

void main() {
  setUpAll(loadTestFonts);

  group('Haber listesi', () {
    testWidgets('satırda tür rozeti ve ortak kaynak adı yok; tarih var', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(_news())), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Haber'), findsOneWidget); // yalnız sekme
      expect(find.textContaining('bingol.edu.tr'), findsNothing);
      expect(find.textContaining('2026'), findsWidgets);
      _ok(tester);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('320 dp x1.3 ${b.name}${rtl ? ' rtl' : ''}: taşma yok', (tester) async {
          useScreen(tester, kPhoneSmall);
          await tester.pumpWidget(buildApp(_scaled(NewsListPage(session: makeSession(_news())), 1.3, rtl: rtl), brightness: b, size: kPhoneSmall));
          await settle(tester);
          expect(find.textContaining('Kampüs genelinde'), findsWidgets);
          _ok(tester);
          await unmount(tester);
        });
      }
    }

    testWidgets('hata tek cümle + Yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = _news()..fail('/news');
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(be)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 3));
      expect(find.text('Yüklenemedi'), findsOneWidget);
      expect(find.textContaining('internet bağlantınızı'), findsNothing);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Haber detayı', () {
    FakeBackend be(String? content) => FakeBackend()
      ..on('/news/1', {'id': 1, 'content': content, 'url': 'https://www.bingol.edu.tr/x'})
      ..on('/bookmarks/news/ids', {'ids': []});
    const title = 'Kampüs genelinde ulaşım düzenlemesi yapıldı';

    testWidgets('kartsız: meta satırı + başlık + gövde + kaynak düğmesi, bilgi kutusu yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          NewsDetailPage(session: makeSession(be('İlk paragraf.\nİkinci paragraf.')), item: newsItem(1, title: title), saved: false),
          size: kPhoneMedium));
      await settle(tester);
      expect(find.byType(BuCard), findsNothing);
      expect(find.textContaining('Haber • '), findsOneWidget);
      expect(find.text(title), findsWidgets);
      expect(find.text('İlk paragraf.'), findsOneWidget);
      expect(find.text('Kaynak sayfada aç'), findsOneWidget);
      expect(find.text('Tam metin kaynak sayfada.'), findsNothing);
      expect(find.byIcon(LucideIcons.info), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('içerik yoksa tek soluk cümle görünür', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(
          buildApp(NewsDetailPage(session: makeSession(be('')), item: newsItem(1, title: title), saved: false), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Tam metin kaynak sayfada.'), findsOneWidget);
      expect(find.text('Kaynak sayfada aç'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('geniş ekranda gövde satır uzunluğu 640 dp ile sınırlı', (tester) async {
      const wide = Size(1000, 800);
      useScreen(tester, wide);
      await tester.pumpWidget(buildApp(
          NewsDetailPage(session: makeSession(be('Uzun paragraf ' * 60)), item: newsItem(1, title: title), saved: false),
          size: wide));
      await settle(tester);
      final w = tester.getSize(find.textContaining('Uzun paragraf').first).width;
      expect(w, lessThanOrEqualTo(600.0));
      _ok(tester);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('320 dp x1.3 ${b.name}${rtl ? ' rtl' : ''}: kapaklı/kapaksız taşma yok', (tester) async {
          useScreen(tester, kPhoneSmall);
          for (final img in [null, 'https://img.invalid/a.jpg']) {
            await tester.pumpWidget(buildApp(
                _scaled(
                    NewsDetailPage(session: makeSession(be('Gövde metni.\nİkinci paragraf.')), item: newsItem(1, imageUrl: img, title: title * 2), saved: false),
                    1.3,
                    rtl: rtl),
                brightness: b,
                size: kPhoneSmall));
            await settle(tester);
            expect(find.text('Kaynak sayfada aç'), findsOneWidget);
            _ok(tester);
          }
          await unmount(tester);
        });
      }
    }

    testWidgets('hata: tek cümle, ikinci açıklama yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = be('x')..fail('/news/1');
      await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(b), item: newsItem(1), saved: false), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İçerik yüklenemedi'), findsOneWidget);
      expect(find.textContaining('internet bağlantınızı'), findsNothing);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Arama', () {
    testWidgets('yazmadan önce yalnız alan + tek cümle; sekmeler sonuçla gelir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(1))), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('En az 2 karakter yazın.'), findsOneWidget);
      expect(find.text('Tümü'), findsNothing);
      expect(find.byIcon(LucideIcons.info), findsNothing);
      await _type(tester, 'kamp');
      expect(find.text('Tümü'), findsOneWidget);
      // Tek sonuç: "Tümünü gör" yok, büyük harfli sayaç yok.
      expect(find.textContaining('Tümünü gör'), findsNothing);
      expect(find.textContaining('SONUÇ'), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('Tümü sekmesinde bölüm başına en çok 4 satır + Tümünü gör (N)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(6))), size: kPhoneMedium));
      await _type(tester, 'kamp');
      expect(find.byKey(const ValueKey('search-hit-NEWS-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-hit-NEWS-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-hit-NEWS-5')), findsNothing);
      expect(find.text('Tümünü gör (6)'), findsOneWidget);
      await tester.tap(find.text('Tümünü gör (6)'));
      await settle(tester);
      expect(find.byKey(const ValueKey('search-hit-NEWS-5')), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('hata tek cümle + Yeniden dene; boş sonuç tek cümle', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(1)..fail('/search'))), size: kPhoneMedium));
      await _type(tester, 'kamp');
      expect(find.text('Sonuçlar yüklenemedi'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);

      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(0))), size: kPhoneMedium));
      await _type(tester, 'zzxx');
      expect(find.text('Sonuç bulunamadı.'), findsOneWidget);
      expect(find.textContaining('Farklı bir kelime'), findsNothing);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('320 dp x1.3 ${b.name}${rtl ? ' rtl' : ''}: sonuçlar taşmaz', (tester) async {
          useScreen(tester, kPhoneSmall);
          await tester.pumpWidget(buildApp(_scaled(SearchPage(session: makeSession(_search(3))), 1.3, rtl: rtl), brightness: b, size: kPhoneSmall));
          await _type(tester, 'kamp');
          expect(find.textContaining('Kampüs haberi'), findsWidgets);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });
}
