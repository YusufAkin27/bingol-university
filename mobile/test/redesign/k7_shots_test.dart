@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/clubs/club_categories.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:bu_kampus/features/clubs/club_members_page.dart';
import 'package:bu_kampus/features/clubs/club_requests_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// K7 (referans 27-30: kulup yonetimi, detay, sheet/diyaloglar, Kuluplerim) ekran goruntuleri: GERCEK ekranlar + sahte API.
/// Varsayilan `flutter test` ile CALISMAZ. Uretim (C:\bu_mobile, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/k7/uygulama' flutter test test/redesign/k7_shots_test.dart
/// Istege bagli: `K7_LANG=tr|en|ar`, `K7_ONLY=27_01,28_`, `K7_MODES=light,dark,x13`.
const _dpr = 2.0;
const _w = 390.0;
const _h = 844.0;

String _lang = 'tr';
AppLocalizations get _l => lookupAppLocalizations(Locale(_lang));

class _Shot {
  const _Shot(this.file, this.be, this.build, {this.after, this.slow = false, this.height = _h});
  final String file;
  final FakeBackend Function() be;
  final Widget Function(FakeBackend b) build;
  final Future<void> Function(WidgetTester t, FakeBackend b)? after;
  final bool slow;
  final double height;
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

const _desc =
    'Bingöl Üniversitesi bünyesinde otonom robotik projeleri geliştiren topluluk. Yeni üye alımları dönem başında onay süreciyle gerçekleşir.';

Map<String, dynamic> _club({
  String status = 'ACTIVE',
  String? role = 'MEMBER',
  String visibility = 'PUBLIC',
  String policy = 'OPEN',
  String name = 'Robotik Kulübü',
  String category = 'teknoloji',
}) =>
    {
      'id': 7,
      'name': name,
      'description': _desc,
      'category': category,
      'memberCount': 86,
      'visibility': visibility,
      'joinPolicy': policy,
      'myStatus': status,
      'myRole': role,
      'coverUrl': 'https://img.invalid/cover.jpg',
    };

const _cats = [
  {'key': 'teknoloji', 'name': 'Teknoloji', 'icon': 'tech', 'count': 3},
  {'key': 'spor', 'name': 'Spor', 'icon': 'sports', 'count': 2},
  {'key': 'sanat', 'name': 'Sanat', 'icon': 'art', 'count': 1},
];

FakeBackend _base() => FakeBackend()
  ..on('/communities/categories', _cats)
  ..on('/communities/7/join-questions', [
    {'id': 1, 'question': 'Neden katılmak istiyorsun?'},
    {'id': 2, 'question': 'Hangi bölümdesin?'},
  ]);

FakeBackend _detail({
  String status = 'ACTIVE',
  String? role = 'MEMBER',
  String visibility = 'PUBLIC',
  String policy = 'OPEN',
  int pending = 0,
}) {
  final now = DateTime.now();
  return _base()
    ..on('/communities/7', _club(status: status, role: role, visibility: visibility, policy: policy))
    ..on('/communities/7/posts*', {
      'items': [
        {
          'id': 1,
          'authorId': 5,
          'authorName': 'Robotik Kulübü',
          'text': 'Haftalık robotik atölye buluşması cuma günü',
          'imageUrl': 'https://img.invalid/p1.jpg',
          'pinned': true,
          'canDelete': true,
          'likeCount': 45,
          'liked': true,
          'createdAt': _iso(now.subtract(const Duration(hours: 20))),
        },
        {
          'id': 2,
          'authorId': 11,
          'authorName': 'Mert Yıldız',
          'text': 'Sensör kalibrasyon testleri tamamlandı bugün',
          'imageUrl': 'https://img.invalid/p2.jpg',
          'canDelete': false,
          'likeCount': 29,
          'createdAt': _iso(now.subtract(const Duration(hours: 3))),
        },
      ],
      'nextCursor': null,
    })
    ..on('/communities/7/requests*', {
      'items': [for (var i = 0; i < pending; i++) {'userId': 20 + i, 'displayName': 'Kişi $i'}],
      'nextCursor': null,
    })
    ..on('/communities/7/members*', {'items': _members, 'nextCursor': null})
    ..on('/events*', {'items': [], 'nextCursor': null});
}

const _members = [
  {'userId': 2, 'displayName': 'Yusuf Demir', 'role': 'OWNER', 'department': 'Bilgisayar Mühendisliği', 'classYear': 4},
  {'userId': 3, 'displayName': 'Zeynep Arslan', 'role': 'MODERATOR', 'department': 'Elektrik-Elektronik Müh.', 'classYear': 3},
  {'userId': 4, 'displayName': 'Barış Çelik', 'role': 'MODERATOR', 'department': 'Mekatronik Müh.', 'classYear': 2},
  {'userId': 5, 'displayName': 'Elif Şahin', 'role': 'MEMBER', 'department': 'Yazılım Mühendisliği', 'classYear': 1},
  {'userId': 6, 'displayName': 'Burak Yıldırım', 'role': 'MEMBER', 'department': 'Makine Mühendisliği', 'classYear': 3},
  {'userId': 7, 'displayName': 'Merve Kaya', 'role': 'MEMBER', 'department': 'Fizik Bölümü', 'classYear': 2},
  {'userId': 8, 'displayName': 'Arda Güneş', 'role': 'MEMBER', 'department': 'Bilgisayar Mühendisliği', 'classYear': 2},
];

FakeBackend _membersBe() => FakeBackend()..on('/communities/7/members*', {'items': _members, 'nextCursor': null});

FakeBackend _requestsBe({bool empty = false}) {
  final now = DateTime.now();
  return FakeBackend()
    ..on('/communities/7/requests*', {
      'items': empty
          ? []
          : [
              {
                'userId': 20,
                'displayName': 'Ahmet Kaan Demir',
                'department': 'Mekatronik Mühendisliği',
                'classYear': 2,
                'requestedAt': _iso(now.subtract(const Duration(minutes: 12))),
                'answers': [
                  {'question': 'Neden katılmak istiyorsun?', 'answer': 'Robotik ile ilgileniyorum, TEKNOFEST otonom araç takımında yazılım geliştirmek ve atölye çalışmalarına aktif katılmak istiyorum.'},
                  {'question': 'Daha önce deneyimin var mı?', 'answer': 'Arduino ve C++ ile orta seviye projeler yaptım.'},
                ],
              },
              {
                'userId': 21,
                'displayName': 'Selin Yılmaz',
                'department': 'Bilgisayar Mühendisliği',
                'classYear': 3,
                'requestedAt': _iso(now.subtract(const Duration(hours: 1))),
                'answers': [
                  {'question': 'Neden katılmak istiyorsun?', 'answer': 'Yapay zeka ve görüntü işleme ekibine katılmak istiyorum.'},
                ],
              },
              {
                'userId': 22,
                'displayName': 'Caner Bozkurt',
                'department': 'Elektrik-Elektronik Mühendisliği',
                'classYear': 1,
                'requestedAt': _iso(now.subtract(const Duration(days: 1))),
                'answers': [
                  {'question': 'Neden katılmak istiyorsun?', 'answer': 'Temel elektronik ve PCB tasarımını öğrenmek istiyorum.'},
                ],
              },
            ],
      'nextCursor': empty ? null : 55,
    })
    ..on('/communities/7/requests?include=answers&size=20&cursor=55', {
      'items': [
        {
          'userId': 23,
          'displayName': 'Deniz Aksoy',
          'department': 'Fizik Bölümü',
          'classYear': 2,
          'requestedAt': _iso(now.subtract(const Duration(days: 2))),
          'answers': [
            {'question': 'Neden katılmak istiyorsun?', 'answer': 'Sensör ve robot kolu projelerinde çalışmak istiyorum.'},
          ],
        },
      ],
      'nextCursor': null,
    });
}

FakeBackend _tabBe({bool mine = true, bool empty = false}) {
  Map<String, dynamic> c(int id, String name, String status, {String cat = 'teknoloji'}) =>
      {'id': id, 'name': name, 'category': cat, 'description': 'Kampüste $name etkinlikleri düzenler.', 'memberCount': 40 + id, 'myStatus': status, 'joinPolicy': 'OPEN'};
  final all = [c(7, 'Robotik Kulübü', mine ? 'ACTIVE' : 'NONE'), c(8, 'Doğa Sporları', 'NONE', cat: 'spor'), c(9, 'Tiyatro Kulübü', 'NONE', cat: 'sanat')];
  return FakeBackend()
    ..on('/communities/categories', _cats)
    ..on('/me/communities*', {'items': mine ? [all.first] : [], 'nextCursor': null})
    ..on('/communities*', {'items': empty ? [] : all, 'nextCursor': null});
}

FakeBackend _myClubs({bool empty = false}) {
  final now = DateTime.now();
  return FakeBackend()
    ..on('/me/communities*', {
      'items': empty
          ? []
          : [
              {'id': 7, 'name': 'Robotik Kulübü', 'myRole': 'OWNER', 'myStatus': 'ACTIVE', 'status': 'ACTIVE', 'memberCount': 86, 'category': 'teknoloji'},
              {'id': 8, 'name': 'Yapay Zeka ve Veri Topluluğu', 'myRole': 'OWNER', 'myStatus': 'ACTIVE', 'status': 'PENDING_REVIEW', 'memberCount': 1},
              {'id': 9, 'name': 'Doğa Sporları ve Dağcılık', 'myRole': 'MODERATOR', 'myStatus': 'ACTIVE', 'memberCount': 124},
              {'id': 10, 'name': 'Tiyatro Kulübü', 'myRole': 'MEMBER', 'myStatus': 'ACTIVE', 'memberCount': 95},
              {'id': 11, 'name': 'Edebiyat ve Münazara Kulübü', 'myRole': 'MEMBER', 'myStatus': 'ACTIVE', 'memberCount': 54},
              {'id': 12, 'name': 'Satranç ve Zeka Oyunları', 'myRole': null, 'myStatus': 'PENDING', 'requestedAt': _iso(now.subtract(const Duration(days: 3)))},
              {'id': 13, 'name': 'Havacılık ve SİHA Kulübü', 'myRole': null, 'myStatus': 'PENDING', 'requestedAt': _iso(now.subtract(const Duration(days: 1)))},
            ],
      'nextCursor': null,
    });
}

Future<void> _tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.tap(f);
  await settle(t, const Duration(milliseconds: 700));
}

