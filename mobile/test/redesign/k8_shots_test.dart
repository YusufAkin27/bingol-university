@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/polls/poll_club_section.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/polls/poll_menu_card.dart';
import 'package:bu_kampus/features/polls/poll_models.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// K8 (Anketler: tasarim 31 ve 32) ekran goruntusu panosu. Varsayilan `flutter test` ile CALISMAZ.
///
/// Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/Toprak Çevik/bu-release/redesign/k8/uygulama' flutter test test/redesign/k8_shots_test.dart
/// Istege bagli: `K8_LANG=tr|en|ar`, `K8_DARK=1`, `K8_SCALE=1.3`, `K8_ONLY=31-01,32` (dosya adi oneki).
const _dpr = 2.0;

String _lang = 'tr';

Future<void> _loadFonts(bool arabic) async {
  await loadTestFonts();
  if (!arabic) return;
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
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: home,
    ),
  );
}

class _Shot {
  const _Shot(this.file, this.setup, this.build, {this.act, this.h = 844, this.pumpMs = 1200, this.drain = false});

  final String file;
  final void Function(FakeBackend b) setup;
  final Widget Function(FakeBackend b) build;
  final Future<void> Function(WidgetTester t)? act;
  final double h;
  final int pumpMs;
  final bool drain;
}

String _tr(String tr, String en, String ar) => switch (_lang) {
      'ar' => ar,
      'en' => en,
      _ => tr,
    };

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first);
  await t.pump(const Duration(milliseconds: 500));
}

// --- Veri -------------------------------------------------------------------------------------------------

