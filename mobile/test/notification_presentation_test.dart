import 'package:bu_kampus/core/push/notification_presentation.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/notifications/notification_exam_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  test('legacy payloads resolve categories and exam/security destinations', () {
    expect(notificationCategory({'type': 'ANNOUNCEMENT', 'pollId': '1'}),
        NotificationCategory.poll);
    expect(
        notificationCategory(
            {'type': 'ANNOUNCEMENT', 'subtype': 'EXAM_REMINDER'}),
        NotificationCategory.academic);
    expect(notificationCategory({'type': 'USER_FOLLOW'}),
        NotificationCategory.social);
    expect(resolvePushTarget({'examId': '42'}),
        const PushTarget(PushDest.exams, id: 42));
    expect(resolvePushTarget({'target': 'ACCOUNT_SECURITY'}).dest,
        PushDest.accountSecurity);
  });

  testWidgets(
      'category filter queries server and cursor retains selected category',
      (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()
      ..on('/notifications', {'items': [], 'unreadCount': 3})
      ..on('/notifications?category=EVENT', {
        'items': [
          {'id': 10, 'type': 'EVENT', 'title': 'Workshop', 'read': false}
        ],
        'nextCursor': 10,
        'unreadCount': 3,
      })
      ..on('/notifications?cursor=10&category=EVENT', {
        'items': [
          {'id': 9, 'type': 'EVENT', 'title': 'Conference', 'read': true}
        ],
        'unreadCount': 3,
      });
    await tester
        .pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('notif-category-event')));
    await settle(tester);
    expect(find.text('Workshop'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notif-load-more')));
    await settle(tester);
    expect(be.requests, contains('GET /notifications?category=EVENT'));
    expect(
        be.requests, contains('GET /notifications?cursor=10&category=EVENT'));
    expect(find.text('Conference'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
      'follow request action calls real endpoint and hides resolved actions',
      (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()
      ..on('/notifications', {
        'items': [
          {
            'id': 1,
            'type': 'FOLLOW_REQUEST',
            'title': 'Request',
            'read': false,
            'data': {'userId': '8'}
          }
        ],
        'unreadCount': 1,
      });
    await tester
        .pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
    await settle(tester);
    expect(be.requests, contains('POST /users/me/follow-requests/8/accept'));
    expect(find.widgetWithText(FilledButton, 'Onayla'), findsNothing);
    await unmount(tester);
  });

  testWidgets(
      'exam sheet uses current server values and handles long text at 320dp',
      (tester) async {
    useScreen(tester, kPhoneSmall);
    final be = FakeBackend()
      ..on('/timetable/exams', {
        'items': [
          {
            'id': 42,
            'title': 'Veri Yapıları ve Algoritmalar',
            'courseName': 'BLG 222',
            'startsAt':
                DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
            'endsAt':
                DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
            'room': 'B-204 Amfi',
            'note': 'Öğrenci kimliğinizi getiriniz.',
          }
        ],
      });
    await tester.pumpWidget(buildApp(Scaffold(
        body: NotificationExamDetail(session: makeSession(be), examId: 42))));
    await settle(tester);
    expect(find.text('B-204 Amfi'), findsOneWidget);
    expect(find.text('Veri Yapıları ve Algoritmalar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
