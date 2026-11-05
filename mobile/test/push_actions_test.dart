import 'package:bu_kampus/core/push/push_actions.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_app.dart';

void main() {
  test(
      'read action only marks the notified conversation/message and is idempotent',
      () async {
    final be = FakeBackend()..on('/conversations/4/read', null, status: 204);
    final session = makeSession(be)..state = SessionState.signedIn;
    final actions = PushActions(session);
    final data = {
      'notificationAction': 'mark_read',
      'conversationId': '4',
      'messageId': '19',
      'actionId': 'read-1'
    };
    expect(await actions.perform(data), isTrue);
    expect(await actions.perform(data), isTrue);
    expect(be.bodies['POST /conversations/4/read'], {'lastMessageId': 19});
    expect(be.count('POST /conversations/4/read'), 1);
  });
  test(
      'signed-out and another recipient notifications cannot change server state',
      () async {
    final be = FakeBackend();
    final session = makeSession(be)..state = SessionState.signedOut;
    final actions = PushActions(session);
    expect(
        await actions.perform(
            {'notificationAction': 'mute_hour', 'conversationId': '4'}),
        isFalse);
    session.state = SessionState.signedIn;
    session.userId = 9;
    expect(
        await actions.perform({
          'notificationAction': 'follow_accept',
          'recipientId': '7',
          'userId': '8'
        }),
        isFalse);
    expect(be.requests, isEmpty);
  });
  test('mute and follow decisions use their existing authenticated endpoints',
      () async {
    final be = FakeBackend()
      ..on('/conversations/4/mute', {})
      ..on('/users/me/follow-requests/8/accept', {})
      ..on('/notifications/unread-count', {'unreadCount': 0});
    final actions = PushActions(makeSession(be)..state = SessionState.signedIn);
    await actions.perform({
      'notificationAction': 'mute_hour',
      'conversationId': '4',
      'actionId': 'mute-1'
    });
    await actions.perform({
      'notificationAction': 'follow_accept',
      'userId': '8',
      'actionId': 'accept-1'
    });
    expect(be.bodies['PUT /conversations/4/mute'], {'durationMinutes': 60});
    expect(be.requests, contains('POST /users/me/follow-requests/8/accept'));
  });
  test(
      'reply opens the composer; text-input responses send an idempotent authenticated reply',
      () async {
    final be = FakeBackend()..on('/conversations/4/messages', {});
    bool composer = false;
    final actions = PushActions(makeSession(be)..state = SessionState.signedIn,
        open: (data, {bool compose = false}) async {
      composer = compose;
    });
    await actions.perform({
      'notificationAction': 'reply',
      'conversationId': '4',
      'actionId': 'reply-1'
    });
    expect(composer, isTrue);
    await actions.perform({
      'notificationAction': 'reply',
      'conversationId': '4',
      'messageId': '19',
      'replyText': 'Merhaba',
      'actionId': 'reply-2'
    });
    expect(be.bodies['POST /conversations/4/messages'],
        {'text': 'Merhaba', 'clientId': 'reply-2', 'replyToMessageId': 19});
  });
  test('QR ile Giris (checkin) etkinligi tarayici odakli acar, sunucu durumunu degistirmez', () async {
    final be = FakeBackend();
    Map<String, dynamic>? opened;
    bool focus = false;
    final actions = PushActions(makeSession(be)..state = SessionState.signedIn,
        open: (data, {bool compose = false}) async {
      opened = data;
      focus = compose;
    });
    expect(await actions.perform({'notificationAction': 'checkin', 'eventId': '12', 'actionId': 'ci-1'}), isTrue);
    expect(opened?['eventId'], '12');
    expect(focus, isTrue);
    expect(be.requests, isEmpty);
  });
}
