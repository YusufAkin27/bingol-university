import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

FakeBackend _notifBe() {
  final now = DateTime.now();
  return FakeBackend()
    ..on('/notifications', {
      'unreadCount': 2,
      'nextCursor': null,
      'items': [
        {
          'id': 1,
          'type': 'ANNOUNCEMENT',
          'title': 'Ders ekleme-bırakma tarihleri duyuruldu ve çok uzun bir başlık deneme metni',
          'read': false,
          'createdAt': now.toIso8601String(),
        },
        {'id': 2, 'type': 'EVENT', 'title': 'Kariyer günleri', 'read': false, 'createdAt': now.toIso8601String()},
        {
          'id': 3,
          'type': 'COMMUNITY',
          'title': 'Müzik Kulübü isteğiniz onaylandı',
          'read': true,
          'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
        {'id': 4, 'type': 'MESSAGE', 'title': 'Mehmet Kaya mesaj gönderdi', 'read': true, 'createdAt': '2020-01-01T10:00:00'},
      ],
    });
}

void main() {
  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      for (final rtl in [false, true]) {
        testWidgets('bildirimler taşma yok ${b.name} ${size.width.toInt()} rtl=$rtl', (tester) async {
          useScreen(tester, size);
          await tester.pumpWidget(buildApp(
              Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: NotificationsPage(session: makeSession(_notifBe()))),
              brightness: b,
              size: size));
          await settle(tester);
          expect(find.text('Kariyer günleri'), findsOneWidget);
          expect(find.text('Tümü'), findsOneWidget);
          await tester.scrollUntilVisible(find.text('Başka bildiriminiz bulunmuyor'), 200, scrollable: find.byType(Scrollable).last);
          expect(find.text('Başka bildiriminiz bulunmuyor'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  }

  testWidgets('eski MESSAGE satırı (sunucu/önbellek) Bildirimler ekranında gizlenir; diğer türler kalır', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()
      ..on('/notifications', {
        'unreadCount': 1,
        'nextCursor': null,
        'items': [
          {'id': 1, 'type': 'MESSAGE', 'title': 'Mehmet Kaya mesaj gönderdi', 'read': false, 'createdAt': DateTime.now().toIso8601String()},
          {'id': 2, 'type': 'FOLLOW_REQUEST', 'title': 'Yeni takip isteği', 'read': false, 'createdAt': DateTime.now().toIso8601String()},
          {'id': 3, 'type': 'EVENT', 'title': 'Kariyer günleri', 'read': true, 'createdAt': DateTime.now().toIso8601String()},
        ],
      });
    await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
    await settle(tester);
    expect(find.text('Mehmet Kaya mesaj gönderdi'), findsNothing);
    expect(find.text('Yeni takip isteği'), findsOneWidget);
    expect(find.text('Kariyer günleri'), findsOneWidget);
    // Okunmamış süzgeci de mesaj satırını göstermez (yalnız takip isteği kalır).
    await tapNotifChip(tester, 'notif-seg-unread');
    expect(find.text('Mehmet Kaya mesaj gönderdi'), findsNothing);
    expect(find.text('Yeni takip isteği'), findsOneWidget);
    await unmount(tester);
  });

  test('mesaj pushu hâlâ ilgili sohbeti açar (yönlendirme değişmedi)', () {
    expect(resolvePushTarget({'type': 'MESSAGE', 'conversationId': '4'}), const PushTarget(PushDest.conversation, id: 4));
    expect(resolvePushTarget({'targetType': 'MESSAGE', 'targetId': '7'}), const PushTarget(PushDest.conversation, id: 7));
    expect(resolvePushTarget({'targetType': 'CONVERSATION', 'targetId': '9'}), const PushTarget(PushDest.conversation, id: 9));
  });

  testWidgets('bildirimler: okunmamış filtresi ve sola kaydırarak silme', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = _notifBe();
    await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
    await settle(tester);
    await tapNotifChip(tester, 'notif-seg-unread');
    expect(find.text('Müzik Kulübü isteğiniz onaylandı'), findsNothing);
    expect(find.text('Kariyer günleri'), findsOneWidget);
    await tapNotifChip(tester, 'notif-seg-all');
    expect(find.text('Müzik Kulübü isteğiniz onaylandı'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('notif-3')), const Offset(-500, 0));
    await settle(tester);
    expect(find.text('Müzik Kulübü isteğiniz onaylandı'), findsNothing);
    expect(be.requests.any((r) => r.startsWith('DELETE /notifications/3')), isTrue);
    await unmount(tester);
  });

  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      for (final rtl in [false, true]) {
        testWidgets('akademik giriş taşma yok ${b.name} ${size.width.toInt()} rtl=$rtl', (tester) async {
          useScreen(tester, size);
          final be = FakeBackend()
            ..on('/timetable/exams/upcoming*', {
              'items': [
                {'id': 1, 'title': 'Güz: Ara sınavlar başlıyor', 'type': 'VIZE', 'startsAt': '2026-11-07T07:00:00Z'},
              ],
            })
            ..on('/academic/calendar/next*', {
              'items': [
                {
                  'id': 1,
                  'kind': 'SINAV',
                  'title': 'Ara sınavlar',
                  'startsAt': '2026-11-06T21:00:00Z',
                  'endsAt': '2026-11-14T21:00:00Z',
                },
                {'id': 2, 'kind': 'SINAV', 'title': 'Yarıyıl sonu sınavları ve çok uzun başlık deneme', 'startsAt': '2027-01-03T21:00:00Z'},
              ],
            });
          await tester.pumpWidget(buildApp(
              Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: AcademicHubPage(session: makeSession(be))),
              brightness: b,
              size: size));
          await settle(tester);
          expect(find.textContaining('SIRADAK'), findsOneWidget);
          expect(find.text('Güz: Ara sınavlar başlıyor'), findsOneWidget);
          expect(find.text('Ders programı'), findsOneWidget);
          expect(find.text('Akademik takvim'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  }
}
