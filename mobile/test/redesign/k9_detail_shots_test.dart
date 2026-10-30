@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/events/event_cover.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// P14 (Etkinlik listesi) ekran goruntuleri: Etkinlikler sayfasi (Kesfet / Etkinliklerim / Olusturduklarim) + Profil > Etkinliklerim.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p14/sonraki' flutter test test/redesign/k9_detail_shots_test.dart
/// Istege bagli: `K9D_LANG=tr|en|ar`, `K9D_ONLY=01,05`, `K9D_MODES=light,dark,x13`.
const _dpr = 2.0;

String _lang = 'tr';
String s(String tr, String en, String ar) => switch (_lang) {
      'ar' => ar,
      'en' => en,
      _ => tr,
    };

String _iso(DateTime d) => d.toUtc().toIso8601String();

AppLocalizations get _l => lookupAppLocalizations(Locale(_lang));

Map<String, dynamic> _ev({
  String? rsvp,
  int going = 34,
  int? cap = 50,
  bool closed = false,
  String status = 'ACTIVE',
  String policy = 'OPEN',
  bool manage = false,
  int? pending,
  bool cover = true,
}) {
  final s = DateTime.now().add(const Duration(days: 10));
  final st = DateTime(s.year, s.month, s.day, 14);
  return {
    'id': 5,
    'title': thisTitle,
    'description': s_('Geleneksel Bingöl Üniversitesi Bahar Şenliği kapsamında kampüs orkestraları, akustik dinletiler ve sürpriz müzikal performanslarla buluşuyoruz. Sahne önü çim alanda piknik düzeni oluşturulacaktır; kendi minder veya sandalyenizi getirebilirsiniz.',
        'Join us for the traditional Spring Festival with campus orchestras, acoustic sets and surprise performances. Bring your own blanket or chair.',
        'انضموا إلينا في مهرجان الربيع التقليدي مع أوركسترا الحرم والعروض الصوتية.'),
    'startsAt': _iso(st),
    'endsAt': _iso(st.add(const Duration(hours: 3))),
    'location': s_('Açık Hava Sahnesi', 'Open Air Stage', 'المسرح المفتوح'),
    'communityId': 7,
    'communityName': s_('Müzik Kulübü', 'Music Club', 'نادي الموسيقى'),
    'goingCount': going,
    'interestedCount': 12,
    if (cap != null) 'capacity': cap,
    'myRsvp': rsvp,
    'status': status,
    'registrationClosed': closed,
    'joinPolicy': policy,
    'canManage': manage,
    if (pending != null) 'pendingCount': pending,
    'coverUrl': cover ? '/files/e1.jpg' : null,
    'createdBy': 2,
  };
}

String s_(String tr, String en, String ar) => s(tr, en, ar);
String get thisTitle => s('Bahar Şenliği', 'Spring Festival', 'مهرجان الربيع');

FakeBackend _be(Map<String, dynamic> ev, {bool checkInOpen = false, bool present = false}) {
  final b = FakeBackend()
    ..on('/events/5', ev)
    ..on('/events/5/my-attendance', {'present': present, 'checkInOpen': checkInOpen})
    ..on('/events/5/admission', {'eventId': 5, 'mode': ev['joinPolicy'], 'questions': ['Neden katılmak istiyorsun?']})
    ..on('/events/5/attendance', [
      for (var i = 0; i < 42; i++) {'userId': 100 + i, 'displayName': 'K $i', 'present': i < 18},
    ]);
  return b;
}

Widget _detail(FakeBackend b) => EventDetailPage(session: makeSession(b), eventId: 5);

class _Cover extends ImageProvider<_Cover> {
  _Cover(this.image);
  final ui.Image image;
  @override
  Future<_Cover> obtainKey(ImageConfiguration c) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_Cover key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image.clone())));
}

Future<ui.Image> _paint(WidgetTester tester, Color a, Color b) async {
  return (await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const w = 800.0, h = 450.0;
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(w, h), [a, b]));
    for (var i = 0; i < 9; i++) {
      c.drawCircle(Offset((i * 97) % 800.0, (i * 61) % 450.0), 40.0 + (i * 23) % 90, Paint()..color = Colors.white.withValues(alpha: .12));
    }
    return rec.endRecording().toImage(800, 450);
  }))!;
}

Future<void> _covers(WidgetTester tester) async {
  final img = await _paint(tester, const Color(0xFF14532D), const Color(0xFF86C77A));
  EventCoverImage.debugProvider = (url) => _Cover(img);
  addTearDown(() => EventCoverImage.debugProvider = null);
}


class _Scn {
  const _Scn(this.file, this.backend, this.page, {this.after, this.height = 844, this.delay = false});
  final String file;
  final FakeBackend Function() backend;
  final Widget Function(FakeBackend b) page;
  final Future<void> Function(WidgetTester t)? after;
  final double height;
  final bool delay;
}

