import 'package:bu_kampus/core/push/active_conversation.dart';
import 'package:bu_kampus/core/push/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  test('on plan mesaj push: ayni messageId iki kez serit cikarmaz; acik sohbet bastirilir', () {
    final s = makeSession(FakeBackend());
    final active = ActiveConversation.test();
    final push = PushService(s, active: active);

    Map<String, dynamic> msg(int conv, int id) => {'type': 'MESSAGE', 'conversationId': '$conv', 'messageId': '$id'};

    expect(push.handleForeground(title: 'Ali', body: 'Yeni mesaj', data: msg(7, 100)), isTrue);
    expect(push.handleForeground(title: 'Ali', body: 'Yeni mesaj', data: msg(7, 100)), isFalse); // tekrar
    expect(push.handleForeground(title: 'Ali', body: 'Yeni mesaj', data: msg(7, 101)), isTrue); // yeni mesaj

    active.enter(7); // sohbet acik + on plan
    expect(push.handleForeground(title: 'Ali', body: 'Yeni mesaj', data: msg(7, 102)), isFalse);
    expect(push.handleForeground(title: 'Ayse', body: 'Yeni mesaj', data: msg(8, 103)), isTrue); // baska sohbet

    // messageId'siz bildirimler (duyuru) tekillestirmeden etkilenmez
    expect(push.handleForeground(title: 'Duyuru', body: 'x', data: const {'type': 'ANNOUNCEMENT'}), isTrue);
    expect(push.handleForeground(title: 'Duyuru', body: 'x', data: const {'type': 'ANNOUNCEMENT'}), isTrue);
  });

  test('PushService oturuma jeton saglayicisini baglar (cikis istegi fcmToken tasir)', () {
    final s = makeSession(FakeBackend());
    expect(s.pushToken, isNull);
    final push = PushService(s, active: ActiveConversation.test());
    expect(s.pushToken, isNotNull);
    expect(s.pushToken!(), isNull); // henuz jeton alinmadi
    push.registrar.token = 'abc';
    expect(s.pushToken!(), 'abc');
  });
}