Future<void> _tapTip(WidgetTester t, String tip) async {
  if (find.byTooltip(tip).evaluate().isEmpty) {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await settle(t, const Duration(milliseconds: 400));
  }
  await t.tap(find.byTooltip(tip).first);
  await settle(t, const Duration(milliseconds: 800));
}

Future<void> _menuThen(WidgetTester t, String item) async {
  await _tapTip(t, _l.clubOptions);
  await _tapText(t, item);
}

/// Sayfa bir rotaya itilir: geri oku (arka plandaki rota) gercek akistaki gibi gorunur.
class _Push extends StatefulWidget {
  const _Push(this.page);
  final Widget page;
  @override
  State<_Push> createState() => _PushState();
}

class _PushState extends State<_Push> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => widget.page));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

Widget _detailPage(FakeBackend b) => ClubDetailPage(session: makeSession(b), communityId: 7);
Widget _membersPage(FakeBackend b) =>
    ClubMembersPage(session: makeSession(b), communityId: 7, myRole: 'OWNER', clubName: 'Robotik Kulübü', memberCount: 86);

/// Referans 29-06: kulup kurulunca "onaya gonderildi" diyalogu (form -> POST -> PENDING_REVIEW).
class _CreateHost extends StatelessWidget {
  const _CreateHost(this.b);
  final FakeBackend b;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (c) => TextButton(onPressed: () => openCreateClub(c, makeSession(b)), child: const Text('open')),
          ),
        ),
      );
}