String _in(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

Map<String, dynamic> _poll(
  int id,
  String title, {
  String type = 'SINGLE',
  String scope = 'GLOBAL',
  String? description,
  bool anonymous = false,
  bool closed = false,
  Duration left = const Duration(days: 2),
  List<int>? mine,
  int? myRating,
  int? maxChoices,
  List<String>? options,
  String showResults = 'ALWAYS',
  bool allowChangeVote = true,
  String state = 'OPEN',
  bool canVote = true,
  String? blocked,
  String? status,
}) {
  final p = samplePoll(
    id: id,
    title: title,
    type: type,
    anonymous: anonymous,
    closed: closed,
    communityId: scope == 'COMMUNITY' ? 5 : null,
    communityName: scope == 'COMMUNITY' ? 'Robotik Kulübü' : null,
    optionCount: options?.length ?? 4,
    myOptionIds: mine,
    myRating: myRating,
    maxChoices: maxChoices,
    showResults: showResults,
    allowChangeVote: allowChangeVote,
    state: state,
    canVote: canVote,
    voteBlockedReason: blocked,
    closesAt: closed ? _in(const Duration(days: -1)) : _in(left),
  );
  p['scope'] = scope;
  if (status != null) p['status'] = status;
  p['description'] = description;
  if (options != null && type != 'RATING') {
    p['options'] = [for (var i = 0; i < options.length; i++) {'id': id * 100 + i + 1, 'text': options[i], 'position': i + 1}];
  }
  return p;
}

FakePolls _fp(FakeBackend b, List<Map<String, dynamic>> polls, {Map<int, Map<int, int>> others = const {}}) {
  final f = fakePolls(b, count: 0);
  f.polls.addAll(polls);
  f.others.addAll(others);
  return f;
}

const _lorem1 = 'Sağlık Kültür ve Spor Daire Başkanlığı iş birliğiyle merkez kafeteryaya alternatif vejetaryen ve geleneksel menü seçenekleri eklenecek.';

List<Map<String, dynamic>> _openList() => [
      _poll(4, 'Yeni dönem yemek menüsü', type: 'MULTI', scope: 'MENU', description: _lorem1, anonymous: true, left: const Duration(days: 2, hours: 3), mine: [401]),
      _poll(3, 'Bahar Şenliği Sahne Sanatçısı Tercihi', type: 'RANKED', description: '2025 Bingöl Üniversitesi Bahar Şenlikleri ana sahnesinde görmek istediğiniz 3 sanatçıyı önceliklendirir.', anonymous: true, left: const Duration(days: 5, hours: 3)),
      _poll(2, 'Robotik Kulübü Atölye Günü Belirleme', scope: 'COMMUNITY', description: 'Mühendislik Fakültesi laboratuvarında yapılacak otonom araç çalışmaları için en uygun ortak saat dilimi.', left: const Duration(days: 1, hours: 3), mine: [201]),
      _poll(1, 'Kütüphane Çalışma Saatleri Değerlendirmesi', type: 'RATING', description: 'Vize haftası öncesi 7/24 açık kalacak blokların belirlenmesi ve gece çay-çorba ikramı saatinin belirlenmesi.', anonymous: true, left: const Duration(hours: 6, minutes: 30)),
    ];

const _openOthers = {
  4: {401: 20, 402: 12, 403: 9},
  3: {301: 150, 302: 100, 303: 40, 304: 27},
  2: {201: 20, 202: 7},
  1: {101: 5, 102: 8, 103: 22, 104: 60, 105: 89},
};

List<Map<String, dynamic>> _closedList() => [
      _poll(12, 'Kantin Çay & Kahve Fiyatlandırma Anketi', type: 'RATING', closed: true, anonymous: false)..['average'] = 2.4,
      _poll(11, 'Güz Dönemi Vize Çalışma Kampı Lokasyonu', scope: 'COMMUNITY', closed: true, options: ['Mühendislik D Blok', 'Kütüphane Zemin Kat', 'Öğrenci Kulüpleri Binası']),
      _poll(20, 'Yapay Zeka Çalıştayı Konu Başlığı', type: 'MULTI', scope: 'COMMUNITY', left: const Duration(days: 1, hours: 3), mine: [2001], options: ['Üretken yapay zeka', 'Görüntü işleme', 'Robotik']),
    ];

const _closedOthers = {
  12: {1201: 150, 1202: 90, 1203: 80, 1204: 60, 1205: 32},
  11: {1101: 80, 1102: 30, 1103: 18},
  20: {2001: 30, 2002: 20, 2003: 5},
};

Map<String, dynamic> _menuPoll({String type = 'SINGLE', int? maxChoices, bool anon = true, int? rating, List<int>? ids, String showResults = 'ALWAYS'}) => _poll(
      1,
      type == 'MULTI'
          ? 'Bahar şenliği konserinde hangi sanatçıları görmek istersiniz?'
          : type == 'RATING'
              ? 'Merkezi Kütüphane 7/24 çalışma salonu konforunu nasıl değerlendiriyorsunuz?'
              : type == 'RANKED'
                  ? 'Güz yarıyılında kampüste en çok hangi atölye açılsın?'
                  : 'Yeni dönem yemek menüsünde hangisi olsun?',
      type: type,
      anonymous: anon,
      maxChoices: maxChoices,
      showResults: showResults,
      mine: ids,
      myRating: rating,
      options: type == 'MULTI'
          ? ['Mor ve Ötesi', 'Madrigal', 'Yüzyüzeyken Konuşuruz', 'Adamlar']
          : type == 'RANKED'
              ? ['Yapay Zeka ve Veri Analitiği', 'Mobil Uygulama Geliştirme (Flutter)', '3D Modelleme ve İHA Tasarımı', 'Finansal Okuryazarlık ve Girişimcilik']
              : ['İskender & Yoğurt', 'Mantı & Mevsim Salata', 'Tavuklu Çökertme Kebabı', 'Karnıyarık & Şehriyeli Pilav'],
    );

final _shots = <_Shot>[
  // ---- 31: liste ----
  _Shot('31-01_liste_acik', (b) => _fp(b, _openList(), others: _openOthers), (b) => PollListPage(session: makeSession(b)), h: 910),
  _Shot('31-02a_liste_hata', (b) => b.fail('/polls*'), (b) => PollListPage(session: makeSession(b)), h: 420),
  _Shot('31-02b_bos_acik', (b) => _fp(b, []), (b) => PollListPage(session: makeSession(b)), h: 520),
  _Shot('31-02c_bos_katildiklarim', (b) => _fp(b, []), (b) => PollListPage(session: makeSession(b)), h: 520,
      act: (t) => _tapText(t, _tr('Katıldıklarım', 'Joined', 'شاركت فيها'))),
  _Shot('31-02d_bos_kapanan', (b) => _fp(b, []), (b) => PollListPage(session: makeSession(b)), h: 520,
      act: (t) => _tapText(t, _tr('Kapanan', 'Closed', 'المغلقة'))),
  _Shot('31-02e_kulup_bos', (b) => _fp(b, []), (b) => PollListPage(session: makeSession(b), communityId: 5, title: _tr('Kulüp anketleri', 'Club polls', 'استطلاعات النادي'), canCreate: true), h: 520),
  _Shot('31-03_liste_kapanan', (b) => _fp(b, _closedList(), others: _closedOthers), (b) => PollListPage(session: makeSession(b)), h: 884,
      act: (t) => _tapText(t, _tr('Kapanan', 'Closed', 'المغلقة'))),
  _Shot('31-0x_liste_yukleniyor', (b) {
    _fp(b, _openList(), others: _openOthers);
    b.delay = const Duration(seconds: 3);
  }, (b) => PollListPage(session: makeSession(b)), h: 844, pumpMs: 400, drain: true),
  // ---- 31: form ----
  _Shot('31-04_form_ust', (b) => _fp(b, []), (b) => PollFormPage(session: makeSession(b), communityId: 5), h: 1051, act: (t) async {
    await t.enterText(find.byType(TextField).first, 'Bahar Şenliği Konser Tarihi');
    await t.enterText(find.byType(TextField).at(1), 'Etkinlik için en uygun zamanı belirliyoruz.');
    await t.enterText(find.byType(TextField).at(2), 'Seçenek 1');
    await t.enterText(find.byType(TextField).at(3), 'Seçenek 2');
    await t.pump();
  }),
  _Shot('31-05_form_alt', (b) => _fp(b, []), (b) => PollFormPage(session: makeSession(b), communityId: 5), h: 1077, act: (t) async {
    await t.tap(find.text(_tr('Yayınla', 'Publish', 'نشر')).last);
    await t.pump(const Duration(milliseconds: 600));
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -2500));
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('31-06a_tarih', (b) => _fp(b, []), (b) => PollFormPage(session: makeSession(b), communityId: 5), h: 900, act: (t) async {
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(_tr('Değiştir', 'Change', 'تغيير')).first);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('31-06b_saat', (b) => _fp(b, []), (b) => PollFormPage(session: makeSession(b), communityId: 5), h: 900, act: (t) async {
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text(_tr('Değiştir', 'Change', 'تغيير')).first);
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text(_tr('Tamam', 'OK', 'حسنًا')).first);
    await t.pump(const Duration(milliseconds: 800));
  }),
  // ---- 32: detay ----
  _Shot('32-01_tek', (b) => _fp(b, [_menuPoll()], others: {1: {101: 120, 102: 90, 103: 80, 104: 52}}), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 917,
      act: (t) => _tapText(t, 'İskender & Yoğurt')),
  _Shot('32-02_coklu', (b) => _fp(b, [_menuPoll(type: 'MULTI', maxChoices: 2, showResults: 'AFTER_CLOSE')]),
      (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 884, act: (t) => _tapText(t, 'Madrigal')),
  _Shot('32-02b_coklu_uyari', (b) => _fp(b, [_menuPoll(type: 'MULTI', maxChoices: 2)]), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 884,
      act: (t) async {
    await _tapText(t, 'Madrigal');
    await _tapText(t, 'Adamlar');
    await _tapText(t, 'Mor ve Ötesi');
  }),
  _Shot('32-03_puan', (b) => _fp(b, [_menuPoll(type: 'RATING')], others: {1: {101: 5, 102: 8, 103: 22, 104: 60, 105: 89}}), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 1057,
      act: (t) async {
    await t.tap(find.bySemanticsLabel(RegExp(_tr('4 yıldız', '4 stars', '4'))).first);
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('32-04_sirali', (b) => _fp(b, [_menuPoll(type: 'RANKED')]), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 884, act: (t) async {
    await _tapText(t, 'Yapay Zeka ve Veri Analitiği');
    await _tapText(t, 'Mobil Uygulama Geliştirme (Flutter)');
    await _tapText(t, '3D Modelleme ve İHA Tasarımı');
  }),
  _Shot('32-05_kulup', (b) {
    _fp(b, [
      _poll(3, 'TEKNOFEST 2026 için hangi kategoriye odaklanalım?', scope: 'COMMUNITY', description: 'Atölye bütçesi ve takım dağılımı bu oylamaya göre şekillenecektir.', anonymous: true, left: const Duration(days: 1, hours: 3), allowChangeVote: false, showResults: 'AFTER_CLOSE', options: ['İnsansız Hava Araçları (İHA)', 'Otonom Kara Aracı (UGV)', 'Su Altı Sistemleri']),
      _poll(2, 'Yeni Kulüp Logosu Seçimi', scope: 'COMMUNITY', closed: true, options: ['Minimalist Çip Rozeti', 'Klasik Dişli', 'Yıldız']),
    ], others: {2: {201: 46, 202: 18, 203: 8}});
  }, (b) => Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(children: [const SizedBox(height: 16), PollClubSection(session: makeSession(b), communityId: 5, canCreate: true)])))),
      h: 941),
  _Shot('32-05b_kulup_bos', (b) => _fp(b, []), (b) => Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(children: [const SizedBox(height: 16), PollClubSection(session: makeSession(b), communityId: 5, canCreate: true)])))),
      h: 700),
  _Shot('32-06_degistir', (b) => _fp(b, [_menuPoll(ids: [101])], others: {1: {101: 120, 102: 90, 103: 80, 104: 52}}), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 884,
      act: (t) => _tapText(t, _tr('Oyu değiştir', 'Change vote', 'تغيير التصويت'))),
  _Shot('32-07_sonuc', (b) => _fp(b, [_menuPoll(ids: [101])], others: {1: {101: 14, 102: 9, 103: 6, 104: 3}}), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 1000),
  _Shot('32-08_hata', (b) => b.fail('/polls/1'), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 600),
  _Shot('32-09_yukleniyor', (b) {
    _fp(b, [_menuPoll()]);
    b.delay = const Duration(seconds: 3);
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 700, pumpMs: 400, drain: true),
];