Future<void> _tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.ensureVisible(f);
  await t.tap(f);
  await settle(t, const Duration(milliseconds: 500));
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
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

Future<void> _tapKey(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 500));
}

final _scns = <_Scn>[
  // ---- 38: RSVP / kontenjan durumlari ----
  _Scn('38a_kayitlar_acik', () => _be(_ev()), _detail, height: 1500),
  _Scn('38b_katiliyor', () => _be(_ev(rsvp: 'GOING')), _detail, height: 1500),
  _Scn('38c_ilgileniyor', () => _be(_ev(rsvp: 'INTERESTED')), _detail, height: 1400),
  _Scn('38d_kontenjan_dolu', () => _be(_ev(going: 50)), _detail, height: 1400),
  _Scn('38e_kayitlar_kapali', () => _be(_ev(closed: true)), _detail, height: 1400),
  _Scn('38f_iptal_edildi', () => _be(_ev(status: 'CANCELLED')), _detail, height: 1200),
  // ---- 39: istek + yoklama ----
  _Scn('39a_istek_sheet', () {
    final b = _be(_ev(policy: 'APPROVAL', cap: 45, going: 12));
    b.handlers.add((req, path) {
      if (req.method == 'PUT' && path == '/events/5/rsvp') {
        return const FakeResult.json({'code': 'ANSWERS_REQUIRED', 'message': 'Tüm sorulara yanıt vermelisiniz.'}, status: 400);
      }
      return null;
    });
    return b;
  }, _detail, height: 900, after: (t) async {
    await _tapKey(t, 'et2-request-send');
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(const ValueKey('et2-apply-send')));
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Scn('39b_istek_bekliyor_geri_cek', () => _be(_ev(policy: 'APPROVAL', rsvp: 'PENDING', cap: 45, going: 12)), _detail, height: 900, after: (t) async {
    await _tapKey(t, 'et2-withdraw');
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Scn('39c_istek_reddedildi', () => _be(_ev(policy: 'APPROVAL', rsvp: 'REJECTED', cap: 45, going: 12)), _detail, height: 1200),
  _Scn('39d_onaylandi_yoklama_bekliyor', () => _be(_ev(policy: 'APPROVAL', rsvp: 'GOING', cap: 45, going: 12)), _detail, height: 1300),
  _Scn('39e_yoklama_acik_kod', () => _be(_ev(rsvp: 'GOING'), checkInOpen: true), _detail, height: 1700, after: (t) async {
    await _tapKey(t, 'detail-enter-code');
    await t.enterText(find.byKey(const ValueKey('detail-code-field')), 'K7M4QX');
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Scn('39f_yoklama_alindi', () => _be(_ev(rsvp: 'GOING'), checkInOpen: true, present: true), _detail, height: 1300),
  _Scn('39g_yoklama_hata', () => _be(_ev(rsvp: 'GOING'), checkInOpen: true), _detail, height: 1700, after: (t) async {
    await _tapKey(t, 'detail-enter-code');
    await t.enterText(find.byKey(const ValueKey('detail-code-field')), '9.123.abc');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump(const Duration(milliseconds: 600));
  }),
  // ---- 41-01: organizator ----
  _Scn('41a_organizator', () => _be(_ev(policy: 'APPROVAL', manage: true, pending: 3, cap: 42, going: 18)), _detail, height: 1700),
  _Scn('41a_organizator_menu', () => _be(_ev(policy: 'APPROVAL', manage: true, pending: 3, cap: 42, going: 18)), _detail, height: 900, after: (t) async {
    await t.tap(find.byTooltip(_l.eventFormManage));
    await t.pump(const Duration(milliseconds: 600));
  }),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = (Platform.environment['K9D_LANG'] ?? 'tr');
  final only = (Platform.environment['K9D_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K9D_MODES'] ?? 'light,dark,x13').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final sc in _scns) {
      if (only.isNotEmpty && !only.any((o) => sc.file.startsWith(o))) continue;
      final name = '${sc.file}${v.$1}_$_lang';
      testWidgets('k9d $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, sc.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        await _covers(tester);

        final b = sc.backend();
        final key = GlobalKey();
        // Gecikmeli senaryoda yanit gelmez: iskelet gorunur.
        if (sc.delay) b.delay = const Duration(seconds: 3);
        await tester.pumpWidget(_app(sc.page(b), v.$2, key, v.$3));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
          await precacheImage(const AssetImage('assets/branding/default_group.png'), ctx);
        });
        await settle(tester, sc.delay ? const Duration(milliseconds: 300) : const Duration(milliseconds: 1200));
        if (sc.after != null) {
          await sc.after!(tester);
          await settle(tester, const Duration(milliseconds: 700));
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
        if (sc.delay) await tester.pump(const Duration(seconds: 25));
      });
    }
  }
}