final _shots = <_Shot>[
  // ---- 27: kulup yonetimi
  _Shot('27_01_uyeler', _membersBe, _membersPage),
  _Shot('27_02a_uye_islemleri', _membersBe, _membersPage, after: (t, b) => _tapTip(t, _l.clubMgmtMemberActions)),
  _Shot('27_02b_cikar_onayi', _membersBe, _membersPage, after: (t, b) async {
    await _tapTip(t, _l.clubMgmtMemberActions);
    await _tapText(t, _l.clubMgmtRemoveFromClub);
  }),
  _Shot('27_02c_yasakla_onayi', _membersBe, _membersPage, after: (t, b) async {
    await _tapTip(t, _l.clubMgmtMemberActions);
    await _tapText(t, _l.clubMgmtBan);
  }),
  _Shot('27_03a_basvurular', _requestsBe, (b) => ClubRequestsPage(session: makeSession(b), communityId: 7), height: 1250),
  _Shot('27_03b_onaylaniyor', _requestsBe, (b) => ClubRequestsPage(session: makeSession(b), communityId: 7), height: 1100, after: (t, b) async {
    b.delay = const Duration(seconds: 30);
    await t.tap(find.text(_l.clubMgmtApprove).at(1));
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Shot('27_03c_daha_fazla', _requestsBe, (b) => ClubRequestsPage(session: makeSession(b), communityId: 7), height: 1500, after: (t, b) async {
    await t.ensureVisible(find.text(_l.clubMgmtMoreRequests));
    await t.tap(find.text(_l.clubMgmtMoreRequests));
    await settle(t, const Duration(milliseconds: 600));
  }),
  _Shot('27_04a_basvuru_bos', () => _requestsBe(empty: true), (b) => ClubRequestsPage(session: makeSession(b), communityId: 7)),
  _Shot('27_04b_arama_yok', _membersBe, _membersPage, after: (t, b) async {
    await t.enterText(find.byType(TextField).first, 'xyz999');
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Shot('27_04c_hata', () => FakeBackend()..fail('/communities/7/members*'), _membersPage),
  _Shot('27_05_kulup_kur', _base, (b) => ClubFormPage(session: makeSession(b)), height: 1750, after: (t, b) async {
    // referans: onayli katilim + iki soru
    await t.tap(find.text(_l.clubMgmtApprovalPolicy).first);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(_l.clubMgmtAddQuestion).first);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(_l.clubMgmtAddQuestion).first);
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('27_05b_kulup_kur_bos', _base, (b) => ClubFormPage(session: makeSession(b)), height: 1300),
  _Shot('27_06a_duzenle_hata', _editBe, _editPage, height: 1750, after: (t, b) async {
    await t.enterText(find.byType(TextField).first, 'Ro');
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(_l.clubMgmtSave).first);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('27_06b_duzenle_kategori_hata', () {
    final b = _editBe();
    b.handlers.add((req, path) => req.method == 'PATCH' && path == '/communities/7'
        ? const FakeResult.json({'code': 'COMMUNITY_CATEGORY_INVALID', 'message': ''}, status: 400)
        : null);
    return b;
  }, _editPage, height: 1750, after: (t, b) async {
    await t.tap(find.text(_l.clubMgmtSave).first);
    await t.pump(const Duration(milliseconds: 800));
  }),
  _Shot('27_06c_duzenle_kismi_kayit', () {
    final b = _editBe();
    b.handlers.add((req, path) => req.method == 'PUT' && path == '/communities/7/join-questions'
        ? const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500)
        : null);
    return b;
  }, _editPage, height: 1750, after: (t, b) async {
    await t.enterText(find.byType(TextField).at(2), 'Daha önce herhangi bir robotik yarışmasında yer aldın mı?');
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(_l.clubMgmtSave).first);
    await t.pump(const Duration(milliseconds: 900));
  }),

  // ---- 28: kulup detay durumlari
  _Shot('28_01_ziyaretci_onayli_ozel', () => _detail(status: 'NONE', role: null, visibility: 'PRIVATE', policy: 'APPROVAL'), _detailPage),
  _Shot('28_02_ziyaretci_acik', () => _detail(status: 'NONE', role: null), _detailPage),
  _Shot('28_03_bekleyen_istek', () => _detail(status: 'PENDING', role: null, visibility: 'PRIVATE', policy: 'APPROVAL'), _detailPage),
  _Shot('28_04_uye', () => _detail(), _detailPage),
  _Shot('28_05a_yonetici', () => _detail(role: 'OWNER', pending: 3), _detailPage),
  _Shot('28_05b_yonetici_menu', () => _detail(role: 'OWNER', pending: 3), _detailPage, after: (t, b) => _tapTip(t, _l.clubOptions)),
  _Shot('28_06_yasakli', () => _detail(status: 'BANNED', role: null, visibility: 'PRIVATE', policy: 'APPROVAL'), _detailPage),
  _Shot('28_07_kullanilamiyor', () => FakeBackend()..fail('/communities/7', status: 404, code: 'COMMUNITY_NOT_FOUND', message: 'x'), _detailPage),
  _Shot('28_08_yukleniyor', () => _detail(), _detailPage, slow: true),

  // ---- 29: sheet ve diyaloglar
  _Shot('29_01a_katilma_istegi', () => _detail(status: 'NONE', role: null, visibility: 'PRIVATE', policy: 'APPROVAL'), _detailPage,
      after: (t, b) => _tapText(t, _l.clubSendJoinRequest)),
  _Shot('29_01b_katilma_istegi_hata', () => _detail(status: 'NONE', role: null, visibility: 'PRIVATE', policy: 'APPROVAL'), _detailPage,
      after: (t, b) async {
    await _tapText(t, _l.clubSendJoinRequest);
    await t.enterText(find.byType(TextField).first, 'Yapay zeka ve robotik projelerinde yer almak istiyorum.');
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(_l.clubMgmtSendRequest).first);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('29_02_ayrilma_onayi', () => _detail(), _detailPage, after: (t, b) => _menuThen(t, _l.clubLeave)),
  _Shot('29_03_sahip_ayrilamaz', () => _detail(role: 'OWNER'), _detailPage, after: (t, b) => _menuThen(t, _l.clubLeave)),
  _Shot('29_04_kulup_sil', () => _detail(role: 'OWNER'), _detailPage, after: (t, b) => _menuThen(t, _l.clubDeleteClub)),
  _Shot('29_05_gonderi_islemleri', () => _detail(role: 'OWNER'), _detailPage, after: (t, b) => _tapTip(t, _l.clubPostActions)),
  _Shot('29_06_onaya_gonderildi', () {
    final b = _base();
    b.handlers.add((req, path) => req.method == 'POST' && path == '/communities'
        ? const FakeResult.json({'id': 9, 'status': 'PENDING_REVIEW'}, status: 202)
        : null);
    return b;
  }, (b) => _CreateHost(b), after: (t, b) async {
    await _tapText(t, 'open');
    await settle(t, const Duration(milliseconds: 600));
    await t.enterText(find.byType(TextField).first, 'Robotik Kulübü');
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(_l.clubMgmtCreateButton).first);
    await t.pump(const Duration(milliseconds: 900));
  }),

  // ---- 12: Kulupler sekmesi durumlari
  _Shot('12_01_kesfet_liste', _tabBe, (b) => ClubsTab(session: makeSession(b))),
  _Shot('12_04_kuluplerim_bos', () => _tabBe(mine: false), (b) => ClubsTab(session: makeSession(b)), after: (t, b) => _tapText(t, _l.clubMgmtTabMine)),
  _Shot('12_05_arama_sonuc_yok', () => _tabBe(empty: true), (b) => ClubsTab(session: makeSession(b)), after: (t, b) async {
    await _tapTip(t, _l.clubMgmtSearch);
    await t.enterText(find.byType(TextField).first, 'xyz');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await settle(t, const Duration(milliseconds: 700));
  }),
  _Shot('12_06_kuluplerim_liste', _tabBe, (b) => ClubsTab(session: makeSession(b)), after: (t, b) => _tapText(t, _l.clubMgmtTabMine)),

  // ---- 30: Kuluplerim
  _Shot('30_01_kuluplerim', _myClubs, (b) => MyClubsPage(session: makeSession(b)), height: 1050),
  _Shot('30_02_satir_secenekleri', _myClubs, (b) => MyClubsPage(session: makeSession(b)), after: (t, b) => _tapText(t, _l.profilePrefsManage)),
  _Shot('30_03a_bos', () => _myClubs(empty: true), (b) => MyClubsPage(session: makeSession(b))),
  _Shot('30_03b_hata', () => FakeBackend()..fail('/me/communities*'), (b) => MyClubsPage(session: makeSession(b))),
  _Shot('30_04_yukleniyor', _myClubs, (b) => MyClubsPage(session: makeSession(b)), slow: true),
];

FakeBackend _editBe() => _base()
  ..on('/communities/7', {..._club(role: 'OWNER', policy: 'APPROVAL', category: 'Yapay_Zeka_101'), 'description': 'Bingöl Üniversitesi Robotik ve Yapay Zeka meraklıları topluluğu.'})
  ..on('/communities/7/join-questions', [
    {'id': 1, 'question': 'Daha önce herhangi bir robotik yarışması veya yazılım projesinde yer aldınız mı?'},
  ]);

Widget _editPage(FakeBackend b) {
  final s = makeSession(b);
  return ClubFormPage(session: s, club: _club(role: 'OWNER', policy: 'APPROVAL', category: 'Yapay_Zeka_101'));
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
  _lang = Platform.environment['K7_LANG'] ?? 'tr';
  final only = (Platform.environment['K7_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K7_MODES'] ?? 'light').split(',');
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
      testWidgets('k7 $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        addTearDown(() => debugNetworkImageHttpClientProvider = null);
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_w * _dpr, s.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);
        ClubCategories.reset();

        final b = s.be();
        if (s.slow) b.delay = const Duration(seconds: 3);
        final key = GlobalKey();
        final built = s.build(b);
        await tester.pumpWidget(_app(built is _CreateHost ? built : _Push(built), v.dark, key, v.scale));
        await tester.pump(const Duration(milliseconds: 100));
        if (!s.slow) {
          await settle(tester, const Duration(milliseconds: 900));
          await _pumpImages(tester);
        }
        if (s.after != null) {
          await s.after!(tester, b);
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
        if (s.slow || b.delay > Duration.zero) await tester.pump(const Duration(seconds: 40));
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
