import 'dart:async';
import 'dart:typed_data';

import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/features/chat/chat_media_viewer.dart';
import 'package:bu_kampus/features/support/support_attachments.dart';
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:bu_kampus/features/support/support_list_widgets.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';
import 'p10_images.dart';
import 'sup_fakes.dart';

/// Destek ekleri + talep listesi (açık talep sınırı, okunmamış yanıt, önizleme) + yeni talep + talep yazışması.

typedef _FakeUploader = FakeUploader;

SupportAttachmentsController _ctl(_FakeUploader up, {int durationMs = 20000, int videoBytes = 3 * 1024 * 1024}) => SupportAttachmentsController(
      uploader: up,
      videos: VideoService(compressor: FakeCompressor(durationMs: durationMs, sizeBytes: videoBytes)),
    );


Map<String, dynamic> _page(List<Object> items, {int? open, int? max}) => {
      'items': items,
      'nextCursor': null,
      if (open != null) 'openCount': open,
      if (max != null) 'maxOpen': max,
    };

String _now() => DateTime.now().toIso8601String();

Map<String, dynamic> _tk(int id, String subject, String status, {String? cat, String? at, Map<String, dynamic>? last}) => {
      'id': id,
      'subject': subject,
      'status': status,
      'category': cat ?? 'TECHNICAL',
      'createdAt': at ?? '2026-10-10T10:00:00',
      'updatedAt': at ?? '2026-10-10T10:00:00',
      if (last != null) 'lastMessage': last,
    };

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => SupportSeenStore.memory = null);

  group('ek denetleyici: istemci sinirlari', () {
    test('gecerli gorsel yuklenir; kimlik ready olunca listelenir', () async {
      final up = _FakeUploader();
      final c = _ctl(up);
      expect(await c.addImage(p10Photo(0)), isNull);
      expect(c.items.single.state, SupportDraftState.ready);
      expect(c.ids, [100]);
      expect(c.hasPending, isFalse);
    });

    test('gorsel > 8 MB ve desteklenmeyen tur yuklemeden reddedilir', () async {
      final up = _FakeUploader();
      final c = _ctl(up);
      final big = Uint8List(kSupportImageMaxBytes + 1)..setAll(0, [0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);
      expect(await c.addImage(big), SupportAttachError.imageSize);
      expect(await c.addImage(Uint8List.fromList(List.filled(64, 7))), SupportAttachError.type);
      expect(await c.addImage(Uint8List(0)), SupportAttachError.type);
      expect(c.items, isEmpty);
      expect(up.log, isEmpty);
    });

    test('en cok 4 ek, en cok 1 video', () async {
      final up = _FakeUploader();
      final c = _ctl(up);
      expect(await c.addVideo(const PickedVideo('a.mp4')), isNull);
      expect(await c.addVideo(const PickedVideo('b.mp4')), SupportAttachError.oneVideo);
      for (var i = 0; i < 3; i++) {
        expect(await c.addImage(p10Photo(i)), isNull);
      }
      expect(c.items.length, 4);
      expect(await c.addImage(p10Photo(5)), SupportAttachError.limit);
      expect(c.precheck(video: false), SupportAttachError.limit);
      expect(c.ids.length, 4);
    });

    test('video > 60 sn ve > 50 MB reddedilir; uygun video poster + sure ile hazir olur', () async {
      final up = _FakeUploader();
      expect(await _ctl(up, durationMs: 61 * 1000).addVideo(const PickedVideo('a.mp4')), SupportAttachError.videoLong);
      expect(await _ctl(up, videoBytes: kSupportVideoMaxBytes + 1).addVideo(const PickedVideo('a.mp4')), SupportAttachError.videoSize);
      final c = _ctl(up, durationMs: 42000);
      expect(await c.addVideo(const PickedVideo('a.mp4')), isNull);
      final d = c.items.single;
      expect(d.isVideo, isTrue);
      expect(d.durationMs, 42000);
      expect(d.preview, isNotNull);
      expect(d.state, SupportDraftState.ready);
    });

    test('yukleme hatasi failed olur, yeniden dene basarir; kaldir listeden dusurur', () async {
      final up = _FakeUploader()..failNext = true;
      final c = _ctl(up);
      await c.addImage(p10Photo(0));
      final d = c.items.single;
      expect(d.state, SupportDraftState.failed);
      expect(c.hasFailed, isTrue);
      expect(c.ids, isEmpty);
      await c.retry(d);
      expect(d.state, SupportDraftState.ready);
      expect(c.ids, [100]);
      c.remove(d);
      expect(c.items, isEmpty);
    });

    test('yuklenirken hasPending; kaldirilan ekin sonucu yok sayilir', () async {
      final up = _FakeUploader()..gate = Completer<void>();
      final c = _ctl(up);
      final f = c.addImage(p10Photo(0));
      await Future<void>.delayed(Duration.zero);
      expect(c.hasPending, isTrue);
      final d = c.items.single;
      c.remove(d);
      up.gate!.complete();
      await f;
      expect(c.items, isEmpty);
      expect(c.ids, isEmpty);
    });
  });

  group('talep listesi', () {
    testWidgets('acik talep sayaci + son mesaj onizlemesi + yeni yanit vurgusu', (t) async {
      SupportSeenStore.memory = {};
      final stamp = _now(); // liste ve detay ayni updatedAt'i tasir
      final b = FakeBackend()
        ..on('/faq', <Object>[])
        ..on('/support/tickets', _page([
          _tk(7, 'Bildirim gelmiyor', 'ANSWERED', at: stamp, last: {'text': 'Cihazini yeniden baslatir misin?', 'fromStaff': true}),
          _tk(6, 'Giris hatasi', 'OPEN', cat: 'ACCOUNT', last: {'text': 'Sifre sifirlama kodu gelmiyor', 'fromStaff': false}),
          _tk(5, 'Eski talep', 'CLOSED', cat: 'OTHER'),
        ], open: 2, max: 5))
        ..on('/support/tickets/7', {
          'ticket': _tk(7, 'Bildirim gelmiyor', 'ANSWERED', at: stamp),
          'messages': [
            {'id': 1, 'text': 'Merhaba', 'fromStaff': false, 'createdAt': _now()},
          ],
        });
      useScreen(t, const Size(390, 1200));
      await t.pumpWidget(buildApp(SupportPage(session: makeSession(b)), size: const Size(390, 1200)));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.byType(SupportOpenMeter), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('Destek: Cihazini yeniden baslatir misin?'), findsOneWidget);
      expect(find.text('Sen: Sifre sifirlama kodu gelmiyor'), findsOneWidget);
      // yanit gelmis + gorulmemis talep rozetle one cikar; digerleri durum hapi tasir
      expect(find.text('Yeni yanıt'), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);
      expect(find.text('Kapalı'), findsOneWidget);
      expect(find.widgetWithText(BuButton, 'Yeni talep'), findsOneWidget);
      expect(find.byType(SupportLimitNote), findsNothing);

      // talep acilip donulunce vurgu kalkar
      await t.tap(find.byKey(const ValueKey('supTicket7')));
      await settle(t, const Duration(milliseconds: 900));
      await t.tap(find.byType(BackButton));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Yeni yanıt'), findsNothing);
      expect(find.text('Yanıtlandı'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('5/5 acik talepte "Yeni talep" yerine aciklayici sinir notu', (t) async {
      final b = FakeBackend()
        ..on('/faq', <Object>[])
        ..on('/support/tickets', _page([for (var i = 1; i <= 5; i++) _tk(i, 'Talep $i', i == 1 ? 'ANSWERED' : 'OPEN')], open: 5, max: 5));
      useScreen(t, const Size(390, 1500));
      await t.pumpWidget(buildApp(SupportPage(session: makeSession(b)), size: const Size(390, 1500)));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.byType(SupportLimitNote), findsOneWidget);
      expect(find.text('Açık talep sınırına ulaştın'), findsOneWidget);
      expect(find.textContaining('en çok 5 açık talebin'), findsOneWidget);
      expect(find.widgetWithText(BuButton, 'Yeni talep'), findsNothing);
      await unmount(t);
    });

    testWidgets('bos durum: aciklama karti + Yeni talep; sayac yok', (t) async {
      final b = FakeBackend()
        ..on('/faq', <Object>[])
        ..on('/support/tickets', _page([], open: 0, max: 5));
      useScreen(t, const Size(390, 900));
      await t.pumpWidget(buildApp(SupportPage(session: makeSession(b)), size: const Size(390, 900)));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Henüz talebin yok.'), findsOneWidget);
      expect(find.widgetWithText(BuButton, 'Yeni talep'), findsOneWidget);
      expect(find.byType(SupportOpenMeter), findsNothing);
      await unmount(t);
    });

    test('okunmamis yanit kurali', () {
      final now = DateTime(2026, 11, 3, 12);
      final fresh = _tk(1, 'a', 'ANSWERED', at: now.subtract(const Duration(days: 1)).toIso8601String());
      expect(supportTicketUnread(fresh, {}, now: now), isTrue);
      expect(supportTicketUnread(fresh, {1: fresh['updatedAt'] as String}, now: now), isFalse);
      expect(supportTicketUnread(_tk(2, 'a', 'OPEN'), {}, now: now), isFalse);
      expect(supportTicketUnread(_tk(3, 'a', 'ANSWERED', at: '2026-01-01T10:00:00'), {}, now: now), isFalse); // eski
      expect(supportTicketUnread({...fresh, 'unread': false}, {}, now: now), isFalse); // sunucu bayragi onceliklidir
      expect(supportTicketUnread({..._tk(4, 'a', 'OPEN', at: '2026-01-01T10:00:00'), 'unread': true}, {}, now: now), isTrue);
    });
  });

  group('yeni talep', () {
    testWidgets('kategori kartlari, sayaclar, ek alani; gonderimde attachmentIds gider', (t) async {
      final b = FakeBackend();
      final up = _FakeUploader();
      final c = _ctl(up);
      useScreen(t, const Size(390, 1400));
      await t.pumpWidget(buildApp(NewTicketPage(session: makeSession(b), attachments: c), size: const Size(390, 1400)));
      await settle(t, const Duration(milliseconds: 600));
      for (final s in ['Hesap', 'Teknik', 'İçerik', 'Diğer']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('0/120'), findsOneWidget);
      expect(find.text('0/2000'), findsOneWidget);
      expect(find.text('0/4'), findsOneWidget);
      expect(find.text('Ek ekle'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('supChoiceTECHNICAL')));
      await t.pump();
      await t.enterText(find.byType(TextField).first, 'Bildirim gelmiyor');
      await t.enterText(find.byType(TextField).last, 'Ayrintilar ekte');
      await t.runAsync(() => c.addImage(p10Photo(1)));
      await t.runAsync(() => c.addVideo(const PickedVideo('v.mp4')));
      await t.pump();
      expect(find.text('2/4'), findsOneWidget);
      await t.ensureVisible(find.widgetWithText(BuButton, 'Gönder'));
      await t.tap(find.widgetWithText(BuButton, 'Gönder'));
      await settle(t, const Duration(milliseconds: 600));
      final body = b.bodies['POST /support/tickets'] as Map;
      expect(body['category'], 'TECHNICAL');
      expect(body['attachmentIds'], [100, 101]);
      expect(c.items, isEmpty); // gonderilen ekler taslaktan duser
      await unmount(t);
    });

    testWidgets('ek yokken attachmentIds gonderilmez; yuklenirken Gonder devre disi', (t) async {
      final b = FakeBackend();
      final up = _FakeUploader()..gate = Completer<void>();
      final c = _ctl(up);
      useScreen(t, const Size(390, 1400));
      await t.pumpWidget(buildApp(NewTicketPage(session: makeSession(b), attachments: c), size: const Size(390, 1400)));
      await settle(t, const Duration(milliseconds: 600));
      await t.enterText(find.byType(TextField).first, 'Konu basligi');
      await t.enterText(find.byType(TextField).last, 'Mesaj');
      unawaited(c.addImage(p10Photo(2)));
      await t.pump();
      await t.pump();
      expect(find.text('Ekler yükleniyor…'), findsOneWidget);
      final btn = t.widget<BuButton>(find.widgetWithText(BuButton, 'Ekler yükleniyor…'));
      expect(btn.onPressed, isNull);
      up.gate!.complete();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      await t.pump();
      expect(find.text('Gönder'), findsOneWidget);
      // ek kaldirilinca ids bos: gonderim ekli alan icermez
      c.remove(c.items.single);
      await t.pump();
      await t.ensureVisible(find.widgetWithText(BuButton, 'Gönder'));
      await t.tap(find.widgetWithText(BuButton, 'Gönder'));
      await settle(t, const Duration(milliseconds: 600));
      expect((b.bodies['POST /support/tickets'] as Map).containsKey('attachmentIds'), isFalse);
      await unmount(t);
    });

    testWidgets('basarisiz ek varken gonderim engellenir ve aciklama verilir', (t) async {
      final b = FakeBackend();
      final up = _FakeUploader()..failNext = true;
      final c = _ctl(up);
      useScreen(t, const Size(390, 1400));
      await t.pumpWidget(buildApp(NewTicketPage(session: makeSession(b), attachments: c), size: const Size(390, 1400)));
      await settle(t, const Duration(milliseconds: 600));
      await t.runAsync(() => c.addImage(p10Photo(1)));
      await t.pump();
      await t.enterText(find.byType(TextField).first, 'Konu basligi');
      await t.enterText(find.byType(TextField).last, 'Mesaj');
      await t.ensureVisible(find.widgetWithText(BuButton, 'Gönder'));
      await t.tap(find.widgetWithText(BuButton, 'Gönder'));
      await settle(t, const Duration(milliseconds: 400));
      expect(find.text('Yüklenemeyen eki kaldır ya da yeniden dene.'), findsOneWidget);
      expect(b.requests.where((r) => r.startsWith('POST /support/tickets')), isEmpty);
      // yeniden dene dugmesi (karo) calisir
      await t.ensureVisible(find.byKey(const ValueKey('supRetry0')));
      await t.tap(find.byKey(const ValueKey('supRetry0')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      expect(c.items.single.state, SupportDraftState.ready);
      await unmount(t);
    });

    testWidgets('"Ek ekle" alt sayfasi: foto/video x galeri/kamera', (t) async {
      useScreen(t, const Size(390, 1400));
      await t.pumpWidget(buildApp(NewTicketPage(session: makeSession(FakeBackend()), attachments: _ctl(_FakeUploader())), size: const Size(390, 1400)));
      await settle(t, const Duration(milliseconds: 600));
      await t.ensureVisible(find.byKey(const ValueKey('supAddAttachment')));
      await t.tap(find.byKey(const ValueKey('supAddAttachment')));
      await settle(t, const Duration(milliseconds: 700));
      for (final s in ['Galeriden fotoğraf', 'Fotoğraf çek', 'Galeriden video', 'Video çek']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      await unmount(t);
    });

    testWidgets('sunucu TICKET_OPEN_LIMIT: sinir notu gosterilir, Gonder kapanir', (t) async {
      final b = FakeBackend()..fail('/support/tickets', status: 422, code: 'TICKET_OPEN_LIMIT', message: 'En cok 5 acik talebin olabilir.');
      useScreen(t, const Size(390, 1400));
      await t.pumpWidget(buildApp(NewTicketPage(session: makeSession(b), attachments: _ctl(_FakeUploader())), size: const Size(390, 1400)));
      await settle(t, const Duration(milliseconds: 600));
      await t.enterText(find.byType(TextField).first, 'Konu basligi');
      await t.enterText(find.byType(TextField).last, 'Mesaj');
      await t.ensureVisible(find.widgetWithText(BuButton, 'Gönder'));
      await t.tap(find.widgetWithText(BuButton, 'Gönder'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byType(SupportLimitNote), findsOneWidget);
      expect(t.widget<BuButton>(find.widgetWithText(BuButton, 'Gönder')).onPressed, isNull);
      await unmount(t);
    });
  });

  group('talep yazismasi', () {
    FakeBackend thread({String status = 'ANSWERED'}) => FakeBackend()
      ..on('/support/tickets/9', {
        'ticket': _tk(9, 'Ekran goruntusu ekte', status, cat: 'TECHNICAL', at: _now()),
        'messages': [
          {
            'id': 1,
            'text': 'Hata ekran goruntusunde.',
            'fromStaff': false,
            'createdAt': _now(),
            'attachments': [
              {'id': 31, 'kind': 'IMAGE', 'url': '/api/support/attachments/31', 'thumbUrl': '/api/support/attachments/31/thumb', 'width': 800, 'height': 600},
              {'id': 32, 'kind': 'VIDEO', 'url': '/api/support/attachments/32', 'thumbUrl': '/api/support/attachments/32/thumb', 'durationMs': 12000},
            ],
          },
          {'id': 2, 'text': 'Gordum, inceliyoruz.', 'fromStaff': true, 'createdAt': _now()},
        ],
      });

    testWidgets('mesajdaki ekler kucuk resim olarak cizilir; dokununca tam ekran goruntuleyici acilir', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(SupportTicketPage(session: makeSession(thread()), ticketId: 9), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Ekran goruntusu ekte'), findsOneWidget); // konu ozet kartinda
      expect(find.text('Hata ekran goruntusunde.'), findsOneWidget);
      expect(find.byKey(const ValueKey('supAtt31')), findsOneWidget);
      expect(find.byKey(const ValueKey('supAtt32')), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget); // video suresi
      await t.tap(find.byKey(const ValueKey('supAtt31')));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.byType(ChatMediaViewer), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('yanit: ek eklenir, gonderimde attachmentIds gider; ek varken bos metin uyarilir', (t) async {
      final b = thread();
      final c = _ctl(_FakeUploader());
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(SupportTicketPage(session: makeSession(b), ticketId: 9, attachments: c), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('supComposerAttach')), findsOneWidget);
      await t.runAsync(() => c.addImage(p10Photo(4)));
      await t.pump();
      await t.tap(find.byTooltip('Gönder'));
      await settle(t, const Duration(milliseconds: 400));
      expect(find.text('Eklerle birlikte kısa bir mesaj da yaz.'), findsOneWidget);
      expect(b.requests.where((r) => r.startsWith('POST /support/tickets/9/messages')), isEmpty);
      await t.enterText(find.widgetWithText(TextField, '').last, 'Ekran goruntusu ekledim');
      await t.tap(find.byTooltip('Gönder'));
      await settle(t, const Duration(milliseconds: 600));
      final body = b.bodies['POST /support/tickets/9/messages'] as Map;
      expect(body['text'], 'Ekran goruntusu ekledim');
      expect(body['attachmentIds'], [100]);
      expect(c.items, isEmpty);
      await unmount(t);
    });

    testWidgets('kapali talepte yanit alani yok, kilit notu var', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(SupportTicketPage(session: makeSession(thread(status: 'CLOSED')), ticketId: 9), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('supComposerAttach')), findsNothing);
      expect(find.text('Bu talep kapatıldı.'), findsOneWidget);
      expect(find.text('Talebi kapat'), findsNothing);
      await unmount(t);
    });
  });

  group('tasma matrisi (3 dil x acik/koyu x 1.0/1.3 x 320/390)', () {
    SupportAttachmentsController draftCtl() {
      final c = _ctl(_FakeUploader());
      return c;
    }
    testWidgets('destek ana (sinirda, onizlemeli, yeni yanitli)', (t) async {
      SupportSeenStore.memory = {};
      final b = FakeBackend()
        ..on('/faq', <Object>[])
        ..on('/support/tickets', _page([
          _tk(1, 'Uzun bir konu basligi ' * 3, 'ANSWERED', at: _now(), last: {'text': 'Uzun bir yanit onizlemesi ' * 6, 'fromStaff': true}),
          for (var i = 2; i <= 5; i++) _tk(i, 'Talep $i', 'OPEN', last: {'text': '', 'attachmentCount': 2, 'fromStaff': false}),
        ], open: 5, max: 5));
      await p00Matrix(t, () => SupportPage(session: makeSession(b)), scaffold: false, settleMs: 700);
    });
    testWidgets('yeni talep (ekli)', (t) async {
      final c = draftCtl();
      await t.runAsync(() async {
        await c.addImage(p10Photo(0));
        await c.addVideo(const PickedVideo('v.mp4'));
        await c.addImage(p10Photo(1));
      });
      await p00Matrix(t, () => NewTicketPage(session: makeSession(FakeBackend()), attachments: c), scaffold: false, settleMs: 500);
    });
    testWidgets('talep yazismasi (ekli balon + ekli taslak)', (t) async {
      final b = FakeBackend()
        ..on('/support/tickets/9', {
          'ticket': _tk(9, 'Konu ' * 12, 'ANSWERED', at: _now()),
          'messages': [
            {
              'id': 1,
              'text': 'Mesaj ' * 20,
              'fromStaff': false,
              'createdAt': _now(),
              'attachments': [
                for (var i = 0; i < 4; i++) {'id': 40 + i, 'kind': i == 3 ? 'VIDEO' : 'IMAGE', 'url': '/api/support/attachments/${40 + i}', 'durationMs': 9000},
              ],
            },
            {'id': 2, 'text': 'Yanit ' * 15, 'fromStaff': true, 'createdAt': _now()},
          ],
        });
      final c = draftCtl();
      await t.runAsync(() async {
        await c.addImage(p10Photo(2));
        await c.addImage(p10Photo(3));
      });
      await p00Matrix(t, () => SupportTicketPage(session: makeSession(b), ticketId: 9, attachments: c), scaffold: false, settleMs: 700);
    });
    testWidgets('geri bildirim + oneri panosu', (t) async {
      final b = FakeBackend()
        ..on('/feedback/mine', _page([]))
        ..on('/suggestions', {
          'totalPages': 1,
          'items': [
            {'id': 1, 'subject': 'Priz eklensin ' * 4, 'message': 'Mesaj ' * 20, 'status': 'PLANNED', 'voteCount': 128, 'votedByMe': true},
          ],
        });
      await p00Matrix(t, () => FeedbackPage(session: makeSession(b)), scaffold: false, settleMs: 600);
      await p00Matrix(t, () => SuggestionsPage(session: makeSession(b)), scaffold: false, settleMs: 600);
    });
  });
}
