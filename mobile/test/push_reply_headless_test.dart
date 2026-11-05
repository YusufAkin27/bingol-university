import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/push/push_actions.dart';
import 'package:bu_kampus/core/push/push_reply_headless.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  group('replyPayloadFrom', () {
    test('geçerli native bağımsız değişkenler yanıt yüküne çevrilir (clientId = actionId)', () {
      final p = replyPayloadFrom({'clientId': 'c-1', 'conversationId': '4', 'text': 'merhaba', 'replyToMessageId': '9', 'recipientId': '7'});
      expect(p, {
        'notificationAction': 'reply',
        'actionId': 'c-1',
        'conversationId': '4',
        'replyText': 'merhaba',
        'messageId': '9',
        'recipientId': '7',
      });
    });

    test('eksik/bozuk bağımsız değişkenler null', () {
      expect(replyPayloadFrom(null), isNull);
      expect(replyPayloadFrom({'clientId': '', 'conversationId': '4', 'text': 'x'}), isNull);
      expect(replyPayloadFrom({'clientId': 'a', 'conversationId': 'x', 'text': 'x'}), isNull);
      expect(replyPayloadFrom({'clientId': 'a', 'conversationId': '4', 'text': '   '}), isNull);
      expect(replyPayloadFrom({'clientId': 'a', 'conversationId': '0', 'text': 'x'}), isNull);
    });

    test('isteğe bağlı alanlar yoksa yükte de yok', () {
      final p = replyPayloadFrom({'clientId': 'a', 'conversationId': '4', 'text': 'x', 'replyToMessageId': null, 'recipientId': ''})!;
      expect(p.containsKey('messageId'), isFalse);
      expect(p.containsKey('recipientId'), isFalse);
    });
  });

  group('classifyReply', () {
    test('başarı ok, yetkisiz fail', () async {
      expect(await classifyReply(() async => true), 'ok');
      expect(await classifyReply(() async => false), 'fail');
    });

    test('geçici ağ/5xx/429 retry; 4xx kesin fail', () async {
      expect(await classifyReply(() async => throw ApiError(0, 'NETWORK', '')), 'retry');
      expect(await classifyReply(() async => throw ApiError(503, 'X', '')), 'retry');
      expect(await classifyReply(() async => throw ApiError(429, 'RATE', '')), 'retry');
      expect(await classifyReply(() async => throw ApiError(403, 'FORBIDDEN', '')), 'fail');
      expect(await classifyReply(() async => throw ApiError(404, 'CONVERSATION_NOT_FOUND', '')), 'fail');
      expect(await classifyReply(() async => throw const FormatException('x')), 'fail');
      expect(await classifyReply(() async => throw StateError('beklenmeyen')), 'retry');
    });
  });

  group('handleReplySend: mevcut PushActions yolu', () {
    test('mesaj sunucuya clientId ile gider; aynı clientId ikinci kez gönderilmez', () async {
      final be = FakeBackend()..on('/conversations/4/messages', {'id': 1});
      final session = makeSession(be)..state = SessionState.signedIn;
      final actions = PushActions(session);
      final args = {'clientId': 'k-1', 'conversationId': '4', 'text': ' selam ', 'replyToMessageId': '9'};
      expect(await handleReplySend(args, actions), 'ok');
      expect(await handleReplySend(args, actions), 'ok');
      expect(be.count('POST /conversations/4/messages'), 1);
      expect(be.bodies['POST /conversations/4/messages'], {'text': 'selam', 'clientId': 'k-1', 'replyToMessageId': 9});
    });

    test('ağ hatası retry, sonra aynı clientId ile yeniden denenince ok', () async {
      final be = FakeBackend()..network('/conversations/4/messages');
      final session = makeSession(be)..state = SessionState.signedIn;
      final actions = PushActions(session);
      final args = {'clientId': 'k-2', 'conversationId': '4', 'text': 'merhaba'};
      expect(await handleReplySend(args, actions), 'retry');
      be.on('/conversations/4/messages', {'id': 2});
      expect(await handleReplySend(args, actions), 'ok');
      expect(be.bodyLog['POST /conversations/4/messages']!.map((b) => (b as Map)['clientId']).toSet(), {'k-2'});
    });

    test('oturum yok ya da başka alıcı fail; geçersiz argüman fail', () async {
      final be = FakeBackend();
      final out = makeSession(be, signedIn: false);
      expect(await handleReplySend({'clientId': 'a', 'conversationId': '4', 'text': 'x'}, PushActions(out)), 'fail');
      final session = makeSession(be)
        ..state = SessionState.signedIn
        ..userId = 1;
      expect(await handleReplySend({'clientId': 'a', 'conversationId': '4', 'text': 'x', 'recipientId': '99'}, PushActions(session)), 'fail');
      expect(await handleReplySend({'conversationId': '4'}, PushActions(session)), 'fail');
      expect(be.count('POST /conversations'), 0);
    });

    test('sunucu 403 kesin fail', () async {
      final be = FakeBackend()..fail('/conversations/4/messages', status: 403, code: 'FORBIDDEN');
      final session = makeSession(be)..state = SessionState.signedIn;
      expect(await handleReplySend({'clientId': 'z', 'conversationId': '4', 'text': 'x'}, PushActions(session)), 'fail');
    });
  });
}
