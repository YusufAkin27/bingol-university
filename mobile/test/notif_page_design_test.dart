import 'package:bu_kampus/core/icons/bu_icons.dart';
import 'package:bu_kampus/core/push/rich/rich_card.dart';
import 'package:bu_kampus/features/notifications/notif_card.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Bildirimler sayfası (Stitch "uygulama içi şerit ve liste", alt kısım): başlık, çipler, gruplar, kartlar,
/// takip isteği düğmeleri, boş/hata/bakım durumları.

String _iso(Duration ago) => DateTime.now().subtract(ago).toIso8601String();

FakeBackend _be({List<Map<String, dynamic>>? items, int unread = 3}) => FakeBackend()
  ..on('/notifications', {
    'unreadCount': unread,
    'nextCursor': null,
    'items': items ??
        [
          {
            'id': 1,
            'type': 'FOLLOW_REQUEST',
            'title': 'Can Öztürk',
            'body': 'Sana takip isteği gönderdi.',
            'read': false,
            'createdAt': _iso(const Duration(minutes: 12)),
            'data': {'senderId': '33', 'senderName': 'Can Öztürk'},
          },
          {
            'id': 2,
            'type': 'SYSTEM',
            'subtype': 'NEW_DEVICE_LOGIN',
            'title': 'Yeni cihazdan giriş',
            'body': 'Samsung Galaxy S24 · 09:41 tarihinde oturum açıldı',
            'read': false,
            'createdAt': _iso(const Duration(minutes: 45)),
            'data': {'actions': 'not_me,view'},
          },
          {
            'id': 3,
            'type': 'ANNOUNCEMENT',
            'subtype': 'ACADEMIC_ANNOUNCEMENT',
            'title': 'Akademik duyuru',
            'body': 'Öğrenci İşleri Daire Başkanlığı ek kontenjan kılavuzunu paylaştı.',
            'read': true,
            'createdAt': _iso(const Duration(minutes: 70)),
          },
          {
            'id': 4,
            'type': 'EVENT',
            'subtype': 'EVENT_ADMISSION',
            'title': 'Başvurunuz onaylandı',
            'body': 'Takım başvurunuz jüri kurulu tarafından onaylandı.',
            'read': false,
            'createdAt': _iso(const Duration(days: 1, hours: 1)),
          },
          {
            'id': 5,
            'type': 'USER_FOLLOW',
            'title': 'Elif seni takip etmeye başladı',
            'body': '',
            'read': true,
            'createdAt': _iso(const Duration(days: 12)),
            'data': {'senderName': 'Elif'},
          },
        ],
  });

Future<void> _mount(WidgetTester tester, FakeBackend be, {Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be)), size: size));
  await settle(tester);
}

