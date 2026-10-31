@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/events/etkinlik2_attendance_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_requests_page.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// P51 Etkinlikler Stitch v3 BIREBIR ekran goruntuleri (390 dp, dpr 2, durum cubugu 0).
///
///   STORE_SHOTS_OUT='C:/bu_qa/shots/tasarim/dd/birebir_etkinlik' flutter test test/redesign/p51_etkinlik_shots_test.dart --run-skipped
/// Istege bagli: `P51_LANG=tr|en|ar`, `P51_ONLY=01,05`, `P51_MODES=light,dark,x13`.
const _dpr = 2.0;
String _lang = 'tr';

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev(int id, String title, String club, int h, int dur, String place, {String? rsvp, int going = 128, int? cap}) {
  final n = DateTime.now();
  final s = DateTime(n.year, n.month, n.day, h);
  return {
    'id': id,
    'source': 'USER',
    'title': title,
    'description': 'Bingöl Üniversitesi Bilgisayar Topluluğu olarak düzenlediğimiz kariyer günlerinde, sektörden deneyimli veri bilimciler ve yapay zeka mühendisleriyle bir araya geliyoruz. Etkinlik boyunca makine öğrenimi uygulamaları, staj olanakları ve kariyer yol haritaları konuşulacaktır. Tüm bölümlerden öğrencilerin katılımına açıktır.',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(Duration(hours: dur))),
    'location': place,
    'communityId': 7,
    'communityName': club,
    'goingCount': going,
    if (cap != null) 'capacity': cap,
    'myRsvp': rsvp,
    'status': 'ACTIVE',
    'joinPolicy': 'OPEN',
    'canManage': false,
    'createdBy': 2,
  };
}

final _list = [
  _ev(1, 'Yapay Zeka ve Veri Bilimi Kariyer Günleri', 'Bilgisayar Topluluğu', 15, 2, 'Konferans Salonu'),
  _ev(2, 'Sonbahar Kampüs Çekimi ve Sergi Hazırlığı', 'Fotoğrafçılık Kulübü', 13, 3, 'Rektörlük Bahçesi', rsvp: 'GOING'),
  _ev(3, 'Akustik Dinleti ve Tanışma Provası', 'Müzik Kulübü', 18, 2, 'Amfi Tiyatro'),
];

FakeBackend _listBe({List<Map<String, dynamic>>? items, bool fail = false}) {
  final b = FakeBackend()
    ..on('/me/events*', {'items': <Object>[], 'nextCursor': null})
    ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null});
  if (fail) {
    b.on('/events/calendar*', {'code': 'X', 'message': 'x'}, status: 500);
  } else {
    b.on('/events/calendar*', items ?? _list, headers: {'x-truncated': 'false'});
  }
  return b;
}

FakeBackend _detailBe({String? rsvp, bool open = false}) {
  final ev = _ev(5, 'Yapay Zeka ve Veri Bilimi Kariyer Günleri', 'Bilgisayar Topluluğu', 15, 2, 'Konferans Salonu', rsvp: rsvp);
  return FakeBackend()
    ..on('/events/5', ev)
    ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': open})
    ..on('/events/5/admission', {'eventId': 5, 'mode': 'OPEN', 'questions': <Object>[]});
}

List<Map<String, dynamic>> _att() => [
      {'userId': 1, 'displayName': 'Zeynep Kaya', 'present': true, 'method': 'QR', 'checkedInAt': '2026-10-31T12:12:00Z'},
      {'userId': 2, 'displayName': 'Ahmet Yılmaz', 'present': true, 'method': 'MANUAL', 'checkedInAt': '2026-10-31T12:18:00Z'},
      {'userId': 3, 'displayName': 'Elif Demir', 'present': false},
      {'userId': 4, 'displayName': 'Murat Çelik', 'present': true, 'method': 'QR', 'checkedInAt': '2026-10-31T12:25:00Z'},
    ];

