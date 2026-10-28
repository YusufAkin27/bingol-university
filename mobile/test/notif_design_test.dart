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
          expect(find.text('Duyuru'), findsOneWidget);
          await tester.scrollUntilVisible(find.text('Silmek için bildirimi sola kaydır'), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text('Hepsi bu kadar'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  }

  testWidgets('bildirimler: okunmamış filtresi ve sola kaydırarak silme', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = _notifBe();
    await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('notif-seg-unread')));
    await settle(tester);
    expect(find.text('Müzik Kulübü isteğiniz onaylandı'), findsNothing);
    expect(find.text('Kariyer günleri'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notif-seg-all')));
    await settle(tester);
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
          expect(find.text('Sıradaki sınav'), findsOneWidget);
          expect(find.text('Güz: Ara sınavlar başlıyor'), findsOneWidget);
          await tester.scrollUntilVisible(find.text('Ara sınavlar'), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text('Yaklaşan tarihler'), findsOneWidget);
          expect(find.text('Ders programı'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  }
}
