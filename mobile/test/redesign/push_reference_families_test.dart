import 'dart:io';
import 'dart:ui' as ui;
import 'package:bu_kampus/core/push/notification_push_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_app.dart';
import '../support/store_shots_images.dart';
import 'p00_support.dart';

const _families = <String, List<(String, String, Map<String, String>)>>{
  '01-sohbet': [
    (
      'Ayşe Yılmaz',
      'Yarınki derse geliyor musun? Kütüphanede çalışacağız.',
      {'type': 'MESSAGE', 'conversationId': '1', 'messageId': '10'}
    ),
    (
      'Bilgisayar Kulübü',
      'Mehmet Demir · Toplantı saat 15:00’e alındı. Giriş kat seminer salonundayız.',
      {
        'type': 'MESSAGE',
        'conversationId': '2',
        'conversationType': 'GROUP',
        'sourceName': 'Kulüp Odası'
      }
    ),
    (
      'Elif Kaya',
      'Fotoğraf',
      {
        'type': 'MESSAGE',
        'conversationId': '3',
        'imageUrl': 'https://fixture.invalid/library.jpg'
      }
    ),
    (
      'Zeynep Arslan',
      'Kütüphanede 3. kattayım, gelirken notları getirir misin?',
      {
        'type': 'MESSAGE',
        'conversationId': '4',
        'messageId': '11',
        'count': '3'
      }
    ),
  ],
  '02-etkinlik': [
    (
      'Etkinlik yarın başlıyor',
      'Yapay Zekâ Atölyesi · Yarın 14:00 · Konferans Salonu',
      {
        'type': 'EVENT',
        'subtype': 'EVENT_REMINDER',
        'eventId': '1',
        'sourceName': 'Yazılım Kulübü'
      }
    ),
    (
      'Etkinlik 1 saat içinde başlıyor',
      'Büyük Veri Zirvesi · 11:00 · Mühendislik Amfisi',
      {
        'type': 'EVENT',
        'subtype': 'EVENT_REMINDER',
        'eventId': '2',
        'badgeText': '1 saat kaldı'
      }
    ),
    (
      'Etkinlikte değişiklik',
      'Kariyer Günleri saati 14:30 olarak güncellendi · İİBF Binası',
      {'type': 'EVENT', 'eventId': '3', 'badgeText': 'Saat Revizesi'}
    ),
    (
      'Başvurunuz onaylandı',
      'Tasarım Hackathonu katılım kaydınız başarıyla onaylandı.',
      {'type': 'EVENT', 'subtype': 'EVENT_ADMISSION', 'eventId': '4'}
    ),
    (
      'Etkinlik iptal edildi',
      'Müzik Kulübü Açık Hava Konseri olumsuz hava koşulları nedeniyle iptal edildi.',
      {'type': 'EVENT', 'eventId': '5', 'badgeText': 'İptal'}
    ),
  ],
  '03-duyuru-ve-haber': [
    (
      'Yeni duyuru',
      'Rektörlük: Bahar Dönemi akademik takvimi senato kararıyla güncellenmiştir.',
      {'type': 'ANNOUNCEMENT', 'newsId': '1', 'badgeText': 'ÖNEMLİ'}
    ),
    (
      'Bölümünüzde yeni duyuru',
      'Bitirme projesi ara teslim raporları için son tarih 15 Kasım saat 17:00 olarak belirlenmiştir.',
      {
        'type': 'ANNOUNCEMENT',
        'subtype': 'ACADEMIC_ANNOUNCEMENT',
        'announcementId': '2',
        'sourceName': 'Bilgisayar Mühendisliği'
      }
    ),
    (
      'Akademik duyuru',
      'Çift anadal ve yan dal başvuru sonuçları Öğrenci Bilgi Sistemi üzerinden ilan edilmiştir.',
      {
        'type': 'ANNOUNCEMENT',
        'subtype': 'ACADEMIC_ANNOUNCEMENT',
        'announcementId': '3',
        'sourceName': 'Öğrenci İşleri'
      }
    ),
    (
      'Kampüs Yaşamı',
      'Merkezi Kütüphane vize haftası boyunca 7/24 kesintisiz hizmet verecektir.',
      {'type': 'NEWS', 'newsId': '4', 'sourceName': 'Güncel Haber'}
    ),
  ],
  '04-akademik': [
    (
      'Sınav hatırlatması',
      'Veri Yapıları vizesi yarın 10:00 · Derslik B-204 · Yanınızda öğrenci kimliği bulundurunuz.',
      {
        'type': 'ANNOUNCEMENT',
        'subtype': 'EXAM_REMINDER',
        'examId': '1',
        'badgeText': 'Yarın 10:00 · B-204'
      }
    ),
    (
      'Ders 30 dk sonra',
      'B-204 · 10:00 · Dr. Öğr. Üyesi Ahmet Yıldırım · İşletim Sistemleri Dersi',
      {
        'style': 'ACADEMIC',
        'targetType': 'TIMETABLE',
        'sourceName': 'Ders Programı'
      }
    ),
    (
      'Ödev teslimi yarın',
      'Algoritmalar ve Karmaşıklık Ödev 2 teslimi için son saat: 23:59',
      {
        'style': 'ACADEMIC',
        'sourceName': 'Akademik',
        'badgeText': '14 saat kaldı'
      }
    ),
    (
      'Yeni not açıklandı',
      'Yazılım Mühendisliği 1. Kısa Sınav (Quiz) notları sisteme yüklendi.',
      {'style': 'ACADEMIC', 'sourceName': 'ÖBS Not'}
    ),
  ],
  '05-yemek-ve-anket': [
    (
      'Bugünün menüsü',
      'Mercimek Çorbası, Orman Kebabı, Pirinç Pilavı, Mevsim Salata',
      {'targetType': 'MEAL', 'badgeText': 'Toplam 820 kcal · Öğle & Akşam'}
    ),
    (
      'Yeni anket',
      'Yemekhane menüsünden memnun musunuz?',
      {'type': 'ANNOUNCEMENT', 'pollId': '1'}
    ),
    (
      'Anket yarın kapanıyor',
      'Güz Dönemi Yemek Hizmetleri Memnuniyet Anketi için son 24 saat.',
      {'type': 'ANNOUNCEMENT', 'pollId': '2', 'badgeText': 'Son 24 saat'}
    ),
  ],
  '06-sosyal': [
    (
      'Mehmet Demir gönderini beğendi',
      'Kütüphanede sabahlayanlar kulübü… başlıklı paylaşımına beğeni',
      {'type': 'POST_LIKE', 'postId': '1'}
    ),
    (
      'Elif Kaya seni takip etmeye başladı',
      'Bilgisayar Mühendisliği · 3. Sınıf',
      {'type': 'USER_FOLLOW', 'userId': '2'}
    ),
    (
      'Can Öztürk takip isteği gönderdi',
      'Endüstri Mühendisliği · 12 ortak arkadaş',
      {'type': 'FOLLOW_REQUEST', 'userId': '3'}
    ),
    (
      'Zeynep Arslan isteğini kabul etti',
      'Artık Zeynep Arslan’ın paylaşımlarını görebilirsin.',
      {'type': 'FOLLOW_ACCEPTED', 'userId': '4'}
    ),
  ],
  '07-guvenlik-ve-destek': [
    (
      'Yeni cihazdan giriş',
      'Samsung Galaxy S24 · Bingöl · Yeni bir cihazdan oturum açıldı.',
      {'type': 'SYSTEM', 'severity': 'critical'}
    ),
    (
      'Şifreniz değiştirildi',
      'Hesap şifreniz başarıyla güncellendi. Bu işlemi siz yapmadıysanız hesabınızı kontrol edin.',
      {'type': 'SYSTEM', 'sourceName': 'Hesap İşlemi'}
    ),
    (
      'İki adımlı doğrulama kapatıldı',
      'Hesap güvenliğiniz için iki adımlı doğrulamayı tekrar aktif etmeniz önerilir.',
      {'type': 'SYSTEM', 'sourceName': 'Güvenlik Önerisi'}
    ),
    (
      'Oturumunuz başka cihazda açıldı',
      'Web Portalı · Chrome (Windows) üzerinden giriş tespit edildi.',
      {'type': 'SYSTEM', 'sourceName': 'Eşzamanlama'}
    ),
    (
      'Destek talebinize yanıt verildi',
      'Öğrenci kartı vizeleme sorunu için destek ekibi yanıt yazdı.',
      {'type': 'SYSTEM', 'ticketId': '1', 'sourceName': 'Destek Masası'}
    ),
  ],
};

