import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../l10n/app_localizations.dart';
import 'rich_actions.dart';
import 'rich_card.dart';

/// Marka kırmızısı (res/values/colors.xml `notification_accent` ile aynı).
const Color kRichAccent = Color(0xFFF73B2E);

/// Küçük simge (res/drawable `ic_stat_bu`; manifestteki varsayılanla aynı).
const String kRichSmallIcon = 'ic_stat_bu';

/// Çizime hazır görseller (ağ/dosya işi çağıranda biter; bu sınıf saf veridir).
class RichRender {
  const RichRender(this.card, {this.avatar, this.picture, this.tile});

  final RichCard card;

  /// Yuvarlak gönderen avatarı (sayaç/grup rozeti işlenmiş PNG). Kişi kartlarında hep dolu (yedek: baş harf).
  final Uint8List? avatar;

  /// `thumb` ise yuvarlatılmış küçük görsel, `big` ise geniş görsel (JPEG).
  final Uint8List? picture;

  /// Kişi olmayan kartlar için kategori karosu (asset baytları).
  final Uint8List? tile;
}

/// Android kanal başlığı/önemi (kanal zaten yerelde kurulur; burada yalnız eklenti için gerekli ad/önem).
({String name, Importance importance, Priority priority}) channelMeta(String id, AppLocalizations l) {
  switch (id) {
    case 'chat':
      return (name: l.bildirimmobilKanalChat, importance: Importance.high, priority: Priority.high);
    case 'event':
      return (name: l.bildirimmobilKanalEvent, importance: Importance.defaultImportance, priority: Priority.defaultPriority);
    case 'poll':
      return (name: l.bildirimmobilKanalPoll, importance: Importance.defaultImportance, priority: Priority.defaultPriority);
    case 'social':
      return (name: l.bildirimmobilKanalSocial, importance: Importance.low, priority: Priority.low);
    case 'academic':
      return (name: l.bildirimmobilKanalAcademic, importance: Importance.high, priority: Priority.high);
    case 'security':
      return (name: l.bildirimmobilKanalSecurity, importance: Importance.high, priority: Priority.high);
    default:
      return (name: l.bildirimmobilKanalAnnouncement, importance: Importance.defaultImportance, priority: Priority.defaultPriority);
  }
}

AndroidNotificationCategory? _category(RichKind k) {
  if (isMessageKind(k)) return AndroidNotificationCategory.message;
  switch (k) {
    case RichKind.eventTomorrow:
    case RichKind.eventSoon:
    case RichKind.eventUpdate:
    case RichKind.eventApproved:
    case RichKind.eventCancelled:
      return AndroidNotificationCategory.event;
    case RichKind.postLike:
    case RichKind.newFollower:
    case RichKind.followRequest:
    case RichKind.followAccepted:
      return AndroidNotificationCategory.social;
    case RichKind.examReminder:
    case RichKind.classSoon:
    case RichKind.homework:
      return AndroidNotificationCategory.reminder;
    case RichKind.newDeviceLogin:
    case RichKind.passwordChanged:
    case RichKind.twoFaChanged:
    case RichKind.sessionReplaced:
      return AndroidNotificationCategory.status;
    default:
      return null;
  }
}

