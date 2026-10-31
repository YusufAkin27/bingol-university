@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/polls/poll_menu_card.dart';
import 'package:bu_kampus/features/support/support_feedback_page.dart';
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

/// Paket 13 (Anketler ve Destek) ekran goruntusu panosu. Varsayilan `flutter test` ile CALISMAZ.
///
/// Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/Toprak Çevik/bu-release/redesign/p13/onceki' flutter test test/redesign/p13_shots_test.dart
/// Istege bagli: `P13_LANG=tr|en|ar`, `P13_DARK=1` (yalniz koyu), `P13_SCALE=1.3`, `P13_ONLY=01,05` (dosya adi oneki).
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
  const _Shot(this.file, this.setup, this.build, {this.act, this.pumpMs = 1200, this.drain = false});

  final String file;
  final void Function(FakeBackend b) setup;
  final Widget Function(FakeBackend b) build;
  final Future<void> Function(WidgetTester t)? act;
  final int pumpMs;

  /// Gecikmeli (yukleniyor) goruntu: cekimden sonra bekleyen zamanlayicilari bosalt.
  final bool drain;
}

Map<String, dynamic> _page(List<Object> items) => {'items': items, 'nextCursor': null};

// --- Anket verisi ----------------------------------------------------------------------------------------

FakePolls _polls(FakeBackend b, {List<Map<String, dynamic>> extra = const [], int count = 0}) {
  final f = fakePolls(b, count: count);
  f.polls.addAll(extra);
  return f;
}

List<Map<String, dynamic>> _listPolls() => [
      samplePoll(
          id: 1, title: 'Yeni dönem kulüp başkanı kim olsun?', communityId: 5, communityName: 'Robotik Kulübü', anonymous: true),
      samplePoll(id: 2, title: 'Kampüste en çok hangi etkinlik türünü istersiniz?', communityId: null, communityName: null, myOptionIds: [201]),
      samplePoll(id: 3, title: 'Bugünün öğle yemeğini puanlayın', type: 'RATING', communityId: null, communityName: null),
      samplePoll(id: 4, title: 'Kütüphane çalışma saatleri yeterli mi?', communityId: null, communityName: null, myOptionIds: [401], allowChangeVote: false),
      samplePoll(id: 9, title: 'Bahar şenliği konser seçimi', communityId: 6, communityName: 'Müzik Topluluğu', closed: true),
    ];

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first);
  await t.pump(const Duration(milliseconds: 500));
}

String _tr(String tr, String en, String ar) => switch (_lang) {
      'ar' => ar,
      'en' => en,
      _ => tr,
    };

// --- Destek verisi ----------------------------------------------------------------------------------------

void _faq(FakeBackend b) => b.on('/faq', [
      {
        'category': 'Hesap',
        'items': [
          {'question': 'Şifremi nasıl değiştiririm?', 'answer': 'Profil > Ayarlar > Güvenlik sayfasından mevcut şifrenizi girerek yeni şifre belirleyebilirsiniz.'},
          {'question': 'Hesabımı nasıl silerim?', 'answer': 'Ayarlar > Gizlilik ve veriler > Verilerim ve hesap bölümünden.'},
        ],
      },
      {
        'category': 'Yemek',
        'items': [
          {'question': 'Yemek listesi ne zaman güncellenir?', 'answer': 'Liste ayda bir, ayın son günü yayımlanır.'},
        ],
      },
    ]);

