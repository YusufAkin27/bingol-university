import 'dart:typed_data';

import 'package:bu_kampus/core/push/rich/rich_actions.dart';
import 'package:bu_kampus/core/push/rich/rich_card.dart';
import 'package:bu_kampus/core/push/rich/rich_notifier.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'dart:ui' show Locale;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tasarımdaki 28 bildirim kartı: yük -> kart türü -> Android ayrıntıları (stil, eylem düğmeleri, kanal, etiket).
/// Sözleşme: NOTIF-CONTRACT.md (backend aynı anahtarları gönderir).

final _tr = lookupAppLocalizations(const Locale('tr'));
final _en = lookupAppLocalizations(const Locale('en'));
final _ar = lookupAppLocalizations(const Locale('ar'));
final _png = Uint8List.fromList(const [137, 80, 78, 71]);

class _Case {
  const _Case(this.no, this.name, this.kind, this.data, this.labels, {this.style, this.channel});

  final int no;
  final String name;
  final RichKind kind;
  final Map<String, String> data;

  /// Beklenen eylem düğmesi etiketleri (tasarımdaki birebir Türkçe metin).
  final List<String> labels;
  final Type? style;
  final String? channel;
}

Map<String, String> _d(Map<String, String> m) => {'richChat': '1', ...m};

