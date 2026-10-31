@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_members_page.dart';
import 'package:bu_kampus/features/clubs/club_requests_page.dart';
import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// Paket 11 (Kulup detayi, uyeler, istekler, anket olusturma) ekran goruntuleri: GERCEK ekranlar + sahte API.
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/p11/sonraki' flutter test test/redesign/p11_shots_test.dart
/// Istege bagli: `P11_LANG=tr|en|ar` (varsayilan tr), `P11_ONLY=01,10`, `P11_MODES=light,dark,x13` (varsayilan light,dark).
const _dpr = 2.0;
const _w = 390.0;
const _h = 844.0;

String _lang = 'tr';
AppLocalizations get _l => lookupAppLocalizations(Locale(_lang));

class _Shot {
  const _Shot(this.file, this.build, {this.after, this.slow = false, this.height = _h});
  final String file;
  final Widget Function(FakeBackend b) build;
  final Future<void> Function(WidgetTester t)? after;
  final bool slow;
  final double height;
}

const _longName = 'Bingöl Üniversitesi Mühendislik Fakültesi Bilgisayar Mühendisliği Öğrenci Topluluğu Büyük Buluşma';
String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _club({String status = 'ACTIVE', String? role = 'OWNER', String name = 'Fotoğraf Kulübü', bool cover = true}) => {
      'id': 7,
      'name': name,
      'description':
          'Kampüste fotoğraf gezileri, teknik atölyeler ve dönem sonu sergisi düzenleyen öğrenci topluluğu. Her çarşamba toplanıyoruz; yeni başlayanlar da çok sevilir.',
      'category': 'Sanat',
      'memberCount': 128,
      'visibility': 'PUBLIC',
      'joinPolicy': 'APPROVAL',
      'myStatus': status,
      'myRole': role,
      if (cover) 'coverUrl': 'https://img.invalid/cover.jpg',
    };

FakeBackend _be({String status = 'ACTIVE', String? role = 'OWNER', int pending = 2, bool posts = true, String name = 'Fotoğraf Kulübü', bool cover = true}) {
  final now = DateTime.now();
  final b = FakeBackend()
    ..on('/communities/7', _club(status: status, role: role, name: name, cover: cover))
    ..on('/communities/7/posts*', {
      'items': posts
          ? [
              {
                'id': 1,
                'authorId': 5,
                'authorName': 'Elif Yıldız',
                'text': 'Cumartesi gezisi: Kale çevresi, 10.00',
                'pinned': true,
                'canDelete': true,
                'createdAt': _iso(now.subtract(const Duration(hours: 3))),
              },
              {
                'id': 2,
                'authorId': 11,
                'authorName': 'Mert Kaya',
                'text': 'Sergi için fotoğraflar hazır',
                'imageUrl': 'https://img.invalid/p2.jpg',
                'canDelete': false,
                'createdAt': _iso(now.subtract(const Duration(days: 1))),
              },
              {
                'id': 3,
                'authorId': 12,
                'authorName': 'Zeynep Arslan',
                'text': 'Teşekkürler herkese!',
                'createdAt': _iso(now.subtract(const Duration(days: 3))),
              },
            ]
          : [],
      'nextCursor': null,
    })
    ..on('/communities/7/requests*', {
      'items': [for (var i = 0; i < pending; i++) {'userId': 20 + i, 'displayName': 'Kişi $i'}],
      'nextCursor': null
    })
    ..on('/communities/7/members*', {
      'items': [
        {'userId': 1, 'displayName': 'Elif Yıldız', 'role': 'OWNER'},
        {'userId': 2, 'displayName': 'Mert Kaya', 'role': 'MODERATOR'},
        {'userId': 3, 'displayName': 'Zeynep Arslan', 'role': 'MEMBER'},
        {'userId': 4, 'displayName': 'Ali Veli', 'role': 'MEMBER'},
      ],
      'nextCursor': null,
    })
    ..on('/communities/7/join-questions', [
      {'id': 1, 'question': 'Neden katılmak istiyorsun?'},
    ])
    ..on('/events*', {
      'items': [
        {'id': 5, 'title': 'Sonbahar fotoğraf yürüyüşü', 'startsAt': _iso(now.add(const Duration(days: 3, hours: 4))), 'location': 'Kale çevresi'},
        {'id': 6, 'title': 'Karanlık oda atölyesi', 'startsAt': _iso(now.add(const Duration(days: 12))), 'location': 'Sanat Merkezi, Salon 2'},
      ],
      'nextCursor': null,
    });
  final f = fakePolls(b, count: 0);
  f.polls
    ..add(samplePoll(id: 1, title: 'Dönem sonu sergisi hangi gün olsun?', communityId: 7, communityName: 'Fotoğraf Kulübü'))
    ..add(samplePoll(id: 2, title: 'Kulüp logosu oylaması', communityId: 7, communityName: 'Fotoğraf Kulübü', anonymous: true));
  return b;
}