FakeBackend _manageBe() => FakeBackend()
  ..on('/events/5/checkin-code', {'code': '482913', 'qrPayload': 'bingol-checkin:5.1.abc', 'validForSeconds': 30})
  ..on('/events/5/attendance', _att())
  ..on('/events/5', {'id': 5, 'goingCount': 31, 'capacity': 40})
  ..on('/events/5/requests*', {
    'items': [
      {'userId': 11, 'displayName': 'Zeynep Kaya', 'department': 'Bilgisayar Mühendisliği', 'classYear': 2},
      {'userId': 12, 'displayName': 'Ahmet Yılmaz', 'department': 'Elektrik-Elektronik Mühendisliği', 'classYear': 3},
      {'userId': 13, 'displayName': 'Elif Demir', 'department': 'Moleküler Biyoloji', 'classYear': 1},
    ],
    'nextCursor': null,
  });

Map<String, dynamic> get _evMap => {'id': 5, 'title': 'Yapay Zeka ve Veri Bilimi Kariyer Günleri', 'communityName': 'Bilgisayar Topluluğu', 'goingCount': 31, 'capacity': 40, 'createdBy': 2};

FakeBackend _formBe({bool noClub = false}) => FakeBackend()
  ..on('/me/communities*', {
    'items': noClub
        ? <Object>[]
        : [
            {'id': 7, 'name': 'Müzik Kulübü', 'myStatus': 'ACTIVE', 'myRole': 'OWNER', 'status': 'ACTIVE', 'joinPolicy': 'OPEN', 'visibility': 'PUBLIC', 'category': 'Müzik', 'memberCount': 210},
          ],
    'nextCursor': null,
  });

class _Scn {
  const _Scn(this.file, this.backend, this.page, {this.height = 844, this.act});
  final String file;
  final FakeBackend Function() backend;
  final Widget Function(FakeBackend b) page;
  final double height;
  final Future<void> Function(WidgetTester t)? act;
}

final _scns = <_Scn>[
  _Scn('01_liste', _listBe, (b) => EventsPage(session: makeSession(b))),
  _Scn('02a_yukleniyor', () => _listBe()..delay = const Duration(seconds: 3), (b) => EventsPage(session: makeSession(b))),
  _Scn('02b_bos', () => _listBe(items: []), (b) => EventsPage(session: makeSession(b))),
  _Scn('02c_hata', () => _listBe(fail: true), (b) => EventsPage(session: makeSession(b))),
  _Scn('03_detay_ziyaretci', _detailBe, (b) => EventDetailPage(session: makeSession(b), eventId: 5), height: 900),
  _Scn('04_detay_katilimci', () => _detailBe(rsvp: 'GOING', open: true), (b) => EventDetailPage(session: makeSession(b), eventId: 5), height: 900),
  _Scn('05_olustur_hata', () => _formBe(), (b) => EventFormPage(session: makeSession(b)), height: 1260, act: (t) async {
    await t.enterText(find.byKey(const ValueKey('evc-title')), 'Ak');
    await t.pump();
    await t.ensureVisible(find.byKey(const ValueKey('evc-submit')));
    await t.tap(find.byKey(const ValueKey('evc-submit')), warnIfMissed: false);
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Scn('06_kulup_gerekli', () => _formBe(noClub: true), (b) => EventFormPage(session: makeSession(b))),
  _Scn('07_yoklama_qr', _manageBe, (b) => Etkinlik2QrPage(session: makeSession(b), event: _evMap)),
  _Scn('08_basvurular', _manageBe, (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _evMap)),
  _Scn('09_yoklama_listesi', _manageBe, (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _evMap)),
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
      testWidgets('p51ev $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(v.$4 * _dpr, sc.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
        tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(_app(sc.page(sc.backend()), v.$2, key, v.$3));
        await settle(tester, Duration(milliseconds: sc.file.startsWith('02a') ? 300 : 1500));
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
        if (sc.file.startsWith('02a')) await tester.pump(const Duration(seconds: 6));
        await unmount(tester);
      });
    }
  }
}