void _tickets(FakeBackend b) => b.on('/support/tickets', _page([
      {'id': 5, 'subject': 'Bildirimler gelmiyor', 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': '2026-10-27T10:00:00'},
      {'id': 6, 'subject': 'Giriş yapamıyorum, hata alıyorum ve ekranda bir uyarı görünüyor', 'status': 'OPEN', 'category': 'ACCOUNT', 'createdAt': '2026-10-28T09:00:00'},
      {'id': 7, 'subject': 'Yemek listesi eksik', 'status': 'CLOSED', 'category': 'CONTENT', 'createdAt': '2026-10-02T12:00:00'},
    ]));

void _ticketDetail(FakeBackend b, {String status = 'ANSWERED'}) => b.on('/support/tickets/5', {
      'ticket': {'id': 5, 'subject': 'Bildirimler gelmiyor', 'status': status, 'category': 'TECHNICAL', 'createdAt': '2026-10-27T10:00:00'},
      'messages': [
        {'id': 1, 'text': 'Merhaba, son iki gündür hiçbir bildirim almıyorum. Ayarlardan kontrol ettim ama açık görünüyor.', 'fromStaff': false, 'createdAt': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String()},
        {'id': 2, 'text': 'Merhaba, geri bildiriminiz için teşekkürler. Cihazınızda pil tasarrufu modunun uygulamayı kısıtlayıp kısıtlamadığını kontrol eder misiniz?', 'fromStaff': true, 'createdAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()},
        {'id': 3, 'text': 'Kontrol ettim, kısıtlama yoktu. Şimdi çalışıyor, teşekkürler!', 'fromStaff': false, 'createdAt': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String()},
      ],
    });

void _feedbackMine(FakeBackend b) => b.on('/feedback/mine', _page([
      {'id': 1, 'subject': 'Karanlık temada kontrast', 'message': 'Profil sayfasındaki bazı yazılar koyu temada okunmuyor.', 'category': 'BUG', 'status': 'IN_REVIEW', 'createdAt': '2026-10-20T10:00:00', 'adminResponse': 'Teşekkürler, düzeltme planlandı.'},
      {'id': 2, 'subject': 'Yemek puanlama', 'message': 'Yemekleri puanlayabilmek harika olmuş.', 'category': 'PRAISE', 'status': 'DONE', 'createdAt': '2026-10-10T10:00:00'},
    ]));

void _suggestions(FakeBackend b) => b.on('/suggestions', {
      'totalPages': 1,
      'items': [
        {'id': 1, 'subject': 'Alerjen bilgisi gösterilsin', 'message': 'Yemek listesinde her yemeğin altında alerjen bilgisi de yer alsın.', 'status': 'PLANNED', 'voteCount': 128, 'votedByMe': true, 'adminResponse': 'Bir sonraki sürümde ekleyeceğiz.'},
        {'id': 2, 'subject': 'Kütüphane doluluk oranı', 'message': 'Çalışma salonlarının anlık doluluk bilgisi uygulamada görünebilir mi?', 'status': 'IN_REVIEW', 'voteCount': 94, 'votedByMe': false},
        {'id': 3, 'subject': 'Ders programı widget\'ı', 'message': 'Ana ekrana eklenebilen küçük bir ders programı.', 'status': 'NEW', 'voteCount': 12, 'votedByMe': false},
      ],
    });

final _shots = <_Shot>[
  // ---- Anketler ----
  _Shot('01_anket_liste', (b) => _polls(b, extra: _listPolls()), (b) => PollListPage(session: makeSession(b))),
  _Shot('02_anket_liste_yukleniyor', (b) {
    _polls(b, extra: _listPolls());
    b.delay = const Duration(seconds: 3);
  }, (b) => PollListPage(session: makeSession(b)), pumpMs: 400, drain: true),
  _Shot('03_anket_liste_bos', (b) => _polls(b), (b) => PollListPage(session: makeSession(b))),
  _Shot('04_anket_liste_hata', (b) => b.fail('/polls*'), (b) => PollListPage(session: makeSession(b))),
  _Shot('05_anket_liste_kapanan', (b) => _polls(b, extra: _listPolls()), (b) => PollListPage(session: makeSession(b)),
      act: (t) => _tapText(t, _tr('Kapanan', 'Closed', 'المغلقة'))),
  _Shot('06_anket_detay_tek', (b) {
    final f = _polls(b, extra: [samplePoll(id: 1, title: 'Yeni dönem kulüp başkanı kim olsun?', optionCount: 4)]);
    f.polls[0]['description'] = 'Oylama 3 gün sürecek. Sonuçlar yalnızca oy verdikten sonra görünür.';
    f.polls[0]['options'] = [
      {'id': 101, 'text': 'Ayşe Yılmaz', 'position': 1},
      {'id': 102, 'text': 'Mehmet Kaya', 'position': 2},
      {'id': 103, 'text': 'Elif Demir', 'position': 3},
      {'id': 104, 'text': 'Boş bırakıyorum', 'position': 4},
    ];
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1),
      act: (t) async {
    await _tapText(t, 'Mehmet Kaya');
  }),
  _Shot('07_anket_detay_coklu', (b) {
    _polls(b, extra: [samplePoll(id: 1, title: 'Hangi etkinliklere katılmak istersiniz?', type: 'MULTI', maxChoices: 3, anonymous: true, optionCount: 5)]);
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1),
      act: (t) async {
    await _tapText(t, 'Seçenek 1');
    await _tapText(t, 'Seçenek 3');
  }),
  _Shot('08_anket_detay_puan', (b) {
    _polls(b, extra: [samplePoll(id: 1, title: 'Bugünün öğle yemeğini puanlayın', type: 'RATING', communityId: null, communityName: null, menuItems: ['Mercimek çorbası', 'Tavuk sote', 'Pilav', 'Ayran'])]);
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1),
      act: (t) async {
    await t.tap(find.bySemanticsLabel(RegExp('4')).first);
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('09_anket_detay_sirali', (b) {
    _polls(b, extra: [samplePoll(id: 1, title: 'Gezi için tercih sıranız', type: 'RANKED', optionCount: 4)]);
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1),
      act: (t) async {
    await _tapText(t, 'Seçenek 3');
    await _tapText(t, 'Seçenek 1');
  }),
  _Shot('10_anket_detay_sonuc', (b) {
    final f = _polls(b, extra: [samplePoll(id: 1, title: 'Yeni dönem kulüp başkanı kim olsun?', anonymous: true, optionCount: 4, myOptionIds: [102])]);
    f.polls[0]['options'] = [
      {'id': 101, 'text': 'Ayşe Yılmaz', 'position': 1},
      {'id': 102, 'text': 'Mehmet Kaya', 'position': 2},
      {'id': 103, 'text': 'Elif Demir', 'position': 3},
      {'id': 104, 'text': 'Boş bırakıyorum', 'position': 4},
    ];
    f.others[1] = {101: 14, 102: 9, 103: 4, 104: 1};
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1)),
  _Shot('11_anket_detay_puan_sonuc', (b) {
    final f = _polls(b, extra: [samplePoll(id: 1, title: 'Bugünün öğle yemeğini puanlayın', type: 'RATING', communityId: null, communityName: null, myRating: 4)]);
    f.others[1] = {101: 1, 102: 2, 103: 5, 104: 12, 105: 7};
    f.polls[0]['average'] = 4.0;
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1)),
  _Shot('12_anket_detay_kapali', (b) {
    final f = _polls(b, extra: [samplePoll(id: 1, title: 'Bahar şenliği konser seçimi', closed: true, optionCount: 3)]);
    f.others[1] = {101: 30, 102: 22, 103: 8};
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1)),
  _Shot('13_anket_detay_hata', (b) => b.fail('/polls/1'), (b) => PollDetailPage(session: makeSession(b), pollId: 1)),
  _Shot('14_anket_detay_yukleniyor', (b) {
    _polls(b, extra: [samplePoll(id: 1)]);
    b.delay = const Duration(seconds: 3);
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1), pumpMs: 400, drain: true),
  _Shot('15_anket_geri_cek_diyalog', (b) {
    _polls(b, extra: [samplePoll(id: 1, myOptionIds: [102])]);
  }, (b) => PollDetailPage(session: makeSession(b), pollId: 1),
      act: (t) => _tapText(t, _tr('Oyu geri çek', 'Retract vote', 'سحب التصويت'))),
  _Shot('16_yemek_puan_karti', (b) {
    final f = _polls(b);
    f.menuPoll = samplePoll(id: 77, type: 'RATING', title: 'Menü', communityName: null, communityId: null, menuItems: ['Mercimek çorbası', 'Tavuk sote', 'Pilav']);
  }, (b) => Scaffold(body: Padding(padding: const EdgeInsets.fromLTRB(20, 80, 20, 0), child: PollMenuCard(session: makeSession(b))))),
  _Shot('17_yemek_puan_karti_verilmis', (b) {
    final f = _polls(b);
    f.menuPoll = samplePoll(id: 77, type: 'RATING', title: 'Menü', communityName: null, communityId: null, myRating: 4, menuItems: ['Mercimek çorbası', 'Tavuk sote', 'Pilav']);
  }, (b) => Scaffold(body: Padding(padding: const EdgeInsets.fromLTRB(20, 80, 20, 0), child: PollMenuCard(session: makeSession(b))))),

  // ---- Destek ----
  _Shot('20_destek', (b) {
    _faq(b);
    _tickets(b);
  }, (b) => SupportPage(session: makeSession(b))),
  _Shot('21_destek_sss_acik', (b) {
    _faq(b);
    _tickets(b);
  }, (b) => SupportPage(session: makeSession(b)), act: (t) => _tapText(t, 'Şifremi nasıl değiştiririm?')),
  _Shot('22_destek_bos', (b) {
    b.on('/faq', <Object>[]);
    b.on('/support/tickets', _page([]));
  }, (b) => SupportPage(session: makeSession(b))),
  _Shot('23_destek_hata', (b) {
    b.fail('/faq');
    b.fail('/support/tickets');
  }, (b) => SupportPage(session: makeSession(b))),
  _Shot('24_destek_yukleniyor', (b) {
    _faq(b);
    _tickets(b);
    b.delay = const Duration(seconds: 3);
  }, (b) => SupportPage(session: makeSession(b)), pumpMs: 400, drain: true),
  _Shot('25_yeni_talep', (b) {}, (b) => NewTicketPage(session: makeSession(b))),
  _Shot('26_yeni_talep_dolu_hata', (b) {}, (b) => NewTicketPage(session: makeSession(b)), act: (t) async {
    await t.tap(find.text(_tr('Gönder', 'Send', 'إرسال')).last);
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('27_talep_detay', _ticketDetail, (b) => SupportTicketPage(session: makeSession(b), ticketId: 5)),
  _Shot('28_talep_kapali', (b) => _ticketDetail(b, status: 'CLOSED'), (b) => SupportTicketPage(session: makeSession(b), ticketId: 5)),
  _Shot('29_talep_hata', (b) => b.fail('/support/tickets/5'), (b) => SupportTicketPage(session: makeSession(b), ticketId: 5)),
  _Shot('30_talep_yukleniyor', (b) {
    _ticketDetail(b);
    b.delay = const Duration(seconds: 3);
  }, (b) => SupportTicketPage(session: makeSession(b), ticketId: 5), pumpMs: 400, drain: true),
  _Shot('31_talep_kapat_diyalog', _ticketDetail, (b) => SupportTicketPage(session: makeSession(b), ticketId: 5),
      act: (t) => _tapText(t, _tr('Talebi kapat', 'Close ticket', 'إغلاق الطلب'))),
  _Shot('32_geri_bildirim', _feedbackMine, (b) => FeedbackPage(session: makeSession(b))),
  _Shot('33_geri_bildirim_bos', (b) => b.on('/feedback/mine', _page([])), (b) => FeedbackPage(session: makeSession(b))),
  _Shot('34_geri_bildirim_hata', (b) => b.fail('/feedback/mine'), (b) => FeedbackPage(session: makeSession(b))),
  _Shot('35_oneriler', _suggestions, (b) => SuggestionsPage(session: makeSession(b))),
  _Shot('36_oneriler_bos', (b) => b.on('/suggestions', {'totalPages': 0, 'items': <Object>[]}), (b) => SuggestionsPage(session: makeSession(b))),
  _Shot('37_oneriler_hata', (b) => b.fail('/suggestions'), (b) => SuggestionsPage(session: makeSession(b))),
  _Shot('38_oneriler_yukleniyor', (b) {
    _suggestions(b);
    b.delay = const Duration(seconds: 3);
  }, (b) => SuggestionsPage(session: makeSession(b)), pumpMs: 400, drain: true),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['P13_LANG'] ?? 'tr';
  final dark = Platform.environment['P13_DARK'] == '1';
  final scale = double.tryParse(Platform.environment['P13_SCALE'] ?? '') ?? 1.0;
  final only = (Platform.environment['P13_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final s in _shots) {
    if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
    final name = '${s.file}_$_lang${dark ? '_koyu' : ''}${scale != 1.0 ? '_x$scale' : ''}';
    testWidgets('p13 $name', skip: skip != null, (tester) async {
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = const Size(390 * _dpr, 844 * _dpr);
      tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
      tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
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
