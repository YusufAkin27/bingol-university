import 'dart:async';

import 'package:bu_kampus/core/cache/cache_policy.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/news/unit_news_detail_page.dart';
import 'package:bu_kampus/features/news/unit_news_models.dart';
import 'package:bu_kampus/features/news/unit_news_strip.dart';
import 'package:bu_kampus/features/profile/edit_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// "Bölümümden" (docs/UNIT_NEWS_API.md): ana sayfa şeridi, detay sayfası ve sessizlik kuralı.

const _profile = {
  'id': 1,
  'email': 'ayse@bingol.edu.tr',
  'displayName': 'Ayşe Yılmaz',
  'role': 'USER',
  'faculty': 'Mühendislik ve Mimarlık Fakültesi',
  'department': 'Bilgisayar Mühendisliği',
  'grade': '2',
};

Map<String, dynamic> _item(int id, String title, {bool files = false, String? unit = 'Bilgisayar Mühendisliği'}) => {
      'id': id,
      'title': title,
      'summary': 'Özet metni',
      'publishedDate': '2026-10-28',
      'sourceName': 'Mühendislik ve Mimarlık Fakültesi',
      'unitName': unit,
      'url': 'https://mmf.bingol.edu.tr/bolumler_/bilgisayar-muhendisligi/duyurular/$id/',
      'attachments': files
          ? [
              {'name': 'vize_programi.pdf', 'url': 'https://mmf.bingol.edu.tr/media/59080/vize.pdf', 'type': 'PDF'},
              {'name': 'eski.doc', 'url': 'http://mmf.bingol.edu.tr/media/1/eski.doc', 'type': 'DOC'}, // https değil: atlanır
            ]
          : <Object>[],
    };

Widget _home(FakeBackend b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}));

/// Ana sayfayı açar; ListView içeriğinin kaydırma uzunluğunu döndürür (düzen yüksekliği karşılaştırması için).
Future<double> _openHome(WidgetTester tester, FakeBackend b, {double height = 3200}) async {
  useScreen(tester, Size(390, height));
  await tester.pumpWidget(buildApp(_home(b)));
  await settle(tester, const Duration(seconds: 2));
  final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  return pos.maxScrollExtent;
}

