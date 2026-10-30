@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/widgets/bu.dart' show LucideIcons;
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// K8 Destek (tasarim 34) ekran goruntusu panosu. Varsayilan `flutter test` ile CALISMAZ.
///
/// Uretim (C:\bu_mobile icinde, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/Toprak Çevik/bu-release/redesign/k8/destek/uygulama' flutter test test/redesign/k8_support_shots_test.dart
/// Istege bagli: `K8_LANG=tr|en|ar`, `K8_DARK=1`, `K8_SCALE=1.3`, `K8_ONLY=34-01,34-04` (dosya adi oneki).
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
  const _Shot(this.file, this.setup, this.build, {this.act, this.h = 844, this.pumpMs = 1200});

  final String file;
  final void Function(FakeBackend b) setup;
  final Widget Function(FakeBackend b) build;
  final Future<void> Function(WidgetTester t)? act;
  final double h;
  final int pumpMs;
}

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first);
  await t.pump(const Duration(milliseconds: 500));
}

void _faq(FakeBackend b) => b.on('/faq', [
      {
        'category': 'Hesap',
        'items': [
          {'question': 'Şifremi unuttum, ne yapmalıyım?', 'answer': 'Öğrenci işleri bilgi sistemindeki kayıtlı e-postanız üzerinden şifre sıfırlama bağlantısı talep edebilirsiniz.\nBağlantı aracılığıyla birkaç adımda yeni şifrenizi belirleyebilirsiniz.'},
        ],
      },
      {
        'category': 'Teknik',
        'items': [
          {'question': 'Kulüp etkinliklerine nasıl katılırım?', 'answer': 'Etkinlik sayfasından katıl düğmesine dokunun.'},
        ],
      },
      {
        'category': 'İçerik',
        'items': [
          {'question': 'Yemekhane menüsü ne zaman güncellenir?', 'answer': 'Liste ayda bir, ayın son günü yayımlanır.'},
        ],
      },
      {'category': 'Diğer', 'items': <Object>[]},
    ]);

Map<String, dynamic> _page(List<Object> items) => {'items': items, 'nextCursor': null};

