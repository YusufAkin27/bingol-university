import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// Teslim tikleri uc uca (istemci tarafi): gonderen ekraninda `receipt` olayi tiki ANINDA ilerletir ve geri dusmez;
/// alici istemci "iletildi" imlecini yalniz cihaza GERCEKTEN ulasan mesaj icin yollar ve ayni imleci tekrarlamaz;
/// soket yokken (arka plan / cevrimdisi) yanlis cift tik uretecek hicbir istek gitmez.
/// Oturum kullanicisi: 1 (gonderen A). Karsi taraf: 11 (alici B).

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {String? status}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(const Duration(hours: 5))),
      if (status != null) 'status': status,
    };

const _conv = {
  'id': 1,
  'type': 'DIRECT',
  'title': 'Ali Veli',
  'peer': {'id': 11, 'displayName': 'Ali Veli'},
};

FakeBackend _be(List<Map<String, dynamic>> msgs) => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

Future<void> _pump(WidgetTester tester, Widget page) async {
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(buildApp(page, size: kPhoneMedium));
  await settle(tester, const Duration(milliseconds: 700));
}

Finder _tick(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

Map<String, dynamic> _receipt(String kind, int upTo, String status, {int cid = 1}) =>
    {'type': 'receipt', 'conversationId': cid, 'kind': kind, 'upToMessageId': upTo, 'status': status};

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });
  setUp(() => MessageCache.instance = MessageCache.memoryOnly());

  group('Gonderen: tik durumu', () {
    testWidgets('SENT -> olay gelince ANINDA cift gri tik -> okundu -> mavi cift; geri dusmez', (tester) async {
      final be = _be([_msg(5, 1, 'merhaba', status: 'SENT')]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
      expect(_tick('Gönderildi'), findsOneWidget);

      rt.debugEmitMessageEvent(_receipt('delivered', 5, 'DELIVERED'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(_tick('İletildi'), findsOneWidget);
      expect(_tick('Gönderildi'), findsNothing);

      rt.debugEmitMessageEvent(_receipt('read', 5, 'READ'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(_tick('Okundu'), findsOneWidget);

      // gecikmis / yinelenen "iletildi" olayi okundu durumunu ezmez
      rt.debugEmitMessageEvent(_receipt('delivered', 5, 'DELIVERED'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(_tick('Okundu'), findsOneWidget);
      expect(_tick('İletildi'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('baska konusmanin olayi ve olay kimliginden YENI mesaj etkilenmez (karismaz)', (tester) async {
      final be = _be([_msg(5, 1, 'eski', status: 'DELIVERED'), _msg(9, 1, 'yeni', status: 'SENT')]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
      rt.debugEmitMessageEvent(_receipt('read', 9, 'READ', cid: 2)); // baska sohbet
      rt.debugEmitMessageEvent(_receipt('delivered', 5, 'DELIVERED')); // yalniz <=5
      await settle(tester, const Duration(milliseconds: 400));
      expect(_tick('Gönderildi'), findsOneWidget); // 9 hala tek tik
      expect(_tick('İletildi'), findsOneWidget);
      expect(_tick('Okundu'), findsNothing);
    });

    testWidgets('kapat-ac: sunucudaki durum acilista dogru gorunur', (tester) async {
      final be = _be([_msg(5, 1, 'merhaba', status: 'DELIVERED')]);
      await _pump(tester, ChatDetailPage(session: makeSession(be), connectRealtime: false, conversation: _conv));
      expect(_tick('İletildi'), findsOneWidget);
    });

    testWidgets('sohbet LISTESI: son mesajin tiki receipt olayiyla aninda tek -> cift tik olur', (tester) async {
      final row = {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
        'unreadCount': 0,
        'lastMessage': _msg(5, 1, 'merhaba', status: 'SENT'),
      };
      final be = FakeBackend()
        ..on('/conversations?size=30', {'items': [row], 'nextCursor': null})
        ..on('/conversations/unread-count',
            {'total': 0, 'archivedChats': 0, 'archivedUnreadChats': 0, 'conversations': <Object>[]});
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      s.realtime = rt;
      await _pump(tester, ChatTab(session: s, connectRealtime: false));
      bool hasIcon(IconData d) => tester.widgetList<Icon>(find.byType(Icon)).any((w) => w.icon == d);
      expect(hasIcon(BuIcons.check), isTrue);
      expect(hasIcon(BuIcons.checkCheck), isFalse);

      rt.debugEmitMessageEvent(_receipt('delivered', 5, 'DELIVERED'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(hasIcon(BuIcons.checkCheck), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('Alici istemci: iletildi imleci', () {
    int deliveredPosts(FakeBackend be) =>
        be.requests.where((r) => r.startsWith('POST /conversations/1/delivered')).length;

    testWidgets('sohbet acik: mesaj gorununce tek POST, TEKRARLANMAZ; yeni mesajda yeni imlec', (tester) async {
      final be = _be([_msg(5, 11, 'selam')]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
      await settle(tester, const Duration(seconds: 2));
      expect(deliveredPosts(be), 1);
      expect((be.bodies['POST /conversations/1/delivered'] as Map)['lastMessageId'], 5);
      await settle(tester, const Duration(seconds: 6)); // yoklama turlari
      expect(deliveredPosts(be), 1, reason: 'ayni imlec tekrar gonderilmez');

      rt.debugEmitMessage(_msg(6, 11, 'ikinci'));
      await settle(tester, const Duration(seconds: 2));
      expect(deliveredPosts(be), 2);
      expect((be.bodies['POST /conversations/1/delivered'] as Map)['lastMessageId'], 6);
    });

    testWidgets('kendi mesajim icin iletildi gonderilmez', (tester) async {
      final be = _be([_msg(5, 1, 'benim', status: 'SENT')]);
      await _pump(tester, ChatDetailPage(session: makeSession(be), connectRealtime: false, conversation: _conv));
      await settle(tester, const Duration(seconds: 3));
      expect(deliveredPosts(be), 0);
    });

    testWidgets('soket YOKKEN (arka plan/cevrimdisi) iletildi yazilmaz: yanlis cift tik uretilmez', (tester) async {
      final be = FakeBackend();
      final rt = ChatRealtime(makeSession(be)); // baglanti yok: send() false doner
      rt.ackDelivered(_msg(7, 11, 'x'));
      await tester.pump(const Duration(seconds: 2));
      expect(be.requests.where((r) => r.contains('delivered')), isEmpty);
    });

    testWidgets('baglanti kopup gelince bilinen iletildi imleci REST ile yeniden yollanir', (tester) async {
      final be = _be([_msg(5, 11, 'karsi')]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
      await settle(tester, const Duration(seconds: 2));
      be.requests.clear();
      rt.debugEmitConnected(false);
      rt.debugEmitConnected(true);
      await settle(tester, const Duration(milliseconds: 600));
      expect(deliveredPosts(be), 1);
      expect((be.bodies['POST /conversations/1/delivered'] as Map)['lastMessageId'], 5);
    });
  });
}