void main() {
  final out = Platform.environment['PUSH_REFERENCE_SHOTS_OUT'];
  setUpAll(loadTestFonts);
  for (final entry in _families.entries) {
    testWidgets('reference push family ${entry.key}', (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      useScreen(tester, Size(390, entry.value.length * 255.0 + 180));
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: p00App(
            Scaffold(
                backgroundColor: const Color(0xff10121c),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
                  child: Column(children: [
                    const Icon(Icons.lock_outline,
                        size: 18, color: Colors.white54),
                    const SizedBox(height: 12),
                    const Text('09:41',
                        style: TextStyle(
                            fontSize: 58,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 24),
                    for (final item in entry.value)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NotificationPushCard(
                            title: item.$1,
                            body: item.$2,
                            data: {
                              ...item.$3,
                              'senderAvatarUrl':
                                  'https://fixture.invalid/avatar.jpg'
                            },
                            count: int.tryParse(item.$3['count'] ?? '') ?? 1,
                            onTap: () {},
                            onAction: (_) {},
                            onClose: entry.key == '06-sosyal' ? () {} : null,
                          )),
                  ]),
                )),
            scaffold: false,
          )));
      await settle(tester, const Duration(seconds: 2));
      await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (out != null)
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(out)..createSync(recursive: true);
          File('${dir.path}/${entry.key}.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
        });
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });
  }
  testWidgets('message card remains accessible at 320dp and larger text',
      (tester) async {
    useScreen(tester, const Size(320, 800));
    await tester.pumpWidget(p00App(
        NotificationPushCard(
            title: 'Çok uzun bir grup ve gönderen adı',
            body:
                'Mesaj önizlemesi dar ekranda düğmelerin taşmasına neden olmamalıdır.',
            data: const {
              'type': 'MESSAGE',
              'conversationId': '1',
              'conversationType': 'GROUP'
            },
            onTap: () {},
            onAction: (_) {},
            onClose: () {}),
        scale: 1.4));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
