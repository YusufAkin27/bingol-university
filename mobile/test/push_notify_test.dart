import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/notify/local_reminders.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_service.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

class _FakeBackend implements LocalReminderBackend {
  final Map<String, List<LocalReminder>> groups = {};
  Map<String, String>? launch;
  int cancelAllCalls = 0;

  @override
  Future<void> replaceGroup(String group, List<LocalReminder> items) async => groups[group] = items;

  @override
  Future<void> upsert(String group, LocalReminder item) async {
    final l = (groups[group] ??= []);
    l.removeWhere((e) => e.id == item.id);
    l.add(item);
  }

  @override
  Future<void> cancel(String group, int id) async => groups[group]?.removeWhere((e) => e.id == id);

  @override
  Future<void> cancelGroup(String group) async => groups.remove(group);

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    groups.clear();
  }

  @override
  Future<bool> notificationsAllowed() async => true;

  @override
  Future<Map<String, String>?> takeLaunchPayload() async {
    final p = launch;
    launch = null;
    return p;
  }
}

void main() {
  setUpAll(loadTestFonts);

  group('resolvePushTarget (saf fonksiyon)', () {
    PushTarget r(Map<String, dynamic> d) => resolvePushTarget(d);

    test('mevcut yuk bicimleri', () {
      expect(r({'conversationId': '7'}), const PushTarget(PushDest.conversation, id: 7));
      expect(r({'targetType': 'EVENT', 'targetId': '3'}), const PushTarget(PushDest.event, id: 3));
      expect(r({'target': 'COMMUNITY', 'value': '4'}), const PushTarget(PushDest.community, id: 4));
      expect(r({'target': 'NEWS', 'value': '9'}), const PushTarget(PushDest.news, id: 9));
      expect(r({'targetType': 'ANNOUNCEMENT', 'targetId': 9}), const PushTarget(PushDest.news, id: 9));
      expect(r({'targetType': 'POST', 'targetId': '5', 'commentId': '8'}),
          const PushTarget(PushDest.post, id: 5, commentId: 8));
      expect(r({'postId': '5'}), const PushTarget(PushDest.post, id: 5));
    });

    test('yeni turler', () {
      expect(r({'targetType': 'POST_MENTION', 'targetId': '5', 'commentId': '2'}),
          const PushTarget(PushDest.post, id: 5, commentId: 2));
      expect(r({'targetType': 'POST_LIKE', 'targetId': '5'}), const PushTarget(PushDest.post, id: 5));
      expect(r({'target': 'USER', 'value': '12', 'userId': '12'}), const PushTarget(PushDest.user, id: 12));
      expect(r({'targetType': 'USER_FOLLOW', 'targetId': '12'}), const PushTarget(PushDest.user, id: 12));
      expect(r({'targetType': 'POLL_CLOSING', 'targetId': '6'}), const PushTarget(PushDest.poll, id: 6));
      expect(r({'targetType': 'POLL', 'pollId': '6'}), const PushTarget(PushDest.poll, id: 6));
      expect(r({'targetType': 'ANNOUNCEMENT_DEPT', 'targetId': '21'}),
          const PushTarget(PushDest.deptAnnouncement, id: 21));
      expect(r({'targetType': 'STORY', 'targetId': '3'}), const PushTarget(PushDest.user, id: 3));
      expect(r({'targetType': 'EXAM'}), const PushTarget(PushDest.exams));
      expect(r({'targetType': 'TIMETABLE'}), const PushTarget(PushDest.timetable));
      expect(r({'type': 'SESSION_REPLACED'}), const PushTarget(PushDest.signOut));
    });

    test('bilinmeyen / bozuk yuk Bildirimler listesine duser (cokme yok)', () {
      const n = PushTarget(PushDest.notifications);
      expect(r({}), n);
      expect(resolvePushTarget(null), n);
      expect(r({'targetType': 'ALIEN', 'targetId': '1'}), n);
      expect(r({'targetType': 'EVENT', 'targetId': 'abc'}), n);
      expect(r({'targetType': 'POLL', 'targetId': '-4'}), n);
      expect(r({'targetType': 42, 'targetId': <int>[1]}), n);
      expect(r({'targetType': 'URL', 'value': 'https://x.y'}), n);
    });
  });

  group('PushRouter (widget): on plan / arka plan / soguk baslatma ayni yoldan', () {
    late FakeBackend b;

    Future<void> pumpShell(WidgetTester tester) async {
      useScreen(tester, kPhoneMedium);
      b = FakeBackend()
        ..on('/notifications', {'items': <Object>[], 'unreadCount': 0, 'nextCursor': null})
        ..on('/polls/6', {'id': 6, 'title': 'Anket', 'options': <Object>[]});
      final s = makeSession(b);
      PushRouter.session = s;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        home: const Scaffold(body: Text('kabuk')),
      ));
    }

    testWidgets('bilinmeyen tur: Bildirimler acilir, istisna yok', (tester) async {
      await pumpShell(tester);
      PushRouter.open({'targetType': 'ALIEN', 'targetId': '1'});
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bos yuk de cokmez', (tester) async {
      await pumpShell(tester);
      PushRouter.open({});
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('POLL_* anket detayina gider', (tester) async {
      await pumpShell(tester);
      PushRouter.open({'targetType': 'POLL_CLOSING', 'targetId': '6'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(b.count('/polls/6'), greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('acilmayan sohbet Bildirimler listesine duser', (tester) async {
      await pumpShell(tester);
      b.fail('/conversations/9', status: 404, code: 'NOT_FOUND');
      PushRouter.open({'conversationId': '9'});
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('sohbet push: {conversation, members} sarmalayicisi acilir, sohbet sayfasi yuklenir', (tester) async {
      await pumpShell(tester);
      b
        ..on('/conversations/9', {
          'conversation': {'id': 9, 'type': 'DIRECT', 'title': 'Ayse Demir', 'unreadCount': 1},
          'members': <Object>[],
        })
        ..on('/conversations/9/messages*', {'items': <Object>[], 'nextCursor': null});
      PushRouter.open({'conversationId': '9'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ChatDetailPage), findsOneWidget);
      expect(find.byType(NotificationsPage), findsNothing);
      expect(b.count('GET /conversations/9/messages'), greaterThan(0)); // _cid cozuldu: TypeError yok
      expect(tester.takeException(), isNull);
    });

    testWidgets('sohbet push: beklenmeyen govde (id yok) Bildirimler listesine duser', (tester) async {
      await pumpShell(tester);
      b.on('/conversations/9', {'members': <Object>[]});
      PushRouter.open({'conversationId': '9'});
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(find.byType(ChatDetailPage), findsNothing);
    });

    test('conversationFromDetail: sarmalayici, duz govde, gecersiz', () {
      expect(PushRouter.conversationFromDetail({'conversation': {'id': 3}, 'members': []})?['id'], 3);
      expect(PushRouter.conversationFromDetail({'id': 4, 'type': 'GROUP'})?['id'], 4);
      expect(PushRouter.conversationFromDetail({'conversation': {'title': 'x'}}), isNull);
      expect(PushRouter.conversationFromDetail('x'), isNull);
      expect(PushRouter.conversationFromDetail(null), isNull);
    });

    testWidgets('oturum kapaliyken hicbir sey acilmaz', (tester) async {
      await pumpShell(tester);
      PushRouter.session = makeSession(b, signedIn: false);
      PushRouter.open({'targetType': 'ALIEN'});
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsNothing);
    });
  });

  group('on plan seridi', () {
    testWidgets('baslik/govde gosterir, bos mesaj gostermez, Ac eylemi cagrilir', (tester) async {
      var opened = 0;
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));
      expect(showPushBanner(ctx, title: '', body: '', onOpen: () {}), isFalse);
      expect(showPushBanner(null, title: 'a', body: 'b', onOpen: () {}), isFalse);
      expect(showPushBanner(ctx, title: 'Yeni takipci', body: 'Ali seni takip etti', onOpen: () => opened++), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Yeni takipci'), findsOneWidget);
      await tester.tap(find.text('Aç'));
      expect(opened, 1);
    });
  });

  group('LocalReminders servisi', () {
    final now = DateTime(2026, 11, 1, 8);
    LocalReminder rem(int id, int hours) =>
        LocalReminder(id: id, at: now.add(Duration(hours: hours)), title: 't$id', body: 'b');

    test('gecmisleri atar, siralar, tekrar kimlikte sonuncuyu tutar, siniri uygular', () async {
      final fb = _FakeBackend();
      final svc = LocalReminders(fb, clock: () => now);
      await svc.replaceGroup('academic', [rem(1, 5), rem(2, -1), rem(3, 2), rem(1, 9)]);
      final l = fb.groups['academic']!;
      expect(l.map((e) => e.id), [3, 1]);
      expect(l.last.at, now.add(const Duration(hours: 9)));

      await svc.replaceGroup('academic', [for (var i = 1; i <= 100; i++) rem(i, i)]);
      expect(fb.groups['academic']!.length, LocalReminders.maxPerGroup);
    });

    test('schedule gecmisi yok sayar; upsert gruba dokunmaz; cancel ve cancelGroup', () async {
      final fb = _FakeBackend();
      final svc = LocalReminders(fb, clock: () => now);
      await svc.replaceGroup('academic', [rem(1, 1)]);
      await svc.schedule('academic', rem(2, 2));
      await svc.schedule('academic', rem(3, -2));
      expect(fb.groups['academic']!.map((e) => e.id).toSet(), {1, 2});
      await svc.cancel('academic', 1);
      expect(fb.groups['academic']!.map((e) => e.id), [2]);
      await svc.cancelGroup('academic');
      expect(fb.groups.containsKey('academic'), isFalse);
      await svc.replaceGroup('x', [rem(5, 1)]);
      await svc.cancelAll();
      expect(fb.cancelAllCalls, 1);
    });

    test('rescheduleAll saglayicilari cagirir; biri hata verirse digeri etkilenmez', () async {
      final fb = _FakeBackend();
      final svc = LocalReminders(fb, clock: () => now);
      svc.registerProvider('bad', () async => throw StateError('x'));
      svc.registerProvider('academic', () async => [rem(7, 3)]);
      await svc.rescheduleAll();
      expect(fb.groups['academic']!.single.id, 7);
    });

    test('toMap: kimlik 31 bit, payload tasinir', () {
      final m = LocalReminder(id: -1, at: now, title: 'a', body: 'b', payload: const {'targetType': 'EXAM'}).toMap();
      expect(m['id'], 0x7fffffff);
      expect(m['channel'], ReminderChannel.academic);
      expect(m['payload'], {'targetType': 'EXAM'});
    });
  });

  group('Bildirim tercihleri ekrani', () {
    testWidgets('alt turler ve ek bayraklar yalniz sunucu gonderdiginde gorunur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/notifications/preferences', {
          'news': true,
          'announcements': true,
          'events': true,
          'communities': true,
          'messages': true,
          'polls': true,
          'subtypes': {'POST_MENTION': true, 'USER_FOLLOW': false},
        });
      await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(b))));
      await tester.pumpAndSettle();
      expect(find.text('Etiketlenmeler'), findsNothing); // ayrıntılı tercihler kapalı başlar
      await tester.ensureVisible(find.text('Ayrıntılı tercihler'));
      await tester.tap(find.text('Ayrıntılı tercihler'));
      await tester.pumpAndSettle();
      expect(find.text('Etiketlenmeler'), findsOneWidget);
      expect(find.text('Yeni takipçiler'), findsOneWidget);
      expect(find.text('Gönderi beğenileri'), findsNothing);
      expect(find.text('Anketler'), findsOneWidget);
      expect(find.text('Akademik duyurular'), findsNothing);
      expect(find.text('Ders ve sınav hatırlatmaları'), findsOneWidget);

      await tester.tap(find.text('Yeni takipçiler'));
      await tester.pumpAndSettle();
      expect(b.bodies['PUT /notifications/preferences'], {
        'subtypes': {'USER_FOLLOW': true}
      });
    });

    testWidgets('ana bayrak kismi govde gonderir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/notifications/preferences',
            {'news': true, 'announcements': true, 'events': true, 'communities': true, 'messages': true});
      await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(b))));
      await tester.pumpAndSettle();
      expect(find.text('Etiketlenmeler'), findsNothing);
      await tester.tap(find.text('Haberler'));
      await tester.pumpAndSettle();
      expect(b.bodies['PUT /notifications/preferences'], {'news': false});
    });
  });
}