FakeBackend _membersBe({bool empty = false}) => FakeBackend()
  ..on('/communities/7/members*', {
    'items': empty
        ? []
        : [
            {'userId': 1, 'displayName': 'Elif Yıldız', 'role': 'OWNER'},
            {'userId': 2, 'displayName': 'Mert Kaya', 'role': 'MODERATOR'},
            {'userId': 3, 'displayName': 'Zeynep Arslan', 'role': 'MEMBER'},
            {'userId': 4, 'displayName': _longName, 'role': 'MEMBER'},
            {'userId': 5, 'displayName': 'Ali Veli', 'role': 'ADMIN'},
            {'userId': 6, 'displayName': 'Selin Demir', 'role': 'MEMBER'},
          ],
    'nextCursor': null,
  });

FakeBackend _reqBe({bool empty = false}) => FakeBackend()
  ..on('/communities/7/requests*', {
    'items': empty
        ? []
        : [
            {
              'userId': 20,
              'displayName': 'Selin Demir',
              'answers': [
                {'question': 'Neden katılmak istiyorsun?', 'answer': 'Çekim tekniklerini öğrenmek ve gezilere katılmak istiyorum.'},
                {'question': 'Hangi ekipmanla çekiyorsun?', 'answer': 'Telefon ve eski bir analog kamera.'},
              ],
            },
            {'userId': 21, 'displayName': _longName, 'answers': []},
            {'userId': 22, 'displayName': 'Ali Veli'},
          ],
    'nextCursor': null,
  });

