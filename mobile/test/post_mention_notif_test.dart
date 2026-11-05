import 'package:bu_kampus/core/push/notification_presentation.dart';
import 'package:bu_kampus/core/push/notification_push_card.dart';
import 'package:bu_kampus/core/push/push_card_parts.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  setUpAll(loadTestFonts);

  const mention = {'type': 'POST_MENTION', 'targetType': 'POST', 'targetId': '77'};

  group('POST_MENTION (etiketlendin) bildirimi', () {
    test('hedef: gonderi detayi (push ve liste ayni tek kaynak)', () {
      expect(resolvePushTarget(mention), const PushTarget(PushDest.post, id: 77));
      expect(resolvePushTarget({'type': 'POST_MENTION', 'targetType': 'FEED_POST', 'targetId': 5}), const PushTarget(PushDest.post, id: 5));
      expect(resolvePushTarget({'type': 'POST_MENTION', 'postId': '9'}), const PushTarget(PushDest.post, id: 9));
    });

    test('kategori sosyal; simge @; kart stili MENTION; kose rozeti mention', () {
      expect(notificationCategory(mention), NotificationCategory.social);
      expect(notificationIcon(mention), Icons.alternate_email);
      expect(pushCardStyle(mention), 'MENTION');
      expect(pushStyleIcon('MENTION'), Icons.alternate_email);
      expect(pushAvatarRole(mention), PushAvatarRole.mention);
    });

    test('bilinmeyen POST_ turu cokmez, sosyal kalir', () {
      const unknown = {'type': 'POST_SOMETHING_NEW', 'targetType': 'POST', 'targetId': '1'};
      expect(notificationCategory(unknown), NotificationCategory.social);
      expect(resolvePushTarget(unknown).dest, PushDest.post);
      expect(pushCardStyle(unknown), 'SOCIAL');
      expect(pushAvatarRole(unknown), isNull);
      expect(notificationIcon(unknown), isA<IconData>());
    });

    testWidgets('liste satiri cizilir (beğeni/takip gibi kisi bildirimi), bilinmeyen tur de cokmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()
        ..on('/notifications', {
          'items': [
            {
              'id': 1,
              'type': 'POST_MENTION',
              'title': 'Ali Veli',
              'body': 'Seni bir gönderide etiketledi',
              'read': false,
              'data': {'targetType': 'POST', 'targetId': '77'}
            },
            {'id': 2, 'type': 'POST_FANCY_NEW', 'title': 'Yeni tür', 'body': 'x', 'read': true},
          ],
          'unreadCount': 1,
        });
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
      await settle(tester);
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('Seni bir gönderide etiketledi'), findsOneWidget);
      expect(find.text('Yeni tür'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
