@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/events/event_cover.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
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
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p14/sonraki' flutter test test/redesign/k9_events_shots_test.dart
/// Istege bagli: `K9E_LANG=tr|en|ar`, `K9E_ONLY=01,05`, `K9E_MODES=light,dark,x13`.
const _dpr = 2.0;

String _lang = 'tr';
String s(String tr, String en, String ar) => switch (_lang) {
      'ar' => ar,
      'en' => en,
      _ => tr,
    };

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev(int id,
    {required String title,
    String? cover,
    String? rsvp,
    bool manage = false,
    bool closed = false,
    String status = 'ACTIVE',
    int days = 0,
    int hour = 14,
    int going = 24,
    String? org,
    String? place,
    int? pending,
    int? cap,
    String? reason}) {
  final n = DateTime.now();
  final st = DateTime(n.year, n.month, n.day + days, hour);
  return {
    'id': id,
    'source': 'USER',
    'title': title,
    'description': 'x',
    'startsAt': _iso(st),
    'endsAt': _iso(st.add(const Duration(hours: 2))),
    'location': place ?? s('Merkez Kampüs Konferans Salonu', 'Main Campus Conference Hall', 'قاعة المؤتمرات في الحرم الرئيسي'),
    'communityName': org ?? s('Bilgisayar Topluluğu', 'Computer Society', 'نادي الحاسوب'),
    'goingCount': going,
    'myRsvp': rsvp,
    'canManage': manage,
    'registrationClosed': closed,
    if (cap != null) 'capacity': cap,
    if (reason != null) 'rejectReason': reason,
    'status': status,
    'coverUrl': cover,
    if (pending != null) 'pendingRequestCount': pending,
    'attendeesPreview': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'avatarUrl': null},
      {'userId': 2, 'displayName': 'Ali Veli', 'avatarUrl': null},
      {'userId': 3, 'displayName': 'Mehmet Kaya', 'avatarUrl': null},
    ],
  };
}

AppLocalizations get _l => lookupAppLocalizations(Locale(_lang));

Map<String, dynamic> _page(List<Map<String, dynamic>> items) => {'items': items, 'nextCursor': null};

String get _t1 => s('Yapay Zeka ve Veri Bilimi Kariyer Günleri', 'AI and Data Science Career Days', 'أيام المهن في الذكاء الاصطناعي وعلوم البيانات');
String get _t2 => s('Bahar Şenliği Açılış Konseri', 'Spring Festival Opening Concert', 'حفل افتتاح مهرجان الربيع');
String get _t3 => s('Fotoğrafçılık Atölyesi', 'Photography Workshop', 'ورشة التصوير الفوتوغرافي');
String get _t4 => s('Bingöl Üniversitesi Mühendislik Fakültesi Bilgisayar Mühendisliği Öğrenci Topluluğu Büyük Buluşma', 'Bingol University Faculty of Engineering Computer Engineering Student Society Grand Meetup',
    'اللقاء الكبير لنادي طلاب هندسة الحاسوب في كلية الهندسة بجامعة بينغول');

List<Map<String, dynamic>> _calendar() {
  return [
    _ev(1, title: s('Bahar Şenliği Hazırlık Toplantısı', 'Spring Festival Planning Meeting', 'اجتماع تحضير مهرجان الربيع'), days: 0, hour: 14, going: 34, org: s('Müzik Kulübü', 'Music Club', 'نادي الموسيقى'), place: s('Konferans Salonu', 'Conference Hall', 'قاعة المؤتمرات')),
    _ev(2, title: s('Yapay Zeka ve Kariyer Sohbeti', 'AI and Career Talk', 'حوار الذكاء الاصطناعي والمهن'), days: 0, hour: 16, going: 52, org: s('Bilişim ve Teknoloji Kulübü', 'Informatics Club', 'نادي المعلوماتية'), place: s('Mühendislik Fakültesi Amfi 1', 'Engineering Hall 1', 'مدرج الهندسة 1')),
    _ev(3, title: s('Kariyer Günleri Açılış Paneli', 'Career Days Opening Panel', 'حلقة افتتاح أيام المهن'), days: 2, hour: 10, going: 18, closed: true, org: s('Kariyer ve Girişimcilik Kulübü', 'Career Club', 'نادي المهن')),
    _ev(4, title: s('Geleneksel Satranç Turnuvası', 'Traditional Chess Tournament', 'بطولة الشطرنج التقليدية'), days: 3, hour: 14, going: 9, status: 'CANCELLED', org: s('Satranç Kulübü', 'Chess Club', 'نادي الشطرنج')),
    _ev(5, title: s('Drone Kodlama Atölyesi', 'Drone Coding Workshop', 'ورشة برمجة الطائرات'), days: 4, hour: 11, going: 40, cap: 40, org: s('Robotik Kulübü', 'Robotics Club', 'نادي الروبوت')),
  ];
}

