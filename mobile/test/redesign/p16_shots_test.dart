@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/events/etkinlik2_attendance_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_requests_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_settings_page.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Paket 16 (etkinlik organizator araclari + QR) ekran goruntuleri: tum durum varyantlari.
///
/// Varsayilan `flutter test` ile CALISMAZ (STORE_SHOTS_OUT yoksa atlanir). Uretim (C:\bu_mobile icinde):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p16/sonraki' flutter test test/redesign/p16_shots_test.dart
/// Istege bagli: `P16_LANG=tr|en|ar`, `P16_ONLY=01,05`, `P16_MODES=light,dark,x13`.
const _dpr = 2.5;
String _lang = 'tr';

Duration _skew = Duration.zero;

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev({String policy = 'APPROVAL', int? capacity = 14, int going = 9, bool closed = false}) {
  final s = DateTime.now().add(const Duration(hours: 3));
  return {
    'id': 5,
    'title': _lang == 'ar'
        ? 'مباراة كرة القدم في الحرم الجامعي'
        : (_lang == 'en' ? 'Campus five-a-side match and summer meetup' : 'Kampüs halı saha maçı ve yaz dönemi tanışma buluşması'),
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': _lang == 'ar' ? 'ملعب الحرم' : (_lang == 'en' ? 'Campus pitch' : 'Kampüs halı sahası'),
    'goingCount': going,
    'capacity': capacity,
    'canManage': true,
    'joinPolicy': policy,
    'registrationClosed': closed,
    'createdBy': 2,
  };
}

List<Map<String, dynamic>> _att({int n = 3}) => [
      {'userId': 11, 'displayName': 'Ayşe Yılmaz', 'department': 'Bilgisayar Mühendisliği', 'present': true, 'method': 'QR', 'markedAt': _iso(DateTime.now())},
      {'userId': 12, 'displayName': 'Can Demir', 'department': 'İşletme', 'present': false},
      {'userId': 2, 'displayName': 'Mehmet Kaya', 'present': true, 'method': 'MANUAL'},
      {'userId': 13, 'displayName': 'Selin Doğan', 'department': 'Hukuk', 'present': true, 'method': 'QR', 'markedAt': _iso(DateTime.now())},
      {'userId': 14, 'displayName': 'Mert Aksoy', 'department': 'Makine Mühendisliği', 'present': false},
      {'userId': 15, 'displayName': 'Zeynep Arslan', 'department': 'Tıp Fakültesi', 'present': false},
    ].take(n).toList();

Map<String, dynamic> _applicant(int id, String name, {String? dep, String? note}) =>
    {'id': id, 'userId': id, 'displayName': name, 'department': dep, 'note': note, 'answers': <String>[], 'status': 'PENDING'};

FakeBackend _base({Duration delay = Duration.zero, int going = 9, int? cap = 14}) {
  final b = FakeBackend(delay: delay)
    ..on('/events/5', _ev(going: going, capacity: cap))
    ..on('/events/5/attendance', _att())
    ..on('/events/5/checkin-code', {
      'code': '5.123.abcdef',
      'qrPayload': 'bingol-checkin:5.123.abcdef',
      'validForSeconds': 30,
    })
    ..on('/events/5/admission', {'eventId': 5, 'mode': 'APPROVAL', 'questions': <String>[]})
    ..on('/events/5/chat-room', {'conversationId': 1, 'closed': false, 'joined': true, 'memberCount': 4});
  return b;
}

FakeBackend _requests({bool full = false, bool empty = false, Duration delay = Duration.zero}) {
  final b = _base(delay: delay, going: full ? 14 : 9);
  b.on('/events/5/requests?status=PENDING&size=50', {
    'items': empty
        ? <Object>[]
        : [
            _applicant(21, 'Ayşe Yılmaz', dep: 'Bilgisayar Mühendisliği'),
            _applicant(22, 'Can Demir', dep: 'İşletme', note: 'Takıma katılmak isterim, kaleci olabilirim'),
            _applicant(23, 'Zeynep Arslan', dep: 'Tıp Fakültesi'),
          ],
    'nextCursor': null,
  });
  b.on('/events/5/requests?status=ACCEPTED&size=50', {
    'items': [_applicant(31, 'Mert Aksoy', dep: 'Makine Mühendisliği'), _applicant(33, 'Elif Çelik', dep: 'Hemşirelik')],
    'nextCursor': null,
  });
  b.on('/events/5/requests?status=REJECTED&size=50', {
    'items': [_applicant(32, 'Selin Doğan', dep: 'Hukuk')],
    'nextCursor': null,
  });
  return b;
}

/// Anahtar varsa onu, yoksa (eski tasarim) metni dokunur.
Future<void> _tapKeyOr(WidgetTester t, String key, String text) async {
  final k = find.byKey(ValueKey(key));
  final f = k.evaluate().isNotEmpty ? k : find.text(text);
  if (f.evaluate().isEmpty) return; // baska dilde metin farkli
  await t.tap(f.first);
}