final _cases = <_Case>[
  _Case(1, 'birebir mesaj', RichKind.directMessage,
      _d({'type': 'MESSAGE', 'subtype': 'MESSAGE_DIRECT', 'title': 'Ayşe Yılmaz', 'body': 'Yarınki derse geliyor musun?', 'senderName': 'Ayşe Yılmaz', 'conversationId': '7', 'channelId': 'chat', 'tag': 'conv:7', 'actions': 'reply,mark_read'}),
      ['Yanıtla', 'Okundu İşaretle'],
      style: MessagingStyleInformation, channel: 'chat'),
  _Case(2, 'kulüp odası', RichKind.groupMessage,
      _d({'type': 'MESSAGE', 'subtype': 'MESSAGE_GROUP', 'title': 'Bilgisayar Kulübü · Mehmet Demir', 'body': 'Toplantı saat 15:00\'e alındı.', 'senderName': 'Mehmet Demir', 'conversationTitle': 'Bilgisayar Kulübü', 'groupBadge': '1', 'conversationId': '9', 'channelId': 'chat', 'tag': 'conv:9', 'actions': 'reply,mute_1h'}),
      ['Yanıtla', '1 Saat Sessize Al'],
      style: MessagingStyleInformation),
  _Case(3, 'fotoğraflı mesaj', RichKind.photoMessage,
      _d({'type': 'MESSAGE', 'title': 'Elif Kaya', 'body': 'Fotoğraf', 'senderName': 'Elif Kaya', 'conversationId': '4', 'imageUrl': 'https://x.bingol.edu.tr/a.jpg', 'imageStyle': 'big', 'channelId': 'chat', 'actions': 'view,reply'}),
      ['Görüntüle', 'Yanıtla'],
      style: BigPictureStyleInformation),
  _Case(4, '3 yeni mesaj', RichKind.messageBurst,
      _d({'type': 'MESSAGE', 'title': 'Zeynep Arslan', 'body': 'Kütüphanede 3. kattayım', 'senderName': 'Zeynep Arslan', 'conversationId': '5', 'count': '3', 'channelId': 'chat', 'actions': 'reply,mark_read'}),
      ['Hızlı Yanıtla', 'Tümünü Aç'],
      style: MessagingStyleInformation),
  _Case(5, 'etkinlik yarın', RichKind.eventTomorrow,
      _d({'type': 'EVENT', 'subtype': 'EVENT_REMINDER', 'title': 'Etkinlik yarın başlıyor', 'body': 'Yapay Zekâ Atölyesi · Yarın 14:00 · Konferans Salonu', 'eventId': '3', 'channelId': 'event', 'actions': 'calendar,view'}),
      ['Takvime Ekle', 'Detay'],
      style: BigTextStyleInformation, channel: 'event'),
  _Case(6, 'etkinlik 1 saat', RichKind.eventSoon,
      _d({'type': 'EVENT', 'subtype': 'EVENT_REMINDER', 'title': 'Etkinlik 1 saat içinde başlıyor', 'body': 'Büyük Veri Zirvesi · 11:00', 'eventId': '3', 'channelId': 'event', 'actions': 'qr_checkin'}),
      ['QR ile Giriş']),
  _Case(7, 'etkinlikte değişiklik', RichKind.eventUpdate,
      _d({'type': 'EVENT', 'subtype': 'EVENT_UPDATE', 'title': 'Etkinlikte değişiklik', 'body': 'Saat 13:00 → 14:30', 'eventId': '3', 'channelId': 'event', 'actions': 'view'}),
      ['Detay']),
  _Case(8, 'başvuru onaylandı', RichKind.eventApproved,
      _d({'type': 'EVENT', 'subtype': 'EVENT_ADMISSION', 'title': 'Başvurunuz onaylandı', 'body': 'Hackathon', 'eventId': '3', 'channelId': 'event', 'actions': 'view'}),
      ['Detay']),
  _Case(9, 'etkinlik iptal', RichKind.eventCancelled,
      _d({'type': 'EVENT', 'subtype': 'EVENT_UPDATE', 'cancelled': '1', 'title': 'Etkinlik iptal edildi', 'body': 'Açık Hava Konseri · olumsuz hava', 'eventId': '3', 'channelId': 'event', 'actions': 'view'}),
      ['Detay']),
  _Case(10, 'yeni duyuru', RichKind.announcement,
      _d({'type': 'ANNOUNCEMENT', 'title': 'Yeni duyuru', 'body': 'Rektörlük: akademik takvim güncellendi', 'targetType': 'ANNOUNCEMENT', 'targetId': '12', 'channelId': 'announcement', 'actions': 'view'}),
      ['Görüntüle'],
      channel: 'announcement'),
  _Case(11, 'bölümünüzde yeni duyuru', RichKind.deptAnnouncement,
      _d({'type': 'ANNOUNCEMENT', 'subtype': 'DEPT_ANNOUNCEMENT', 'title': 'Bölümünüzde yeni duyuru', 'body': 'Bitirme projesi ara teslim', 'label': 'Bilgisayar Mühendisliği', 'targetType': 'ANNOUNCEMENT_DEPT', 'targetId': '4', 'channelId': 'announcement', 'actions': 'view'}),
      ['Görüntüle']),
  _Case(12, 'akademik duyuru', RichKind.academicAnnouncement,
      _d({'type': 'ANNOUNCEMENT', 'subtype': 'ACADEMIC_ANNOUNCEMENT', 'title': 'Akademik duyuru', 'body': 'Çift anadal sonuçları', 'channelId': 'academic', 'actions': 'view'}),
      ['Görüntüle'],
      channel: 'academic'),
  _Case(13, 'haber', RichKind.news,
      _d({'type': 'NEWS', 'title': 'Kampüs Yaşamı', 'body': 'Merkezi Kütüphane vize haftası', 'newsId': '5', 'imageUrl': 'https://x.bingol.edu.tr/n.jpg', 'imageStyle': 'thumb', 'channelId': 'announcement', 'actions': 'view'}),
      ['Görüntüle']),
  _Case(14, 'sınav hatırlatması', RichKind.examReminder,
      _d({'type': 'ANNOUNCEMENT', 'subtype': 'EXAM_REMINDER', 'title': 'Sınav hatırlatması', 'body': 'Veri Yapıları · yarın 10:00 · B-204', 'channelId': 'academic', 'actions': 'exam_card'}),
      ['Sınav Belgesi']),
  _Case(15, 'ders 30 dk sonra', RichKind.classSoon,
      _d({'type': 'ANNOUNCEMENT', 'subtype': 'CLASS_REMINDER', 'title': 'Ders 30 dk sonra', 'body': 'B-204 · 10:00', 'channelId': 'academic', 'actions': 'open_schedule'}),
      ['Programı Aç']),
  _Case(16, 'ödev teslimi', RichKind.homework,
      _d({'type': 'ANNOUNCEMENT', 'subtype': 'HOMEWORK_DUE', 'title': 'Ödev teslimi yarın', 'body': 'Algoritmalar · 23:59', 'channelId': 'academic', 'actions': 'view'}),
      ['Görüntüle']),
  _Case(17, 'bugünün menüsü', RichKind.menuToday,
      _d({'type': 'ANNOUNCEMENT', 'subtype': 'MENU_DAILY', 'title': 'Bugünün menüsü', 'body': 'Mercimek, Orman Kebabı · Toplam 1250 kcal', 'imageUrl': 'https://x.bingol.edu.tr/m.jpg', 'imageStyle': 'thumb', 'channelId': 'announcement', 'actions': 'view'}),
      ['Görüntüle']),
  _Case(18, 'yeni anket', RichKind.pollNew,
      _d({'type': 'ANNOUNCEMENT', 'subtype': 'POLL', 'title': 'Yeni anket', 'body': 'Kampüs yemek memnuniyeti', 'pollId': '2', 'channelId': 'poll', 'actions': 'vote'}),
      ['Oy ver'],
      channel: 'poll'),
  _Case(19, 'anket yarın kapanıyor', RichKind.pollClosing,
      _d({'type': 'ANNOUNCEMENT', 'subtype': 'POLL_CLOSING', 'title': 'Anket yarın kapanıyor', 'body': 'Son 24 saat', 'pollId': '2', 'channelId': 'poll', 'actions': 'vote'}),
      ['Oy ver']),
  _Case(20, 'beğeni', RichKind.postLike,
      _d({'type': 'POST_LIKE', 'title': 'Elif gönderini beğendi', 'body': '', 'senderName': 'Elif', 'postId': '8', 'imageUrl': 'https://x.bingol.edu.tr/p.jpg', 'imageStyle': 'thumb', 'channelId': 'social', 'actions': 'view'}),
      ['Görüntüle'],
      channel: 'social'),
  _Case(21, 'yeni takipçi', RichKind.newFollower,
      _d({'type': 'USER_FOLLOW', 'title': 'Can seni takip etmeye başladı', 'body': 'Bilgisayar Müh. · 3. sınıf', 'senderName': 'Can', 'targetType': 'USER', 'targetId': '33', 'channelId': 'social', 'actions': 'follow_back'}),
      ['Takip et']),
  _Case(22, 'takip isteği', RichKind.followRequest,
      _d({'type': 'FOLLOW_REQUEST', 'title': 'Can takip isteği gönderdi', 'body': 'İşletme', 'senderName': 'Can', 'senderId': '33', 'channelId': 'social', 'actions': 'accept,reject'}),
      ['Onayla', 'Reddet']),
  _Case(23, 'istek kabul', RichKind.followAccepted,
      _d({'type': 'FOLLOW_ACCEPTED', 'title': 'Can takip isteğini kabul etti', 'body': '', 'senderName': 'Can', 'targetType': 'USER', 'targetId': '33', 'channelId': 'social', 'actions': 'view'}),
      ['Profili Gör']),
  _Case(24, 'yeni cihazdan giriş', RichKind.newDeviceLogin,
      _d({'type': 'SYSTEM', 'subtype': 'NEW_DEVICE_LOGIN', 'title': 'Yeni cihazdan giriş', 'body': 'Samsung Galaxy S24 · 09:41', 'channelId': 'security', 'actions': 'not_me,view'}),
      ['Bu ben değilim', 'Görüntüle'],
      channel: 'security'),
  _Case(25, 'şifre değişti', RichKind.passwordChanged,
      _d({'type': 'SYSTEM', 'subtype': 'PASSWORD_CHANGED', 'title': 'Şifreniz değiştirildi', 'body': 'Siz yapmadıysanız hemen şifrenizi sıfırlayın.', 'channelId': 'security', 'actions': 'reset_password'}),
      ['Hemen Sıfırla']),
  _Case(26, '2FA', RichKind.twoFaChanged,
      _d({'type': 'SYSTEM', 'subtype': 'TWO_FA_DISABLED', 'title': 'İki adımlı doğrulama kapatıldı', 'body': 'Hesabınızı korumak için açın.', 'channelId': 'security', 'actions': 'enable_2fa'}),
      ['2FA Aç']),
  _Case(27, 'oturum başka cihazda', RichKind.sessionReplaced,
      _d({'type': 'SYSTEM', 'subtype': 'SESSION_REPLACED', 'title': 'Oturumunuz başka cihazda açıldı', 'body': 'Android oturumu', 'channelId': 'security', 'actions': 'sign_out_device'}),
      ['Cihazı Çıkar']),
  _Case(28, 'destek yanıtı', RichKind.supportReply,
      _d({'type': 'SYSTEM', 'title': 'Destek talebinize yanıt verildi', 'body': '#41 Şifre sorunu', 'targetType': 'TICKET', 'targetId': '41', 'channelId': 'announcement', 'actions': 'view_ticket'}),
      ['Talebi Görüntüle']),
];

