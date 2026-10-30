import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart' show LucideIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

FakeBackend _backend() => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': <Object>[], 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

ChatDetailPage _detail(Session s) => ChatDetailPage(
      session: s,
      connectRealtime: false,
      mediaLibrary: FakeMediaLibrary.photos(1),
      ensureAccess: (c, p, {rationale}) async => true,
      conversation: const {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
      },
    );

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('sendButton')));
  await settle(tester, const Duration(milliseconds: 600));
}

void main() {
  setUpAll(loadTestFonts);
  // Cihaz diskine dokunma: mesaj kaydi bellek icinde (her test temiz).
  setUp(() => MessageCache.instance = MessageCache.memoryOnly());

  /// Pasif durum metni/seridi ASLA gorunmez (kullanici karari 2026-10-30): bekliyor, kuyrukta, internet yok...
  void expectNoQueueNotices() {
    for (final t in ['Bekliyor', 'Kuyrukta', 'İnternet bağlantısı yok', 'Kayıtlı veriler gösteriliyor', 'bağlantı gelince', 'gönderilecek']) {
      expect(find.textContaining(t), findsNothing, reason: t);
    }
  }

  testWidgets('cevrimdisi gonderim: balon normal gonderiliyor gorunur (metin/serit yok, kirmizi hata yok); teslim edilince degisir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = _backend()..network('/conversations/1/messages');
    final s = makeSession(be);
    var deliver = false;
    final ob = Outbox(
        store: MemoryOutboxStore(),
        autoSchedule: false,
        sender: (i) async {
          if (!deliver) throw ApiError(0, 'NETWORK', '');
          return {'id': 55, 'conversationId': 1, 'senderId': 1, 'text': i.text, 'clientId': i.clientId, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'status': 'SENT'};
        });
    s.api.outbox = ob;
    await tester.pumpWidget(buildApp(_detail(s), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 600));

    await _type(tester, 'selam kuyruk');
    expect(find.text('selam kuyruk'), findsOneWidget);
    expect(ob.pendingCount, 1);
    expectNoQueueNotices();
    expect(find.byIcon(LucideIcons.clock), findsOneWidget); // balonda normal gonderiliyor gostergesi
    expect(find.text('Gönderilemedi'), findsNothing);
    expect(find.textContaining('Yeniden'), findsNothing);

    deliver = true;
    await ob.retry(ob.items.single.clientId);
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byIcon(LucideIcons.clock), findsNothing); // teslim: gosterge kalkti, tik oldu
    expectNoQueueNotices();
    expect(find.text('selam kuyruk'), findsOneWidget); // çift balon yok
    expect(ob.items, isEmpty);
    await tester.pumpWidget(const SizedBox());
    ob.dispose();
  });

  testWidgets('kalici hata: balon kirmizi + Yeniden dene; dokununca kuyruk yeniden dener ve teslim olur', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = _backend()..network('/conversations/1/messages');
    final s = makeSession(be);
    var mode = 'net';
    final ob = Outbox(
        store: MemoryOutboxStore(),
        autoSchedule: false,
        sender: (i) async {
          if (mode == 'net') throw ApiError(0, 'NETWORK', '');
          if (mode == 'bad') throw ApiError(422, 'VALIDATION', 'x');
          return {'id': 56, 'conversationId': 1, 'senderId': 1, 'text': i.text, 'clientId': i.clientId, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'status': 'SENT'};
        });
    s.api.outbox = ob;
    await tester.pumpWidget(buildApp(_detail(s), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 600));
    await _type(tester, 'hatali');
    expectNoQueueNotices();
    expect(find.byIcon(LucideIcons.clock), findsOneWidget);

    mode = 'bad';
    await ob.retry(ob.items.single.clientId);
    await settle(tester, const Duration(milliseconds: 600));
    expect(ob.failedCount, 1);
    expect(find.byIcon(LucideIcons.clock), findsNothing);
    expect(find.textContaining('Yeniden'), findsOneWidget); // YALNIZ kalici hatada Gonderilemedi + Yeniden dene

    mode = 'ok';
    await tester.tap(find.textContaining('Yeniden'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(ob.items, isEmpty);
    expect(find.textContaining('Yeniden'), findsNothing);
    expect(find.text('hatali'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    ob.dispose();
  });

  testWidgets('sohbet yeniden acilinca kuyruktaki mesaj normal gonderiliyor balonu olarak gelir (metin yok)', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = makeSession(_backend());
    final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false, sender: (i) async => throw ApiError(0, 'NETWORK', ''));
    ob.enqueue(conversationId: 1, clientId: 'c-old', text: 'eski bekleyen');
    s.api.outbox = ob;
    await tester.pumpWidget(buildApp(_detail(s), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('eski bekleyen'), findsOneWidget);
    expectNoQueueNotices();
    expect(find.byIcon(LucideIcons.clock), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    ob.dispose();
  });

  testWidgets('sohbet onbellekten acilir: sunucu yokken son mesajlar gorunur, hata ekrani ve serit yok', (tester) async {
    useScreen(tester, kPhoneMedium);
    MessageCache.instance.saveMessages(1, [
      for (var i = 3; i >= 1; i--)
        {'id': i, 'conversationId': 1, 'senderId': 11, 'text': 'kayitli mesaj $i', 'createdAt': DateTime.now().toUtc().toIso8601String(), 'status': 'SENT'},
    ]);
    final be = FakeBackend()..offline = true;
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(_detail(s), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('kayitli mesaj 3'), findsOneWidget);
    expect(find.text('kayitli mesaj 1'), findsOneWidget);
    expect(find.textContaining('Tekrar'), findsNothing); // hata ekrani yok
    expectNoQueueNotices();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sunucu yanitlayinca kayit sunucu sayfasiyla birlesir (duzenlenen guncellenir, yeni eklenir) ve yeniden yazilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    MessageCache.instance.saveMessages(1, [
      {'id': 2, 'conversationId': 1, 'senderId': 11, 'text': 'eski metin', 'createdAt': DateTime.now().toUtc().toIso8601String()},
      {'id': 1, 'conversationId': 1, 'senderId': 11, 'text': 'ilk', 'createdAt': DateTime.now().toUtc().toIso8601String()},
    ]);
    final be = _backend()
      ..on('/conversations/1/messages?size=30', {
        'items': [
          {'id': 3, 'conversationId': 1, 'senderId': 11, 'text': 'yeni gelen', 'createdAt': DateTime.now().toUtc().toIso8601String(), 'status': 'SENT'},
          {'id': 2, 'conversationId': 1, 'senderId': 11, 'text': 'duzenlenmis metin', 'edited': true, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'status': 'SENT'},
        ],
        'nextCursor': null,
      });
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(_detail(s), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('yeni gelen'), findsOneWidget);
    expect(find.text('duzenlenmis metin'), findsOneWidget);
    expect(find.text('eski metin'), findsNothing);
    final saved = await MessageCache.instance.readMessages(1);
    expect(saved.map((m) => m['id']), [3, 2]);
    expect(saved.first['text'], 'yeni gelen');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Yemek: ag yokken onbellekteki liste SESSIZCE gosterilir (Son guncelleme/Internet yok seridi yok)', (tester) async {
    useScreen(tester, kPhoneMedium);
    final n = DateTime.now();
    final month = [
      for (var d = 1; d <= DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day; d++)
        {'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}', 'items': ['Pilav']},
    ];
    final be = FakeBackend()..on('/menu', month, headers: {'etag': '"m1"'});
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(MenuPage(session: s), size: kPhoneMedium));
    await settle(tester);
    expect(find.textContaining('Pilav'), findsWidgets);
    await tester.pumpWidget(const SizedBox());

    be.offline = true;
    await tester.pumpWidget(buildApp(MenuPage(session: s), size: kPhoneMedium));
    await settle(tester);
    expect(find.textContaining('Pilav'), findsWidgets); // onbellekten
    expectNoQueueNotices();
    expect(find.textContaining('Son güncelleme'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
