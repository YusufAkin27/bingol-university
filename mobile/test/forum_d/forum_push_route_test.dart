import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/notification_presentation.dart';
import 'package:bu_kampus/core/push/notification_push_card.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_extras.dart';
import '../support/forum_d_harness.dart';

void main() {
  group('resolvePushTarget: forum yukleri', () {
    test('FORUM_TOPIC -> konu', () {
      expect(resolvePushTarget({'targetType': 'FORUM_TOPIC', 'targetId': '12', 'topicId': '12'}), const PushTarget(PushDest.forumTopic, id: 12));
      expect(resolvePushTarget({'targetType': 'FORUM_TOPIC', 'targetId': 12}), const PushTarget(PushDest.forumTopic, id: 12), reason: 'topicId yoksa targetId konudur');
    });

    test('FORUM_COMMENT + topicId -> konu + yorum; yalniz yorum -> forumComment', () {
      expect(resolvePushTarget({'targetType': 'FORUM_COMMENT', 'targetId': '55', 'topicId': '12'}), const PushTarget(PushDest.forumTopic, id: 12, commentId: 55));
      expect(resolvePushTarget({'targetType': 'FORUM_COMMENT', 'targetId': '55'}), const PushTarget(PushDest.forumComment, id: 55));
    });

    test('moderasyon, kucuk harf, eksik kimlik, bilinmeyen FORUM_ turu: cokmez', () {
      expect(resolvePushTarget({'type': 'FORUM_MODERATION', 'targetType': 'forum_topic', 'targetId': 9}), const PushTarget(PushDest.forumTopic, id: 9));
      expect(resolvePushTarget({'targetType': 'FORUM_TOPIC'}), const PushTarget(PushDest.notifications));
      expect(resolvePushTarget({'targetType': 'FORUM_WHATEVER', 'targetId': 'abc'}), const PushTarget(PushDest.notifications));
      expect(resolvePushTarget({'targetType': 'FORUM_TOPIC', 'targetId': -3}), const PushTarget(PushDest.notifications));
      expect(resolvePushTarget({'topicId': '3'}), const PushTarget(PushDest.forumTopic, id: 3));
    });

    test('mevcut hedefler bozulmadi', () {
      expect(resolvePushTarget({'targetType': 'POST_COMMENT', 'targetId': '7', 'commentId': '2'}), const PushTarget(PushDest.post, id: 7, commentId: 2));
      expect(resolvePushTarget({'conversationId': '4'}), const PushTarget(PushDest.conversation, id: 4));
      expect(resolvePushTarget({'targetType': 'EVENT', 'targetId': '3'}), const PushTarget(PushDest.event, id: 3));
      expect(resolvePushTarget(null), const PushTarget(PushDest.notifications));
    });
  });

  group('bildirim sunumu', () {
    test('forum bildirimi kisi avatari degil forum karosu; moderasyon ayri ton; kategori sosyal', () {
      final d = {'type': 'FORUM_COMMENT_REPLY', 'style': 'social', 'targetType': 'FORUM_COMMENT', 'targetId': '55', 'topicId': '12'};
      expect(isForumPush(d), isTrue);
      expect(pushCardStyle(d), 'FORUM');
      expect(notificationCategory(d), NotificationCategory.social);
      expect(notificationIcon(d), BuIcons.messageSquareText);
      expect(pushCardStyle({'type': 'FORUM_MODERATION', 'style': 'system', 'targetType': 'FORUM_TOPIC', 'targetId': '9'}), 'MODERATION');
      expect(isForumPush({'type': 'POST_LIKE'}), isFalse);
      expect(pushCardStyle({'type': 'POST_LIKE'}), 'SOCIAL', reason: 'eski sosyal akış aynı');
    });
  });

  group('PushRouter + bildirim listesi', () {
    late FakeBackend b;
    late FakeForum f;
    late FakeForumExtras x;
    late RouteLog log;

    setUp(() {
      b = FakeBackend();
      f = fakeForum(b, count: 3);
      x = fakeForumExtras(f);
      log = RouteLog();
    });

    Future<void> mount(WidgetTester tester, Widget home) async {
      useScreen(tester, kPhoneMedium);
      PushRouter.session = makeSession(b);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [log],
        theme: BuTheme.light(),
        home: home,
      ));
      await settle(tester, const Duration(milliseconds: 300));
    }

    testWidgets('konu bildirimi forum konusunu acar', (tester) async {
      await mount(tester, const Scaffold());
      final r = PushRouter.open({'type': 'FORUM_TOPIC_LIKE', 'targetType': 'FORUM_TOPIC', 'targetId': '500'});
      await settle(tester, const Duration(milliseconds: 400));
      expect(log.count('forum_topic'), 1);
      expect(log.count('notifications'), 0);
      // Konu sayfası kapanınca açıldı sayılır.
      rootNavigatorKey.currentState!.pop();
      await settle(tester, const Duration(milliseconds: 400));
      expect(await r, isTrue);
    });

    testWidgets('yorum bildirimi (konu + yorum) konuyu acar; yalniz yorum kimligi gelirse konu sunucudan cozulur', (tester) async {
      x.commentsById[55] = sampleForumCommentD(id: 55, topicId: 500);
      await mount(tester, const Scaffold());
      PushRouter.open({'type': 'FORUM_COMMENT_REPLY', 'targetType': 'FORUM_COMMENT', 'targetId': '55', 'topicId': '500'});
      await settle(tester, const Duration(milliseconds: 400));
      expect(log.count('forum_topic'), 1);
      expect(b.requests.where((r) => r.contains('/forum/comments/55')), isEmpty, reason: 'topicId varken ek istek yok');
      rootNavigatorKey.currentState!.pop();
      await settle(tester, const Duration(milliseconds: 400));

      PushRouter.open({'type': 'FORUM_COMMENT_LIKE', 'targetType': 'FORUM_COMMENT', 'targetId': '55'});
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests, contains('GET /forum/comments/55'));
      expect(log.count('forum_topic'), 2);
    });

    testWidgets('silinmis yorum (404): bildirim listesine duser, cokmez', (tester) async {
      await mount(tester, const Scaffold());
      final r = await PushRouter.open({'type': 'FORUM_COMMENT_LIKE', 'targetType': 'FORUM_COMMENT', 'targetId': '999'});
      await settle(tester, const Duration(milliseconds: 600));
      expect(r, isFalse);
      expect(log.count('notifications'), 1);
      expectNoException(tester);
    });

    testWidgets('bildirim satiri: forum karosu + "Forum" etiketi; dokununca konu acilir; bilinmeyen tur cokmez', (tester) async {
      final now = DateTime.now().toUtc().toIso8601String();
      b.on('/notifications', {
        'unreadCount': 3,
        'nextCursor': null,
        'items': [
          {
            'id': 1,
            'type': 'FORUM_TOPIC_COMMENT',
            'title': 'Anonim #7 konuna yorum yaptı',
            'body': 'Kantin fiyatları hakkında',
            'read': false,
            'createdAt': now,
            'data': {'style': 'social', 'sourceName': 'Yemekhane', 'targetType': 'FORUM_COMMENT', 'targetId': 55, 'topicId': 500},
          },
          {
            'id': 2,
            'type': 'FORUM_MODERATION',
            'title': 'Yorumun kaldırıldı',
            'body': 'Topluluk kuralları',
            'read': false,
            'createdAt': now,
            'data': {'style': 'system', 'targetType': 'FORUM_COMMENT', 'targetId': 56, 'topicId': 500},
          },
          {
            'id': 3,
            'type': 'FORUM_GELECEKTEKI_TUR',
            'title': 'Yeni bir tür',
            'read': false,
            'createdAt': now,
            'data': {'targetType': 'FORUM_YENI', 'targetId': 1},
          },
        ],
      });
      await mount(tester, NotificationsPage(session: makeSession(b)));
      await settle(tester, const Duration(seconds: 1));
      expectNoException(tester);
      expect(find.text('Anonim #7 konuna yorum yaptı'), findsOneWidget);
      expect(find.text('Yemekhane'), findsOneWidget, reason: 'kaynak etiketi kategori adı');
      expect(find.byIcon(BuIcons.messageSquareText), findsWidgets);
      expect(find.byType(BuAvatar), findsNothing, reason: 'anonim yazar için kişi avatarı çizilmez');
      expect(find.text('Yeni bir tür'), findsOneWidget);

      await tester.tap(find.text('Anonim #7 konuna yorum yaptı'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(log.count('forum_topic'), 1);
      rootNavigatorKey.currentState!.pop();
      await settle(tester, const Duration(milliseconds: 400));

      // Bilinmeyen FORUM_ türü: liste çökmez, hedef açılamadı bildirimi (uyarı) verir.
      await tester.tap(find.text('Yeni bir tür'));
      await settle(tester, const Duration(milliseconds: 600));
      expectNoException(tester);
    });

    testWidgets('koyu tema + 1.3x yazi: forum bildirim satiri tasmaz', (tester) async {
      b.on('/notifications', {
        'unreadCount': 1,
        'nextCursor': null,
        'items': [
          {
            'id': 1,
            'type': 'FORUM_FOLLOWED_TOPIC_COMMENT',
            'title': 'Takip ettiğin konuya çok uzun bir yorum geldi ${'uzun ' * 10}',
            'body': 'Gövde ${'metin ' * 20}',
            'read': false,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'data': {'style': 'social', 'sourceName': 'Kampüs Yaşamı ve Serbest Kürsü', 'targetType': 'FORUM_COMMENT', 'targetId': 55, 'topicId': 500},
          },
        ],
      });
      useScreen(tester, kPhoneSmall);
      PushRouter.session = makeSession(b);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: ThemeMode.dark,
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)), child: w!),
        home: NotificationsPage(session: makeSession(b)),
      ));
      await settle(tester, const Duration(seconds: 1));
      expectNoException(tester);
    });
  });
}
