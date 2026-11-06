import 'package:bu_kampus/core/push/push_actions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// QA alani 4: bildirimden sohbet eylemleri (yanitla / okundu / 1 saat sessize al) ve oturum/alici korumalari.
void main() {
  setUpAll(mockSecureStorage);

  test('reply: metin POST /messages (clientId = actionId, replyToMessageId), ayni actionId ikinci kez gonderilmez', () async {
    final be = FakeBackend();
    final s = makeSession(be);
    var opened = 0;
    final a = PushActions(s, open: (d, {compose = false}) async => opened++);
    final data = {
      'notificationAction': 'reply',
      'actionId': 'act-1',
      'conversationId': '4',
      'messageId': '9',
      'replyText': '  tamam  ',
    };
    expect(await a.perform(data), isTrue);
    expect(await a.perform(data), isTrue);
    expect(be.count('POST /conversations/4/messages'), 1);
    expect(be.bodies['POST /conversations/4/messages'], {'text': 'tamam', 'clientId': 'act-1', 'replyToMessageId': 9});
    expect(opened, 0);
  });

  test('reply: metin yoksa sohbet yazma kipinde acilir (gonderim yok)', () async {
    final be = FakeBackend();
    final s = makeSession(be);
    var composeSeen = false;
    final b = PushActions(s, open: (d, {compose = false}) async => composeSeen = compose);
    expect(await b.perform({'notificationAction': 'reply', 'actionId': 'x', 'conversationId': '4'}), isTrue);
    expect(composeSeen, isTrue);
    expect(be.count('POST /conversations/4/messages'), 0);
  });

  test('reply: 4000+ karakter reddedilir, istek atilmaz', () async {
    final be = FakeBackend();
    final a = PushActions(makeSession(be), open: (d, {compose = false}) async {});
    await expectLater(
        a.perform({'notificationAction': 'reply', 'actionId': 'big', 'conversationId': '4', 'replyText': 'x' * 4001}),
        throwsA(isA<FormatException>()));
    expect(be.count('POST /conversations/4/messages'), 0);
  });

  test('mark_read: POST /read {lastMessageId}; sohbet listesi yenilenmek uzere isaretlenir', () async {
    final be = FakeBackend();
    final s = makeSession(be);
    final before = s.badges.conversationsDirty.value;
    final a = PushActions(s, open: (d, {compose = false}) async {});
    expect(await a.perform({'notificationAction': 'mark_read', 'actionId': 'm1', 'conversationId': '4', 'messageId': '12'}), isTrue);
    expect(be.bodies['POST /conversations/4/read'], {'lastMessageId': 12});
    expect(s.badges.conversationsDirty.value, before + 1);
  });

  test('baska hesabin bildirimi (recipientId uyusmaz): hicbir istek atilmaz', () async {
    final be = FakeBackend();
    final a = PushActions(makeSession(be), open: (d, {compose = false}) async {});
    expect(
        await a.perform({'notificationAction': 'mark_read', 'actionId': 'o', 'conversationId': '4', 'messageId': '12', 'recipientId': '99'}),
        isFalse);
    expect(be.requests.where((r) => r.startsWith('POST /conversations')), isEmpty);
  });

  test('oturum yokken durum degistiren eylem yapilmaz (yalniz acma saklanir)', () async {
    final be = FakeBackend();
    final s = makeSession(be, signedIn: false);
    var opened = 0;
    final a = PushActions(s, open: (d, {compose = false}) async => opened++);
    expect(await a.perform({'notificationAction': 'reply', 'actionId': 'z', 'conversationId': '4', 'replyText': 'x'}), isFalse);
    expect(be.count('POST /conversations/4/messages'), 0);
    expect(opened, 0);
    expect(await a.perform({'notificationAction': 'open', 'conversationId': '4'}), isFalse);
    expect(opened, 1);
  });
}
