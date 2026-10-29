@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/features/events/etkinlik2_attendance_page.dart';
import 'package:bu_kampus/features/events/event_cover.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
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
import 'p10_images.dart';

/// K9 (Paket 15 form + Paket 16) (etkinlik organizator araclari + QR) ekran goruntuleri: tum durum varyantlari.
///
/// Varsayilan `flutter test` ile CALISMAZ (STORE_SHOTS_OUT yoksa atlanir). Uretim (C:\bu_mobile icinde):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p16/sonraki' flutter test test/redesign/k9_shots_test.dart
/// Istege bagli: `K9_LANG=tr|en|ar`, `K9_ONLY=01,05`, `K9_MODES=light,dark,x13`.
const _dpr = 2.5;
String _lang = 'tr';

Duration _skew = Duration.zero;

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _ev({String policy = 'APPROVAL', int? capacity = 50, int going = 12, bool closed = false}) {
  final s = DateTime.now().add(const Duration(hours: 3));
  return {
    'id': 5,
    'title': _lang == 'ar'
        ? 'ليلة الموسيقى الصوتية في الحرم الجامعي'
        : (_lang == 'en' ? 'Acoustic Campus Night and spring meetup' : "Akustik Kampüs Gecesi '24 ve bahar buluşması"),
    'communityName': _lang == 'ar' ? 'نادي الموسيقى' : (_lang == 'en' ? 'Music Club' : 'Müzik Kulübü'),
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': _lang == 'ar' ? 'ملعب الحرم' : (_lang == 'en' ? 'Campus pitch' : 'Merkezi amfi'),
    'goingCount': going,
    'capacity': capacity,
    'canManage': true,
    'joinPolicy': policy,
    'registrationClosed': closed,
    'createdBy': 2,
  };
}

List<Map<String, dynamic>> _att() {
  const people = [
    ('Elif Yıldız', 'Fen-Edebiyat Fakültesi · Sosyoloji', 'MANUAL'),
    ('Emre Kaya', 'Mühendislik Fakültesi · Bilgisayar', 'QR'),
    ('Selin Yılmaz', 'İktisadi ve İdari Bilimler · İşletme', 'QR'),
    ('Ahmet Demir', 'İlahiyat Fakültesi', null),
    ('Mehmet Doğan', 'Ziraat Fakültesi · Bahçe Bitkileri', null),
  ];
  return [
    for (var i = 0; i < people.length; i++)
      {
        'userId': 11 + i,
        'displayName': people[i].$1,
        'department': people[i].$2,
        'present': people[i].$3 != null,
        if (people[i].$3 != null) 'method': people[i].$3,
        if (people[i].$3 == 'QR') 'markedAt': _iso(DateTime.now()),
      },
  ];
}

Map<String, dynamic> _applicant(int id, String name, {String? dep, String? note, String? email, int minAgo = 12}) => {
      'id': id,
      'userId': id,
      'displayName': name,
      'department': dep,
      'note': note,
      'email': email,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: minAgo))),
      'answers': <String>[],
      'status': 'PENDING'
    };

FakeBackend _base({Duration delay = Duration.zero, int going = 12, int? cap = 50}) {
  final b = FakeBackend(delay: delay)
    ..on('/events/5', _ev(going: going, capacity: cap))
    ..on('/events/5/attendance', _att())
    ..on('/events/5/checkin-code', {
      'code': 'K7M4QX',
      'qrPayload': 'bingol-checkin:K7M4QX',
      'validForSeconds': 30,
    })
    ..on('/events/5/admission', {'eventId': 5, 'mode': 'APPROVAL', 'questions': <String>[]})
    ..on('/events/5/chat-room', {'conversationId': 1, 'closed': false, 'joined': true, 'memberCount': 4});
  return b;
}