void _tickets(FakeBackend b) => b.on('/support/tickets', _page([
      {'id': 5, 'subject': 'Giriş yaparken hata alıyorum', 'status': 'OPEN', 'category': 'ACCOUNT', 'createdAt': '2026-05-14T10:45:00'},
      {'id': 6, 'subject': 'Mühendislik Kulübü etkinliği için kayıt olamıyorum', 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': '2026-05-12T10:00:00'},
      {'id': 7, 'subject': 'Profil bilgisi güncelleme', 'status': 'CLOSED', 'category': 'ACCOUNT', 'createdAt': '2026-04-28T12:00:00'},
    ]));

void _thread(FakeBackend b, {String status = 'OPEN'}) => b.on('/support/tickets/5', {
      'ticket': {'id': 5, 'subject': 'Giriş yaparken hata alıyorum', 'status': status, 'category': 'TECHNICAL', 'createdAt': '2026-05-14T14:30:00'},
      'messages': [
        {'id': 1, 'text': 'Merhaba, kampüste uygulamaya giriş yapmaya çalışırken yetkilendirme uyarısı alıyorum.', 'fromStaff': false, 'createdAt': '2026-05-14T10:45:00'},
        {'id': 2, 'text': 'Sorun sunucu taraflı önbellek temizliği ile çözülmüştür. Tekrar kontrol edebilir misiniz?', 'fromStaff': true, 'createdAt': '2026-05-14T11:15:00'},
        {'id': 3, 'text': 'Şimdi sorunsuz giriş yapabildim, teşekkür ederim.', 'fromStaff': false, 'createdAt': '2026-05-14T11:22:00'},
      ],
    });

final _shots = <_Shot>[
  _Shot('34-01_ana', (b) {
    _faq(b);
    _tickets(b);
  }, (b) => SupportPage(session: makeSession(b)), h: 1190, act: (t) => _tapText(t, 'Şifremi unuttum, ne yapmalıyım?')),
  _Shot('34-02a_hiz_siniri_hata', (b) {
    b.on('/faq', <Object>[]);
    b.on('/support/tickets', {'code': 'RATE_LIMITED', 'message': ''}, status: 429);
  }, (b) => SupportPage(session: makeSession(b)), h: 844),
  _Shot('34-02b_bos', (b) {
    b.on('/faq', <Object>[]);
    b.on('/support/tickets', _page([]));
  }, (b) => SupportPage(session: makeSession(b)), h: 844),
  _Shot('34-02c_eslesme_yok', (b) {
    _faq(b);
    _tickets(b);
  }, (b) => SupportPage(session: makeSession(b)), h: 844, act: (t) async {
    await t.enterText(find.byType(TextField).first, 'zzzz');
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('34-03_form', (b) {}, (b) => NewTicketPage(session: makeSession(b)), h: 844, act: (t) async {
    await t.tap(find.text(_lang == 'tr' ? 'Gönder' : (_lang == 'ar' ? 'إرسال' : 'Send')).last);
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('34-04_talep_acik', (b) => _thread(b), (b) => SupportTicketPage(session: makeSession(b), ticketId: 5), h: 844),
  _Shot('34-05_talep_kapali', (b) => _thread(b, status: 'CLOSED'), (b) => SupportTicketPage(session: makeSession(b), ticketId: 5), h: 844),
  _Shot('34-06_kapat_diyalog', (b) => _thread(b), (b) => SupportTicketPage(session: makeSession(b), ticketId: 5), h: 844, act: (t) async {
    await t.tap(find.byType(PopupMenuButton<String>));
    await settle(t, const Duration(milliseconds: 900));
    await t.tap(find.descendant(of: find.byType(PopupMenuItem<String>), matching: find.byIcon(LucideIcons.lock)).first, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 600));
  }),
  _Shot('34-07_menu_acik', (b) => _thread(b), (b) => SupportTicketPage(session: makeSession(b), ticketId: 5), h: 844, act: (t) async {
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('34-08_yukleniyor', (b) {
    _faq(b);
    _tickets(b);
    b.delay = const Duration(seconds: 3);
  }, (b) => SupportPage(session: makeSession(b)), h: 844, pumpMs: 400),
];

Map<String, dynamic> _sug(int id, String subject, String message, String status, int votes, bool mine, String when) =>
    {'id': id, 'subject': subject, 'message': message, 'status': status, 'voteCount': votes, 'votedByMe': mine, 'createdAt': when};

void _suggestions(FakeBackend b) => b.on('/suggestions', {
      'totalPages': 1,
      'items': [
        _sug(1, 'Kütüphane sessiz çalışma katına ek priz ve uzatma kablosu konulması', 'Final haftalarında 3. kat kütüphanede yer bulsak bile priz sayısı yetersiz kalıyor, masalara priz eklensin.', 'PLANNED', 128, true,
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String()),
        _sug(2, 'Yemekhane turnike geçişlerinde öğrenci kimlik barkodunun mobil ekranda gösterilmesi', 'Fiziksel kartı unutan öğrenciler için uygulama içi tek kullanımlık geçiş kodu sağlansın.', 'IN_REVIEW', 94, false,
            DateTime.now().subtract(const Duration(days: 4)).toIso8601String()),
        _sug(3, 'Kampüs içi bisiklet park alanlarının üstünün kapatılması', 'Kışın yağışta bisikletler paslanıyor, merkezi duraklara sundurma yapılsın.', 'NEW', 67, false,
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String()),
      ],
    });

final _shots35 = <_Shot>[
  _Shot('35-01_form', (b) => b.on('/feedback/mine', _page([])), (b) => FeedbackPage(session: makeSession(b)), h: 560, act: (t) async {
    await t.enterText(find.byType(TextField).first, 'Kısaca özetle');
    await t.pump();
  }),
  _Shot('35-02_gonderilenler', (b) => b.on('/feedback/mine', {
        'items': [
          {'id': 1, 'subject': 'Yemekhane menüsü için kalori ve alerjen detayı eklensin', 'message': 'x', 'category': 'SUGGESTION', 'status': 'NEW', 'createdAt': '2026-10-28T10:45:00'},
          {'id': 2, 'subject': 'Ders programı çakışma uyarısı ekranında kaydırma takılıyor', 'message': 'x', 'category': 'BUG', 'status': 'IN_REVIEW', 'createdAt': '2026-10-14T10:00:00'},
          {'id': 3, 'subject': 'Merkezi Kütüphane grup çalışma odası rezervasyon hatırlatması', 'message': 'x', 'category': 'SUGGESTION', 'status': 'PLANNED', 'createdAt': '2026-10-02T10:00:00'},
          {'id': 4, 'subject': 'Kulüp etkinlik takvimi entegrasyonu harika olmuş', 'message': 'x', 'category': 'PRAISE', 'status': 'DONE', 'createdAt': '2026-09-28T10:00:00'},
          {'id': 5, 'subject': 'Ring sefer saatleri güncellemesi', 'message': 'x', 'category': 'COMPLAINT', 'status': 'REJECTED', 'createdAt': '2026-09-15T10:00:00'},
        ],
        'nextCursor': 9,
      }), (b) => FeedbackPage(session: makeSession(b)), h: 1500),
  _Shot('35-02b_bos', (b) => b.on('/feedback/mine', _page([])), (b) => FeedbackPage(session: makeSession(b)), h: 844),
  _Shot('35-03_pano', _suggestions, (b) => SuggestionsPage(session: makeSession(b)), h: 900),
  _Shot('35-04a_bos', (b) => b.on('/suggestions', {'totalPages': 0, 'items': <Object>[]}), (b) => SuggestionsPage(session: makeSession(b)), h: 520),
  _Shot('35-04b_hata', (b) => b.fail('/suggestions'), (b) => SuggestionsPage(session: makeSession(b)), h: 520),
  _Shot('35-05_detay', _suggestions, (b) => SuggestionsPage(session: makeSession(b)), h: 700, act: (t) async {
    await t.tap(find.textContaining('Kütüphane sessiz').first);
    await t.pump(const Duration(milliseconds: 700));
  }),
];

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['K8_LANG'] ?? 'tr';
  final dark = Platform.environment['K8_DARK'] == '1';
  final scale = double.tryParse(Platform.environment['K8_SCALE'] ?? '') ?? 1.0;
  final only = (Platform.environment['K8_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final s in [..._shots, ..._shots35]) {
    if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
    final name = '${s.file}_$_lang${dark ? '_koyu' : ''}${scale != 1.0 ? '_x$scale' : ''}';
    testWidgets('k8 destek $name', skip: skip != null, (tester) async {
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
      await settle(tester, const Duration(seconds: 9));
      await unmount(tester);
    });
  }
}
