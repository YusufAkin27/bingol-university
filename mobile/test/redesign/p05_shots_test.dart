@Tags(['store-shots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/profile/saved_news_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// Paket 5 (Haber ve Arama) ekran goruntuleri: GERCEK ekranlar + sahte API, tum durum varyantlari.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p05/sonraki' flutter test test/redesign/p05_shots_test.dart
/// Istege bagli: `P05_LANG=tr|en|ar` (varsayilan tr), `P05_ONLY=01,10`, `P05_MODES=light,dark,x13` (varsayilan light,dark).
/// Arapca: Windows'ta Arial yuklenir (testte sistem yedek yazi tipi yok); yalniz yerlesimi gormek icindir.
const _dpr = 2.0;
const _w = 390.0;
const _h = 844.0;

String _lang = 'tr';

class _Shot {
  const _Shot(this.file, this.build, {this.after, this.recent, this.slow = false, this.height = _h});
  final String file;
  final Widget Function(FakeBackend b) build;
  final Future<void> Function(WidgetTester t)? after;

  /// Son aramalar (guvenli depoya yazilir).
  final List<String>? recent;

  /// true: yanit gecikir (yukleniyor durumu).
  final bool slow;
  final double height;
}

Map<String, dynamic> _n(int i, {String type = 'HABER', String? title, bool img = true, String? eventDate}) => newsItem(
      i,
      type: type,
      title: title,
      imageUrl: img ? 'https://img.invalid/n$i.jpg' : null,
      eventDate: eventDate,
    );

const _titles = [
  'Rektörümüz öğrencilerle bir araya geldi: kampüs yaşamı ve yeni dönem hedefleri konuşuldu',
  'Güz dönemi ders ekleme-bırakma tarihleri açıklandı',
  'Üniversitemiz uluslararası araştırma ağına katıldı',
  'Kampüs genelinde ulaşım düzenlemesi yapıldı',
  'Yemekhane hizmet saatleri güncellendi',
  'Kütüphane sınav haftasında 7/24 açık olacak',
];

List<Map<String, dynamic>> _news({String type = 'HABER', bool images = true, int count = 6}) => [
      for (var i = 0; i < count; i++)
        _n(i + 1,
            type: type,
            title: _titles[i % _titles.length],
            img: images && i != 2 && i != 4,
            eventDate: type == 'ETKINLIK' ? '2026-11-${10 + i}' : null),
    ];

FakeBackend _newsBackend({bool maintenance = false, String type = 'HABER', bool images = true, bool empty = false}) =>
    FakeBackend()
      ..on('/news', newsPage(empty ? [] : _news(type: type, images: images)))
      ..on('/status', {
        'NEWS': {'maintenance': maintenance},
        'MENU': {'maintenance': false},
      })
      ..on('/bookmarks/news/ids', {
        'ids': [2, 5]
      });

const _article =
    'Bingöl Üniversitesi, yeni akademik yılın ilk haftasında öğrencilerle bir araya gelerek kampüs yaşamını ve dönem hedeflerini değerlendirdi.\n'
    'Toplantıda ulaşım, yemekhane, kütüphane ve yurt hizmetlerine ilişkin öğrenci talepleri tek tek ele alındı; ilgili birimlere yönlendirildi.\n'
    'Öğrenci toplulukları da yıl boyunca düzenlenecek etkinlik takvimini paylaştı. Güz döneminde kültür, spor ve bilim alanlarında 40\'tan fazla etkinlik planlanıyor.\n'
    'Üniversite yönetimi, öğrencilerin görüş ve önerilerini mobil uygulama üzerinden de iletebileceğini hatırlattı. Duyurular ve yeni gelişmeler bu sayfadan takip edilebilecek.';

FakeBackend _detailBackend({String? content = _article}) => FakeBackend()
  ..on('/news/1', {
    'id': 1,
    'content': content,
    'url': 'https://www.bingol.edu.tr/haber/1',
    'eventDate': null,
  })
  ..on('/bookmarks/news/ids', {'ids': []});

Map<String, dynamic> _hit(String type, int id, String title, {String? snippet, String? date, String? img}) =>
    {'type': type, 'targetId': id, 'title': title, 'snippet': snippet, 'date': date, 'imageUrl': img};

FakeBackend _searchBackend({bool empty = false}) => FakeBackend()
  ..on('/search', {
    'groups': empty
        ? []
        : [
            {
              'type': 'NEWS',
              'items': [
                _hit('NEWS', 1, 'Kampüs genelinde ulaşım düzenlemesi yapıldı', date: '2026-10-12', img: 'https://img.invalid/n1.jpg'),
                _hit('ANNOUNCEMENT', 2, 'Güz dönemi kampüs etkinlik takvimi yayınlandı', date: '2026-10-09'),
              ],
            },
            {
              'type': 'COMMUNITY',
              'items': [_hit('COMMUNITY', 3, 'Kampüs Fotoğraf Kulübü', snippet: '48 üye')],
            },
            {
              'type': 'EVENT',
              'items': [_hit('EVENT', 4, 'Kampüs Tanıtım Günü', date: '2026-11-03', snippet: 'Merkez Kampüs')],
            },
          ],
  })
  ..on('/users/search', {
    'items': empty
        ? []
        : [
            {'id': 7, 'displayName': 'Kampüs Rehberi', 'department': 'Bilgisayar Mühendisliği', 'classYear': 3},
            {'id': 8, 'displayName': 'Mert Kampüslü', 'faculty': 'Mühendislik Fakültesi'},
          ],
    'nextCursor': null,
  });

Future<void> _type(WidgetTester t, String q) async {
  await t.enterText(find.byType(TextField).first, q);
  await t.pump(const Duration(milliseconds: 500));
}

final _shots = <_Shot>[
  _Shot('01_haber_liste', (b) => NewsListPage(session: makeSession(b))),
  _Shot('02_haber_liste_bakim', (b) => NewsListPage(session: makeSession(b))),
  _Shot('03_haber_liste_duyuru', (b) => NewsListPage(session: makeSession(b), initialType: 'DUYURU')),
  _Shot('04_haber_liste_etkinlik', (b) => NewsListPage(session: makeSession(b), initialType: 'ETKINLIK')),
  _Shot('05_haber_liste_yukleniyor', (b) => NewsListPage(session: makeSession(b)), slow: true),
  _Shot('06_haber_liste_bos', (b) => NewsListPage(session: makeSession(b))),
  _Shot('07_haber_liste_hata', (b) => NewsListPage(session: makeSession(b))),
  _Shot('10_detay_kapakli',
      (b) => NewsDetailPage(session: makeSession(b), item: _n(1, title: _titles[0]), saved: false)),
  _Shot('11_detay_kapaksiz',
      (b) => NewsDetailPage(session: makeSession(b), item: _n(1, title: _titles[1], img: false), saved: true)),
  _Shot('12_detay_etkinlik',
      (b) => NewsDetailPage(session: makeSession(b), item: _n(1, type: 'ETKINLIK', title: _titles[2], eventDate: '2026-11-14', img: false), saved: false)),
  _Shot('13_detay_yukleniyor',
      (b) => NewsDetailPage(session: makeSession(b), item: _n(1, title: _titles[0]), saved: false),
      slow: true),
  _Shot('14_detay_hata', (b) => NewsDetailPage(session: makeSession(b), item: _n(1, title: _titles[0]), saved: false)),
  _Shot('15_detay_icerik_yok',
      (b) => NewsDetailPage(session: makeSession(b), item: _n(1, title: _titles[3]), saved: false)),
  _Shot('16_detay_kaydirilmis',
      (b) => NewsDetailPage(session: makeSession(b), item: _n(1, title: _titles[0]), saved: false),
      after: (t) async {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('20_favori_dolu', (b) => SavedNewsPage(session: makeSession(b))),
  _Shot('21_favori_bos', (b) => SavedNewsPage(session: makeSession(b))),
  _Shot('22_favori_hata', (b) => SavedNewsPage(session: makeSession(b))),
  _Shot('23_favori_yukleniyor', (b) => SavedNewsPage(session: makeSession(b)), slow: true),
  _Shot('30_arama_bos', (b) => SearchPage(session: makeSession(b))),
  _Shot('31_arama_son_aramalar', (b) => SearchPage(session: makeSession(b)), recent: ['kütüphane saatleri', 'burs', 'yemek listesi', 'erasmus']),
  _Shot('32_arama_sonuc_tumu', (b) => SearchPage(session: makeSession(b)), after: (t) => _type(t, 'kamp')),
  _Shot('33_arama_sonuc_haber_sekme', (b) => SearchPage(session: makeSession(b)), after: (t) async {
    await _type(t, 'kamp');
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text(lookupAppLocalizations(Locale(_lang)).newsTypeNews).first);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('34_arama_sonuc_yok', (b) => SearchPage(session: makeSession(b)), after: (t) => _type(t, 'zzxx')),
  _Shot('35_arama_hata', (b) => SearchPage(session: makeSession(b)), after: (t) => _type(t, 'kamp')),
  _Shot('36_arama_yukleniyor', (b) => SearchPage(session: makeSession(b)), slow: true, after: (t) => _type(t, 'kamp')),
];

FakeBackend _backendFor(String file) {
  switch (file) {
    case '02_haber_liste_bakim':
      return _newsBackend(maintenance: true);
    case '03_haber_liste_duyuru':
      return _newsBackend(type: 'DUYURU', images: false);
    case '04_haber_liste_etkinlik':
      return _newsBackend(type: 'ETKINLIK');
    case '06_haber_liste_bos':
      return _newsBackend(empty: true);
    case '07_haber_liste_hata':
      return _newsBackend()..fail('/news');
    case '14_detay_hata':
      return _detailBackend()..fail('/news/1');
    case '15_detay_icerik_yok':
      return _detailBackend(content: '');
    case '21_favori_bos':
      return FakeBackend()..on('/bookmarks', {'items': [], 'nextCursor': null});
    case '22_favori_hata':
      return FakeBackend()..fail('/bookmarks');
    case '20_favori_dolu':
    case '23_favori_yukleniyor':
      return FakeBackend()
        ..on('/bookmarks', {
          'items': [
            for (var i = 0; i < 5; i++) {'news': _n(i + 1, title: _titles[i], type: i == 1 ? 'DUYURU' : 'HABER', img: i != 2)}
          ],
          'nextCursor': null,
        });
    case '34_arama_sonuc_yok':
      return _searchBackend(empty: true);
    case '35_arama_hata':
      return _searchBackend()..fail('/search');
    case '36_arama_yukleniyor':
    case '32_arama_sonuc_tumu':
    case '33_arama_sonuc_haber_sekme':
      return _searchBackend();
    case '30_arama_bos':
    case '31_arama_son_aramalar':
      return _searchBackend();
    case '10_detay_kapakli':
    case '11_detay_kapaksiz':
    case '12_detay_etkinlik':
    case '13_detay_yukleniyor':
    case '16_detay_kaydirilmis':
      return _detailBackend();
    default:
      return _newsBackend();
  }
}

class _Variant {
  const _Variant(this.suffix, this.dark, this.scale);
  final String suffix;
  final bool dark;
  final double scale;
}

Widget _app(Widget home, bool dark, GlobalKey key, double scale) {
  final lang = _lang;
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, lang),
      darkTheme: BuTheme.forLocale(Brightness.dark, lang),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _loadFonts(bool arabic) async {
  await loadTestFonts();
  if (!arabic) return;
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
}

Future<void> _pumpImages(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['P05_LANG'] ?? 'tr';
  final only = (Platform.environment['P05_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P05_MODES'] ?? 'light,dark').split(',');
  final variants = <_Variant>[
    if (modes.contains('light')) const _Variant('', false, 1),
    if (modes.contains('dark')) const _Variant('_koyu', true, 1),
    if (modes.contains('x13')) const _Variant('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final s in _shots) {
      if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
      final name = '${s.file}${v.suffix}_$_lang';
      testWidgets('p05 $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        addTearDown(() => debugNetworkImageHttpClientProvider = null);
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_w * _dpr, s.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final b = _backendFor(s.file);
        if (s.slow) b.delay = const Duration(seconds: 3);
        final key = GlobalKey();
        // Guvenli depo taklidi makeSession icinde kurulur; son aramalar ondan sonra yazilir.
        final home = s.build(b);
        if (s.recent != null) {
          await const FlutterSecureStorage().write(key: 'recent_searches', value: jsonEncode(s.recent));
        } else {
          await const FlutterSecureStorage().delete(key: 'recent_searches');
        }
        await tester.pumpWidget(_app(home, v.dark, key, v.scale));
        await tester.pump(const Duration(milliseconds: 100));
        if (!s.slow) {
          await settle(tester, const Duration(milliseconds: 900));
          await _pumpImages(tester);
        }
        if (s.after != null) {
          await s.after!(tester);
          if (!s.slow) {
            await settle(tester, const Duration(milliseconds: 700));
            await _pumpImages(tester);
          } else {
            await tester.pump(const Duration(milliseconds: 600));
          }
        } else if (s.slow) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
          // ignore: avoid_print
          print('YAZILDI ${f.path} ${image.width}x${image.height}');
        });
        if (s.slow) await tester.pump(const Duration(seconds: 5));
        await unmount(tester);
        await const FlutterSecureStorage().delete(key: 'recent_searches');
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
