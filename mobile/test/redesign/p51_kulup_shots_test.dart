@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// P51 Kulupler Stitch v3 BIREBIR ekran goruntuleri (390x844, dpr 2).
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim:
///   STORE_SHOTS_OUT='C:/bu_qa/shots/tasarim/dd/birebir_kulup' flutter test test/redesign/p51_kulup_shots_test.dart
/// Istege bagli: `P51_LANG=tr|en|ar`, `P51_ONLY=01,05`, `P51_MODES=light,dark,x13`.
const _dpr = 2.0;
String _lang = 'tr';

Map<String, dynamic> _c(int id, String name, String cat, int n, {String st = 'NONE', String? role, String? requestedAt}) => {
      'id': id,
      'name': name,
      'category': cat,
      'memberCount': n,
      'myStatus': st,
      'myRole': role,
      'joinPolicy': 'OPEN',
      'visibility': 'PUBLIC',
      'requestedAt': requestedAt,
    };

final _discover = [
  _c(1, 'Fotoğraf Kulübü', 'Sanat', 128),
  _c(2, 'Müzik Kulübü', 'Müzik', 210, st: 'ACTIVE', role: 'MEMBER'),
  _c(3, 'Bilgisayar Topluluğu', 'Teknoloji', 345),
  _c(4, 'Satranç Kulübü', 'Bilim', 64, st: 'PENDING'),
  _c(5, 'Doğa Sporları Kulübü', 'Spor', 182),
];

final _mine = [
  _c(1, 'Fotoğraf Kulübü', 'Sanat', 128, st: 'ACTIVE', role: 'OWNER'),
  _c(3, 'Bilgisayar Topluluğu', 'Teknoloji', 345, st: 'ACTIVE', role: 'ADMIN'),
  _c(2, 'Müzik Kulübü', 'Müzik', 210, st: 'ACTIVE', role: 'MEMBER'),
  _c(5, 'Doğa Sporları Kulübü', 'Spor', 182, st: 'ACTIVE', role: 'MEMBER'),
  _c(4, 'Satranç Kulübü', 'Bilim', 64, st: 'PENDING', requestedAt: '2026-05-14T09:00:00Z'),
];

FakeBackend _listBe({List<Map<String, dynamic>>? discover, bool fail = false}) {
  final b = FakeBackend()
    ..on('/communities/categories', [
      {'category': 'Sanat', 'count': 3},
      {'category': 'Spor', 'count': 2},
      {'category': 'Bilim', 'count': 2},
      {'category': 'Müzik', 'count': 1},
      {'category': 'Teknoloji', 'count': 1},
    ])
    ..on('/me/communities*', {'items': _mine, 'nextCursor': null});
  if (fail) {
    b.on('/communities*', {'code': 'X', 'message': 'x'}, status: 500);
  } else {
    b.on('/communities*', {'items': discover ?? _discover, 'nextCursor': null});
  }
  return b;
}

FakeBackend _detailBe({required String status, String? role, int pending = 0}) {
  final b = FakeBackend()
    ..on('/communities/7', {
      'id': 7,
      'name': 'Fotoğraf Kulübü',
      'description':
          'Bingöl Üniversitesi bünyesinde analog ve dijital fotoğrafçılığı sevdirmek, kampüs içi ve doğa atölyeleri düzenlemek amacıyla kurulmuş bağımsız öğrenci topluluğuyuz.',
      'category': 'Sanat',
      'memberCount': 128,
      'visibility': 'PUBLIC',
      'joinPolicy': 'OPEN',
      'myStatus': status,
      'myRole': role,
      'createdAt': '2019-03-12T09:00:00Z',
    })
    ..on('/communities/7/posts*', {'items': <Object>[], 'nextCursor': null})
    ..on('/communities/7/requests*', {
      'items': [for (var i = 0; i < pending; i++) {'userId': 20 + i, 'displayName': 'Aday $i', 'answers': <Object>[]}],
      'nextCursor': null,
    })
    ..on('/communities/7/members*', {
      'items': [
        {'userId': 1, 'displayName': 'Elif Yıldız', 'role': 'OWNER'},
        {'userId': 2, 'displayName': 'Ahmet Kaya', 'role': 'MEMBER'},
        {'userId': 3, 'displayName': 'Selin Çelik', 'role': 'MEMBER'},
        {'userId': 4, 'displayName': 'Murat Özkan', 'role': 'MEMBER'},
      ],
      'nextCursor': null,
    })
    ..on('/communities/7/polls*', {'items': <Object>[], 'nextCursor': null})
    ..on('/polls*', {'items': <Object>[], 'nextCursor': null})
    ..on('/events*', {'items': <Object>[], 'nextCursor': null});
  return b;
}

class _Scn {
  const _Scn(this.file, this.backend, this.page, {this.height = 844, this.act});
  final String file;
  final FakeBackend Function() backend;
  final Widget Function(FakeBackend b) page;
  final double height;
  final Future<void> Function(WidgetTester t)? act;
}

Widget _tab(FakeBackend b) => ClubsTab(session: makeSession(b));

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).first);
  await settle(t, const Duration(milliseconds: 700));
}

final _scns = <_Scn>[
  _Scn('01_kesfet', _listBe, _tab),
  _Scn('02_kuluplerim', _listBe, _tab, act: (t) => _tapText(t, 'Kulüplerim')),
  _Scn('03a_yukleniyor', () => _listBe()..delay = const Duration(seconds: 3), _tab),
  _Scn('03b_bos', () => _listBe(discover: []), _tab),
  _Scn('03c_hata', () => _listBe(fail: true), _tab),
  _Scn('04_detay_ziyaretci', () => _detailBe(status: 'NONE'), (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Scn('05_detay_yonetici', () => _detailBe(status: 'ACTIVE', role: 'OWNER', pending: 2), (b) => ClubDetailPage(session: makeSession(b), communityId: 7),
      act: (t) => _tapText(t, 'Üyeler')),
  _Scn('06_olustur_hata', () => _listBe(), (b) => ClubFormPage(session: makeSession(b)), act: (t) async {
    await t.enterText(find.byType(TextField).first, 'Fo');
    await t.pump();
    final btn = find.text('Oluştur');
    await t.ensureVisible(btn.last);
    await t.tap(btn.last);
    await settle(t, const Duration(milliseconds: 600));
    await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, 600));
    await settle(t, const Duration(milliseconds: 300));
  }),
];

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
  _lang = (Platform.environment['P51_LANG'] ?? 'tr');
  final only = (Platform.environment['P51_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P51_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double, double)>[
    if (modes.contains('light')) ('', false, 1.0, 390),
    if (modes.contains('dark')) ('_koyu', true, 1.0, 390),
    if (modes.contains('x13')) ('_x1.3_320', false, 1.3, 320),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final sc in _scns) {
      if (only.isNotEmpty && !only.any((o) => sc.file.startsWith(o))) continue;
      final name = '${sc.file}${v.$1}_$_lang';
      testWidgets('p51 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(v.$4 * _dpr, sc.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
        tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(_app(sc.page(sc.backend()), v.$2, key, v.$3));
        await settle(tester, Duration(milliseconds: sc.file.startsWith('03a') ? 300 : 1200));
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
        if (sc.file.startsWith('03a')) await tester.pump(const Duration(seconds: 6));
        await unmount(tester);
      });
    }
  }
}