Future<void> _tapChip(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  final horizontal = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.horizontal);
  tester.state<ScrollableState>(horizontal).position.jumpTo(0);
  await tester.pump();
  // Çipler yatay kaydırılır (tasarımda da son çip kesik görünür); tembel listede önce kaydırarak görünür kıl.
  await tester.scrollUntilVisible(f, 80, scrollable: horizontal);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('başlık: BU KAMPÜS işareti, "Bildirimler", "N Yeni" rozeti ve "Tümünü okundu yap"', (tester) async {
    await _mount(tester, _be());
    expect(find.text('BU KAMPÜS'), findsOneWidget);
    expect(find.text('BU'), findsOneWidget); // kırmızı daire içindeki işaret
    expect(find.text('Bildirimler'), findsNWidgets(2)); // üst çubuk + liste başlığı
    expect(find.text('3 Yeni'), findsOneWidget);
    expect(find.text('Tümünü okundu yap'), findsOneWidget);
    expect(find.byIcon(BuIcons.bell), findsWidgets);
    await unmount(tester);
  });

  testWidgets('filtre çipleri: Tümü, Mesajlar, Etkinlik, Duyuru, Sosyal (tümü seçili başlar)', (tester) async {
    await _mount(tester, _be());
    for (final k in ['all', 'messages', 'events', 'announcements', 'social']) {
      expect(find.byKey(ValueKey('notif-seg-$k')), findsOneWidget, reason: k);
    }
    for (final t in ['Tümü', 'Mesajlar', 'Etkinlik', 'Duyuru', 'Sosyal']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await unmount(tester);
  });

  testWidgets('gruplar: BUGÜN / DÜN / DAHA ESKİ ve grup başına okunmamış sayısı', (tester) async {
    await _mount(tester, _be());
    expect(find.text('BUGÜN'), findsOneWidget);
    expect(find.text('2 okunmamış'), findsOneWidget); // bugün: id 1, 2
    expect(find.text('DÜN'), findsOneWidget);
    expect(find.text('1 okunmamış'), findsOneWidget); // dün: id 4
    await tester.scrollUntilVisible(find.text('DAHA ESKİ'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('DAHA ESKİ'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('okunmamış satırda kırmızı nokta görünür, okunmuşta ölçeği 0', (tester) async {
    await _mount(tester, _be());
    final dots = tester.widgetList<AnimatedScale>(find.byKey(const ValueKey('notif-unread-dot'))).toList();
    expect(dots.where((d) => d.scale == 1).length, 3);
    expect(dots.where((d) => d.scale == 0).length, greaterThanOrEqualTo(1));
    await unmount(tester);
  });

  testWidgets('kişi satırında avatar, sistem satırında ikon rozeti', (tester) async {
    await _mount(tester, _be());
    expect(find.byType(NotifBadge), findsWidgets);
    expect(find.text('Yeni cihazdan giriş'), findsOneWidget);
    // Yeni cihaz girişi: kırmızı uyarı satırı.
    expect(find.text('Bu siz değilseniz şifrenizi sıfırlayın'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('takip isteği: Onayla -> POST accept, karar etiketi gösterilir, düğmeler kalkar', (tester) async {
    final be = _be();
    await _mount(tester, be);
    expect(find.byKey(const ValueKey('notif-accept-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('notif-reject-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notif-accept-1')));
    await settle(tester);
    expect(be.requests.any((r) => r == 'POST /users/me/follow-requests/33/accept'), isTrue);
    expect(find.byKey(const ValueKey('notif-accept-1')), findsNothing);
    expect(find.byKey(const ValueKey('notif-decided-1')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('takip isteği: Reddet -> POST decline', (tester) async {
    final be = _be();
    await _mount(tester, be);
    await tester.tap(find.byKey(const ValueKey('notif-reject-1')));
    await settle(tester);
    expect(be.requests.any((r) => r == 'POST /users/me/follow-requests/33/decline'), isTrue);
    await unmount(tester);
  });

  testWidgets('takip isteği kararı başarısızsa düğmeler kalır', (tester) async {
    final be = _be()..fail('/users/me/follow-requests/33/accept', status: 500);
    await _mount(tester, be);
    await tester.tap(find.byKey(const ValueKey('notif-accept-1')));
    await settle(tester);
    expect(find.byKey(const ValueKey('notif-accept-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('notif-decided-1')), findsNothing);
    await unmount(tester);
  });

  testWidgets('kategori süzgeci: Etkinlik yalnız etkinlik, Sosyal yalnız takip, Mesajlar boş', (tester) async {
    await _mount(tester, _be());
    await _tapChip(tester, 'notif-seg-events');
    await settle(tester);
    expect(find.text('Başvurunuz onaylandı'), findsOneWidget);
    expect(find.text('Akademik duyuru'), findsNothing);

    await _tapChip(tester, 'notif-seg-social');
    await settle(tester);
    expect(find.text('Can Öztürk'), findsOneWidget);
    expect(find.text('Başvurunuz onaylandı'), findsNothing);

    await _tapChip(tester, 'notif-seg-announcements');
    await settle(tester);
    expect(find.text('Akademik duyuru'), findsOneWidget);
    expect(find.text('Can Öztürk'), findsNothing);

    await _tapChip(tester, 'notif-seg-messages');
    await settle(tester);
    expect(find.text('Bu türde bildirim yok.'), findsOneWidget);

    await _tapChip(tester, 'notif-seg-all');
    await settle(tester);
    expect(find.text('Can Öztürk'), findsOneWidget);
    await unmount(tester);
  });

  test('kategori eşlemesi (saf)', () {
    expect(notifCategoryOf('EVENT'), NotifCategory.events);
    expect(notifCategoryOf('COMMUNITY'), NotifCategory.events);
    expect(notifCategoryOf('NEWS'), NotifCategory.announcements);
    expect(notifCategoryOf('ANNOUNCEMENT'), NotifCategory.announcements);
    expect(notifCategoryOf('POST_LIKE'), NotifCategory.social);
    expect(notifCategoryOf('FOLLOW_REQUEST'), NotifCategory.social);
    expect(notifCategoryOf('MESSAGE'), NotifCategory.messages);
    expect(notifCategoryOf('SYSTEM'), isNull);
    expect(notifCategoryOf(null), isNull);
    expect(notifCategoryOf('SYSTEM', subtype: 'EVENT_UPDATE'), NotifCategory.events);
  });

  test('satır türü: üst düzey ya da data içindeki alanlardan çözülür; bozuk yük atmaz', () {
    expect(notifKindOf({'type': 'FOLLOW_REQUEST'}, const {}), RichKind.followRequest);
    expect(notifKindOf({'type': 'SYSTEM', 'subtype': 'PASSWORD_CHANGED'}, const {}), RichKind.passwordChanged);
    expect(notifKindOf({'type': 'SYSTEM'}, {'actions': 'not_me,view'}), RichKind.newDeviceLogin);
    expect(notifKindOf({'type': 'SYSTEM', 'actions': ['view_ticket']}, const {}), RichKind.supportReply);
    expect(notifKindOf(const {}, const {}), RichKind.generic);
    expect(notifBadgeOf(RichKind.newDeviceLogin).tone, 1);
    expect(notifIsPerson(RichKind.newFollower), isTrue);
    expect(notifIsPerson(RichKind.menuToday), isFalse);
  });

  testWidgets('tümünü okundu yap: POST /notifications/read {all:true}, rozet düşer, nokta söner', (tester) async {
    final be = _be();
    await _mount(tester, be);
    await tester.tap(find.byKey(const ValueKey('notif-mark-all')));
    await settle(tester);
    expect(be.bodies['POST /notifications/read'], {'all': true});
    expect(find.text('3 Yeni'), findsNothing);
    expect(find.byKey(const ValueKey('notif-mark-all')), findsNothing);
    await unmount(tester);
  });

  testWidgets('liste sonu: "Başka bildiriminiz bulunmuyor"', (tester) async {
    await _mount(tester, _be());
    await tester.scrollUntilVisible(find.text('Başka bildiriminiz bulunmuyor'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Başka bildiriminiz bulunmuyor'), findsOneWidget);
    expect(find.text('Önemli kampüs gelişmelerini anında iletmeye devam edeceğiz.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('boş liste: "Henüz bildiriminiz yok."', (tester) async {
    await _mount(tester, _be(items: const [], unread: 0));
    expect(find.text('Henüz bildiriminiz yok.'), findsOneWidget);
    expect(find.text('Tümünü okundu yap'), findsNothing);
    await unmount(tester);
  });

  testWidgets('yükleniyor: iskelet, sonra içerik', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = _be()..delay = const Duration(milliseconds: 400);
    await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Can Öztürk'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('Can Öztürk'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('hata: yüklenemedi kartı + Tekrar dene', (tester) async {
    final be = FakeBackend()..fail('/notifications', status: 500);
    await _mount(tester, be);
    expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
    be.on('/notifications', {'unreadCount': 0, 'nextCursor': null, 'items': <Object>[]});
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester);
    expect(find.text('Henüz bildiriminiz yok.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('bakım (503): bakım bandı + hata kartı', (tester) async {
    final be = FakeBackend()..fail('/notifications', status: 503, code: 'MAINTENANCE');
    await _mount(tester, be);
    expect(find.text('Sistem bakımda.'), findsOneWidget);
    expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('alanlar yoksa (eski sunucu) bozulmaz: avatar/görsel/eylem null güvenli', (tester) async {
    final be = FakeBackend()
      ..on('/notifications', {
        'unreadCount': 1,
        'nextCursor': null,
        'items': [
          {'id': 9, 'type': 'FOLLOW_REQUEST', 'title': 'Biri', 'read': false, 'createdAt': _iso(const Duration(minutes: 1))},
          {'id': 10, 'type': 'UNKNOWN_X', 'title': null, 'body': null, 'read': true, 'createdAt': null, 'data': 'bozuk{'},
        ],
      });
    await _mount(tester, be);
    expect(tester.takeException(), isNull);
    expect(find.text('Biri'), findsOneWidget);
    // Kimlik yoksa Onayla/Reddet çizilmez (yalnız karta dokunuş).
    expect(find.byKey(const ValueKey('notif-accept-9')), findsNothing);
    await unmount(tester);
  });

  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      for (final rtl in [false, true]) {
        testWidgets('taşma yok ${b.name} ${size.width.toInt()} rtl=$rtl', (tester) async {
          useScreen(tester, size);
          await tester.pumpWidget(buildApp(
              Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: NotificationsPage(session: makeSession(_be()))),
              brightness: b,
              size: size));
          await settle(tester);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  }
}
