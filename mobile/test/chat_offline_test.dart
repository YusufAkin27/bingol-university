import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
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
      conversation: {
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

  testWidgets('cevrimdisi gonderim: balon Bekliyor (kirmizi hata yok); teslim edilince sunucu mesajiyla degisir', (tester) async {
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
    expect(find.text('Bekliyor'), findsOneWidget);
    expect(find.text('Gönderilemedi'), findsNothing);
    expect(find.textContaining('Yeniden'), findsNothing);

    deliver = true;
    await ob.retry(ob.items.single.clientId);
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Bekliyor'), findsNothing);
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
    expect(find.text('Bekliyor'), findsOneWidget);

    mode = 'bad';
    await ob.retry(ob.items.single.clientId);
    await settle(tester, const Duration(milliseconds: 600));
    expect(ob.failedCount, 1);
    expect(find.text('Bekliyor'), findsNothing);
    expect(find.textContaining('Yeniden'), findsOneWidget);

    mode = 'ok';
    await tester.tap(find.textContaining('Yeniden'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(ob.items, isEmpty);
    expect(find.textContaining('Yeniden'), findsNothing);
    expect(find.text('hatali'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    ob.dispose();
  });

  testWidgets('sohbet yeniden acilinca kuyruktaki mesaj Bekliyor balonu olarak gelir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = makeSession(_backend());
    final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false, sender: (i) async => throw ApiError(0, 'NETWORK', ''));
    ob.enqueue(conversationId: 1, clientId: 'c-old', text: 'eski bekleyen');
    s.api.outbox = ob;
    await tester.pumpWidget(buildApp(_detail(s), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('eski bekleyen'), findsOneWidget);
    expect(find.text('Bekliyor'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    ob.dispose();
  });

  testWidgets('cevrimdisiyken galeri/kamera: medya baglanti uyarisi', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = makeSession(_backend());
    await tester.pumpWidget(buildApp(_detail(s), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 600));
    s.api.connectivity.reportFailure(); // sayfa yüklenince bağlantı koptu
    expect(s.api.connectivity.online, isFalse);
    await tester.tap(find.byTooltip('Kamera'));
    await tester.pump();
    expect(find.text('Bağlantı gelince tekrar deneyin'), findsOneWidget);
  });

  testWidgets('Yemek: onbellekten gelen liste "Son guncelleme" etiketi gosterir; canli veride yok', (tester) async {
    useScreen(tester, kPhoneMedium);
    final n = DateTime.now();
    final month = [
      for (var d = 1; d <= 28; d++)
        {'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}', 'items': ['Pilav']},
    ];
    final be = FakeBackend()..on('/menu', month, headers: {'etag': '"m1"'});
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(MenuPage(session: s), size: kPhoneMedium));
    await settle(tester);
    expect(find.textContaining('Son güncelleme'), findsNothing);
    await tester.pumpWidget(const SizedBox());

    be.offline = true;
    await tester.pumpWidget(buildApp(MenuPage(session: s), size: kPhoneMedium));
    await settle(tester);
    expect(find.textContaining('Son güncelleme'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
