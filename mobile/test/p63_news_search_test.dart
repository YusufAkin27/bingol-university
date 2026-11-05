import 'package:bu_kampus/features/news/icerik_parts.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/profile/saved_news_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Stitch v3 BİREBİR (Haber + Arama): ölçüler 390 dp referans PNG/HTML'den (docs/design/BIREBIR_HABER.md).

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

/// Bugunun tarihi + sabit saat: "Son guncelleme" yalniz saat olarak gorunur (tarih bugun degilse "31 Ekim 14:32" biciminde).
String _todayAt1432() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}T14:32:00';
}

FakeBackend _news({bool maintenance = false, bool images = true, String? lastSuccessAt}) => FakeBackend()
  ..on('/news', newsPage([for (var i = 1; i <= 4; i++) newsItem(i, title: 'Kampüs genelinde ulaşım düzenlemesi yapıldı $i', imageUrl: images ? 'https://img.invalid/n$i.jpg' : null)]))
  ..on('/status', {
    'NEWS': {'maintenance': maintenance, 'lastSuccessAt': lastSuccessAt ?? _todayAt1432()},
    'MENU': {'maintenance': false},
  })
  ..on('/bookmarks/news/ids', {'ids': []});

Map<String, dynamic> _hit(int i) => {'type': 'NEWS', 'targetId': i, 'title': 'Kampüs haberi $i', 'date': '2026-10-1$i'};

FakeBackend _search(int newsCount) => FakeBackend()
  ..on('/search', {
    'groups': [
      {'type': 'NEWS', 'items': [for (var i = 1; i <= newsCount; i++) _hit(i)]},
      {
        'type': 'COMMUNITY',
        'items': [
          {'type': 'COMMUNITY', 'targetId': 30, 'title': 'Kampüs Fotoğraf Kulübü', 'memberCount': 48, 'myStatus': 'NONE'},
          {'type': 'COMMUNITY', 'targetId': 31, 'title': 'Robotik Kulübü', 'memberCount': 86, 'myStatus': 'ACTIVE'},
        ],
      },
    ],
  })
  ..on('/users/search', {
    'items': [
      {'id': 7, 'displayName': 'Elif Yıldız', 'department': 'Bilgisayar Mühendisliği', 'classYear': 2, 'email': 'elif@bingol.edu.tr'}
    ]
  });

Future<void> _type(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField).first, q);
  await tester.pump(const Duration(milliseconds: 500));
  await settle(tester);
}

