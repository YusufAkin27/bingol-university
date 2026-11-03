@Tags(['store-shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/support/support_attachments.dart';
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
import '../support/store_shots_images.dart';
import 'sup_fakes.dart';

/// Destek talepleri yeniden tasarımı ekran görüntüleri (390x844 / 320 dp, dpr 2).
///
/// Varsayılan `flutter test` ile ÇALIŞMAZ (ortam değişkeni yoksa atlanır). Üretim:
///   STORE_SHOTS_OUT='C:/bu_qa/shots/destek' flutter test test/redesign/sup_redesign_shots_test.dart
/// İsteğe bağlı: `SUP_LANG=tr|en|ar`, `SUP_ONLY=s01,s03`, `SUP_MODES=light,dark,x13`.
const _dpr = 2.0;
String _lang = 'tr';

Map<String, dynamic> _page(List<Object> items, {int? open, int? max}) => {
      'items': items,
      'nextCursor': null,
      if (open != null) 'openCount': open,
      if (max != null) 'maxOpen': max,
    };

String _ago(Duration d) => DateTime.now().subtract(d).toIso8601String();

Map<String, dynamic> _tk(int id, String subject, String status, String cat, Duration ago, {Map<String, dynamic>? last}) => {
      'id': id,
      'subject': subject,
      'status': status,
      'category': cat,
      'createdAt': _ago(ago + const Duration(hours: 5)),
      'updatedAt': _ago(ago),
      if (last != null) 'lastMessage': last,
    };

void _faq(FakeBackend b) => b.on('/faq', [
      {
        'category': 'Hesap',
        'items': [
          {'question': 'Şifremi nasıl değiştiririm?', 'answer': 'Profil ayarlarından şifre sıfırlama bağlantısı iste.'},
          {'question': 'Hesabımı nasıl silerim?', 'answer': 'Profil, Ayarlar, Hesabı sil.'},
        ],
      },
    ]);

void _tickets(FakeBackend b, {int open = 3, bool five = false}) {
  final list = <Object>[
    _tk(3812, 'Yemekhane puanı görünmüyor', 'ANSWERED', 'TECHNICAL', const Duration(hours: 2),
        last: {'text': 'Kayıtlar incelendi ve puan güncellemeniz yapıldı.', 'fromStaff': true}),
    _tk(3790, 'Kulüp listesinde eksiklik', 'OPEN', 'CONTENT', const Duration(days: 2), last: {'text': 'Listede Satranç Kulübü yok.', 'fromStaff': false}),
    _tk(3745, 'Giriş yaparken hata alıyorum', 'OPEN', 'ACCOUNT', const Duration(days: 5), last: {'text': '', 'attachmentCount': 2, 'fromStaff': false}),
    if (five) ...[
      _tk(3700, 'Bildirimler geç geliyor', 'OPEN', 'TECHNICAL', const Duration(days: 8)),
      _tk(3690, 'Profil fotoğrafı yüklenmiyor', 'OPEN', 'TECHNICAL', const Duration(days: 9)),
    ],
    _tk(3411, 'Derslik kodu güncellemesi', 'CLOSED', 'OTHER', const Duration(days: 40)),
  ];
  b.on('/support/tickets', _page(list, open: open, max: 5));
}

void _thread(FakeBackend b, {String status = 'ANSWERED'}) {
  b.on('/support/tickets/3812', {
    'ticket': {'id': 3812, 'subject': 'Yemekhane puanı görünmüyor', 'status': status, 'category': 'TECHNICAL', 'createdAt': _ago(const Duration(hours: 6)), 'updatedAt': _ago(const Duration(hours: 1))},
    'messages': [
      {
        'id': 1,
        'text': 'Dün öğle menüsünde puanım eksik görünüyor. Ekran görüntüleri ve kısa bir video ekledim.',
        'fromStaff': false,
        'createdAt': _ago(const Duration(hours: 6)),
        'attachments': [
          {'id': 11, 'kind': 'IMAGE', 'url': '/api/support/attachments/1', 'thumbUrl': '/api/support/attachments/1', 'width': 900, 'height': 1600},
          {'id': 12, 'kind': 'IMAGE', 'url': '/api/support/attachments/2', 'thumbUrl': '/api/support/attachments/2', 'width': 900, 'height': 1600},
          {'id': 13, 'kind': 'VIDEO', 'url': '/api/support/attachments/3', 'thumbUrl': '/api/support/attachments/3', 'durationMs': 14000},
        ],
      },
      {'id': 2, 'text': 'Merhaba, görüntüleri aldık. Hangi uygulama sürümünü kullanıyorsun?', 'fromStaff': true, 'createdAt': _ago(const Duration(hours: 3))},
      {'id': 3, 'text': '2.0.6 sürümü.', 'fromStaff': false, 'createdAt': _ago(const Duration(hours: 2, minutes: 30))},
      {'id': 4, 'text': 'Kayıtlar incelendi ve puan güncellemeniz yapıldı. Profilinizden kontrol edebilirsiniz.', 'fromStaff': true, 'createdAt': _ago(const Duration(hours: 1))},
    ],
  });
}

class _Scn {
  const _Scn(this.file, this.backend, this.page, {this.height = 844, this.pumpMs = 1200});
  final String file;
  final FakeBackend Function() backend;
  final Widget Function(FakeBackend b) page;
  final double height;
  final int pumpMs;
}

extension _Also on FakeBackend {
  void also(void Function(FakeBackend b) f) => f(this);
}

/// Taslak ekli denetleyici (gerçek seçici yok; sahte yükleyici). [mode]: 0 hazır, 1 üçüncü ek yükleniyor, 2 üçüncü ek başarısız.
Future<SupportAttachmentsController> _fill(WidgetTester t, int mode) async {
  final c = SupportAttachmentsController(
    uploader: mode == 0 ? FakeUploader() : _MixedUploader(failLast: mode == 2),
    videos: VideoService(compressor: FakeCompressor(durationMs: 27000, poster0: storeImageBytes(2))),
  );
  await t.runAsync(() async {
    await c.addImage(storeImageBytes(0));
    await c.addVideo(const PickedVideo('v.mp4'));
    unawaited(c.addImage(storeImageBytes(3)));
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  return c;
}

class _MixedUploader implements SupportAttachmentUploader {
  _MixedUploader({required this.failLast});
  final bool failLast;
  int n = 100;
  int images = 0;

  @override
  Future<SupportAttachment> uploadImage(image) async {
    images++;
    if (images >= 2) {
      if (failLast) throw StateError('x');
      await Completer<void>().future; // sonsuza dek yükleniyor
    }
    final id = n++;
    return SupportAttachment(id: id, kind: 'IMAGE', url: '/api/support/attachments/$id');
  }

  @override
  Future<SupportAttachment> uploadVideo(video, onProgress) async {
    onProgress(1);
    return SupportAttachment(id: n++, kind: 'VIDEO', url: '/api/support/attachments/9', durationMs: 27000);
  }
}

final _scns = <_Scn>[
  _Scn('s01_liste', () => FakeBackend()..also(_faq)..also((b) => _tickets(b)), (b) => SupportPage(session: makeSession(b)), height: 1500),
  _Scn('s01b_sinirda', () => FakeBackend()..also(_faq)..also((b) => _tickets(b, open: 5, five: true)), (b) => SupportPage(session: makeSession(b)), height: 1900),
  _Scn('s01c_bos', () => FakeBackend()..on('/faq', <Object>[])..on('/support/tickets', _page([], open: 0, max: 5)), (b) => SupportPage(session: makeSession(b))),
  _Scn('s01d_yukleniyor', () => FakeBackend()..also(_faq)..also((b) => _tickets(b))..delay = const Duration(seconds: 3), (b) => SupportPage(session: makeSession(b)), pumpMs: 300),
  _Scn('s02_yeni_talep', FakeBackend.new, (b) => NewTicketPage(session: makeSession(b)), height: 1250),
  _Scn('s03_yazisma', () => FakeBackend()..also(_thread), (b) => SupportTicketPage(session: makeSession(b), ticketId: 3812), height: 1000),
  _Scn('s03b_yazisma_kapali', () => FakeBackend()..also((b) => _thread(b, status: 'CLOSED')), (b) => SupportTicketPage(session: makeSession(b), ticketId: 3812), height: 1000),
  _Scn('s05_geri_bildirim', () => FakeBackend()..on('/feedback/mine', _page([])), (b) => FeedbackPage(session: makeSession(b)), height: 1100),
  _Scn('s06_oneriler', () => FakeBackend()..on('/suggestions', {
        'totalPages': 1,
        'items': [
          {'id': 1, 'subject': 'Kütüphane 24 saat açık olsun', 'message': 'Sınav dönemlerinde salonlar yetersiz kalıyor.', 'status': 'PLANNED', 'voteCount': 142, 'votedByMe': true},
          {'id': 2, 'subject': 'Ring sefer saatleri sıklaştırılsın', 'message': 'Sabah ve akşam saatlerinde yoğunluk var.', 'status': 'IN_REVIEW', 'voteCount': 86, 'votedByMe': false},
        ],
      }), (b) => SuggestionsPage(session: makeSession(b))),
];

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
  _lang = (Platform.environment['SUP_LANG'] ?? 'tr');
  final only = (Platform.environment['SUP_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['SUP_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double, double)>[
    if (modes.contains('light')) ('', false, 1.0, 390),
    if (modes.contains('dark')) ('_koyu', true, 1.0, 390),
    if (modes.contains('x13')) ('_x1.3_320', false, 1.3, 320),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    // Görsel çözümleme gerçek zaman ister (sahte saat ilerlemez): kısa bekle, sonra kareyi çiz.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await ro.toImage(pixelRatio: _dpr);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final dir = Directory(out!)..createSync(recursive: true);
      final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
      // ignore: avoid_print
      print('YAZILDI ${f.path} ${image.width}x${image.height}');
    });
  }

  for (final v in variants) {
    for (final sc in _scns) {
      if (only.isNotEmpty && !only.any((o) => sc.file.startsWith(o))) continue;
      final name = '${sc.file}${v.$1}_$_lang';
      testWidgets('sup $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(v.$4 * _dpr, sc.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
        tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final be = sc.backend();
        await tester.pumpWidget(_app(const Scaffold(body: SizedBox.expand()), v.$2, key, v.$3));
        unawaited(tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => sc.page(be))));
        await settle(tester, Duration(milliseconds: sc.pumpMs));
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await shot(tester, key, name);
        if (sc.pumpMs < 500) await tester.pump(const Duration(seconds: 6));
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }

    // Ekli yeni talep ve ekli yanıt alanı: hazır denetleyici gerektirdiği için ayrı kurulur.
    for (final withAtt in [('s02b_yeni_talep_ekli', 0), ('s02c_yeni_talep_yukleniyor', 1), ('s02d_yeni_talep_hata', 2), ('s04_yazisma_ekli_taslak', 3)]) {
      if (only.isNotEmpty && !only.any((o) => withAtt.$1.startsWith(o))) continue;
      final name = '${withAtt.$1}${v.$1}_$_lang';
      testWidgets('sup $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(v.$4 * _dpr, (withAtt.$2 == 3 ? 900 : 1350) * _dpr);
        tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
        tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final be = FakeBackend();
        final c = await _fill(tester, withAtt.$2 == 3 ? 0 : withAtt.$2);
        if (withAtt.$2 == 3) _thread(be);
        final page = withAtt.$2 == 3
            ? SupportTicketPage(session: makeSession(be), ticketId: 3812, attachments: c)
            : NewTicketPage(session: makeSession(be), attachments: c);
        await tester.pumpWidget(_app(const Scaffold(body: SizedBox.expand()), v.$2, key, v.$3));
        unawaited(tester.state<NavigatorState>(find.byType(Navigator)).push(MaterialPageRoute<void>(builder: (_) => page)));
        await settle(tester, const Duration(milliseconds: 1000));
        if (withAtt.$2 != 3) {
          await tester.enterText(find.byType(TextField).first, 'Bildirimler geç geliyor');
          await tester.enterText(find.byType(TextField).last, 'Son iki gündür bildirimler 10-15 dakika gecikmeyle geliyor. Ekran görüntülerini ekledim.');
          await tester.pump(const Duration(milliseconds: 300));
        } else {
          await tester.enterText(find.byType(TextField).last, 'Ekran görüntüsünü ekledim');
          await tester.pump(const Duration(milliseconds: 300));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await shot(tester, key, name);
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