Future<void> _tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _tapTip(WidgetTester t, String tip) async {
  await t.tap(find.byTooltip(tip).first);
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> _menuThen(WidgetTester t, String item) async {
  await _tapTip(t, _l.clubOptions);
  await _tapText(t, item);
}

final _shots = <_Shot>[
  _Shot('01_detay_ziyaretci', (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Shot('02_detay_uye', (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Shot('03_detay_yonetici', (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Shot('04_detay_etkinlikler', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _tapText(t, _l.clubTabEvents)),
  _Shot('05_detay_uyeler', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _tapText(t, _l.clubTabMembers)),
  _Shot('06_detay_anketler', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _tapText(t, _l.clubTabPolls)),
  _Shot('07_detay_yukleniyor', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), slow: true),
  _Shot('08_detay_hata', (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Shot('09_detay_kapali', (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Shot('10_detay_gonderi_yok', (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Shot('11_detay_menu_yonetici', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _tapTip(t, _l.clubOptions)),
  _Shot('12_detay_silme_onayi', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _menuThen(t, _l.clubDeleteClub)),
  _Shot('13_detay_ayrilma_onayi', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _menuThen(t, _l.clubLeave)),
  _Shot('14_detay_sahip_ayrilamaz', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _menuThen(t, _l.clubLeave)),
  _Shot('15_detay_bekleyen_istek', (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Shot('16_detay_kaydirilmis', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) async {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -330));
    await t.pump(const Duration(milliseconds: 700));
  }),
  _Shot('17_detay_uzun_ad_kapaksiz', (b) => ClubDetailPage(session: makeSession(b), communityId: 7)),
  _Shot('18_detay_gonderi_menu', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _tapTip(t, _l.clubPostActions)),
  _Shot('19_detay_katilma_istegi', (b) => ClubDetailPage(session: makeSession(b), communityId: 7), after: (t) => _tapText(t, _l.clubSendJoinRequest)),
  _Shot('20_uyeler_dolu', (b) => ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER', clubName: 'Fotoğraf Kulübü', memberCount: 128)),
  _Shot('21_uyeler_bos', (b) => ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER', clubName: 'Fotoğraf Kulübü', memberCount: 0)),
  _Shot('22_uyeler_hata', (b) => ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER')),
  _Shot('23_uyeler_yukleniyor', (b) => ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER'), slow: true),
  _Shot('24_uyeler_menu', (b) => ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER', clubName: 'Fotoğraf Kulübü', memberCount: 128),
      after: (t) => _tapTip(t, _l.clubMgmtMemberActions)),
  _Shot('25_uyeler_cikar_onayi', (b) => ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER', clubName: 'Fotoğraf Kulübü', memberCount: 128),
      after: (t) async {
    await _tapTip(t, _l.clubMgmtMemberActions);
    await _tapText(t, _l.clubMgmtRemoveFromClub);
  }),
  _Shot('26_uyeler_arama_sonuc_yok', (b) => ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER', clubName: 'Fotoğraf Kulübü', memberCount: 128),
      after: (t) async {
    await t.enterText(find.byType(TextField).first, 'zzzz');
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('30_istekler_dolu', (b) => ClubRequestsPage(session: makeSession(b), communityId: 7)),
  _Shot('31_istekler_bos', (b) => ClubRequestsPage(session: makeSession(b), communityId: 7)),
  _Shot('32_istekler_hata', (b) => ClubRequestsPage(session: makeSession(b), communityId: 7)),
  _Shot('33_istekler_yukleniyor', (b) => ClubRequestsPage(session: makeSession(b), communityId: 7), slow: true),
  _Shot('40_anket_form', (b) => PollFormPage(session: makeSession(b), communityId: 7), height: 1500),
  _Shot('41_anket_form_ekran', (b) => PollFormPage(session: makeSession(b), communityId: 7)),
  _Shot('42_anket_form_hata', (b) => PollFormPage(session: makeSession(b), communityId: 7), after: (t) async {
    await t.tap(find.text(_l.pollPublish).first);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('43_anket_form_dolu', (b) => PollFormPage(session: makeSession(b), communityId: 7), height: 1500, after: (t) async {
    final f = find.byType(TextField);
    await t.enterText(f.at(0), 'Dönem sonu sergisi hangi gün olsun?');
    await t.enterText(f.at(1), 'Tarihi birlikte belirleyelim.');
    await t.enterText(f.at(2), 'Cuma');
    await t.enterText(f.at(3), 'Cumartesi');
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(_l.pollAddOption).first);
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('44_anket_form_puanlama', (b) => PollFormPage(session: makeSession(b), communityId: 7), after: (t) async {
    await t.tap(find.text(_l.pollTypeRating).first);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('45_anket_tarih_secici', (b) => PollFormPage(session: makeSession(b), communityId: 7), after: (t) async {
    await t.tap(find.text(_l.pollChange).first);
    await t.pump(const Duration(milliseconds: 700));
  }),
];

FakeBackend _backendFor(String f) {
  switch (f) {
    case '01_detay_ziyaretci':
    case '19_detay_katilma_istegi':
      return _be(status: 'NONE', role: null);
    case '02_detay_uye':
    case '18_detay_gonderi_menu':
      return _be(role: 'MEMBER');
    case '07_detay_yukleniyor':
      return _be();
    case '08_detay_hata':
      return FakeBackend()..fail('/communities/7');
    case '09_detay_kapali':
      return FakeBackend()..fail('/communities/7', status: 404, code: 'COMMUNITY_NOT_FOUND', message: 'x');
    case '10_detay_gonderi_yok':
      return _be(posts: false);
    case '13_detay_ayrilma_onayi':
      return _be(role: 'MEMBER');
    case '15_detay_bekleyen_istek':
      return _be(status: 'PENDING', role: null);
    case '17_detay_uzun_ad_kapaksiz':
      return _be(name: _longName, cover: false);
    case '21_uyeler_bos':
      return _membersBe(empty: true);
    case '22_uyeler_hata':
      return FakeBackend()..fail('/communities/7/members*');
    case '20_uyeler_dolu':
    case '23_uyeler_yukleniyor':
    case '24_uyeler_menu':
    case '25_uyeler_cikar_onayi':
    case '26_uyeler_arama_sonuc_yok':
      return _membersBe();
    case '30_istekler_dolu':
    case '33_istekler_yukleniyor':
      return _reqBe();
    case '31_istekler_bos':
      return _reqBe(empty: true);
    case '32_istekler_hata':
      return FakeBackend()..fail('/communities/7/requests*');
    default:
      if (f.startsWith('4')) return FakeBackend();
      return _be();
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
  _lang = Platform.environment['P11_LANG'] ?? 'tr';
  final only = (Platform.environment['P11_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P11_MODES'] ?? 'light,dark').split(',');
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
      testWidgets('p11 $name', skip: skip != null, (tester) async {
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
        await tester.pumpWidget(_app(s.build(b), v.dark, key, v.scale));
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
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
