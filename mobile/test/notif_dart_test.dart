import 'package:bu_kampus/core/push/notification_push_card.dart';
import 'package:bu_kampus/core/push/push_banner.dart';
import 'package:bu_kampus/core/push/push_card_parts.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

Widget _card(Map<String, dynamic> data,
        {String title = 'Başlık',
        String body = 'Gövde metni',
        int count = 1,
        bool compact = false,
        void Function(String)? onAction}) =>
    p00App(NotificationPushCard(
        title: title,
        body: body,
        data: data,
        count: count,
        compact: compact,
        onTap: () {},
        onAction: onAction ?? (_) {},
        onClose: () {}));

String _iso(Duration d) => DateTime.now().toUtc().add(d).toIso8601String();

void main() {
  group('sunucu yük sözleşmesi', () {
    test('style sunucudan gelir (büyük/küçük harf fark etmez), SYSTEM artık güvenlik sayılmaz', () {
      expect(pushCardStyle({'style': 'event_cancelled'}), 'EVENT_CANCELLED');
      expect(pushCardStyle({'style': 'LIKE', 'type': 'POST_LIKE'}), 'LIKE');
      expect(pushCardStyle({'type': 'SYSTEM'}), 'SYSTEM');
      expect(pushCardStyle({'type': 'SYSTEM', 'securityKind': 'NEW_DEVICE'}), 'SECURITY');
      expect(pushCardStyle({'type': 'SYSTEM', 'severity': 'critical'}), 'SECURITY');
      expect(pushCardStyle({'style': 'MODERATION'}), 'MODERATION');
    });

    test('aksiyon tablosu: yalnız işlevi olanlar', () {
      expect(pushCardActions({'style': 'CHAT_DIRECT', 'messageId': '1'}), ['reply', 'mark_read']);
      expect(pushCardActions({'style': 'CHAT_DIRECT'}, count: 3), ['reply', 'open_all']);
      expect(pushCardActions({'style': 'EVENT_UPDATE'}), ['ack', 'open']);
      expect(pushCardActions({'style': 'EVENT_REMINDER'}), ['calendar', 'map']);
      expect(pushCardActions({'style': 'FOLLOW_REQUEST'}), ['follow_accept', 'follow_decline']);
      expect(pushCardActions({'style': 'SECURITY', 'securityKind': 'NEW_DEVICE'}), ['security']);
      // Veri/işlev yok: uydurma aksiyon çıkmaz.
      expect(pushCardActions({'style': 'MEAL'}), ['open']);
      expect(pushCardActions({'style': 'ANNOUNCEMENT'}), ['open']);
      expect(pushCardActions({'style': 'MODERATION'}), ['open']);
    });

    test('görsel kuralı: göreli yol, API ana makinesi ve bingol.edu.tr alt alanı; diğerleri atılır', () {
      const origin = 'https://api.bukampus.example';
      expect(pushImageUrl('https://www.bingol.edu.tr/a.jpg', origin: origin), isNotNull);
      expect(pushImageUrl('https://bingol.edu.tr/a.jpg', origin: origin), isNotNull);
      expect(pushImageUrl('https://api.bukampus.example/files/a.jpg', origin: origin), isNotNull);
      expect(pushImageUrl('/files/a.jpg', origin: origin), contains('/files/a.jpg'));
      expect(pushImageUrl('https://evil.example/a.jpg', origin: origin), isNull);
      expect(pushImageUrl('https://bingol.edu.tr.evil.example/a.jpg', origin: origin), isNull);
      expect(pushImageUrl('http://www.bingol.edu.tr/a.jpg', origin: origin), isNull);
      expect(pushImageUrl('//evil.example/a.jpg', origin: origin), isNull);
      expect(pushImageUrl('', origin: origin), isNull);
    });
  });

  group('uygulama içi kart', () {
    testWidgets('kaynak etiketi, başlık yanı rozeti, saat çipi ve eski/yeni saat yalnız veri varsa çizilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_card({
        'style': 'EVENT_UPDATE',
        'type': 'EVENT',
        'eventId': '3',
        'sourceName': 'Kariyer Merkezi',
        'badgeText': 'Saat Revizesi',
        'eventStartsAt': _iso(const Duration(days: 1)),
        'location': 'İİBF Binası',
        'oldStartsAt': '2026-11-06T10:00:00Z',
        'newStartsAt': '2026-11-06T11:30:00Z',
      }, title: 'Etkinlikte değişiklik'));
      await settle(tester);
      expect(find.textContaining('Kariyer Merkezi'), findsOneWidget);
      expect(find.text('Saat Revizesi'), findsOneWidget);
      expect(find.textContaining('İİBF Binası'), findsOneWidget);
      expect(find.text('Yeni saat 14:30'), findsOneWidget);
      expect(find.text('(Eski saat: 13:00)'), findsOneWidget);
      // Aksiyonlar: Anladım + Program Detayı.
      expect(find.text('Anladım'), findsOneWidget);
      expect(find.text('Program Detayı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('veri yoksa çip/rozet/saat/kcal çizilmez (uydurma yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_card({'style': 'MEAL', 'targetType': 'MEAL'}, title: 'Bugünün menüsü'));
      await settle(tester);
      expect(find.byType(PushChip), findsNothing);
      expect(find.textContaining('kcal'), findsNothing);
      expect(find.text('Menüyü Gör'), findsOneWidget);
    });

    testWidgets('kcal çipi yalnız totalKcal geldiyse (ve kcalComplete false değilse)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_card({'style': 'MEAL', 'totalKcal': '820'}));
      await settle(tester);
      expect(find.text('Toplam 820 kcal'), findsOneWidget);
      await tester.pumpWidget(_card({'style': 'MEAL', 'totalKcal': '820', 'kcalComplete': 'false'}));
      await settle(tester);
      expect(find.textContaining('kcal'), findsNothing);
    });

    testWidgets('güvenlik: kritik şerit + olaya göre aksiyon etiketi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final tapped = <String>[];
      await tester.pumpWidget(_card({'style': 'SECURITY', 'securityKind': 'NEW_DEVICE', 'severity': 'critical'},
          title: 'Yeni cihazdan giriş', onAction: tapped.add));
      await settle(tester);
      expect(find.text('Bu ben değilim'), findsOneWidget);
      await tester.tap(find.text('Bu ben değilim'));
      expect(tapped, ['security']);
      await tester.pumpWidget(_card({'style': 'SECURITY', 'securityKind': 'PASSWORD_CHANGED', 'severity': 'critical'}));
      await settle(tester);
      expect(find.text('Hemen Sıfırla'), findsOneWidget);
    });

    testWidgets('çoklu mesaj: avatar sayı rozeti + "N yeni mesaj" çipi + Hızlı Yanıtla / Tümünü Aç', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_card({'style': 'CHAT_DIRECT', 'conversationId': '4', 'type': 'MESSAGE'}, title: 'Zeynep Arslan', count: 3));
      await settle(tester);
      expect(find.text('3 yeni mesaj'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Hızlı Yanıtla'), findsOneWidget);
      expect(find.text('Tümünü Aç'), findsOneWidget);
    });

    testWidgets('üçüncü taraf görsel adresi çizilmez (küçük resim yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_card({'style': 'ANNOUNCEMENT', 'imageUrl': 'https://evil.example/a.jpg'}));
      await settle(tester);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('kompakt şerit: etkinlikte tarih karosu + saat/yer satırı; ack eylemi şeridi kapatır', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(_card({
        'style': 'EVENT_REMINDER',
        'type': 'EVENT',
        'eventStartsAt': '2026-11-02T11:00:00Z',
        'location': 'Konferans Salonu'
      }, title: 'Yapay Zekâ Atölyesi', compact: true));
      await settle(tester);
      expect(find.byType(PushDateTile), findsOneWidget);
      expect(find.text('KAS'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('14:00 · Konferans Salonu'), findsOneWidget);

      final center = PushBannerCenter(duration: const Duration(minutes: 1));
      final calls = <String>[];
      await tester.pumpWidget(p00App(const SizedBox.shrink()));
      final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
      center.show(BannerItem(key: 'e', title: 'T', body: 'B', data: const {'style': 'EVENT_UPDATE', 'eventId': '1'}),
          onTap: (_) => calls.add('tap'), onAction: (a, _) => calls.add(a), overlay: overlay);
      await settle(tester);
      center.action(center.items.value.first, 'ack');
      await settle(tester);
      expect(calls, isEmpty, reason: 'Anladım yalnız kapatır');
      expect(center.items.value, isEmpty);
      center.hide();
    });
  });

  group('gelen kutusu', () {
    FakeBackend be0(List<Map<String, dynamic>> items, {int unread = 2}) =>
        FakeBackend()..on('/notifications', {'unreadCount': unread, 'nextCursor': null, 'items': items});

    testWidgets('"N Yeni" rozeti, grup başlığında okunmamış sayacı, "12 dk önce", okunmuş satırda aksiyon yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final now = DateTime.now();
      final be = be0([
        {
          'id': 1,
          'type': 'FOLLOW_REQUEST',
          'title': 'Can Öztürk',
          'body': 'Sana takip isteği gönderdi.',
          'read': false,
          'data': {'userId': '8'},
          'actorAvatarUrl': 'https://www.bingol.edu.tr/a.jpg',
          'createdAt': now.subtract(const Duration(minutes: 12)).toIso8601String(),
        },
        {
          'id': 2,
          'type': 'EVENT',
          'subtype': 'EVENT_REMINDER',
          'title': 'Etkinlik yarın başlıyor',
          'read': false,
          'sourceName': 'Yazılım Kulübü',
          'data': {'eventId': '5', 'badgeText': 'Yarın'},
          'createdAt': now.subtract(const Duration(minutes: 45)).toIso8601String(),
        },
        {
          'id': 3,
          'type': 'EVENT',
          'subtype': 'EVENT_REMINDER',
          'title': 'Okunmuş hatırlatma',
          'read': true,
          'data': {'eventId': '6'},
          'createdAt': now.subtract(const Duration(minutes: 50)).toIso8601String(),
        },
      ]);
      // Zil (Bildirimler): yalnız bilgilendirme; takip isteği burada GÖRÜNMEZ. Okunmamış etkinlik hatırlatması:
      // Takvime Ekle + Haritada Gör; okunmuş satırda aksiyon yok.
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
      await settle(tester);
      expect(find.byKey(const ValueKey('notif-new-badge')), findsOneWidget);
      expect(find.text('1 Yeni'), findsOneWidget);
      expect(find.text('1 okunmamış'), findsOneWidget);
      expect(find.text('Can Öztürk'), findsNothing);
      expect(find.text('Yazılım Kulübü'), findsOneWidget);
      expect(find.text('Yarın'), findsOneWidget);
      expect(find.widgetWithText(PushActionButton, 'Takvime Ekle'), findsOneWidget);
      expect(find.widgetWithText(PushActionButton, 'Haritada Gör'), findsOneWidget);
      expect(find.byType(PushActionButton), findsNWidgets(2));
      await unmount(tester);

      // Kalp (Hareketler): yalnız takip isteği; avatar + Onayla/Reddet; etkinlik satırları görünmez.
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be), socialOnly: true)));
      await settle(tester);
      expect(find.text('1 Yeni'), findsOneWidget);
      expect(find.text('12 dk önce'), findsOneWidget);
      expect(find.text('Etkinlik yarın başlıyor'), findsNothing);
      expect(find.byType(PushAvatar), findsOneWidget);
      expect(find.widgetWithText(PushActionButton, 'Onayla'), findsOneWidget);
      expect(find.widgetWithText(PushActionButton, 'Reddet'), findsOneWidget);
      expect(find.byType(PushActionButton), findsNWidgets(2));
      await tester.tap(find.widgetWithText(PushActionButton, 'Reddet'));
      await settle(tester);
      expect(be.requests, contains('POST /users/me/follow-requests/8/decline'));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('güvenlik bildirimi: kritik şerit + "Bu ben değilim"; moderasyon bildirimi güvenlik aksiyonu almaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final now = DateTime.now().toIso8601String();
      final be = be0([
        {
          'id': 1,
          'type': 'SYSTEM',
          'title': 'Yeni cihazdan giriş',
          'read': false,
          'data': {'securityKind': 'NEW_DEVICE', 'severity': 'critical'},
          'createdAt': now,
        },
        {
          'id': 2,
          'type': 'SYSTEM',
          'title': 'İçeriğiniz kaldırıldı',
          'read': false,
          'data': {'style': 'MODERATION'},
          'createdAt': now,
        },
      ]);
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
      await settle(tester);
      expect(find.widgetWithText(PushActionButton, 'Bu ben değilim'), findsOneWidget);
      expect(find.text('Hesap Güvenliği'), findsNothing);
      expect(find.byType(PushActionButton), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('boş/okunmamış yoksa "N Yeni" rozeti çizilmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = be0([
        {'id': 1, 'type': 'EVENT', 'title': 'Okunmuş', 'read': true, 'createdAt': DateTime.now().toIso8601String()},
      ], unread: 0);
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
      await settle(tester);
      expect(find.byKey(const ValueKey('notif-new-badge')), findsNothing);
      await unmount(tester);
    });
  });

  group('tercihler ve etkinlik', () {
    testWidgets('Günlük menü anahtarı yalnız sunucu `mealMenu` alanını döndürürse çizilir ve PUT atar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()
        ..on('/notifications/preferences', {
          'news': true,
          'announcements': true,
          'events': true,
          'messages': true,
          'communities': true,
          'mealMenu': false,
          'subtypes': <String, dynamic>{},
        });
      await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: NotificationPrefsGroup(session: makeSession(be))))));
      await settle(tester);
      expect(find.text('Günlük menü'), findsOneWidget);
      await tester.tap(find.text('Günlük menü'));
      await settle(tester);
      expect(be.bodies['PUT /notifications/preferences'], {'mealMenu': true});
      await unmount(tester);

      final be2 = FakeBackend()
        ..on('/notifications/preferences', {
          'news': true,
          'announcements': true,
          'events': true,
          'messages': true,
          'communities': true,
          'subtypes': <String, dynamic>{},
        });
      await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: NotificationPrefsGroup(session: makeSession(be2))))));
      await settle(tester);
      expect(find.text('Günlük menü'), findsNothing);
      await unmount(tester);
    });

    testWidgets('etkinlik giriş kodu sayfası: kapasite doluluğu yalnız kapasite ve katılım varsa', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()
        ..on('/events/7/checkin-code', {'code': 'abcdef123456', 'manualCode': 'AB12CD', 'validForSeconds': 60, 'qrPayload': 'x'})
        ..on('/events/7/attendance/roster', <dynamic>[]);
      await tester.pumpWidget(buildApp(Etkinlik2QrPage(session: makeSession(be), event: const {'id': 7, 'title': 'Atölye', 'capacity': 50, 'goingCount': 44})));
      await settle(tester);
      expect(find.text('Kapasite: %88 dolu'), findsOneWidget);
      await unmount(tester);
      await tester.pumpWidget(buildApp(Etkinlik2QrPage(session: makeSession(be), event: const {'id': 7, 'title': 'Atölye'})));
      await settle(tester);
      expect(find.byKey(const ValueKey('et2-capacity')), findsNothing);
      await unmount(tester);
    });
  });
}
