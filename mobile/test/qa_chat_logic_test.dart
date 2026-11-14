import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// QA alani 4 (sohbet): mantik regresyonlari. Her test bir QA-CHAT-xx bulgusuna ya da bir kenar duruma baglidir.

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {int cid = 1}) => {
      'id': id,
      'conversationId': cid,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 600 - id))),
    };

FakeBackend _backend(List<Map<String, dynamic>> msgs) => FakeBackend()
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

const _conv = {
  'id': 1,
  'type': 'DIRECT',
  'title': 'Ali Veli',
  'peer': {'id': 11, 'displayName': 'Ali Veli'},
};

Future<void> _pump(WidgetTester tester, Widget page) async {
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(buildApp(page, size: kPhoneMedium));
  await settle(tester, const Duration(milliseconds: 600));
}

/// "Iletildi" imlecini kaydeden gercek zamanli katman (soket yok).
class _RecRt extends ChatRealtime {
  _RecRt(super.session);
  final delivered = <List<int>>[];

  @override
  bool sendDelivered(int conversationId, int lastMessageId) {
    delivered.add([conversationId, lastMessageId]);
    return true;
  }
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() => MessageCache.instance = MessageCache.memoryOnly());

  group('ChatDetail gercek zamanli birlesim', () {
    testWidgets('ayni mesaj WS ten iki kez gelirse tek balon (yinelenen mesaj)', (tester) async {
      final s = makeSession(_backend([_msg(1, 11, 'Ilk')]));
      final rt = ChatRealtime(s);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
      rt.debugEmitMessage(_msg(2, 11, 'Yeni mesaj'));
      rt.debugEmitMessage(_msg(2, 11, 'Yeni mesaj'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Yeni mesaj'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sirasiz gelen mesajlar sunucu kimligine gore dizilir (eski kimlik ustte)', (tester) async {
      final s = makeSession(_backend([_msg(1, 11, 'Birinci')]));
      final rt = ChatRealtime(s);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
      rt.debugEmitMessage(_msg(4, 11, 'Dorduncu'));
      rt.debugEmitMessage(_msg(3, 11, 'Ucuncu'));
      await settle(tester, const Duration(milliseconds: 400));
      final y3 = tester.getTopLeft(find.text('Ucuncu')).dy;
      final y4 = tester.getTopLeft(find.text('Dorduncu')).dy;
      expect(y3 < y4, isTrue, reason: 'id 3, id 4 un USTUNDE (liste en yeni altta)');
      await unmount(tester);
    });

    testWidgets('baska konusmanin mesaji bu sohbete eklenmez', (tester) async {
      final s = makeSession(_backend([_msg(1, 11, 'Ilk')]));
      final rt = ChatRealtime(s);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
      rt.debugEmitMessage(_msg(9, 11, 'Baska sohbet', cid: 2));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Baska sohbet'), findsNothing);
      await unmount(tester);
    });
  });

  group('QA-CHAT-04 duzenleme hatasi', () {
    for (final code in ['MESSAGE_EDIT_EXPIRED', 'MESSAGE_EDIT_LIMIT', 'MESSAGE_NOT_EDITABLE']) {
      testWidgets('$code: duzenleme kipinden cikilir, giris alani bosalir', (tester) async {
        final be = _backend([_msg(3, 1, 'Eski metin')])..fail('/messages/3', status: 403, code: code);
        final s = makeSession(be);
        await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, conversation: _conv));
        await tester.longPress(find.text('Eski metin'));
        await settle(tester, const Duration(milliseconds: 400));
        await tester.tap(find.text('Düzenle'));
        await settle(tester, const Duration(milliseconds: 400));
        expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, 'Eski metin');
        await tester.enterText(find.byType(TextField).last, 'Yeni metin');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('sendButton')));
        await settle(tester, const Duration(milliseconds: 400));
        expect(be.count('PATCH /messages/3'), 1);
        expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, isEmpty);
        await unmount(tester);
      });
    }

    testWidgets('gecici hata (500) duzenleme kipini ve yazilan metni korur', (tester) async {
      final be = _backend([_msg(3, 1, 'Eski metin')])..fail('/messages/3', status: 500, code: 'SERVER_ERROR');
      final s = makeSession(be);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, conversation: _conv));
      await tester.longPress(find.text('Eski metin'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Düzenle'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).last, 'Yeni metin');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, 'Yeni metin');
      await unmount(tester);
    });
  });

  group('ChatTab okunmamis sayaci', () {
    FakeBackend listBackend() => FakeBackend()
      ..on('/conversations?size=30', {
        'items': [
          {
            'id': 1,
            'type': 'DIRECT',
            'title': 'Ali Veli',
            'peer': {'id': 11, 'displayName': 'Ali Veli'},
            'unreadCount': 0,
            'lastMessage': _msg(1, 11, 'Selam'),
          },
        ],
        'nextCursor': null,
      })
      ..on('/conversations/unread-count', {'total': 0, 'archivedChats': 0, 'archivedUnreadChats': 0, 'conversations': <Object>[]});

    testWidgets('baskasinin mesaji sayaci artirir, kendi mesajim artirmaz, kendi okundu bilgim sifirlar', (tester) async {
      final s = makeSession(listBackend());
      final rt = s.realtime!;
      await _pump(tester, ChatTab(session: s, connectRealtime: false));
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      rt.debugEmitMessage({..._msg(2, 1, 'Benim mesajim'), 'clientId': 'c-own'});
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('1'), findsNothing, reason: 'kendi mesajim okunmamis sayilmaz');

      rt.debugEmitMessage(_msg(3, 11, 'Karsi mesaj'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('1'), findsOneWidget);

      rt.debugEmitMessage(_msg(4, 11, 'Bir tane daha'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('2'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('QA-CHAT-10 sufgec/arama sonraki sayfalari ceker', () {
    Map<String, dynamic> row(int id, String type, String title) => {
          'id': id,
          'type': type,
          'title': title,
          if (type == 'DIRECT') 'peer': {'id': 100 + id, 'displayName': title},
          'unreadCount': 0,
          'lastMessage': _msg(id, 11, 'Merhaba $id', cid: id),
        };

    FakeBackend twoPages() => FakeBackend()
      ..on('/conversations?size=30', {
        'items': [for (var i = 1; i <= 30; i++) row(i, 'DIRECT', 'Kisi $i')],
        'nextCursor': 99,
      })
      ..on('/conversations?size=30&cursor=99', {
        'items': [row(31, 'CLUB', 'Robotik Kulubu Odasi'), row(32, 'DIRECT', 'Zeynep Aydin')],
        'nextCursor': null,
      })
      ..on('/conversations/unread-count', {'total': 0, 'archivedChats': 0, 'archivedUnreadChats': 0, 'conversations': <Object>[]});

    testWidgets('Kulupler cipi: ilk sayfada kulup yoksa sonraki sayfa kendiliginden cekilir', (tester) async {
      final be = twoPages();
      final s = makeSession(be);
      await _pump(tester, ChatTab(session: s, connectRealtime: false));
      expect(be.count('cursor=99'), 0, reason: 'sufgec yokken kaydirma olmadan 2. sayfa istenmez');
      await tester.tap(find.text('Kulüpler'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.count('cursor=99'), 1);
      expect(find.text('Robotik Kulubu Odasi'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('arama: 2. sayfadaki kisi bulunur', (tester) async {
      final be = twoPages();
      final s = makeSession(be);
      await _pump(tester, ChatTab(session: s, connectRealtime: false));
      await tester.enterText(find.byType(TextField).first, 'zeynep');
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.count('cursor=99'), 1);
      expect(find.text('Zeynep Aydin'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('ChatRealtime iletildi imleci', () {
    test('yalniz ilerler, kendi mesajim icin gonderilmez, ayni kimlik tekrar gonderilmez', () {
      final s = makeSession(FakeBackend());
      final rt = _RecRt(s);
      rt.ackDelivered(_msg(5, 11, 'a'));
      rt.ackDelivered(_msg(5, 11, 'a')); // yinelenen
      rt.ackDelivered(_msg(4, 11, 'eski')); // geri gitmez
      rt.ackDelivered(_msg(6, 1, 'benim')); // kendi mesajim
      rt.ackDelivered({..._msg(7, 11, 'b'), 'conversationId': 2});
      rt.ackDelivered(_msg(8, 11, 'c'));
      expect(rt.delivered, [
        [1, 5],
        [2, 7],
        [1, 8],
      ]);
    });

    test('QA-CHAT-09: stop() (oturum kapanisi) iletildi imlecini sifirlar; yeni hesap ayni kimlikle yeniden gonderir', () {
      final s = makeSession(FakeBackend());
      final rt = _RecRt(s);
      rt.ackDelivered(_msg(5, 11, 'a'));
      rt.stop();
      rt.ackDelivered(_msg(5, 11, 'a'));
      expect(rt.delivered, [
        [1, 5],
        [1, 5],
      ]);
    });
  });
}
