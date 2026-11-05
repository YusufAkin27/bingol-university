import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/push/notification_push_card.dart';
import 'package:bu_kampus/features/notifications/notification_exam_detail.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';
import 'p00_support.dart';

/// Bildirim tasarımı (2.1.4) ekran görüntüleri: kart aileleri, uygulama içi şerit, gelen kutusu, sınav detayı.
/// Varyantlar: açık 390 x1.0 tr / koyu 390 x1.0 tr / açık 320 x1.3 tr / koyu 320 x1.3 ar (RTL).
/// PNG yazmak için NOTIF_DART_SHOTS_OUT ortam değişkeni; değişken yokken yalnız taşma/istisna denetlenir.
typedef _Item = (String, String, Map<String, dynamic>, int);

const _img = 'https://www.bingol.edu.tr/media/fixture.jpg';

String _iso(Duration d) => DateTime.now().toUtc().add(d).toIso8601String();

List<_Item> _chatEvent() => [
      ('Ayşe Yılmaz', 'Yarınki derse geliyor musun? Kütüphanede çalışacağız.', {'style': 'CHAT_DIRECT', 'type': 'MESSAGE', 'conversationId': '1', 'messageId': '10', 'senderAvatarUrl': _img}, 1),
      ('Bilgisayar Kulübü', 'Mehmet Demir: Toplantı saat 15:00’e alındı. Giriş kat seminer salonundayız.', {'style': 'CHAT_GROUP', 'type': 'MESSAGE', 'conversationId': '2', 'conversationType': 'GROUP', 'conversationTitle': 'Kulüp Odası'}, 1),
      ('Elif Kaya', 'Fotoğraf', {'style': 'CHAT_MEDIA', 'type': 'MESSAGE', 'conversationId': '3', 'imageUrl': _img, 'senderAvatarUrl': _img}, 1),
      ('Zeynep Arslan', 'Kütüphanede 3. kattayım, gelirken notları getirir misin?', {'style': 'CHAT_DIRECT', 'type': 'MESSAGE', 'conversationId': '4', 'messageId': '11', 'senderAvatarUrl': _img}, 3),
      ('Etkinlik yarın başlıyor', 'Yapay Zekâ Atölyesi', {'style': 'EVENT_REMINDER', 'type': 'EVENT', 'eventId': '1', 'sourceName': 'Yazılım Kulübü', 'badgeText': 'Yarın', 'eventStartsAt': _iso(const Duration(days: 1)), 'location': 'Konferans Salonu'}, 1),
      ('Etkinlikte değişiklik', 'Kariyer Günleri saati güncellendi.', {'style': 'EVENT_UPDATE', 'type': 'EVENT', 'eventId': '3', 'sourceName': 'Kariyer Merkezi', 'badgeText': 'Saat Revizesi', 'eventStartsAt': '2026-11-06T11:30:00Z', 'oldStartsAt': '2026-11-06T10:00:00Z', 'newStartsAt': '2026-11-06T11:30:00Z', 'location': 'İİBF Binası'}, 1),
      ('Başvurunuz onaylandı', 'Tasarım Hackathonu katılım kaydınız onaylandı.', {'style': 'EVENT_ADMISSION', 'type': 'EVENT', 'eventId': '4', 'sourceName': 'Bilişim Kulübü'}, 1),
      ('Etkinlik iptal edildi', 'Açık Hava Konseri olumsuz hava koşulları nedeniyle iptal edildi.', {'style': 'EVENT_CANCELLED', 'type': 'EVENT', 'eventId': '5', 'sourceName': 'Müzik Kulübü', 'badgeText': 'İptal'}, 1),
    ];

List<_Item> _newsAcademicMeal() => [
      ('Kampüs Yaşamı', 'Merkezi Kütüphane vize haftası boyunca 7/24 kesintisiz hizmet verecektir.', {'style': 'ANNOUNCEMENT', 'type': 'NEWS', 'newsId': '4', 'imageUrl': _img, 'sourceName': 'Haber'}, 1),
      ('Yeni duyuru', 'Rektörlük: Bahar Dönemi akademik takvimi güncellenmiştir.', {'style': 'ANNOUNCEMENT', 'type': 'ANNOUNCEMENT', 'newsId': '1', 'important': '1'}, 1),
      ('Sınav hatırlatması', 'Veri Yapıları vizesi yarın. Yanınızda öğrenci kimliği bulundurunuz.', {'style': 'EXAM', 'type': 'ANNOUNCEMENT', 'examId': '1', 'eventStartsAt': _iso(const Duration(days: 1)), 'location': 'B-204'}, 1),
      ('Bugünün menüsü', 'Mercimek Çorbası, Orman Kebabı, Pirinç Pilavı, Mevsim Salata', {'style': 'MEAL', 'targetType': 'MEAL', 'imageUrl': _img, 'totalKcal': '820'}, 1),
      ('Yeni anket', 'Yemekhane menüsünden memnun musunuz?', {'style': 'POLL', 'type': 'ANNOUNCEMENT', 'pollId': '1'}, 1),
      ('Anket yarın kapanıyor', 'Güz Dönemi Yemek Hizmetleri Memnuniyet Anketi için son 24 saat.', {'style': 'POLL', 'type': 'ANNOUNCEMENT', 'pollId': '2', 'badgeText': 'Son 24 saat'}, 1),
    ];

