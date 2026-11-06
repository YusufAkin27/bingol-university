@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/clubs/club_categories.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/home/home_clubs.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Kulup dalgasi ekran goruntuleri: Ana Sayfa kulup seridi, tum kulupler sayfasi, kulup anket kilidi.
/// Varsayilan `flutter test` ile CALISMAZ. Uretim:
///   STORE_SHOTS_OUT='C:/bu_qa/shots/kulup_dalgasi' flutter test test/redesign/clubs_wave_shots_test.dart
/// Istege bagli: `CW_LANG=tr|en|ar`, `CW_MODES=light,dark,x13`.
const _dpr = 2.0;

Map<String, dynamic> _c(int id, String name, String cat, int n,
        {String st = 'NONE', String? role, String? desc, String policy = 'OPEN', String? created}) =>
    {
      'id': id,
      'name': name,
      'category': cat,
      'description': desc ?? '$name; etkinlikler, atölyeler ve buluşmalar.',
      'memberCount': n,
      'myStatus': st,
      'myRole': role,
      'joinPolicy': policy,
      'visibility': 'PUBLIC',
      'createdAt': created ?? '2024-0${id % 9 + 1}-10T10:00:00Z',
    };

final _all = [
  _c(1, 'Fotoğraf Kulübü', 'Sanat', 128, st: 'ACTIVE', role: 'OWNER'),
  _c(2, 'Müzik Kulübü', 'Müzik', 210, st: 'ACTIVE', role: 'MEMBER'),
  _c(3, 'Bilgisayar Topluluğu', 'Teknoloji', 345),
  _c(4, 'Satranç Kulübü', 'Bilim', 64, st: 'PENDING', policy: 'APPROVAL'),
  _c(5, 'Doğa Sporları Kulübü', 'Spor', 182),
  _c(6, 'Tiyatro Kulübü', 'Sanat', 97),
];

FakeBackend _listBe({List<Map<String, dynamic>>? all, bool fail = false}) {
  final data = all ?? _all;
  final b = FakeBackend()
    ..on('/communities/categories', [
      {'key': 'Sanat', 'name': 'Sanat', 'count': 2},
      {'key': 'Spor', 'name': 'Spor', 'count': 1},
      {'key': 'Bilim', 'name': 'Bilim', 'count': 1},
      {'key': 'Müzik', 'name': 'Müzik', 'count': 1},
      {'key': 'Teknoloji', 'name': 'Teknoloji', 'count': 1},
    ])
    ..on('/me/communities*', {'items': [for (final c in data) if (c['myStatus'] == 'ACTIVE' || c['myStatus'] == 'PENDING') c], 'nextCursor': null});
  if (fail) {
    b.on('/communities*', {'code': 'X', 'message': 'x'}, status: 500);
  } else {
    b.on('/communities*', {'items': data, 'nextCursor': null});
  }
  return b;
}

FakeBackend _detailBe({required String status, String? role, String policy = 'OPEN', bool polls = false}) {
  final b = FakeBackend()
    ..on('/communities/7', {
      'id': 7,
      'name': 'Fotoğraf Kulübü',
      'description': 'Bingöl Üniversitesi bünyesinde fotoğrafçılığı sevdirmek amacıyla kurulmuş öğrenci topluluğu.',
      'category': 'Sanat',
      'memberCount': 128,
      'visibility': 'PUBLIC',
      'joinPolicy': policy,
      'myStatus': status,
      'myRole': role,
      'createdAt': '2019-03-12T09:00:00Z',
    })
    ..on('/communities/7/posts*', {'items': <Object>[], 'nextCursor': null})
    ..on('/communities/7/requests*', {'items': <Object>[], 'nextCursor': null})
    ..on('/communities/7/members*', {'items': <Object>[], 'nextCursor': null})
    ..on('/events*', {'items': <Object>[], 'nextCursor': null});
  if (polls) {
    fakePolls(b, count: 2).polls
      ..clear()
      ..addAll([samplePoll(id: 1, title: 'Yeni dönem etkinlik temasi', communityId: 7), samplePoll(id: 2, title: 'Atölye günü', communityId: 7)]);
  } else if (status == 'ACTIVE') {
    fakePolls(b, count: 0);
  } else {
    // Sunucu davranisi: uye olmayana 403.
    b.fail('/polls*', status: 403, code: 'POLL_NOT_ELIGIBLE', message: 'Bu ankete katılma hakkınız yok.');
  }
  return b;
}

