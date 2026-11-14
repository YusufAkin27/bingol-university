import 'package:bu_kampus/core/notification_counts.dart';
import 'package:bu_kampus/core/push/notification_push_card.dart';
import 'package:bu_kampus/core/push/notification_presentation.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuHeader;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_app.dart';

/// NOTIFSPLIT: iki AYRI bildirim merkezi. Zil = Bildirimler (scope=INFORMATION: etkinlik/duyuru/sistem), kalp = Hareketler
/// (scope=SOCIAL: beğeni/yorum/takip/istek/kulüp başvurusu). Bir bildirim yalnız birinde görünür; sayaçlar bağımsızdır.

String _now() => DateTime.now().toUtc().toIso8601String();

Map<String, Object?> _n(int id, String type, String title,
        {String? subtype, String? scope, Map<String, Object?>? data, bool read = false}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      'body': '',
      'read': read,
      'createdAt': _now(),
      if (subtype != null) 'subtype': subtype,
      if (scope != null) 'scope': scope,
      if (data != null) 'data': data,
    };

void main() {
  setUpAll(loadTestFonts);

  group('merkez aidiyeti (istemci savunması)', () {
    test('sunucu scope verirse o geçerlidir', () {
      expect(NotificationsPage.belongsToCenter({'type': 'POST_LIKE', 'scope': 'SOCIAL'}, social: true), isTrue);
      expect(NotificationsPage.belongsToCenter({'type': 'POST_LIKE', 'scope': 'SOCIAL'}, social: false), isFalse);
      expect(NotificationsPage.belongsToCenter({'type': 'EVENT', 'scope': 'INFORMATION'}, social: false), isTrue);
    });

    test('eski sunucuda (scope yok) tür/alt türden çıkarılır: sosyal zile, bilgilendirme kalbe girmez', () {
      for (final t in ['POST_LIKE', 'POST_COMMENT', 'COMMENT_REPLY', 'USER_FOLLOW', 'FOLLOW_REQUEST', 'FOLLOW_ACCEPTED']) {
        expect(NotificationsPage.belongsToCenter({'type': t}, social: false), isFalse, reason: t);
        expect(NotificationsPage.belongsToCenter({'type': t}, social: true), isTrue, reason: t);
      }
      expect(NotificationsPage.belongsToCenter({'type': 'COMMUNITY', 'subtype': 'COMMUNITY_JOIN'}, social: true), isTrue);
      for (final t in ['EVENT', 'ANNOUNCEMENT', 'NEWS', 'SYSTEM', 'COMMUNITY']) {
        expect(NotificationsPage.belongsToCenter({'type': t}, social: true), isFalse, reason: t);
        expect(NotificationsPage.belongsToCenter({'type': t}, social: false), isTrue, reason: t);
      }
    });

    test('süzgeç parametreleri', () {
      expect(NotificationsPage.bellCategoryParam(NotifBellFilter.events), 'EVENT');
      expect(NotificationsPage.bellCategoryParam(NotifBellFilter.announcements), 'ANNOUNCEMENT,ACADEMIC,POLL');
      expect(NotificationsPage.bellCategoryParam(NotifBellFilter.system), 'SYSTEM');
      expect(NotificationsPage.bellCategoryParam(NotifBellFilter.all), isNull);
      expect(NotificationsPage.heartKindParam(NotifHeartFilter.likes), 'LIKES');
      expect(NotificationsPage.heartKindParam(NotifHeartFilter.comments), 'COMMENTS');
      expect(NotificationsPage.heartKindParam(NotifHeartFilter.follows), 'FOLLOWS');
      expect(NotificationsPage.heartKindParam(NotifHeartFilter.all), isNull);
    });

    test('kulüp üyelik başvurusu sosyal sayılır ve Onayla/Reddet eylemleri verir; sonuç bildirimi vermez', () {
      final req = {'type': 'COMMUNITY', 'subtype': 'COMMUNITY_JOIN', 'communityId': '4', 'userId': '9'};
      expect(notificationCategory(req), NotificationCategory.social);
      expect(pushCardStyle(req), 'CLUB_JOIN_REQUEST');
      expect(pushCardActions(req), ['member_approve', 'member_reject']);
      final result = {'type': 'COMMUNITY', 'subtype': 'COMMUNITY_JOIN', 'communityId': '4'};
      expect(notificationCategory(result), NotificationCategory.social);
      expect(pushCardActions(result), isNot(contains('member_approve')));
    });

    test('yeni metinler tr/en/ar tanımlı', () {
      for (final code in ['tr', 'en', 'ar']) {
        final l = lookupAppLocalizations(Locale(code));
        for (final v in [
          l.activityTitle,
          l.activityEmpty,
          l.activityFilterLikes,
          l.activityFilterComments,
          l.activityFilterFollows,
          l.notifFilterEvents,
          l.notifFilterAnnouncements,
          l.notifFilterSystem,
          l.activityRequestStale,
        ]) {
          expect(v.trim(), isNotEmpty, reason: code);
        }
      }
      expect(lookupAppLocalizations(const Locale('tr')).activityTitle, 'Hareketler');
    });
  });

  group('sayaçlar', () {
    test('applyNotificationCounts: zil ve kalp bağımsız; bekleyen istekler kalbe', () {
      final s = makeSession(FakeBackend());
      expect(
          applyNotificationCounts(s, {
            'social': 3,
            'information': 5,
            'unreadCount': 8,
            'pendingFollowRequests': 2,
            'pendingMembershipRequests': 1,
          }),
          isTrue);
      expect(s.badges.notifications.value, 5);
      expect(s.badges.social.value, 3);
      expect(s.badges.socialPending.value, 3);
    });

    test('me/summary alanlarına ve eski sunucuya (alan yok) uyum', () {
      final s = makeSession(FakeBackend());
      s.badges.notifications.value = 7;
      expect(applyNotificationCounts(s, {'unreadSocial': 1, 'unreadInformation': 4}), isTrue);
      expect(s.badges.notifications.value, 4);
      expect(s.badges.social.value, 1);
      expect(applyNotificationCounts(s, {'unreadNotifications': 9}), isFalse);
      expect(s.badges.notifications.value, 4, reason: 'tanınmayan yanıt sayaca dokunmaz');
    });

    test('refreshNotificationCounts uç yoksa özet uca düşer', () async {
      final b = FakeBackend()
        ..fail('/notifications/unread-counts', status: 404, code: 'NOT_FOUND')
        ..on('/me/summary', {'unreadNotifications': 6, 'unreadSocial': 2, 'unreadInformation': 4});
      final s = makeSession(b);
      await refreshNotificationCounts(s);
      expect(s.badges.notifications.value, 4);
      expect(s.badges.social.value, 2);
    });
  });

  group('Bildirimler (zil)', () {
    FakeBackend bell() => FakeBackend()
      ..on('/notifications/unread-counts', {'social': 4, 'information': 2, 'unreadCount': 6})
      ..on('/users/me/follow-requests/count', {'count': 3})
      ..on('/notifications', {
        'unreadCount': 6,
        'nextCursor': null,
        'items': [
          _n(1, 'EVENT', 'Kodlama atölyesi yarın', scope: 'INFORMATION'),
          _n(2, 'ANNOUNCEMENT', 'Final takvimi yayınlandı', scope: 'INFORMATION'),
          // Eski/yanlış sunucu: sosyal satır zile sızarsa istemci gizler.
          _n(3, 'POST_LIKE', 'Melisa gönderini beğendi.', scope: 'SOCIAL'),
          _n(4, 'USER_FOLLOW', 'Ahmet seni takip etmeye başladı.'),
        ],
      });

    testWidgets('sosyal satır görünmez; başlık Bildirimler; çipler Tümü/Okunmamış/Etkinlikler/Duyurular/Sistem',
        (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = bell();
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Kodlama atölyesi yarın'), findsOneWidget);
      expect(find.text('Final takvimi yayınlandı'), findsOneWidget);
      expect(find.text('Melisa gönderini beğendi.'), findsNothing);
      expect(find.text('Ahmet seni takip etmeye başladı.'), findsNothing);
      expect(tester.widget<BuHeader>(find.byType(BuHeader)).title, 'Bildirimler'); // başlık yalnız anlamsal etiket
      // Çip şeridi yatay kayar: görünmeyenler için şeridi kaydırarak ara.
      final strip = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);
      for (final t in ['Tümü', 'Okunmamış', 'Etkinlikler', 'Duyurular', 'Sistem']) {
        await tester.scrollUntilVisible(find.text(t), 60, scrollable: strip.first);
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Beğeniler'), findsNothing);
      expect(find.byKey(const ValueKey('follow-requests-entry')), findsNothing, reason: 'takip istekleri yalnız kalpte');
      expect(b.requests.any((r) => r.startsWith('GET /notifications?') && r.contains('scope=INFORMATION')), isTrue);
      await unmount(tester);
    });

    testWidgets('Duyurular çipi birleşik kategori ister; Etkinlikler EVENT', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = bell();
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('notif-category-announcement')));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests.any((r) => r.contains('category=ANNOUNCEMENT%2CACADEMIC%2CPOLL') || r.contains('category=ANNOUNCEMENT,ACADEMIC,POLL')), isTrue);
      await tester.tap(find.byKey(const ValueKey('notif-category-event')));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests.any((r) => r.contains('category=EVENT')), isTrue);
      await unmount(tester);
    });

    testWidgets('Tümünü okundu yap yalnız INFORMATION kapsamını gönderir; kalp sayacı etkilenmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = bell();
      final s = makeSession(b);
      s.badges.social.value = 4;
      s.badges.notifications.value = 2;
      await tester.pumpWidget(buildApp(NotificationsPage(session: s), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.text('Tümünü okundu yap'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.bodies['POST /notifications/read'], {'all': true, 'scope': 'INFORMATION'});
      expect(s.badges.social.value, 4);
      await unmount(tester);
    });

    testWidgets('boş durum ve hata durumu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final e = FakeBackend()..on('/notifications', {'items': <Object>[], 'nextCursor': null, 'unreadCount': 0});
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(e)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Henüz bildiriminiz yok.'), findsOneWidget);
      await unmount(tester);

      final f = FakeBackend()..fail('/notifications', status: 500);
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(f)), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Yeniden dene'), findsWidgets);
      await unmount(tester);
    });
  });

  group('Hareketler (kalp)', () {
    FakeBackend heart() => FakeBackend()
      ..on('/users/me/follow-requests/count', {'count': 2})
      ..on('/notifications', {
        'unreadCount': 6,
        'nextCursor': null,
        'items': [
          _n(1, 'POST_LIKE', 'Melisa gönderini beğendi.', scope: 'SOCIAL', data: {'postId': '5', 'actorId': '7'}),
          _n(2, 'USER_FOLLOW', 'Ahmet seni takip etmeye başladı.', scope: 'SOCIAL', data: {'userId': '8'}),
          _n(3, 'COMMUNITY', 'Yazılım Kulübü için yeni üyelik başvurusu var.',
              subtype: 'COMMUNITY_JOIN', scope: 'SOCIAL', data: {'communityId': '4', 'userId': '9'}),
          _n(4, 'EVENT', 'Etkinlik hatırlatması', scope: 'INFORMATION'),
        ],
      });

    testWidgets('yalnız sosyal; başlık Hareketler; çipler Tümü/Beğeniler/Yorumlar/Takip ve İstekler; istekler satırı',
        (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = heart();
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b), socialOnly: true), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.widget<BuHeader>(find.byType(BuHeader)).title, 'Hareketler');
      expect(find.text('Melisa gönderini beğendi.'), findsOneWidget);
      expect(find.text('Ahmet seni takip etmeye başladı.'), findsOneWidget);
      expect(find.text('Yazılım Kulübü için yeni üyelik başvurusu var.'), findsOneWidget);
      expect(find.text('Etkinlik hatırlatması'), findsNothing);
      final strip = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);
      for (final t in ['Tümü', 'Beğeniler', 'Yorumlar', 'Takip ve İstekler']) {
        await tester.scrollUntilVisible(find.text(t), 60, scrollable: strip.first);
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Okunmamış'), findsNothing);
      expect(find.text('Etkinlikler'), findsNothing);
      expect(find.byKey(const ValueKey('follow-requests-entry')), findsOneWidget);
      expect(b.requests.any((r) => r.startsWith('GET /notifications?') && r.contains('scope=SOCIAL')), isTrue);
      await unmount(tester);
    });

    testWidgets('Beğeniler çipi kind=LIKES ister; tümünü okundu yap scope=SOCIAL', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = heart();
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b), socialOnly: true), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('activity-filter-likes')));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests.any((r) => r.contains('kind=LIKES')), isTrue);
      await tester.tap(find.byKey(const ValueKey('activity-filter-follows')));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests.any((r) => r.contains('kind=FOLLOWS')), isTrue);
      await tester.tap(find.text('Tümünü okundu yap'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.bodies['POST /notifications/read'], {'all': true, 'scope': 'SOCIAL'});
      await unmount(tester);
    });

    testWidgets('Üyelik başvurusu Onayla/Reddet gerçek uca gider', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = heart();
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b), socialOnly: true), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Onayla'), findsOneWidget);
      expect(find.text('Reddet'), findsWidgets);
      await tester.ensureVisible(find.text('Onayla'));
      await tester.tap(find.text('Onayla'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests, contains('POST /communities/4/requests/9/approve'));
      expect(find.text('Onayla'), findsNothing, reason: 'sonuçlanan başvuruda düğme kalmaz');
      await unmount(tester);
    });

    testWidgets('Reddet; eskimiş başvuruda (404) dürüst mesaj', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = heart();
      b.fail('/communities/4/requests/9/reject', status: 404, code: 'REQUEST_NOT_FOUND', message: 'x');
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b), socialOnly: true), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await tester.ensureVisible(find.text('Reddet').last);
      await tester.tap(find.text('Reddet').last);
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests, contains('POST /communities/4/requests/9/reject'));
      expect(find.text('Bu başvuru artık beklemiyor; daha önce sonuçlanmış olabilir.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('boş durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      final e = FakeBackend()
        ..on('/users/me/follow-requests/count', {'count': 0})
        ..on('/notifications', {'items': <Object>[], 'nextCursor': null, 'unreadCount': 0});
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(e), socialOnly: true), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.textContaining('Henüz hareket yok'), findsOneWidget);
      await unmount(tester);
    });
  });
}