void main() {
  setUpAll(loadTestFonts);

  group('Haber listesi (16/17)', () {
    testWidgets('kart ölçüleri: 72 dp görsel, 14 dp iç boşluk, 110 dp adım ve tek satır meta', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(_news())), size: kPhoneMedium));
      await settle(tester);
      final thumbs = find.byType(IcerikThumb);
      expect(thumbs, findsNWidgets(4));
      expect(tester.getSize(thumbs.first), const Size(72, 72));
      final pitch = tester.getTopLeft(thumbs.at(1)).dy - tester.getTopLeft(thumbs.at(0)).dy;
      expect(pitch, closeTo(110, 2));
      expect(tester.getTopLeft(thumbs.first).dx, 34);
      expect(find.byType(NewsRowDivider), findsNothing);
      expect(find.textContaining(' · bingol.edu.tr'), findsNWidgets(4));
      // Sekme şeridi: 44 dp, kapsül yok; seçili sekme koyu, 2 dp marka alt çizgisi.
      expect(tester.getSize(find.byType(IcerikUnderlineTabs)).height, 44);
      expect(find.byType(IcerikTabs), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('görselsiz haberde fotoğraf yerine bilgi ikonlu kart vardır', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(_news(images: false))), size: kPhoneMedium));
      await settle(tester);
      expect(find.byType(IcerikThumb), findsNothing);
      expect(tester.getTopLeft(find.textContaining('düzenlemesi yapıldı 1').first).dx, 98);
      expect(find.byType(IcerikCard), findsNWidgets(4));
      await unmount(tester);
    });

    testWidgets('bakım bandı: warnSoft + "Son güncelleme: 14:32"', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(_news(maintenance: true))), size: kPhoneMedium));
      await settle(tester);
      expect(find.textContaining('Haber kaynağına şu an ulaşılamıyor'), findsOneWidget);
      expect(find.text('Son güncelleme: 14:32'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('bakım bandı: son güncelleme başka günse "31 Ekim 14:32" biçiminde (gün + ay + saat)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(_news(maintenance: true, lastSuccessAt: '2020-10-31T14:32:00'))), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Son güncelleme: 31 Ekim 14:32'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hata: soluk tek cümle + marka metin düğmesi (simge yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(_news()..fail('/news'))), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 3));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      expect(find.byIcon(BuIcons.cloudOff), findsNothing);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('320 dp x1.3 ${b.name}${rtl ? ' rtl' : ''}: taşma yok', (tester) async {
          useScreen(tester, kPhoneSmall);
          await tester.pumpWidget(buildApp(_scaled(NewsListPage(session: makeSession(_news(maintenance: true))), 1.3, rtl: rtl), brightness: b, size: kPhoneSmall));
          await settle(tester);
          expect(find.textContaining('Kampüs genelinde'), findsWidgets);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });

  group('Haber detayı (18/19)', () {
    FakeBackend be(String? content) => FakeBackend()
      ..on('/news/1', {'id': 1, 'content': content, 'url': 'https://www.bingol.edu.tr/x'})
      ..on('/bookmarks/news/ids', {'ids': []});
    const title = 'Üniversitemizde Kariyer Günleri Düzenleniyor';

    testWidgets('kapaklı: kapak 240 dp, 40 dp düğmeler, HABER etiketi, 26 sp başlık, 16 sp gövde, 48 dp kaynak düğmesi', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          NewsDetailPage(session: makeSession(be('İlk paragraf.\nİkinci paragraf.')), item: newsItem(1, title: title, imageUrl: 'https://img.invalid/a.jpg'), saved: true),
          size: kPhoneMedium));
      await settle(tester);
      expect(tester.getSize(find.byType(FlexibleSpaceBar)).height, 240);
      expect(find.text('HABER'), findsOneWidget);
      expect(find.textContaining('2026 · bingol.edu.tr'), findsOneWidget);
      final h = tester.widget<Text>(find.text(title).last);
      expect(h.style!.fontSize, 26);
      expect(h.style!.fontWeight, FontWeight.w700);
      final body = tester.widget<Text>(find.text('İlk paragraf.'));
      expect(body.style!.fontSize, 16);
      expect(body.style!.height, 1.5);
      expect(find.text('İçeriğin tamamı için kaynak sayfayı açın.'), findsOneWidget);
      final btn = find.byKey(const ValueKey('news-open-source'));
      expect(tester.getSize(btn).height, 48);
      expect(tester.getSize(btn).width, 350);
      // Kayıtlı yer imi: marka renkli dolu simge.
      final pr = tester.element(find.byType(Scaffold).first).bu.prText;
      expect(tester.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('news-save')), matching: find.byType(Icon))).color, pr);
      expect(find.byType(BuCard), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('kapaksız etkinlik: üstte yalnız daire düğmeler, "Etkinlik tarihi", kutu/ikon yok, bağlantı hatası düz metin', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          NewsDetailPage(
              session: makeSession(be('Gövde.')),
              item: newsItem(1, type: 'ETKINLIK', title: title, eventDate: '2026-11-14'),
              saved: false),
          size: kPhoneMedium));
      await settle(tester);
      expect(find.text('ETKİNLİK'), findsOneWidget);
      expect(find.text('Etkinlik tarihi: 14 Kasım 2026'), findsOneWidget);
      expect(find.byIcon(BuIcons.calendar), findsNothing);
      expect(find.byIcon(BuIcons.info), findsNothing);
      expect(find.byType(BuCard), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('geniş ekranda gövde satır uzunluğu 640 dp ile sınırlı', (tester) async {
      const wide = Size(1000, 800);
      useScreen(tester, wide);
      await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(be('Uzun paragraf ' * 60)), item: newsItem(1, title: title), saved: false), size: wide));
      await settle(tester);
      expect(tester.getSize(find.textContaining('Uzun paragraf').first).width, lessThanOrEqualTo(600.0));
      await unmount(tester);
    });

    testWidgets('hata: soluk tek cümle + Yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = be('x')..fail('/news/1');
      await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(b), item: newsItem(1), saved: false), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İçerik yüklenemedi'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('320 dp x1.3 ${b.name}${rtl ? ' rtl' : ''}: kapaklı/kapaksız taşma yok', (tester) async {
          useScreen(tester, kPhoneSmall);
          for (final img in [null, 'https://img.invalid/a.jpg']) {
            await tester.pumpWidget(buildApp(
                _scaled(NewsDetailPage(session: makeSession(be('Gövde metni.\nİkinci paragraf.')), item: newsItem(1, imageUrl: img, title: title * 2), saved: false), 1.3, rtl: rtl),
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
  });

  group('Favoriler (20/21)', () {
    testWidgets('başlık + "3 kayıtlı haber", çizgili satırlar, kayıtlı yer imi dolu; Çevrimdışı/Temizle yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()
        ..on('/bookmarks', {
          'items': [for (var i = 1; i <= 3; i++) {'news': newsItem(i, title: 'Kayıtlı haber $i')}],
          'nextCursor': null,
        });
      await tester.pumpWidget(buildApp(SavedNewsPage(session: makeSession(be)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Favori haberler'), findsOneWidget);
      expect(find.text('3 kayıtlı haber'), findsOneWidget);
      expect(find.byType(NewsRowDivider), findsNWidgets(2));
      expect(find.textContaining('Çevrimdışı'), findsNothing);
      expect(find.text('Temizle'), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('boş: soluk iki cümle, illüstrasyon/eylem yok; hata: soluk cümle + Yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SavedNewsPage(session: makeSession(FakeBackend()..on('/bookmarks', {'items': [], 'nextCursor': null}))), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Henüz kaydettiğiniz bir haber yok.'), findsOneWidget);
      expect(find.text('Haber detayındaki işaretle haberleri buraya ekleyebilirsiniz.'), findsOneWidget);
      expect(find.text('Haberleri Keşfet'), findsNothing);
      await unmount(tester);

      await tester.pumpWidget(buildApp(SavedNewsPage(session: makeSession(FakeBackend()..fail('/bookmarks'))), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 3));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Arama (22-26)', () {
    testWidgets('başlangıç: 48 dp alan, 34 dp çipler (Tümü seçili), ipucu + Son aramalar yok (geçmiş boş)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(1))), size: kPhoneMedium));
      await settle(tester);
      expect(tester.getSize(find.ancestor(of: find.byType(TextField).first, matching: find.byType(AnimatedContainer)).first).height, 48);
      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('Gönderi'), findsOneWidget);
      expect(find.textContaining('en az 2 karakter yazın'), findsOneWidget);
      expect(find.byIcon(BuIcons.info), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('sonuç (Tümü): "N sonuç", büyük harf bölümler + Tümünü gör (n), kulüp hapları, kişide e-posta yok, eşleşme vurgusu', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(1))), size: kPhoneMedium));
      await _type(tester, 'kamp');
      expect(find.textContaining(' sonuç'), findsOneWidget);
      expect(find.text('HABER'), findsOneWidget);
      expect(find.text('KULÜP'), findsOneWidget);
      expect(find.text('KİŞİ'), findsOneWidget);
      expect(find.text('Tümünü gör (1)'), findsWidgets);
      expect(find.text('Katıl'), findsOneWidget);
      expect(find.text('Üyesin'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği · 2. sınıf'), findsOneWidget);
      expect(find.textContaining('elif@'), findsNothing);
      expect(find.text('EY'), findsNothing); // kisi: baş harf yok, varsayilan avatar gorseli
      // Eşleşen "Kamp" marka rengi + 600.
      final pr = tester.element(find.byType(Scaffold).first).bu.prText;
      var found = false;
      for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
        r.text.visitChildren((span) {
          if (span is TextSpan && span.text == 'Kamp' && span.style?.color == pr && span.style?.fontWeight == FontWeight.w600) found = true;
          return true;
        });
      }
      expect(found, isTrue);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('Tümü sekmesinde bölüm başına en çok 4 satır + Tümünü gör (N)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(6))), size: kPhoneMedium));
      await _type(tester, 'kamp');
      expect(find.byKey(const ValueKey('search-hit-NEWS-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-hit-NEWS-5')), findsNothing);
      expect(find.text('Tümünü gör (6)'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('sonuç yok: ortada başlık + "Farklı bir kelime deneyin."; hata: Yüklenemedi + Yeniden dene; hız sınırı bandı', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(FakeBackend()..on('/search', {'groups': []})..on('/users/search', {'items': []}))), size: kPhoneMedium));
      await _type(tester, 'xyzqw');
      expect(find.text('Sonuç bulunamadı.'), findsOneWidget);
      expect(find.text('Farklı bir kelime deneyin.'), findsOneWidget);
      await unmount(tester);

      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(1)..fail('/search'))), size: kPhoneMedium));
      await _type(tester, 'kamp');
      expect(find.text('Yüklenemedi'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hız sınırı (429): Yüklenemedi + Yeniden dene + warnSoft bant + 3 satır iskelet', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(_search(1)..fail('/search', status: 429, code: 'RATE_LIMITED'))), size: kPhoneMedium));
      await _type(tester, 'ders programı');
      expect(find.text('Yüklenemedi'), findsOneWidget);
      expect(find.text('Çok fazla istek gönderildi, birkaç saniye bekleyin.'), findsWidgets);
      expect(find.text('Yeniden dene'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('320 dp x1.3 ${b.name}${rtl ? ' rtl' : ''}: başlangıç ve sonuçlar taşmaz', (tester) async {
          useScreen(tester, kPhoneSmall);
          await tester.pumpWidget(buildApp(_scaled(SearchPage(session: makeSession(_search(3))), 1.3, rtl: rtl), brightness: b, size: kPhoneSmall));
          await settle(tester);
          _ok(tester);
          await _type(tester, 'kamp');
          expect(find.textContaining('Kampüs haberi'), findsWidgets);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });
}
