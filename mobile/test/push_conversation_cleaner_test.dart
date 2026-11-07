import 'package:bu_kampus/core/push/active_conversation.dart';
import 'package:bu_kampus/core/push/conversation_cleaner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ActiveConversation active;
  late List<Map<String, Object?>> calls;
  late ConversationNotificationCleaner cleaner;

  setUp(() {
    active = ActiveConversation.test();
    calls = [];
    cleaner = ConversationNotificationCleaner(
      active: active,
      invoke: (method, args) async {
        expect(method, 'dismissConversation');
        calls.add(args);
      },
    );
  });

  tearDown(() => cleaner.dispose());

  test('acik ve on plandaki sohbet icin YALNIZ o sohbet temizlenir', () {
    active.enter(5);
    expect(calls, [
      {'conversationId': 5}
    ]);
    active.leave(5);
    active.enter(6);
    expect(calls.last, {'conversationId': 6});
    expect(calls.length, 2, reason: 'baska sohbet kimligi gonderilmez');
  });

  test('ayni sohbet icin tekrar bildirim tetiklenmez', () {
    active.enter(5);
    active.setForeground(true); // degismedi
    expect(calls.length, 1);
  });

  test('arka plana gecince temizlik yok, one gelince tekrar temizlenir', () {
    active.enter(5);
    active.setForeground(false);
    expect(calls.length, 1);
    active.setForeground(true);
    expect(calls.length, 2, reason: 'geri donuste sohbet hala acik: birikenler silinir');
  });

  test('sohbet acik degilken hicbir sey silinmez', () {
    active.setForeground(true);
    expect(calls, isEmpty);
  });

  test('yerel kod yoksa (MissingPluginException) sessiz', () async {
    final c = ConversationNotificationCleaner(
        active: ActiveConversation.test(),
        invoke: (m, a) async => throw MissingPluginException());
    await c.dismissConversation(3);
    c.dispose();
  });

  test('gecersiz kimlik yok sayilir', () async {
    await cleaner.dismissConversation(0);
    await cleaner.dismissConversation(-2);
    expect(calls, isEmpty);
  });
}