class _Scene {
  const _Scene(this.file, this.backend, this.page, {this.height = 844, this.drain = Duration.zero, this.pre, this.after});
  final String file;
  final FakeBackend Function() backend;
  final Widget Function(FakeBackend b) page;
  final double height;

  /// Test sonunda bekleyen zamanlayicilari bosaltmak icin ilerletilecek sure.
  final Duration drain;
  final Duration? pre;
  final Future<void> Function(WidgetTester t)? after;
}

final _scenes = <_Scene>[
  _Scene('01_istekler', () => _requests(), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev())),
  _Scene('02_istekler_dolu', () => _requests(full: true), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev(going: 14))),
  _Scene('03_istekler_bos', () => _requests(empty: true), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev())),
  _Scene('04_istekler_yukleniyor', () => _requests(delay: const Duration(seconds: 3)), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev()),
      pre: const Duration(milliseconds: 500), drain: const Duration(seconds: 12)),
  _Scene('05_istekler_hata', () {
    final b = _requests();
    b.network('/events/5/requests?status=PENDING&size=50');
    return b;
  }, (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev())),
  _Scene('06_ayarlar', () => _base(), (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _ev()), height: 900),
  _Scene('07_ayarlar_hata', () => _base(), (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _ev()), height: 900, after: (t) async {
    await t.enterText(find.byKey(const ValueKey('et2-settings-cap')), '5');
    await _tapKeyOr(t, 'et2-settings-save', 'Kaydet');
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Scene('08_ayarlar_iptal_onayi', () => _base(), (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _ev()), height: 900, after: (t) async {
    final f = find.byKey(const ValueKey('et2-cancel-event'));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(f, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Scene('09_qr', () => _base(), (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(policy: 'OPEN'))),
  _Scene('10_qr_yukleniyor', () => _base(delay: const Duration(seconds: 3)), (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(policy: 'OPEN')),
      pre: const Duration(milliseconds: 500), drain: const Duration(seconds: 12)),
  _Scene('11_qr_hata', () {
    final b = _base();
    b.fail('/events/5/checkin-code', status: 500);
    return b;
  }, (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(policy: 'OPEN')), drain: const Duration(seconds: 6)),
  _Scene('12_qr_suresi_doldu', () {
    final b = _base();
    var n = 0;
    b.handlers.add((req, path) {
      if (path == '/events/5/checkin-code') {
        n++;
        if (n == 1) {
          return const FakeResult.json({'code': '5.123.abcdef', 'qrPayload': 'bingol-checkin:5.123.abcdef', 'validForSeconds': 10});
        }
        return const FakeResult.json({'code': 'ERR', 'message': 'Sunucu hatasi'}, status: 500);
      }
      return null;
    });
    return b;
  }, (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(policy: 'OPEN'), now: () => DateTime.now().add(_skew)), after: (t) async {
    _skew = const Duration(seconds: 12);
    await t.pump(const Duration(milliseconds: 1100));
    await t.pump(const Duration(milliseconds: 1100));
  }, drain: const Duration(seconds: 6)),
  _Scene('13_yoklama', () => _base(), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN'))),
  _Scene('14_yoklama_gelmedi', () => _base(), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN')), after: (t) async {
    await _tapKeyOr(t, 'et2-filter-absent', 'Gelmedi');
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Scene('15_yoklama_bos', () {
    final b = _base();
    b.on('/events/5/attendance', <Object>[]);
    return b;
  }, (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN'))),
  _Scene('16_yoklama_yukleniyor', () => _base(delay: const Duration(seconds: 3)), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN')),
      pre: const Duration(milliseconds: 500), drain: const Duration(seconds: 12)),
  _Scene('17_yoklama_hata', () {
    final b = _base();
    b.network('/events/5/attendance');
    return b;
  }, (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN'))),
];

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

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['P16_LANG'] ?? 'tr';
  final only = (Platform.environment['P16_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P16_MODES'] ?? 'light,dark,x13').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() async {
    mockSecureStorage();
    await _loadFonts(_lang == 'ar');
  });

  for (final v in variants) {
    for (final s in _scenes) {
      if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
      final name = '${s.file}${v.$1}_$_lang';
      testWidgets('p16 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, s.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final key = GlobalKey();
        final be = s.backend();
        await tester.pumpWidget(_app(s.page(be), v.$2, key, v.$3));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
          await precacheImage(const AssetImage('assets/branding/default_group.png'), ctx);
        });
        if (s.pre != null) {
          await tester.pump(s.pre!);
        } else {
          await settle(tester, const Duration(milliseconds: 900));
        }
        if (s.after != null) {
          await s.after!(tester);
          if (s.pre == null) await settle(tester, const Duration(milliseconds: 600));
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
        await unmount(tester);
        if (s.drain > Duration.zero) await tester.pump(s.drain);
        tester.takeException();
      });
    }
  }
}