const _soup = ['Mercimek çorbası', 'Ezogelin', 'Domates çorbası'];
Map<String, dynamic> _soupPoll({bool anon = true, bool closed = false, String showResults = 'ALWAYS', List<int>? mine, bool allowChange = true, String state = 'OPEN', bool canVote = true, String? blocked, String? status, String type = 'SINGLE'}) =>
    _poll(1, 'Yarın menüde hangi çorbayı görmek istersiniz?',
        type: type, anonymous: anon, closed: closed, showResults: showResults, mine: mine, allowChangeVote: allowChange, state: state, canVote: canVote, blocked: blocked, status: status, options: type == 'RATING' ? null : _soup);

Widget _menuHost(FakeBackend b) => Scaffold(body: Padding(padding: const EdgeInsets.fromLTRB(20, 80, 20, 0), child: PollMenuCard(session: makeSession(b))));

final _shots33 = <_Shot>[
  _Shot('33-01_sonuclar', (b) => _fp(b, [_soupPoll(mine: [101])], others: {1: {101: 57, 102: 39, 103: 29}}), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 893),
  _Shot('33-02_sonuclar_gizli', (b) => _fp(b, [_soupPoll(mine: [101], showResults: 'AFTER_CLOSE')]), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 844),
  _Shot('33-03_kapandi', (b) => _fp(b, [_soupPoll(closed: true, anon: false)], others: {1: {101: 87, 102: 28, 103: 13}}), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 911),
  _Shot('33-03b_kapandi_puan', (b) {
    final f = _fp(b, [_soupPoll(closed: true, anon: false, type: 'RATING')], others: {1: {101: 2, 102: 3, 103: 10, 104: 31, 105: 40}});
    f.polls[0]['average'] = 4.2;
    f.polls[0]['ratingCount'] = 86;
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 911),
  _Shot('33-04_acilmadi', (b) => _fp(b, [_soupPoll(state: 'SCHEDULED', canVote: false, blocked: 'NOT_OPEN', showResults: 'AFTER_CLOSE')]), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 844),
  _Shot('33-05a_yetki_yok', (b) => _fp(b, [_soupPoll(canVote: false, blocked: 'NOT_ELIGIBLE', showResults: 'AFTER_CLOSE')]), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 500),
  _Shot('33-05b_degistirilemez', (b) => _fp(b, [_soupPoll(mine: [101], allowChange: false, showResults: 'AFTER_CLOSE', canVote: false, blocked: 'ALREADY_VOTED')]), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 500),
  _Shot('33-05c_kapandi_oy_yok', (b) => _fp(b, [_soupPoll(status: 'CANCELLED', canVote: false, blocked: 'CLOSED', showResults: 'AFTER_CLOSE')]), (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 500),
  _Shot('33-06a_geri_cek', (b) {
    b.fail('/polls/1');
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1, initial: Poll.fromJson(_soupPoll(mine: [101]))), h: 844, act: (t) async {
    await _tapText(t, _tr('Oyu geri çek', 'Retract vote', 'سحب الصوت'));
  }),
  _Shot('33-06b_geri_cekildi', (b) {
    _fp(b, [_soupPoll(mine: [101])], others: {1: {101: 57, 102: 39, 103: 29}});
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1), h: 844, act: (t) async {
    await _tapText(t, _tr('Oyu geri çek', 'Retract vote', 'سحب الصوت'));
    await _tapText(t, _tr('Geri çek', 'Retract', 'سحب'));
  }),
  _Shot('15-menu-puan_bos', (b) {
    final f = _fp(b, []);
    f.menuPoll = samplePoll(id: 77, type: 'RATING', title: 'Menü', communityName: null, communityId: null);
  }, _menuHost, h: 420),
  _Shot('15-menu-puan_verilmis', (b) {
    final f = _fp(b, []);
    f.menuPoll = samplePoll(id: 77, type: 'RATING', title: 'Menü', communityName: null, communityId: null, myRating: 4);
  }, _menuHost, h: 420),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['K8_LANG'] ?? 'tr';
  final dark = Platform.environment['K8_DARK'] == '1';
  final scale = double.tryParse(Platform.environment['K8_SCALE'] ?? '') ?? 1.0;
  final only = (Platform.environment['K8_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final s in [..._shots, ..._shots33]) {
    if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
    final name = '${s.file}_$_lang${dark ? '_koyu' : ''}${scale != 1.0 ? '_x$scale' : ''}';
    testWidgets('k8 $name', skip: skip != null, (tester) async {
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = Size(390 * _dpr, s.h * _dpr);
      tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
      tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
      addTearDown(tester.view.reset);

      final b = FakeBackend();
      s.setup(b);
      final key = GlobalKey();
      await tester.pumpWidget(_app(s.build(b), dark, key, scale));
      await settle(tester, Duration(milliseconds: s.pumpMs));
      if (s.act != null) {
        await s.act!(tester);
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
      if (s.drain) await settle(tester, const Duration(seconds: 9));
      await unmount(tester);
    });
  }
}