FakeBackend _full() => FakeBackend()
  ..on('/events/calendar*', _calendar(), headers: {'x-truncated': 'false'})
  ..on('/me/events?mode=attending&size=20', _page([
    _ev(2, title: _t2, cover: '/files/e2.jpg', rsvp: 'GOING', days: 0, hour: 19, going: 56),
    _ev(3, title: _t3, rsvp: 'GOING', days: 1, hour: 11, going: 12, org: s('Fotoğraf Kulübü', 'Photo Club', 'نادي التصوير')),
    _ev(4, title: _t4, rsvp: 'GOING', days: 2, hour: 10, going: 3),
  ]))
  ..on('/me/events?mode=past&size=20', _page([
    _ev(30, title: s('Kariyer Zirvesi 2026', 'Career Summit 2026', 'قمة المهن 2026'), cover: '/files/e3.jpg', rsvp: 'GOING', days: -3, hour: 10, going: 210),
    _ev(31, title: s('Satranç Turnuvası', 'Chess Tournament', 'بطولة الشطرنج'), rsvp: 'GOING', days: -9, hour: 13, going: 32),
  ]))
  ..on('/me/events?mode=organizing&size=20', _page([
    _ev(8, title: _t1, cover: '/files/e1.jpg', manage: true, going: 128, pending: 4),
    _ev(10, title: _t3, manage: true, days: 1, going: 12, closed: true),
    _ev(11, title: s('Onay bekleyen etkinlik', 'Event waiting for review', 'فعالية بانتظار المراجعة'), manage: true, status: 'PENDING_REVIEW', days: 5, going: 0),
    _ev(12, title: s('İptal edilen seminer', 'Cancelled seminar', 'ندوة ملغاة'), manage: true, status: 'CANCELLED', days: 2, going: 9),
  ]));

FakeBackend _empty() => FakeBackend()
  ..on('/events/calendar*', <Object>[], headers: {'x-truncated': 'false'})
  ..on('/me/events*', _page([]));

FakeBackend _failing() => FakeBackend()
  ..fail('/events/calendar*')
  ..fail('/me/events*');

class _Cover extends ImageProvider<_Cover> {
  _Cover(this.image);
  final ui.Image image;
  @override
  Future<_Cover> obtainKey(ImageConfiguration c) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_Cover key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image.clone())));
}

Future<ui.Image> _paint(WidgetTester tester, Color a, Color b, int seed) async {
  return (await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const w = 800.0, h = 450.0;
    c.drawRect(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(w, h), [a, b]));
    for (var i = 0; i < 7; i++) {
      final x = (seed * 97 + i * 131) % 800;
      final y = (seed * 53 + i * 71) % 450;
      c.drawCircle(Offset(x.toDouble(), y.toDouble()), 40.0 + (i * 23 + seed * 7) % 90,
          Paint()..color = Colors.white.withValues(alpha: .10 + (i % 3) * .05));
    }
    return rec.endRecording().toImage(800, 450);
  }))!;
}