void main() {
  setUpAll(loadTestFonts);

  group('model', () {
    test('https olmayan ek ve kimliksiz satır atlanır; birim yoksa kaynak adı görünür', () {
      final ok = UnitNewsItem.tryParse(_item(1, 'Vize', files: true, unit: null))!;
      expect(ok.attachments.map((a) => a.name), ['vize_programi.pdf']);
      expect(ok.sourceLabel, 'Mühendislik ve Mimarlık Fakültesi');
      expect(UnitNewsItem.tryParse({'title': 'x'}), isNull);
      expect(UnitNewsItem.tryParse({'id': 1}), isNull);
      expect(UnitNewsItem.tryParse(_item(2, 'Vize'))!.sourceLabel, 'Bilgisayar Mühendisliği');
    });

    test('önbellek politikası: /news/unit 10 dk, haber 20 dk kalır', () {
      expect(CachePolicy.freshFor('/news/unit?limit=10'), const Duration(minutes: 10));
      expect(CachePolicy.freshFor('/news/unit/7'), const Duration(minutes: 10));
      expect(CachePolicy.freshFor('/news?type=HABER&page=0&size=5'), const Duration(minutes: 20));
    });
  });

  group('ana sayfa şeridi', () {
    testWidgets('dolu liste: başlık + kartlar görünür, ekli kartta simge var', (tester) async {
      final b = FakeBackend()
        ..on('/users/me', _profile)
        ..on('/news/unit?limit=10', [_item(1, 'Vize sınav programı', files: true), _item(2, 'Staj duyurusu')]);
      await _openHome(tester, b);
      expect(find.text('Bölümümden'), findsOneWidget);
      expect(find.byType(UnitNewsCard), findsNWidgets(2));
      expect(find.text('Vize sınav programı'), findsOneWidget);
      expect(find.text('Staj duyurusu'), findsOneWidget);
      expect(find.byKey(const ValueKey('unit-news-attach')), findsOneWidget); // yalnız ekli kartta
      expect(find.textContaining('28 Ekim 2026'), findsNWidgets(2));
      expect(b.count('GET /news/unit?limit=10'), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('karta dokununca detay açılır; gövde, Ekler ve Kaynakta aç görünür', (tester) async {
      final b = FakeBackend()
        ..on('/users/me', _profile)
        ..on('/news/unit?limit=10', [_item(7, 'Vize sınav programı', files: true)])
        ..on('/news/unit/7', {..._item(7, 'Vize sınav programı', files: true), 'body': 'Birinci paragraf.\n\nİkinci paragraf.'});
      await _openHome(tester, b);
      await tester.tap(find.text('Vize sınav programı'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(UnitNewsDetailPage), findsOneWidget);
      expect(b.requests, contains('GET /news/unit/7'));
      expect(find.text('Birinci paragraf.'), findsOneWidget);
      expect(find.text('İkinci paragraf.'), findsOneWidget);
      expect(find.text('Ekler'), findsOneWidget);
      expect(find.text('vize_programi.pdf'), findsOneWidget);
      expect(find.text('eski.doc'), findsNothing); // https olmayan ek gösterilmez
      expect(find.text('Kaynakta aç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    final hiddenCases = <String, FakeBackend Function()>{
      'boş liste': () => FakeBackend()
        ..on('/users/me', _profile)
        ..on('/news/unit?limit=10', <Object>[]),
      'sunucu hatası (500)': () => FakeBackend()
        ..on('/users/me', _profile)
        ..fail('/news/unit'),
      'yetki hatası (403)': () => FakeBackend()
        ..on('/users/me', _profile)
        ..fail('/news/unit', status: 403, code: 'FORBIDDEN'),
      'ağ hatası': () => FakeBackend()
        ..on('/users/me', _profile)
        ..network('/news/unit'),
      'beklenmeyen yanıt (liste değil)': () => FakeBackend()
        ..on('/users/me', _profile)
        ..on('/news/unit?limit=10', {'oops': true}),
      'uç tanımsız (varsayılan)': () => FakeBackend()..on('/users/me', _profile),
      'bölüm yok': () => FakeBackend()
        ..on('/users/me', {..._profile, 'department': null, 'faculty': null})
        ..on('/news/unit?limit=10', [_item(1, 'Görünmemeli')]),
      'bölüm boş metin': () => FakeBackend()
        ..on('/users/me', {..._profile, 'department': '  '})
        ..on('/news/unit?limit=10', [_item(1, 'Görünmemeli')]),
      'profil okunamadı': () => FakeBackend()
        ..fail('/users/me')
        ..on('/news/unit?limit=10', [_item(1, 'Görünmemeli')]),
    };

    // Referans: şeritsiz ana sayfanın kaydırma uzunluğu.
    for (final e in hiddenCases.entries) {
      testWidgets('şerit gizli, iz yok, yükseklik 0: ${e.key}', (tester) async {
        final base = await _openHome(tester, FakeBackend(), height: 700);
        await unmount(tester);
        final b = e.value();
        final extent = await _openHome(tester, b, height: 700);
        expect(extent, greaterThan(0)); // kaydırılabilir içerik: karşılaştırma anlamlı
        expect(find.byType(UnitNewsSection), findsNothing);
        expect(find.byType(UnitNewsCard), findsNothing);
        expect(find.text('Bölümümden'), findsNothing);
        expect(find.text('Görünmemeli'), findsNothing);
        expect(find.textContaining('bulunamadı'), findsNothing);
        expect(find.byKey(const ValueKey('unit-news-section')), findsNothing);
        expect(extent, base, reason: 'şerit yokken düzen değişmemeli');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('bölümü olmayan kullanıcıda /news/unit hiç çağrılmaz', (tester) async {
      final b = FakeBackend()
        ..on('/users/me', {..._profile, 'department': null})
        ..on('/news/unit?limit=10', [_item(1, 'x')]);
      await _openHome(tester, b);
      expect(b.count('/news/unit'), 0);
    });

    testWidgets('oturum bölümü biliyorsa (kabuk okudu) ana sayfa /users/me çekmez', (tester) async {
      final b = FakeBackend()
        ..fail('/users/me')
        ..on('/news/unit?limit=10', [_item(1, 'Kabuktan bilinen')]);
      final s = makeSession(b)..setDepartment('Bilgisayar Mühendisliği');
      useScreen(tester, const Size(390, 3200));
      await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: s, onOpenTab: (i, {newsType}) {}))));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Kabuktan bilinen'), findsOneWidget);
      expect(b.count('GET /users/me'), 0);
    });

    testWidgets('profil düzenlemede bölüm seçilince şerit kendiliğinden gelir', (tester) async {
      final b = FakeBackend()
        ..on('/users/me', {..._profile, 'department': null})
        ..on('/news/unit?limit=10', [_item(1, 'Yeni bölümün haberi')]);
      final s = makeSession(b);
      useScreen(tester, const Size(390, 3200));
      await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: s, onOpenTab: (i, {newsType}) {}))));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(UnitNewsSection), findsNothing);
      expect(b.count('/news/unit'), 0);
      s.setDepartment('Bilgisayar Mühendisliği'); // EditProfilePage kaydı bunu yapar
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Yeni bölümün haberi'), findsOneWidget);
    });

    testWidgets('çekip yenileme şeridi yeniden ister', (tester) async {
      final b = FakeBackend()
        ..on('/users/me', _profile)
        ..on('/news/unit?limit=10', [_item(1, 'Eski haber')]);
      await _openHome(tester, b);
      expect(find.text('Eski haber'), findsOneWidget);
      b.on('/news/unit?limit=10', [_item(1, 'Eski haber'), _item(2, 'Yeni haber')]);
      unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
      await settle(tester, const Duration(seconds: 2));
      expect(b.count('GET /news/unit?limit=10'), 2);
      expect(find.text('Yeni haber'), findsOneWidget);
    });

    testWidgets('liste sonradan boşalırsa (yenileme) şerit kalkar', (tester) async {
      final b = FakeBackend()
        ..on('/users/me', _profile)
        ..on('/news/unit?limit=10', [_item(1, 'Geçici haber')]);
      await _openHome(tester, b);
      expect(find.byType(UnitNewsSection), findsOneWidget);
      b.on('/news/unit?limit=10', <Object>[]);
      unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(UnitNewsSection), findsNothing);
      expect(find.text('Bölümümden'), findsNothing);
    });

    for (final dark in [false, true]) {
      for (final size in kPhoneSizes) {
        testWidgets('şerit taşma yok (${dark ? 'koyu' : 'açık'} ${size.width.toInt()})', (tester) async {
          useScreen(tester, Size(size.width, 3200));
          final b = FakeBackend()
            ..on('/users/me', _profile)
            ..on('/news/unit?limit=10', [
              _item(1, 'Çok uzun bir başlık: 2026-2027 Eğitim-Öğretim Yılı Güz Yarıyılı Ara Sınav Programı ve Sınav Kuralları Hakkında Önemli Duyuru', files: true, unit: 'Çok Uzun Bir Bölüm Adı Bilgisayar ve Yazılım Mühendisliği (İngilizce)'),
              _item(2, 'Kısa'),
            ]);
          await tester.pumpWidget(buildApp(_home(b), brightness: dark ? Brightness.dark : Brightness.light));
          await settle(tester, const Duration(seconds: 2));
          expect(find.byType(UnitNewsCard), findsNWidgets(2));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('detay sayfası', () {
    UnitNewsItem listItem() => UnitNewsItem.tryParse(_item(7, 'Vize sınav programı', files: true))!;

    Future<List<Uri>> open(WidgetTester tester, FakeBackend b, {bool opens = true}) async {
      useScreen(tester, kPhoneMedium);
      final opened = <Uri>[];
      await tester.pumpWidget(buildApp(UnitNewsDetailPage(
        session: makeSession(b),
        item: listItem(),
        opener: (u) async {
          opened.add(u);
          return opens;
        },
      )));
      await settle(tester, const Duration(seconds: 1));
      return opened;
    }

    FakeBackend backend() => FakeBackend()
      ..on('/news/unit/7', {..._item(7, 'Vize sınav programı', files: true), 'body': 'Birinci paragraf.\n\nİkinci paragraf.\n\nÜçüncü.'});

    testWidgets('başlık, kaynak, tarih, paragraflar, ekler', (tester) async {
      await open(tester, backend());
      expect(find.text('Vize sınav programı'), findsOneWidget);
      expect(find.text('MÜHENDİSLİK VE MİMARLIK FAKÜLTESİ'), findsOneWidget);
      expect(find.textContaining('28 Ekim 2026'), findsOneWidget);
      expect(find.text('Birinci paragraf.'), findsOneWidget);
      expect(find.text('İkinci paragraf.'), findsOneWidget);
      expect(find.text('Üçüncü.'), findsOneWidget);
      expect(find.text('Ekler'), findsOneWidget);
      expect(find.byKey(const ValueKey('unit-attachment-https://mmf.bingol.edu.tr/media/59080/vize.pdf')), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ek satırı dış bağlantı olarak açılır', (tester) async {
      final opened = await open(tester, backend());
      await tester.tap(find.text('vize_programi.pdf'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(opened, [Uri.parse('https://mmf.bingol.edu.tr/media/59080/vize.pdf')]);
    });

    testWidgets('Kaynakta aç haber bağlantısını açar', (tester) async {
      final opened = await open(tester, backend());
      await tester.tap(find.text('Kaynakta aç'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(opened.single.toString(), 'https://mmf.bingol.edu.tr/bolumler_/bilgisayar-muhendisligi/duyurular/7/');
    });

    testWidgets('bağlantı açılamazsa uyarı çıkar', (tester) async {
      await open(tester, backend(), opens: false);
      await tester.tap(find.text('vize_programi.pdf'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Bağlantı açılamadı.'), findsOneWidget);
    });

    testWidgets('ekler en az 44 dp dokunma hedefi', (tester) async {
      await open(tester, backend());
      final r = tester.getSize(find.byKey(const ValueKey('unit-attachment-https://mmf.bingol.edu.tr/media/59080/vize.pdf')));
      expect(r.height, greaterThanOrEqualTo(44));
      expect(tester.getSize(find.byKey(const ValueKey('unit-open-source'))).height, greaterThanOrEqualTo(44));
    });

    testWidgets('detay yüklenemezse hata + yeniden dene; ekler listeden yine görünür', (tester) async {
      final b = FakeBackend()..fail('/news/unit/7', status: 404, code: 'UNIT_NEWS_NOT_FOUND');
      await open(tester, b);
      expect(find.text('Yeniden dene'), findsOneWidget);
      expect(find.text('vize_programi.pdf'), findsOneWidget);
      b.on('/news/unit/7', {..._item(7, 'Vize sınav programı', files: true), 'body': 'Geldi.'});
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Geldi.'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      for (final size in kPhoneSizes) {
        testWidgets('detay taşma yok (${dark ? 'koyu' : 'açık'} ${size.width.toInt()})', (tester) async {
          useScreen(tester, size);
          await tester.pumpWidget(buildApp(
              UnitNewsDetailPage(session: makeSession(backend()), item: listItem(), opener: (_) async => true),
              brightness: dark ? Brightness.dark : Brightness.light));
          await settle(tester, const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('bölüm zorunluluğu (kayıt)', () {
    testWidgets('bölüm seçilmeden Devam: hata gösterilir, sonraki adıma geçilmez, istek atılmaz', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Devam'));
      await tester.pump();
      expect(find.text('Bölümünüzü seçin.'), findsOneWidget);
      expect(find.text('Adım 1/3'), findsOneWidget);
      expect(b.count('/auth/register'), 0);
      await unmount(tester);
    });
  });

  group('bölüm zorunluluğu (profil düzenleme)', () {
    testWidgets('bölümsüz profilde kaydet: hata gösterilir, PATCH atılmaz', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(EditProfilePage(
        session: makeSession(b),
        profile: const {'displayName': 'Ayşe Yılmaz', 'language': 'tr', 'showEmail': false},
      )));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Kaydet').last);
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Bölümü seçin.'), findsOneWidget);
      expect(b.count('PATCH /users/me'), 0);
    });

    testWidgets('bölüm seçilince kayıt gider', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(EditProfilePage(
        session: makeSession(b),
        profile: const {'displayName': 'Ayşe Yılmaz', 'language': 'tr', 'showEmail': false},
      )));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Bölüm seçin'));
      await pickFromSearch(tester, 'biyo', 'Biyoloji');
      await tester.tap(find.text('Kaydet').last);
      await settle(tester, const Duration(milliseconds: 500));
      expect((b.bodies['PATCH /users/me'] as Map)['department'], 'Biyoloji');
    });
  });
}