/// Kart + görseller + dil -> Android bildirim ayrıntıları. SAF (eklenti çağrısı yok): testte alanlar doğrulanır.
///
/// Stil kuralları (tasarımdaki kart):
/// - sohbet (kişi/grup/birikim): MessagingStyle + Person(avatar); grup kartında `conversationTitle` büyük, gönderen küçük;
/// - fotoğraflı mesaj (`imageStyle=big`): BigPicture (geniş görsel), avatar büyük simgede;
/// - `thumb` + kişi kartı (beğeni): avatar büyük simge, gönderi görseli genişletilince BigPicture;
/// - `thumb` + kişi olmayan (haber, menü): küçük görsel sağda (büyük simge);
/// - diğerleri: kategori karosu büyük simge + BigText.
AndroidNotificationDetails buildAndroidDetails(RichRender r, AppLocalizations l, {DateTime? now}) {
  final c = r.card;
  final meta = channelMeta(c.channelId, l);
  final when = now ?? DateTime.now();
  final danger = kRichSpecs[c.kind]?.danger ?? false;
  final person = isPersonKind(c.kind);
  final actions = <AndroidNotificationAction>[
    for (final a in richActionsFor(c, l))
      AndroidNotificationAction(
        a.id,
        a.label,
        // Arka plan eylemini (yanıt/okundu/...) biz kaldırırız (başarısızsa kart kalır ve hata gösterir);
        // arayüz açan eylemde sistem kaldırır.
        cancelNotification: !a.background,
        showsUserInterface: !a.background,
        inputs: a.input ? [AndroidNotificationActionInput(label: l.notifActReplyHint, allowFreeFormInput: true)] : const [],
        semanticAction: a.id == 'reply'
            ? SemanticAction.reply
            : a.id == 'mark_read'
                ? SemanticAction.markAsRead
                : SemanticAction.none,
      ),
  ];

  StyleInformation style;
  AndroidBitmap<Object>? largeIcon;
  final avatarBitmap = r.avatar == null ? null : ByteArrayAndroidBitmap(r.avatar!);
  final tileBitmap = r.tile == null ? null : ByteArrayAndroidBitmap(r.tile!);

  if (isMessageKind(c.kind)) {
    final name = c.senderName.isNotEmpty ? c.senderName : c.title;
    final p = Person(
      name: name,
      key: 'sender:${c.senderName.isNotEmpty ? c.senderName : c.tag}',
      important: true,
      icon: r.avatar == null ? null : ByteArrayAndroidIcon(r.avatar!),
    );
    largeIcon = avatarBitmap;
    if (c.kind == RichKind.photoMessage && r.picture != null) {
      style = BigPictureStyleInformation(
        ByteArrayAndroidBitmap(r.picture!),
        contentTitle: name,
        summaryText: c.body,
        largeIcon: avatarBitmap,
        showBigPictureWhenCollapsed: true,
      );
    } else {
      final group = c.kind == RichKind.groupMessage;
      style = MessagingStyleInformation(
        p,
        conversationTitle: group ? (c.conversationTitle.isNotEmpty ? c.conversationTitle : c.title) : null,
        groupConversation: group,
        messages: [Message(c.body.isNotEmpty ? c.body : c.title, when, p)],
      );
    }
  } else if (person) {
    largeIcon = avatarBitmap ?? tileBitmap;
    style = (c.imageStyle != RichImageStyle.none && r.picture != null)
        ? BigPictureStyleInformation(
            ByteArrayAndroidBitmap(r.picture!),
            contentTitle: c.title,
            summaryText: c.body.isEmpty ? null : c.body,
            largeIcon: largeIcon,
          )
        : BigTextStyleInformation(c.body, contentTitle: c.title);
  } else if (c.imageStyle == RichImageStyle.thumb && r.picture != null) {
    largeIcon = ByteArrayAndroidBitmap(r.picture!);
    style = BigTextStyleInformation(c.body, contentTitle: c.title);
  } else if (c.imageStyle == RichImageStyle.big && r.picture != null) {
    largeIcon = tileBitmap;
    style = BigPictureStyleInformation(
      ByteArrayAndroidBitmap(r.picture!),
      contentTitle: c.title,
      summaryText: c.body.isEmpty ? null : c.body,
      largeIcon: tileBitmap,
    );
  } else {
    largeIcon = tileBitmap;
    style = BigTextStyleInformation(c.body, contentTitle: c.title);
  }

  final header = richHeaderLabel(c, l);
  return AndroidNotificationDetails(
    c.channelId,
    meta.name,
    importance: meta.importance,
    priority: meta.priority,
    icon: kRichSmallIcon,
    color: kRichAccent,
    colorized: false,
    largeIcon: largeIcon,
    styleInformation: style,
    tag: c.tag,
    number: c.count > 1 ? c.count : null,
    subText: header.isEmpty ? null : header,
    category: _category(c.kind),
    // Kilit ekranında kart tam görünür; gövdeyi sunucu önizleme tercihine göre zaten kısıtlar ("Yeni mesaj").
    visibility: NotificationVisibility.public,
    autoCancel: true,
    showWhen: true,
    when: when.millisecondsSinceEpoch,
    onlyAlertOnce: false,
    actions: actions,
    // Güvenlik/iptal kartlarında ışık rengi marka kırmızısı.
    ledColor: danger ? kRichAccent : null,
    enableLights: danger,
  );
}

/// Bildirime iliştirilen yük (dokunuş/eylem sırasında ham FCM verisi geri okunur). JSON, yalnız metin değerleri.
String richPayloadOf(RichCard c) => jsonEncode({
      for (final e in c.data.entries) e.key: '${e.value}',
      '_id': '${c.notificationId}',
    });

/// [richPayloadOf] çıktısını geri çözer; bozuksa boş harita.
Map<String, dynamic> richPayloadParse(String? payload) {
  if (payload == null || payload.isEmpty) return const {};
  try {
    final m = jsonDecode(payload);
    if (m is Map) return {for (final e in m.entries) '${e.key}': e.value};
  } catch (_) {}
  return const {};
}