Future<void> _covers(WidgetTester tester) async {
  final imgs = [
    await _paint(tester, const Color(0xFF8E1B13), const Color(0xFFE0603C), 1),
    await _paint(tester, const Color(0xFF1F3A8A), const Color(0xFF4F8FD9), 2),
    await _paint(tester, const Color(0xFF14532D), const Color(0xFF65B96F), 3),
  ];
  EventCoverImage.debugProvider = (url) => _Cover(imgs[url.hashCode.abs() % imgs.length]);
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

Widget _events(FakeBackend b, {int tab = 0}) => EventsPage(session: makeSession(b), initialTab: tab);

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

String get _todayDay => '${DateTime.now().day}';

final _scns = <_Scn>[
  _Scn('36a_kesfet_gun', _full, (b) => _events(b), after: (t) async {
    await t.tap(find.descendant(of: find.byKey(const ValueKey('events-calendar')), matching: find.text(_todayDay)).last);
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Scn('36b_kesfet_ay_listesi', _full, (b) => _events(b), height: 1500),
  _Scn('36c_kesfet_gun_bos_not', () => _full()..on('/events/calendar*', _calendar(), headers: {'x-truncated': 'true'}), (b) => _events(b), after: (t) async {
    // Bugunden baska, etkinligi olmayan bir gun
    final d = DateTime.now().day;
    final pick = d <= 20 ? d + 7 : d - 7;
    await t.tap(find.descendant(of: find.byKey(const ValueKey('events-calendar')), matching: find.text('$pick')).last);
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Scn('36d_etkinliklerim_yaklasan', _full, (b) => _events(b, tab: 1), height: 1300),
  _Scn('36e_etkinliklerim_gecmis', _full, (b) => _events(b, tab: 1), after: (t) async {
    await _tapText(t, _l.eventListPast);
  }),
  _Scn('36f_olusturduklarim', _full, (b) => _events(b, tab: 2), height: 1500),
  _Scn('36g_olusturduklarim_menu', _full, (b) => _events(b, tab: 2), after: (t) async {
    await t.tap(find.byTooltip(_l.eventListOptions).first);
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Scn('36h_profil_etkinliklerim', _full, (b) => MyEventsPage(session: makeSession(b)), height: 1300),
  _Scn('36i_profil_olusturduklarim', _full, (b) => MyEventsPage(session: makeSession(b)), after: (t) async {
    await _tapText(t, _l.profilyardEventsCreated);
  }),
  _Scn('36j_profil_bos', _empty, (b) => MyEventsPage(session: makeSession(b))),
  // ---- 37 ----
  _Scn('37a_yukleniyor', _full, (b) => _events(b), delay: true),
  _Scn('37b_bos_yaklasan', _empty, (b) => _events(b, tab: 1)),
  _Scn('37b_bos_olusturduklarim', () => _empty()..on('/me/communities*', {'items': [{'id': 7, 'name': 'K', 'myRole': 'OWNER', 'myStatus': 'ACTIVE'}]}), (b) => _events(b, tab: 2)),
  _Scn('37b_bos_kulup_yok', () => _empty()..on('/me/communities*', {'items': <Object>[]}), (b) => _events(b, tab: 2)),
  _Scn('37c_hata', _failing, (b) => _events(b)),
  _Scn('37d_ayril_diyalogu', _full, (b) => _events(b, tab: 1), after: (t) async {
    await t.tap(find.byTooltip(_l.eventListOptions).first);
    await settle(t, const Duration(milliseconds: 400));
    await t.tap(find.text(_l.eventListLeaveTitle).first);
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Scn('37e_iptal_diyalogu', _full, (b) => _events(b, tab: 2), after: (t) async {
    await t.tap(find.byTooltip(_l.eventListOptions).first);
    await settle(t, const Duration(milliseconds: 400));
    await t.tap(find.text(_l.eventListCancelConfirm).first);
    await settle(t, const Duration(milliseconds: 500));
  }),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = (Platform.environment['K9E_LANG'] ?? 'tr');
  final only = (Platform.environment['K9E_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K9E_MODES'] ?? 'light,dark,x13').split(',');
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
      testWidgets('k9e $name', skip: skip != null, (tester) async {
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