void main() {
  test('28 kartın tamamı tabloda ve kart türleri benzersiz', () {
    expect(_cases.length, 28);
    expect(_cases.map((c) => c.kind).toSet().length, 28);
    // enum: 28 kart + generic
    expect(RichKind.values.length, 29);
  });

  for (final c in _cases) {
    group('kart ${c.no} ${c.name}', () {
      final card = RichCard.tryParse(c.data)!;

      test('tür doğru çözülür', () {
        expect(card.kind, c.kind);
      });

      test('eylem düğmeleri tasarımdaki etiketlerle ve sırayla', () {
        expect(richActionsFor(card, _tr).map((a) => a.label).toList(), c.labels);
      });

      test('Android ayrıntıları: kanal, etiket, simge, vurgu rengi, gizlilik', () {
        final d = buildAndroidDetails(RichRender(card, avatar: _png, picture: _png, tile: _png), _tr);
        expect(d.channelId, c.channel ?? card.channelId);
        expect(d.tag, card.tag);
        expect(d.icon, 'ic_stat_bu');
        expect(d.color, kRichAccent);
        expect(d.visibility, NotificationVisibility.public);
        expect(d.actions!.map((a) => a.title).toList(), c.labels);
        if (c.style != null) expect(d.styleInformation.runtimeType, c.style);
      });

      test('eylem kimliği -> arka plan/arayüz ayrımı tutarlı', () {
        final d = buildAndroidDetails(RichRender(card, avatar: _png, tile: _png), _tr);
        for (final a in richActionsFor(card, _tr)) {
          final na = d.actions!.firstWhere((x) => x.id == a.id);
          expect(na.showsUserInterface, !a.background, reason: a.id);
          expect(na.cancelNotification, !a.background, reason: a.id);
        }
      });
    });
  }

  group('kart ayrıntıları', () {
    RichCard parse(Map<String, String> m) => RichCard.tryParse(_d(m))!;

    test('sohbet etiketi (tag) ve kimlik: aynı sohbet tek kart (çökme)', () {
      final a = parse({'type': 'MESSAGE', 'title': 'A', 'body': 'x', 'conversationId': '7', 'tag': 'conv:7'});
      final b = parse({'type': 'MESSAGE', 'title': 'A', 'body': 'başka', 'conversationId': '7', 'tag': 'conv:7'});
      final c = parse({'type': 'MESSAGE', 'title': 'B', 'body': 'x', 'conversationId': '8', 'tag': 'conv:8'});
      expect(a.notificationId, b.notificationId);
      expect(a.notificationId, isNot(c.notificationId));
      expect(a.notificationId, richNotificationId('conv:7'));
      expect(a.notificationId, greaterThan(0)); // 31 bit
    });

    test('etiket yoksa sohbet kimliğinden türetilir', () {
      expect(parse({'type': 'MESSAGE', 'title': 'A', 'body': 'x', 'conversationId': '7'}).tag, 'conv:7');
    });

    test('sayaç > 1: number ve üst etiket "N yeni mesaj"', () {
      final card = parse({'type': 'MESSAGE', 'title': 'Z', 'body': 'x', 'senderName': 'Z', 'count': '3', 'conversationId': '5', 'actions': 'reply'});
      final d = buildAndroidDetails(RichRender(card, avatar: _png), _tr);
      expect(d.number, 3);
      expect(d.subText, '3 yeni mesaj');
      expect(buildAndroidDetails(RichRender(card, avatar: _png), _en).subText, '3 new messages');
    });

    test('sunucu `label` üst etiketi ezer (bölüm adı)', () {
      final card = parse({'type': 'ANNOUNCEMENT', 'subtype': 'DEPT_ANNOUNCEMENT', 'title': 'x', 'body': 'y', 'label': 'Bilgisayar Mühendisliği'});
      expect(buildAndroidDetails(RichRender(card, tile: _png), _tr).subText, 'Bilgisayar Mühendisliği');
    });

    test('kişi mesajı: MessagingStyle Person adı + avatar; grup: konuşma başlığı', () {
      final dm = parse({'type': 'MESSAGE', 'title': 'Ayşe', 'body': 'selam', 'senderName': 'Ayşe', 'conversationId': '1'});
      final s = buildAndroidDetails(RichRender(dm, avatar: _png), _tr).styleInformation as MessagingStyleInformation;
      expect(s.person.name, 'Ayşe');
      expect(s.person.icon, isA<ByteArrayAndroidIcon>());
      expect(s.groupConversation, isFalse);
      expect(s.messages!.single.text, 'selam');

      final g = parse({'type': 'MESSAGE', 'title': 'Kulüp · Mehmet', 'body': 'merhaba', 'senderName': 'Mehmet', 'conversationTitle': 'Kulüp', 'groupBadge': '1', 'conversationId': '2'});
      final gs = buildAndroidDetails(RichRender(g, avatar: _png), _tr).styleInformation as MessagingStyleInformation;
      expect(gs.groupConversation, isTrue);
      expect(gs.conversationTitle, 'Kulüp');
      expect(gs.person.name, 'Mehmet');
    });

    test('fotoğraf: geniş görsel BigPicture, görsel inmediyse MessagingStyle yedeği', () {
      final card = parse({'type': 'MESSAGE', 'title': 'Elif', 'body': 'Fotoğraf', 'senderName': 'Elif', 'conversationId': '4', 'imageUrl': 'https://x.bingol.edu.tr/a.jpg', 'imageStyle': 'big'});
      expect(buildAndroidDetails(RichRender(card, avatar: _png, picture: _png), _tr).styleInformation, isA<BigPictureStyleInformation>());
      expect(buildAndroidDetails(RichRender(card, avatar: _png), _tr).styleInformation, isA<MessagingStyleInformation>());
    });

    test('haber/menü `thumb`: küçük görsel büyük simgede; beğeni `thumb`: avatar büyük simgede, görsel genişletilince', () {
      final news = parse({'type': 'NEWS', 'title': 'Haber', 'body': 'özet', 'imageUrl': 'https://x.bingol.edu.tr/n.jpg', 'imageStyle': 'thumb'});
      final pic = Uint8List.fromList(const [1, 2, 3]);
      final dn = buildAndroidDetails(RichRender(news, picture: pic, tile: _png), _tr);
      expect((dn.largeIcon as ByteArrayAndroidBitmap).data, pic);

      final like = parse({'type': 'POST_LIKE', 'title': 'Elif beğendi', 'body': '', 'senderName': 'Elif', 'imageUrl': 'https://x.bingol.edu.tr/p.jpg', 'imageStyle': 'thumb'});
      final dl = buildAndroidDetails(RichRender(like, avatar: _png, picture: pic), _tr);
      expect((dl.largeIcon as ByteArrayAndroidBitmap).data, _png);
      expect(dl.styleInformation, isA<BigPictureStyleInformation>());
    });

    test('görsel yoksa kategori karosu büyük simge olur', () {
      final card = parse({'type': 'EVENT', 'subtype': 'EVENT_REMINDER', 'title': 'x', 'body': 'y', 'actions': 'view'});
      final d = buildAndroidDetails(RichRender(card, tile: _png), _tr);
      expect((d.largeIcon as ByteArrayAndroidBitmap).data, _png);
    });

    test('reply eyleminin satır içi giriş alanı var; diğerlerinde yok', () {
      final card = parse({'type': 'MESSAGE', 'title': 'A', 'body': 'x', 'senderName': 'A', 'conversationId': '1', 'actions': 'reply,mark_read,mute_1h'});
      final acts = buildAndroidDetails(RichRender(card, avatar: _png), _tr).actions!;
      expect(acts.firstWhere((a) => a.id == 'reply').inputs, isNotEmpty);
      expect(acts.firstWhere((a) => a.id == 'mark_read').inputs, isEmpty);
      expect(acts.firstWhere((a) => a.id == 'reply').semanticAction, SemanticAction.reply);
    });

    test('etiketler EN ve AR dilinde de dolu (boş etiket yok)', () {
      for (final l in [_en, _ar]) {
        for (final c in _cases) {
          final card = RichCard.tryParse(c.data)!;
          for (final a in richActionsFor(card, l)) {
            expect(a.label.trim(), isNotEmpty, reason: '${c.name} ${a.id}');
          }
        }
      }
      expect(richActionsFor(RichCard.tryParse(_cases[0].data)!, _en).map((a) => a.label), ['Reply', 'Mark as read']);
    });

    test('bilinmeyen eylem kimliği çizilmez, bildirim yine görünür', () {
      final card = parse({'type': 'ANNOUNCEMENT', 'title': 'T', 'body': 'B', 'actions': 'view,teleport,shred'});
      expect(card.actions, ['view', 'teleport', 'shred']);
      expect(richActionsFor(card, _tr).map((a) => a.id), ['view']);
      final d = buildAndroidDetails(RichRender(card, tile: _png), _tr);
      expect(d.actions!.map((a) => a.id), ['view']);
    });

    test('en çok 3 eylem düğmesi çizilir', () {
      final card = parse({'type': 'MESSAGE', 'title': 'A', 'body': 'x', 'senderName': 'A', 'conversationId': '1', 'actions': 'reply,mark_read,mute_1h,view'});
      expect(richActionsFor(card, _tr).length, 3);
    });

    test('yük zengin değilse (richChat yok) kart oluşmaz: eski yol aynen kalır', () {
      expect(RichCard.tryParse({'type': 'MESSAGE', 'title': 'A', 'body': 'x'}), isNull);
      expect(RichCard.isRich({'richChat': '0'}), isFalse);
      expect(RichCard.isRich(null), isFalse);
      expect(RichCard.tryParse({'richChat': '1'}), isNull); // başlık+gövde boş
    });

    test('bilinmeyen tür/alt tür: generic kart, kanal duyuruya düşer, eylemsiz de çizilir', () {
      final card = parse({'type': 'FOO', 'title': 'Bir şey', 'body': 'oldu', 'channelId': 'bilinmeyen'});
      expect(card.kind, RichKind.generic);
      expect(card.channelId, 'announcement');
      expect(buildAndroidDetails(RichRender(card, tile: _png), _tr).actions, isEmpty);
    });

    test('yük anahtarları sayısal olmayan/bozuk değerlerde atmaz', () {
      final card = parse({'type': 'MESSAGE', 'title': 'A', 'body': 'x', 'count': 'abc', 'imageStyle': '??', 'actions': ' , ,reply,,'});
      expect(card.count, 1);
      expect(card.imageStyle, RichImageStyle.none);
      expect(card.actions, ['reply']);
    });

    test('payload gidiş-dönüş: ham yük ve bildirim kimliği korunur', () {
      final card = RichCard.tryParse(_cases[0].data)!;
      final back = richPayloadParse(richPayloadOf(card));
      expect(back['conversationId'], '7');
      expect(back['richChat'], '1');
      expect(back['_id'], '${card.notificationId}');
      expect(richPayloadParse('bozuk{'), isEmpty);
      expect(richPayloadParse(null), isEmpty);
    });
  });
}