List<_Item> _socialSecurity() => [
      ('Mehmet Demir gönderini beğendi', 'Kütüphanede sabahlayanlar kulübü… başlıklı paylaşımına beğeni', {'style': 'LIKE', 'type': 'POST_LIKE', 'postId': '1', 'senderAvatarUrl': _img, 'imageUrl': _img}, 1),
      ('Elif Kaya seni takip etmeye başladı', 'Bilgisayar Mühendisliği · 3. Sınıf', {'style': 'FOLLOW', 'type': 'USER_FOLLOW', 'userId': '2', 'senderAvatarUrl': _img}, 1),
      ('Can Öztürk takip isteği gönderdi', 'Endüstri Mühendisliği', {'style': 'FOLLOW_REQUEST', 'type': 'FOLLOW_REQUEST', 'userId': '3', 'senderAvatarUrl': _img}, 1),
      ('Zeynep Arslan isteğini kabul etti', 'Artık Zeynep Arslan’ın paylaşımlarını görebilirsin.', {'style': 'FOLLOW_ACCEPTED', 'type': 'FOLLOW_ACCEPTED', 'userId': '4', 'senderAvatarUrl': _img}, 1),
      ('Yeni cihazdan giriş', 'Android cihazdan 09:41 tarihinde yeni bir oturum açıldı.', {'style': 'SECURITY', 'type': 'SYSTEM', 'securityKind': 'NEW_DEVICE', 'severity': 'critical'}, 1),
      ('Şifreniz değiştirildi', 'Bu işlemi siz yapmadıysanız hemen şifrenizi sıfırlayın.', {'style': 'SECURITY', 'type': 'SYSTEM', 'securityKind': 'PASSWORD_CHANGED', 'severity': 'critical'}, 1),
      ('İçeriğiniz kaldırıldı', 'Paylaşımınız topluluk kurallarına aykırı bulundu.', {'style': 'MODERATION', 'type': 'SYSTEM'}, 1),
      ('Destek talebinize yanıt verildi', 'Talebiniz için destek ekibi yanıt yazdı.', {'style': 'SUPPORT', 'type': 'SYSTEM', 'ticketId': '1', 'sourceName': 'Destek Masası'}, 1),
    ];

const _variants = <(String, bool, double, double, double, String)>[
  ('light390', false, 390, 1.0, 844, 'tr'),
  ('dark390', true, 390, 1.0, 844, 'tr'),
  ('light320x13', false, 320, 1.3, 800, 'tr'),
  ('dark320x13-ar', true, 320, 1.3, 800, 'ar'),
];

