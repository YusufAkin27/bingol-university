@Tags(['store-shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// P68 Anketler + Destek Stitch v3 BIREBIR ekran goruntuleri (390x844, dpr 2).
///
/// Varsayilan `flutter test` ile CALISMAZ (ortam degiskeni yoksa atlanir). Uretim:
///   STORE_SHOTS_OUT='C:/bu_qa/shots/tasarim/pollsup' flutter test test/redesign/p68_anket_destek_shots_test.dart
/// Istege bagli: `P68_LANG=tr|en|ar`, `P68_ONLY=a01,d02`, `P68_MODES=light,dark,x13`.
const _dpr = 2.0;
String _lang = 'tr';

String _later(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

Map<String, dynamic> _poll(int id, String title, String scope, String type, Duration left, {List<String>? opts, List<int>? mine, bool anonymous = false, String showResults = 'ALWAYS'}) {
  final p = samplePoll(id: id, title: title, type: type, anonymous: anonymous, optionCount: opts?.length ?? 3, myOptionIds: mine, closesAt: _later(left), showResults: showResults);
  p['scope'] = scope;
  if (scope != 'COMMUNITY') {
    p['communityId'] = null;
    p['communityName'] = null;
  }
  if (opts != null) {
    p['options'] = [for (var i = 0; i < opts.length; i++) {'id': id * 100 + i + 1, 'text': opts[i], 'position': i + 1}];
  }
  return p;
}

const _menuOpts = ['Mevcut menü', 'Daha çok vejetaryen seçenek', 'Daha çok tatlı çeşidi', 'Kahvaltı eklensin'];

FakeBackend _listBe({bool fail = false, bool empty = false}) {
  final b = FakeBackend();
  if (fail) return b..fail('/polls*');
  final f = fakePolls(b, count: 0);
  if (!empty) {
    f.polls
        ..add(_poll(1, 'Kütüphane çalışma saatleri', 'GLOBAL', 'MULTI', const Duration(days: 1, hours: 3), opts: ['24 saat açık', 'Hafta sonu açık', 'Mevcut saatler'], mine: [101]))
      ..add(_poll(2, 'Kulüp başkanlığı seçimi', 'COMMUNITY', 'RANKED', const Duration(days: 5, hours: 3), opts: ['Ayşe', 'Mehmet', 'Elif']))
      ..add(_poll(3, 'Yeni dönem yemek menüsü', 'MENU', 'SINGLE', const Duration(days: 2, hours: 3), opts: _menuOpts));
    f.others[1] = {101: 100, 102: 40, 103: 15};
    f.others[2] = {201: 40, 202: 30, 203: 19};
    f.others[3] = {301: 20, 302: 12, 303: 6, 304: 4};
  }
  return b;
}

FakeBackend _voteBe({bool voted = false}) {
  final b = FakeBackend();
  final f = fakePolls(b, count: 0);
  f.polls.add(_poll(1, 'Yeni dönem yemek menüsü', 'MENU', 'SINGLE', const Duration(days: 2, hours: 3),
      opts: _menuOpts, anonymous: true, mine: voted ? [101] : null, showResults: 'AFTER_VOTE'));
  f.others[1] = {101: 13, 102: 9, 103: 4, 104: 2};
  return b;
}

FakeBackend _emptyForm() {
  final b = FakeBackend();
  fakePolls(b, count: 0);
  return b;
}

Map<String, dynamic> _page(List<Object> items) => {'items': items, 'nextCursor': null};

void _faq(FakeBackend b) => b.on('/faq', [
      {
        'category': 'Hesap',
        'items': [
          {
            'question': 'Şifremi nasıl değiştiririm?',
            'answer': 'Öğrenci işleri bilgi sistemine kayıtlı e-posta adresin üzerinden profil ayarlarından şifre sıfırlama bağlantısı talep edebilirsin.'
          },
          {'question': 'Hesabımı nasıl silerim?', 'answer': 'Profil > Ayarlar > Hesabı sil.'},
          {'question': 'Etkinliğe nasıl katılırım?', 'answer': 'Etkinlik sayfasındaki Katıl düğmesine dokun.'},
        ],
      },
    ]);

void _tickets(FakeBackend b) => b.on('/support/tickets', _page([
      {'id': 3812, 'subject': 'Yemekhane puanı görünmüyor', 'status': 'ANSWERED', 'category': 'ACCOUNT', 'createdAt': '2026-10-12T10:00:00'},
      {'id': 3790, 'subject': 'Kulüp listesinde eksiklik', 'status': 'OPEN', 'category': 'TECHNICAL', 'createdAt': '2026-10-10T10:00:00'},
      {'id': 3411, 'subject': 'Derslik kodu güncellemesi', 'status': 'CLOSED', 'category': 'ACCOUNT', 'createdAt': '2026-09-28T10:00:00'},
    ]));

void _thread(FakeBackend b) {
  final now = DateTime.now();
  String at(int h, int m) => DateTime(now.year, now.month, now.day, h, m).toIso8601String();
  b.on('/support/tickets/3812', {
    'ticket': {'id': 3812, 'subject': 'Yemekhane puanı görünmüyor', 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': at(14, 10)},
    'messages': [
      {'id': 1, 'text': 'Merhaba, yaşadığınız problem hangi günkü yemek puanında meydana geldi? Tarih ve menü bilgisini iletebilir misiniz?', 'fromStaff': true, 'createdAt': at(14, 15)},
      {'id': 2, 'text': 'Dün öğle menüsünde (11 Ekim) puanım sistemde eksik göründü, kontrol edebilir misiniz?', 'fromStaff': false, 'createdAt': at(14, 20)},
      {'id': 3, 'text': 'Kayıtlar incelendi ve puan güncellemeniz yapıldı. Profilinizden kontrol edebilirsiniz.', 'fromStaff': true, 'createdAt': at(14, 38)},
    ],
  });
}

Map<String, dynamic> _sug(int id, String subject, String message, String status, int votes, bool mine) => {
      'id': id,
      'subject': subject,
      'message': message,
      'status': status,
      'voteCount': votes,
      'votedByMe': mine,
      'createdAt': DateTime.now().subtract(Duration(days: id)).toIso8601String()
    };

void _suggestions(FakeBackend b) => b.on('/suggestions', {
      'totalPages': 1,
      'items': [
        _sug(1, 'Kütüphane 24 saat açık olsun', 'Sınav dönemlerinde çalışma salonları yetersiz kalıyor, merkezi kütüphanenin saatleri uzatılsın.', 'PLANNED', 142, true),
        _sug(2, 'Ring sefer saatleri sıklaştırılsın', 'Sabah 08:30 ve akşam 17:00 saatlerinde ring otobüslerinde aşırı yoğunluk yaşanıyor.', 'IN_REVIEW', 86, false),
        _sug(3, 'Kampüs içi bisiklet park alanları', 'Fakülte önlerindeki bisiklet kilit alanlarının sayısı artırılmalı ve üstü kapatılmalıdır.', 'IN_REVIEW', 54, false),
      ],
    });

class _Scn {
  const _Scn(this.file, this.backend, this.page, {this.height = 844, this.act, this.pumpMs = 1200});
  final String file;
  final FakeBackend Function() backend;
  final Widget Function(FakeBackend b) page;
  final double height;
  final Future<void> Function(WidgetTester t)? act;
  final int pumpMs;
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first);
  await settle(t, const Duration(milliseconds: 700));
}

final _scns = <_Scn>[
  _Scn('a01_liste', _listBe, (b) => PollListPage(session: makeSession(b))),
  _Scn('a01b_bos', () => _listBe(empty: true), (b) => PollListPage(session: makeSession(b))),
  _Scn('a01c_hata', () => _listBe(fail: true), (b) => PollListPage(session: makeSession(b))),
  _Scn('a01d_yukleniyor', () => _listBe()..delay = const Duration(seconds: 3), (b) => PollListPage(session: makeSession(b)), pumpMs: 300),
  _Scn('a02_oy_verme', () => _voteBe(), (b) => PollDetailPage(session: makeSession(b), pollId: 1), act: (t) => _tapText(t, 'Mevcut menü')),
  _Scn('a03_sonuclar', () => _voteBe(voted: true), (b) => PollDetailPage(session: makeSession(b), pollId: 1)),
  _Scn('a04_olustur', _emptyForm, (b) => PollFormPage(session: makeSession(b), communityId: 5), height: 1125, act: (t) async {
    await t.enterText(find.byType(TextField).at(0), 'Final haftası kütüphane saatleri uzatılsın');
    await t.enterText(find.byType(TextField).at(1), 'Anketin amacı ve detaylarını belirtebilirsiniz...');
    await t.enterText(find.byType(TextField).at(2), 'Evet, 24 saat açık kalmalı');
    await t.enterText(find.byType(TextField).at(3), 'Mevcut saatler yeterli');
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Scn('a04b_olustur_hata', _emptyForm, (b) => PollFormPage(session: makeSession(b), communityId: 5), height: 1125, act: (t) async {
    await t.enterText(find.byType(TextField).at(0), 'Final haftası kütüphane saatleri uzatılsın');
    await t.enterText(find.byType(TextField).at(2), 'Evet, 24 saat açık kalmalı');
    final btn = find.text(_lang == 'tr' ? 'Yayınla' : (_lang == 'ar' ? 'نشر' : 'Publish'));
    await t.scrollUntilVisible(btn, 300, scrollable: find.byType(Scrollable).first);
    await t.tap(btn);
    await settle(t, const Duration(milliseconds: 700));
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, 900));
    await settle(t, const Duration(milliseconds: 300));
  }),
  _Scn('d01_ana', () => FakeBackend()..also(_faq)..also(_tickets), (b) => SupportPage(session: makeSession(b)), act: (t) => _tapText(t, 'Şifremi nasıl değiştiririm?')),
  _Scn('d02_yazisma', () => FakeBackend()..also(_thread), (b) => SupportTicketPage(session: makeSession(b), ticketId: 3812)),
  _Scn('d03_yeni_talep', FakeBackend.new, (b) => NewTicketPage(session: makeSession(b))),
  _Scn('d03b_yeni_talep_hata', FakeBackend.new, (b) => NewTicketPage(session: makeSession(b)), act: (t) async {
    await t.enterText(find.byType(TextField).first, 'De');
    await t.pump();
    final btn = find.text(_lang == 'tr' ? 'Gönder' : (_lang == 'ar' ? 'إرسال' : 'Send')).last;
    await t.ensureVisible(btn);
    await t.tap(btn);
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Scn('d04a_bos', () => FakeBackend()..on('/faq', <Object>[])..on('/support/tickets', _page([])), (b) => SupportPage(session: makeSession(b))),
  _Scn('d04b_hata', () => FakeBackend()..also(_faq)..on('/support/tickets', {'code': 'X', 'message': 'x'}, status: 500), (b) => SupportPage(session: makeSession(b))),
  _Scn('d04c_yukleniyor', () => FakeBackend()..also(_faq)..also(_tickets)..delay = const Duration(seconds: 3), (b) => SupportPage(session: makeSession(b)), pumpMs: 300),
  _Scn('d05_oneriler', () => FakeBackend()..also(_suggestions), (b) => SuggestionsPage(session: makeSession(b))),
  _Scn('d05b_bos', () => FakeBackend()..on('/suggestions', {'totalPages': 0, 'items': <Object>[]}), (b) => SuggestionsPage(session: makeSession(b))),
];

extension _Also on FakeBackend {
  void also(void Function(FakeBackend b) f) => f(this);
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

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = (Platform.environment['P68_LANG'] ?? 'tr');
  final only = (Platform.environment['P68_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['P68_MODES'] ?? 'light').split(',');
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
      testWidgets('p68 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(v.$4 * _dpr, sc.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
        tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        // Gercek akis: sayfa bir rotadan itilir (ust cubukta geri oku gorunur).
        final be = sc.backend();
        await tester.pumpWidget(_app(const Scaffold(body: SizedBox.expand()), v.$2, key, v.$3));
        unawaited(tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => sc.page(be))));
        await settle(tester, Duration(milliseconds: sc.pumpMs));
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
        if (sc.pumpMs < 500) await tester.pump(const Duration(seconds: 6));
        await unmount(tester);
      });
    }
  }
}