FakeBackend _requests({bool full = false, bool empty = false, Duration delay = Duration.zero}) {
  final b = full ? _base(delay: delay, going: 4, cap: 4) : _base(delay: delay, cap: empty ? null : 50);
  b.on('/events/5/requests?status=PENDING&size=50', {
    'items': empty
        ? <Object>[]
        : full
            ? [_applicant(21, 'Ahmet Demir', dep: 'İlahiyat Fakültesi', note: 'Etkinlik içeriği çalışma alanımla doğrudan ilgili, katılım sağlamayı çok isterim.', minAgo: 30)]
            : [
                _applicant(21, 'Emre Kaya',
                    dep: 'Mühendislik Fakültesi · Bilgisayar Müh. (3. Sınıf)',
                    email: 'emre.kaya@bingol.edu.tr',
                    note: 'Kulüp akustik dinletisinde gitar çalmak istiyorum, ekipman getirebilirim.'),
                _applicant(22, 'Selin Yılmaz',
                    dep: 'İktisadi ve İdari Bilimler · İşletme (2. Sınıf)',
                    email: 'selin.yilmaz@bingol.edu.tr',
                    note: 'Kulüp etkinliklerine ilk kez katılıyorum, sabırsızlanıyorum!',
                    minAgo: 45),
                _applicant(23, 'Barış Öztürk',
                    dep: 'Fen Edebiyat Fakültesi · Moleküler Biyoloji',
                    email: 'baris.ozturk@bingol.edu.tr',
                    note: 'Katılım için kayıt oluşturuyorum.',
                    minAgo: 120),
              ],
    'nextCursor': null,
  });
  b.on('/events/5/requests?status=ACCEPTED&size=50', {
    'items': [_applicant(31, 'Emre Kaya', dep: 'Bilgisayar Müh.'), _applicant(33, 'Selin Yılmaz', dep: 'İşletme')],
    'nextCursor': null,
  });
  b.on('/events/5/requests?status=REJECTED&size=50', {
    'items': [_applicant(32, 'Mehmet Doğan', dep: 'Ziraat Fakültesi')],
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
  // ---- Grup 41: katilim istekleri ----
  _Scene('41d_istekler', () => _requests(), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev(going: 12, capacity: 50)), after: (t) async {
    // "Istek onaylandi." bildirimi (referans alt bildirim)
    await _tapKeyOr(t, 'et2-approve-21', 'Onayla');
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Scene('41e_istekler_dolu', () => _requests(full: true), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev(going: 4, capacity: 4))),
  _Scene('41f_istekler_bos', () => _requests(empty: true), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev(capacity: null))),
  _Scene('41g_istekler_hata', () {
    final b = _requests(empty: true);
    b.network('/events/5/requests?status=PENDING&size=50');
    return b;
  }, (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev(capacity: null))),
  _Scene('41h_istekler_yukleniyor', () => _requests(delay: const Duration(seconds: 3)), (b) => Etkinlik2RequestsPage(session: makeSession(b), event: _ev()),
      pre: const Duration(milliseconds: 500), drain: const Duration(seconds: 12)),
  // ---- Grup 41: ayarlar ----
  _Scene('41b_ayarlar', () => _base(), (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _ev(going: 12, capacity: 20)), height: 1100),
  _Scene('41b_ayarlar_hata', () => _base(), (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _ev(going: 12, capacity: 20)), height: 1100, after: (t) async {
    await t.enterText(find.byKey(const ValueKey('et2-settings-cap')), '10');
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Scene('41c_ayarlar_iptal_diyalogu', () => _base(), (b) => Etkinlik2SettingsPage(session: makeSession(b), event: _ev(going: 12, capacity: 20)), height: 1100, after: (t) async {
    final f = find.byKey(const ValueKey('et2-cancel-event'));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(f, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 600));
  }),
  // ---- Grup 42: QR ----
  _Scene('42a_qr', () {
    _skew = Duration.zero;
    return _base();
  }, (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(policy: 'OPEN', going: 18)), after: (t) async {
    _skew = const Duration(seconds: 25);
    await t.pump(const Duration(milliseconds: 1100));
  }),
  _Scene('42b_qr_suresi_doldu', () {
    _skew = Duration.zero;
    final b = _base();
    var n = 0;
    b.handlers.add((req, path) {
      if (path == '/events/5/checkin-code') {
        n++;
        if (n == 1) {
          return const FakeResult.json({'code': 'K7M4QX', 'qrPayload': 'bingol-checkin:K7M4QX', 'validForSeconds': 10});
        }
        return const FakeResult.json({'code': 'ERR', 'message': 'Sunucu hatasi'}, status: 500);
      }
      return null;
    });
    return b;
  }, (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(policy: 'OPEN', going: 18), now: () => DateTime.now().add(_skew)), after: (t) async {
    _skew = const Duration(seconds: 12);
    await t.pump(const Duration(milliseconds: 1100));
    await t.pump(const Duration(milliseconds: 1100));
  }, drain: const Duration(seconds: 6)),
  _Scene('42c_qr_hata', () {
    final b = _base();
    b.fail('/events/5/checkin-code', status: 500);
    return b;
  }, (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(policy: 'OPEN', going: 18)), drain: const Duration(seconds: 6)),
  _Scene('42d_qr_yukleniyor', () => _base(delay: const Duration(seconds: 3)), (b) => Etkinlik2QrPage(session: makeSession(b), event: _ev(policy: 'OPEN')),
      pre: const Duration(milliseconds: 500), drain: const Duration(seconds: 12)),
  // ---- Grup 42: yoklama listesi ----
  _Scene('42e_yoklama', () => _base(), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN'))),
  _Scene('42f_yoklama_elle', () => _base(), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN')), after: (t) async {
    await t.tap(find.byKey(const ValueKey('et2-mark-14')));
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Scene('42g_yoklama_gelmedi_bos', () {
    final b = _base();
    b.on('/events/5/attendance', _att().where((e) => e['present'] == true).toList());
    return b;
  }, (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN')), after: (t) async {
    await _tapKeyOr(t, 'et2-filter-absent', 'Gelmedi');
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Scene('42h_yoklama_hata', () {
    final b = _base();
    b.network('/events/5/attendance');
    return b;
  }, (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN'))),
  _Scene('42i_yoklama_yukleniyor', () => _base(delay: const Duration(seconds: 3)), (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN')),
      pre: const Duration(milliseconds: 500), drain: const Duration(seconds: 12)),
  _Scene('42j_yoklama_bos', () {
    final b = _base();
    b.on('/events/5/attendance', <Object>[]);
    return b;
  }, (b) => Etkinlik2AttendancePage(session: makeSession(b), event: _ev(policy: 'OPEN'))),
];


// ---- Grup 40: etkinlik formu ----
Map<String, dynamic> _club(int id, String name, String role, {int members = 120, Map<String, dynamic>? extra}) =>
    {'id': id, 'name': name, 'myRole': role, 'myStatus': 'ACTIVE', 'memberCount': members, ...?extra};

final _coverImg = MemoryImage(p10Photo(1, w: 640, h: 360));

DateTime _formNow() => DateTime(2026, 10, 30, 10, 20);

FakeBackend _formBe(List<Map<String, dynamic>> clubs, {Duration delay = Duration.zero}) =>
    FakeBackend(delay: delay)..on('/me/communities*', {'items': clubs})..on('/events', {'id': 77});

Map<String, dynamic> _editEv() => {
      'id': 9,
      'title': 'Bahar Dönemi Akustik Konseri',
      'description': 'Akustik gece için kulüp üyeleri sahne alacak.',
      'startsAt': DateTime(2026, 11, 3, 15, 30).toUtc().toIso8601String(),
      'endsAt': DateTime(2026, 11, 3, 17, 30).toUtc().toIso8601String(),
      'location': 'Fen-Edebiyat Fakültesi Konferans Salonu',
      'capacity': 450,
      'joinPolicy': 'APPROVAL',
      'communityId': 7,
      'communityName': 'Müzik Kulübü',
      'coverUrl': '/files/x.png',
    };

Future<void> _fillForm(WidgetTester t) async {
  await t.enterText(find.byKey(const ValueKey('evc-title')), 'Bahar Dönemi Akustik Kampüs Dinletisi');
  await t.enterText(find.byKey(const ValueKey('evc-desc')), 'Merkezi amfide gerçekleşecek akustik müzik dinletimize tüm öğrencilerimiz davetlidir. Katılım serbesttir.');
  await t.enterText(find.byKey(const ValueKey('evc-place')), 'Fen-Edebiyat Fakültesi Konferans Salonu');
  await t.ensureVisible(find.text('Yarın'));
  await t.tap(find.text('Yarın'));
  await t.pump();
  await t.tap(find.text('14:00'));
  await t.pump();
}

final _formScenes = <_Scene>[
  _Scene('40a_form', () => _formBe([_club(7, 'Müzik Kulübü', 'OWNER')]), (b) => EventFormPage(session: makeSession(b), now: _formNow),
      height: 1900, after: _fillForm),
  _Scene('40c_dogrulama', () => _formBe([_club(7, 'Müzik Kulübü', 'OWNER'), _club(8, 'Tiyatro Kulübü', 'MODERATOR')]),
      (b) => EventFormPage(session: makeSession(b), now: _formNow), height: 1950, after: (t) async {
    await t.enterText(find.byKey(const ValueKey('evc-title')), 'Et');
    await t.enterText(find.byKey(const ValueKey('evc-desc')), 'Bingöl Üniversitesi Mühendislik Fakültesi Konferans Salonu ' * 20);
    await t.ensureVisible(find.byKey(const ValueKey('evc-cap')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('evc-cap')));
    await t.enterText(find.byKey(const ValueKey('evc-cap')), '0');
    await t.pump();
    await t.ensureVisible(find.byKey(const ValueKey('evc-submit')));
    await t.tap(find.byKey(const ValueKey('evc-submit')));
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Scene('40d_kulup_yok', () => _formBe([]), (b) => EventFormPage(session: makeSession(b), now: _formNow)),
  _Scene('40e_kulup_secici', () {
    return _formBe([
      _club(7, 'Müzik Kulübü', 'OWNER', members: 342),
      _club(8, 'Tiyatro ve Sahne Sanatları Kulübü', 'OWNER', members: 180),
      _club(9, 'Yazılım ve Bilişim Kulübü', 'MODERATOR', members: 512),
      _club(10, 'Doğa Sporları ve Dağcılık Kulübü', 'MODERATOR', members: 229),
    ]);
  }, (b) => EventFormPage(session: makeSession(b), now: _formNow, communityId: 7), height: 900, after: (t) async {
    await t.tap(find.byKey(const ValueKey('et2-club-field')));
    await t.pump(const Duration(milliseconds: 700));
  }),
  _Scene('40g_duzenle_kapak_sheet', () {
    EventCoverImage.debugProvider = (_) => _coverImg;
    return _formBe([]);
  }, (b) => EventFormPage(session: makeSession(b), event: _editEv(), now: _formNow), height: 900, after: (t) async {
    await t.tap(find.text('Değiştir'));
    await t.pump(const Duration(milliseconds: 700));
  }),
  _Scene('40h_duzenle', () {
    EventCoverImage.debugProvider = (_) => _coverImg;
    return _formBe([]);
  }, (b) => EventFormPage(session: makeSession(b), event: _editEv(), now: _formNow), height: 1500),
  _Scene('40i_form_yukleniyor', () => _formBe([_club(7, 'Müzik Kulübü', 'OWNER')], delay: const Duration(seconds: 3)),
      (b) => EventFormPage(session: makeSession(b), now: _formNow), pre: const Duration(milliseconds: 500), drain: const Duration(seconds: 12)),
  _Scene('40j_sunucu_hata', () {
    final b = _formBe([_club(7, 'Müzik Kulübü', 'OWNER')]);
    b.fail('/events', status: 403, code: 'FORBIDDEN', message: 'Forbidden');
    return b;
  }, (b) => EventFormPage(session: makeSession(b), now: _formNow), height: 1900, after: (t) async {
    await _fillForm(t);
    await t.ensureVisible(find.byKey(const ValueKey('evc-submit')));
    await t.tap(find.byKey(const ValueKey('evc-submit')));
    await t.pump(const Duration(milliseconds: 600));
    await t.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await t.pump(const Duration(milliseconds: 300));
  }),
];

Future<void> _loadMono() async {
  final f = FontLoader('monospace');
  final file = File('C:/Windows/Fonts/consolab.ttf');
  if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await f.load();
}

Future<void> _loadFonts(bool arabic) async {
  await _loadFonts0(arabic);
  await _loadMono();
}

Future<void> _loadFonts0(bool arabic) async {
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
  _lang = Platform.environment['K9_LANG'] ?? 'tr';
  final only = (Platform.environment['K9_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K9_MODES'] ?? 'light,dark,x13').split(',');
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
    for (final s in [..._scenes, ..._formScenes]) {
      if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
      final name = '${s.file}${v.$1}_$_lang';
      testWidgets('k9 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, s.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        final key = GlobalKey();
        EventCoverImage.debugProvider = null;
        final be = s.backend();
        await tester.pumpWidget(_app(s.page(be), v.$2, key, v.$3));
        await tester.runAsync(() async {
          final ctx = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
          await precacheImage(const AssetImage('assets/branding/default_group.png'), ctx);
          if (EventCoverImage.debugProvider != null) await precacheImage(_coverImg, ctx);
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