Future<void> _shot(WidgetTester tester, GlobalKey key, String? out, String name) async {
  if (out == null) return;
  // Varlık/ağ görselleri gerçek zamanda çözülür: bekle, bir kare çiz, sonra yakala.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(out)..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  final out = Platform.environment['NOTIF_DART_SHOTS_OUT'];
  setUpAll(loadTestFonts);

  for (final v in _variants) {
    final (tag, dark, width, scale, height, lang) = v;

    for (final sheet in <(String, List<_Item>)>[
      ('cards-1-chat-event', _chatEvent()),
      ('cards-2-news-exam-meal-poll', _newsAcademicMeal()),
      ('cards-3-social-security-support', _socialSecurity()),
    ]) {
      testWidgets('kartlar ${sheet.$1} $tag', (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        useScreen(tester, Size(width, 6400));
        final key = GlobalKey();
        await tester.pumpWidget(p00App(
          Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: key,
                child: Container(
                  width: width,
                  color: dark ? const Color(0xff10121c) : const Color(0xffe9ebf2),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final item in sheet.$2)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NotificationPushCard(
                              title: item.$1, body: item.$2, data: item.$3, count: item.$4, onTap: () {}, onAction: (_) {}, onClose: item.$3['style'] == 'LIKE' ? () {} : null)),
                  ]),
                ),
              ),
            ),
          ),
          dark: dark,
          scale: scale,
          lang: lang,
          scaffold: false,
        ));
        await settle(tester, const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await _shot(tester, key, out, '${sheet.$1}-$tag');
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }

    testWidgets('uygulama içi şerit yığını $tag', (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      useScreen(tester, Size(width, height));
      final key = GlobalKey();
      final cards = <_Item>[
        ('Ayşe Yılmaz', 'Yarınki derse geliyor musun?', {'style': 'CHAT_DIRECT', 'type': 'MESSAGE', 'conversationId': '1', 'senderAvatarUrl': _img}, 1),
        ('Yapay Zekâ Atölyesi', 'Etkinlik yarın başlıyor', {'style': 'EVENT_REMINDER', 'type': 'EVENT', 'eventId': '1', 'eventStartsAt': '2026-11-02T11:00:00Z', 'location': 'Konferans Salonu'}, 1),
        ('Akademik takvim güncellendi', 'Bahar dönemi akademik takvimi güncellendi.', {'style': 'ANNOUNCEMENT', 'type': 'ANNOUNCEMENT', 'newsId': '1', 'important': '1'}, 1),
        ('Zeynep Arslan', 'Notları getirir misin?', {'style': 'CHAT_DIRECT', 'type': 'MESSAGE', 'conversationId': '4', 'senderAvatarUrl': _img}, 3),
      ];
      await tester.pumpWidget(p00App(
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: width,
              color: dark ? const Color(0xff10121c) : const Color(0xfff4f5f8),
              padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final c in cards)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NotificationPushCard(title: c.$1, body: c.$2, data: c.$3, count: c.$4, compact: true, onTap: () {}, onAction: (_) {}, onClose: () {})),
              ]),
            ),
          ),
        ),
        dark: dark,
        scale: scale,
        lang: lang,
        scaffold: false,
      ));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await _shot(tester, key, out, 'strip-$tag');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('gelen kutusu $tag', (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      useScreen(tester, Size(width, scale > 1 ? 1500 : 1300));
      final now = DateTime.now();
      String ago(Duration d) => now.subtract(d).toIso8601String();
      final be = FakeBackend()
        ..on('/notifications', {
          'unreadCount': 3,
          'nextCursor': null,
          'items': [
            {'id': 1, 'type': 'FOLLOW_REQUEST', 'title': 'Can Öztürk', 'body': 'Sana takip isteği gönderdi.', 'read': false, 'data': {'userId': '8'}, 'actorAvatarUrl': _img, 'createdAt': ago(const Duration(minutes: 12))},
            {'id': 2, 'type': 'SYSTEM', 'title': 'Yeni cihazdan giriş', 'body': 'Android cihazdan 09:41 tarihinde oturum açıldı.', 'read': false, 'data': {'securityKind': 'NEW_DEVICE', 'severity': 'critical'}, 'createdAt': ago(const Duration(minutes: 45))},
            {'id': 3, 'type': 'EVENT', 'subtype': 'EVENT_REMINDER', 'title': 'Etkinlik yarın başlıyor', 'body': 'Yapay Zekâ Atölyesi', 'read': false, 'sourceName': 'Yazılım Kulübü', 'data': {'eventId': '5', 'badgeText': 'Yarın', 'eventStartsAt': _iso(const Duration(days: 1)), 'location': 'Konferans Salonu'}, 'createdAt': ago(const Duration(minutes: 50))},
            {'id': 4, 'type': 'ANNOUNCEMENT', 'title': 'Akademik takvim güncellendi', 'body': 'Bahar dönemi akademik takvimi güncellendi.', 'read': true, 'data': {'style': 'ANNOUNCEMENT'}, 'createdAt': ago(const Duration(hours: 3))},
            {'id': 5, 'type': 'ANNOUNCEMENT', 'title': 'Bugünün menüsü', 'body': 'Mercimek Çorbası, Orman Kebabı, Pirinç Pilavı', 'read': true, 'data': {'style': 'MEAL', 'totalKcal': '820', 'targetType': 'MEAL'}, 'createdAt': ago(const Duration(hours: 27))},
            {'id': 6, 'type': 'EVENT', 'subtype': 'EVENT_ADMISSION', 'title': 'Başvurunuz onaylandı', 'body': 'Tasarım Hackathonu katılım kaydınız onaylandı.', 'read': true, 'sourceName': 'Bilişim Kulübü', 'data': {'eventId': '4'}, 'createdAt': ago(const Duration(hours: 30))},
          ],
        });
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: p00App(NotificationsPage(session: makeSession(be)), dark: dark, scale: scale, lang: lang, scaffold: false)));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await _shot(tester, key, out, 'inbox-$tag');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('sınav detayı $tag', (tester) async {
      useScreen(tester, Size(width, height));
      final be = FakeBackend()
        ..on('/timetable/exams', {
          'items': [
            {
              'id': 42,
              'title': 'Veri Yapıları ve Algoritmalar',
              'courseName': 'BLG 222',
              'type': 'VIZE',
              'startsAt': DateTime.now().add(const Duration(hours: 14)).toIso8601String(),
              'endsAt': DateTime.now().add(const Duration(hours: 15, minutes: 30)).toIso8601String(),
              'room': 'B-204 Amfi',
              'note': 'Fotoğraflı öğrenci kimliğinizi yanınızda bulundurunuz.',
            }
          ]
        });
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: p00App(NotificationExamDetail(session: makeSession(be), examId: 42), dark: dark, scale: scale, lang: lang)));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await _shot(tester, key, out, 'exam-$tag');
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