class _Scn {
  const _Scn(this.file, this.backend, this.page, {this.act, this.height = 844});
  final String file;
  final FakeBackend Function() backend;
  final Widget Function(FakeBackend b) page;
  final double height;
  final Future<void> Function(WidgetTester t)? act;
}

Widget _tab(FakeBackend b) => ClubsTab(session: makeSession(b));

Widget _home(FakeBackend b) => Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 24),
              HomeClubs(session: makeSession(b), onOpenAll: () {}),
            ]),
          ),
        ),
      ),
    );

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).first);
  await settle(t, const Duration(milliseconds: 700));
}

Future<void> _scrollDetailToPolls(WidgetTester t) async {
  await t.drag(find.byType(CustomScrollView).first, const Offset(0, -260));
  await settle(t, const Duration(milliseconds: 500));
}

final _scns = <_Scn>[
  _Scn('01_ana_sayfa_seridi', _listBe, _home, height: 420),
  _Scn('02_ana_sayfa_bos', () => _listBe(all: const []), _home, height: 320),
  _Scn('03_ana_sayfa_hata', () => _listBe(fail: true)..on('/me/communities*', {'code': 'X', 'message': 'x'}, status: 500), _home, height: 320),
  _Scn('04_kulupler_kesfet', _listBe, _tab),
  _Scn('05_kulupler_arama', _listBe, _tab, act: (t) async {
    await t.enterText(find.byType(TextField).first, 'kulup');
    await t.pump(const Duration(milliseconds: 600));
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Scn('06_kulupler_siralama', _listBe, _tab, act: (t) async {
    await t.tap(find.byKey(const ValueKey('clubsSortButton')));
    await settle(t, const Duration(milliseconds: 700));
  }),
  _Scn('07_kulupler_kategori', _listBe, _tab, act: (t) => _tapText(t, 'Sanat')),
  _Scn('08_kuluplerim', _listBe, _tab, act: (t) => _tapText(t, 'Kulüplerim')),
  _Scn('09_kulupler_bos', () => _listBe(all: const []), _tab),
  _Scn('10_kulupler_hata', () => _listBe(fail: true), _tab),
  _Scn('11_anket_kilit_katil', () => _detailBe(status: 'NONE'), (b) => ClubDetailPage(session: makeSession(b), communityId: 7), act: _scrollDetailToPolls),
  _Scn('12_anket_kilit_istek', () => _detailBe(status: 'NONE', policy: 'APPROVAL'), (b) => ClubDetailPage(session: makeSession(b), communityId: 7), act: _scrollDetailToPolls),
  _Scn('13_anket_kilit_bekliyor', () => _detailBe(status: 'PENDING', policy: 'APPROVAL'), (b) => ClubDetailPage(session: makeSession(b), communityId: 7), act: _scrollDetailToPolls),
  _Scn('14_anket_bos_yonetici', () => _detailBe(status: 'ACTIVE', role: 'OWNER'), (b) => ClubDetailPage(session: makeSession(b), communityId: 7), act: _scrollDetailToPolls),
  _Scn('15_anket_liste_uye', () => _detailBe(status: 'ACTIVE', role: 'MEMBER', polls: true), (b) => ClubDetailPage(session: makeSession(b), communityId: 7), act: _scrollDetailToPolls),
];

Widget _app(Widget home, bool dark, GlobalKey key, double scale, String lang) {
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
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  final lang = Platform.environment['CW_LANG'] ?? 'tr';
  final modes = (Platform.environment['CW_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double, double)>[
    if (modes.contains('light')) ('', false, 1.0, 390),
    if (modes.contains('dark')) ('_koyu', true, 1.0, 390),
    if (modes.contains('x13')) ('_x1.3_320', false, 1.3, 320),
  ];

  setUpAll(() => _loadFonts(lang == 'ar'));

  for (final v in variants) {
    for (final sc in _scns) {
      final name = '${sc.file}${v.$1}_$lang';
      testWidgets('kulup dalgasi $name', skip: skip != null, (tester) async {
        ClubCategories.reset();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(v.$4 * _dpr, sc.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
        tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(_app(sc.page(sc.backend()), v.$2, key, v.$3, lang));
        await settle(tester, const Duration(milliseconds: 1200));
        if (sc.act != null) await sc.act!(tester);
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
        await unmount(tester);
      });
    }
  }
}
