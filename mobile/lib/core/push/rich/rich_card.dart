import '../../../l10n/app_localizations.dart';

/// Zengin (veri-mesajı) bildirim kartı modeli — SAF Dart: eklenti, ağ ve UI yok (arka plan isolate'inde ve testlerde
/// aynen çalışır). Sözleşme: `docs/design/BILDIRIM_SOZLESMESI` / NOTIF-CONTRACT (FCM `data`, `richChat=1`).

/// Tasarımdaki 28 kart + bilinmeyen yük için [generic].
enum RichKind {
  directMessage, // 1
  groupMessage, // 2
  photoMessage, // 3
  messageBurst, // 4
  eventTomorrow, // 5
  eventSoon, // 6
  eventUpdate, // 7
  eventApproved, // 8
  eventCancelled, // 9
  announcement, // 10
  deptAnnouncement, // 11
  academicAnnouncement, // 12
  news, // 13
  examReminder, // 14
  classSoon, // 15
  homework, // 16
  menuToday, // 17
  pollNew, // 18
  pollClosing, // 19
  postLike, // 20
  newFollower, // 21
  followRequest, // 22
  followAccepted, // 23
  newDeviceLogin, // 24
  passwordChanged, // 25
  twoFaChanged, // 26
  sessionReplaced, // 27
  supportReply, // 28
  generic,
}

/// Sunucu kanal kimlikleri (Android kanal tablosuyla aynı).
const Set<String> kRichChannels = {'chat', 'event', 'announcement', 'poll', 'social', 'academic', 'security'};

/// Sohbet bildirimi (kişi/grup/fotoğraf/birikim) mi: MessagingStyle + avatar kullanır.
bool isMessageKind(RichKind k) =>
    k == RichKind.directMessage || k == RichKind.groupMessage || k == RichKind.photoMessage || k == RichKind.messageBurst;

/// Sosyal kartlar (gönderen avatarı vardır; sistem karosu değil).
bool isPersonKind(RichKind k) =>
    isMessageKind(k) ||
    k == RichKind.postLike ||
    k == RichKind.newFollower ||
    k == RichKind.followRequest ||
    k == RichKind.followAccepted;

enum RichImageStyle { none, big, thumb }

String _s(Object? v) => v == null ? '' : '$v'.trim();

int? _int(Object? v) {
  final n = v == null ? null : int.tryParse('$v');
  return n != null && n > 0 ? n : null;
}

bool _flag(Object? v) {
  final s = _s(v).toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

class RichCard {
  RichCard._({
    required this.kind,
    required this.title,
    required this.body,
    required this.channelId,
    required this.tag,
    required this.type,
    required this.subtype,
    required this.count,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.imageUrl,
    required this.imageStyle,
    required this.groupBadge,
    required this.conversationTitle,
    required this.label,
    required this.actions,
    required this.data,
  });

  final RichKind kind;
  final String title;
  final String body;
  final String channelId;

  /// Çökme anahtarı: aynı etiketli bildirim öncekinin yerine geçer (sohbet başına tek kart).
  final String tag;
  final String type;
  final String subtype;

  /// Birikim sayacı (`count`, yalnız > 1 anlamlı).
  final int count;
  final String senderName;
  final String? senderAvatarUrl;
  final String? imageUrl;
  final RichImageStyle imageStyle;
  final bool groupBadge;
  final String conversationTitle;

  /// Üst etiket (bölüm adı, kulüp adı...) — sunucu gönderirse sınıf adının yerine geçer (`label`).
  final String label;

  /// Sunucunun istediği eylem kimlikleri (sıralı, tekil; bilinmeyenler dahil — çizimde süzülür).
  final List<String> actions;

  /// Ham yük (dokunuş/eylemde yönlendirme ve istek için).
  final Map<String, dynamic> data;

  /// `richChat=1` mi (eski yol için: yoksa standart bildirim davranışı aynen kalır).
  static bool isRich(Map<String, dynamic>? d) => d != null && _flag(d['richChat']);

  /// Zengin değilse veya başlık+gövde ikisi de boşsa null.
  static RichCard? tryParse(Map<String, dynamic>? raw) {
    if (!isRich(raw)) return null;
    final d = <String, dynamic>{for (final e in raw!.entries) e.key: e.value};
    final title = _s(d['title']);
    final body = _s(d['body']);
    if (title.isEmpty && body.isEmpty) return null;

    final actions = <String>[
      for (final a in _s(d['actions']).split(','))
        if (a.trim().isNotEmpty) a.trim().toLowerCase(),
    ];
    final uniq = <String>[];
    for (final a in actions) {
      if (!uniq.contains(a)) uniq.add(a);
    }
    final count = _int(d['count']) ?? 1;
    final style = switch (_s(d['imageStyle']).toLowerCase()) {
      'big' => RichImageStyle.big,
      'thumb' => RichImageStyle.thumb,
      _ => RichImageStyle.none,
    };
    final kind = resolveRichKind(d, uniq, count: count, style: style);
    var channel = _s(d['channelId']).toLowerCase();
    if (!kRichChannels.contains(channel)) channel = defaultChannelOf(kind);
    final avatar = _s(d['senderAvatarUrl']);
    final image = _s(d['imageUrl']);
    var tag = _s(d['tag']);
    if (tag.isEmpty) {
      final c = _s(d['conversationId']);
      final tid = _s(d['targetId']);
      tag = c.isNotEmpty ? 'conv:$c' : '${kind.name}:${tid.isNotEmpty ? tid : richNotificationId(title).toRadixString(16)}';
    }
    return RichCard._(
      kind: kind,
      title: title,
      body: body,
      channelId: channel,
      tag: tag,
      type: _s(d['type']).toUpperCase(),
      subtype: _s(d['subtype']).toUpperCase(),
      count: count,
      senderName: _s(d['senderName']),
      senderAvatarUrl: avatar.isEmpty ? null : avatar,
      imageUrl: image.isEmpty ? null : image,
      imageStyle: image.isEmpty ? RichImageStyle.none : style,
      groupBadge: _flag(d['groupBadge']),
      conversationTitle: _s(d['conversationTitle']),
      label: _s(d['label']),
      actions: List.unmodifiable(uniq),
      data: Map.unmodifiable(d),
    );
  }

  /// Bildirim kimliği: etiketten kararlı (FNV-1a; `String.hashCode` süreçler arası kararlı DEĞİLDİR).
  int get notificationId => richNotificationId(tag);
}

/// Etiketten 31 bitlik kararlı kimlik (aynı sohbet = aynı kimlik = çökme).
int richNotificationId(String tag) {
  var h = 0x811c9dc5;
  for (final u in tag.codeUnits) {
    h ^= u & 0xff;
    h = (h * 0x01000193) & 0xffffffff;
    h ^= (u >> 8) & 0xff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// Varsayılan kanal (yük kanal göndermezse/bilinmeyen gönderirse).
String defaultChannelOf(RichKind k) {
  switch (k) {
    case RichKind.directMessage:
    case RichKind.groupMessage:
    case RichKind.photoMessage:
    case RichKind.messageBurst:
      return 'chat';
    case RichKind.eventTomorrow:
    case RichKind.eventSoon:
    case RichKind.eventUpdate:
    case RichKind.eventApproved:
    case RichKind.eventCancelled:
      return 'event';
    case RichKind.academicAnnouncement:
    case RichKind.examReminder:
    case RichKind.classSoon:
    case RichKind.homework:
      return 'academic';
    case RichKind.pollNew:
    case RichKind.pollClosing:
      return 'poll';
    case RichKind.postLike:
    case RichKind.newFollower:
    case RichKind.followRequest:
    case RichKind.followAccepted:
      return 'social';
    case RichKind.newDeviceLogin:
    case RichKind.passwordChanged:
    case RichKind.twoFaChanged:
    case RichKind.sessionReplaced:
      return 'security';
    default:
      return 'announcement';
  }
}

/// Backend `NotifCard` sabit adı -> mobil kart türü (push `data.card` ve bildirim satırı `card`). Backend'in `card`
/// alanı kart kararını tek yerde verir (alt tür adları tek başına EVENT_HOUR/POLL_CLOSING/iptal ayrımını taşımaz).
/// Tabloda olmayan değer null döner; çağıran eski alt tür/eylem yoluna düşer.
const Map<String, RichKind> kBackendCardKinds = {
  'CHAT_DM': RichKind.directMessage,
  'CHAT_GROUP': RichKind.groupMessage,
  'CHAT_PHOTO': RichKind.photoMessage,
  'CHAT_MANY': RichKind.messageBurst,
  'EVENT_DAY': RichKind.eventTomorrow,
  'EVENT_HOUR': RichKind.eventSoon,
  'EVENT_CHANGED': RichKind.eventUpdate,
  'EVENT_ADMISSION': RichKind.eventApproved,
  'EVENT_CANCELLED': RichKind.eventCancelled,
  'ANNOUNCEMENT': RichKind.announcement,
  'UNIT_ANNOUNCEMENT': RichKind.deptAnnouncement,
  'ACADEMIC_ANNOUNCEMENT': RichKind.academicAnnouncement,
  'NEWS': RichKind.news,
  'EXAM_REMINDER': RichKind.examReminder,
  'MENU_TODAY': RichKind.menuToday,
  'POLL_NEW': RichKind.pollNew,
  'POLL_CLOSING': RichKind.pollClosing,
  'POST_LIKE': RichKind.postLike,
  'USER_FOLLOW': RichKind.newFollower,
  'FOLLOW_REQUEST': RichKind.followRequest,
  'FOLLOW_ACCEPTED': RichKind.followAccepted,
  'SECURITY_NEW_DEVICE': RichKind.newDeviceLogin,
  'SECURITY_PASSWORD': RichKind.passwordChanged,
  'SECURITY_2FA_OFF': RichKind.twoFaChanged,
  'SECURITY_2FA_ON': RichKind.twoFaChanged,
  'SECURITY_SESSION': RichKind.sessionReplaced,
  'SUPPORT_TICKET': RichKind.supportReply,
};

/// `card` değerinden kart türü; boş/bilinmeyen = null.
RichKind? richKindOfCard(Object? card) {
  final k = _s(card).toUpperCase();
  return k.isEmpty ? null : kBackendCardKinds[k];
}

/// Yükten kart türünü çözer: önce backend `card`, sonra `subtype`/`type`, olmazsa eylem kimlikleri ve kanal ipuçları (backend alt tür adları
/// değişse de doğru kart çıkar). SAF fonksiyon.
RichKind resolveRichKind(Map<String, dynamic> d, List<String> actions,
    {required int count, required RichImageStyle style}) {
  final byCard = richKindOfCard(d['card']);
  if (byCard != null) return byCard;
  final type = _s(d['type']).toUpperCase();
  final sub = _s(d['subtype']).toUpperCase();
  final channel = _s(d['channelId']).toLowerCase();
  final has = actions.contains;
  bool subHas(String s) => sub.contains(s);

  // Eylem kimliği tek başına güvenlik kartını belirler (alt tür adı değişse de).
  if (sub.isEmpty && channel != 'chat' && type != 'MESSAGE') {
    if (has('not_me')) return RichKind.newDeviceLogin;
    if (has('reset_password')) return RichKind.passwordChanged;
    if (has('enable_2fa')) return RichKind.twoFaChanged;
    if (has('sign_out_device')) return RichKind.sessionReplaced;
  }

  // Güvenlik kartları (kanal ya da alt tür).
  if (channel == 'security' ||
      subHas('NEW_DEVICE') ||
      subHas('PASSWORD') ||
      subHas('TWO_FA') ||
      subHas('2FA') ||
      subHas('SESSION')) {
    if (subHas('PASSWORD') || (sub.isEmpty && has('reset_password'))) return RichKind.passwordChanged;
    if (subHas('TWO_FA') || subHas('2FA') || (sub.isEmpty && has('enable_2fa'))) return RichKind.twoFaChanged;
    if (subHas('SESSION') || (sub.isEmpty && has('sign_out_device'))) return RichKind.sessionReplaced;
    if (subHas('NEW_DEVICE') || has('not_me')) return RichKind.newDeviceLogin;
    if (has('reset_password')) return RichKind.passwordChanged;
    if (has('enable_2fa')) return RichKind.twoFaChanged;
    if (has('sign_out_device')) return RichKind.sessionReplaced;
  }

  // Sohbet.
  if (type == 'MESSAGE' || sub.startsWith('MESSAGE') || channel == 'chat') {
    if (style == RichImageStyle.big) return RichKind.photoMessage;
    if (count > 1) return RichKind.messageBurst;
    if (_flag(d['groupBadge']) || sub == 'MESSAGE_GROUP') return RichKind.groupMessage;
    return RichKind.directMessage;
  }

  // Sosyal.
  if (type == 'POST_LIKE' || sub == 'POST_LIKE') return RichKind.postLike;
  if (type == 'FOLLOW_REQUEST' || sub == 'FOLLOW_REQUEST') return RichKind.followRequest;
  if (type == 'FOLLOW_ACCEPTED' || sub == 'FOLLOW_ACCEPTED') return RichKind.followAccepted;
  if (type == 'USER_FOLLOW' || sub == 'USER_FOLLOW') return RichKind.newFollower;

  // Etkinlik.
  if (type == 'EVENT' || sub.startsWith('EVENT') || channel == 'event') {
    if (sub == 'EVENT_ADMISSION') return RichKind.eventApproved;
    if (sub == 'EVENT_UPDATE' || subHas('CANCEL') || _flag(d['cancelled'])) {
      final cancelled = subHas('CANCEL') || _flag(d['cancelled']) || _s(d['tone']).toLowerCase() == 'danger';
      return cancelled ? RichKind.eventCancelled : RichKind.eventUpdate;
    }
    if (sub == 'EVENT_REMINDER' || sub.isEmpty) {
      return has('qr_checkin') ? RichKind.eventSoon : RichKind.eventTomorrow;
    }
    return RichKind.eventUpdate;
  }

  // Anket.
  if (sub == 'POLL' || sub.startsWith('POLL') || type.startsWith('POLL') || channel == 'poll' || has('vote')) {
    final closing = subHas('CLOS') || subHas('ENDING') || _flag(d['closing']);
    return closing ? RichKind.pollClosing : RichKind.pollNew;
  }

  // Akademik.
  if (sub == 'EXAM_REMINDER' || has('exam_card')) return RichKind.examReminder;
  if (subHas('CLASS') || has('open_schedule')) return RichKind.classSoon;
  if (subHas('HOMEWORK') || subHas('ASSIGNMENT')) return RichKind.homework;
  if (sub == 'ACADEMIC_ANNOUNCEMENT' || type == 'ACADEMIC_ANNOUNCEMENT' || channel == 'academic') {
    return RichKind.academicAnnouncement;
  }

  // Menü / haber / duyuru / destek.
  if (subHas('MENU')) return RichKind.menuToday;
  if (type == 'NEWS') return RichKind.news;
  if (has('view_ticket') || subHas('TICKET') || (type == 'SYSTEM' && _s(d['targetType']).toUpperCase() == 'TICKET')) {
    return RichKind.supportReply;
  }
  if (subHas('DEPT') || subHas('UNIT')) return RichKind.deptAnnouncement;
  if (type == 'ANNOUNCEMENT' || channel == 'announcement') return RichKind.announcement;
  return RichKind.generic;
}

/// Kart başına görünüm kuralları.
class RichKindSpec {
  const RichKindSpec(this.tile, {this.danger = false});

  /// `assets/notif/tile_<tile>.png` (kişi kartlarında avatar varsa kullanılmaz; yedek).
  final String tile;

  /// Soluk kırmızı ton (iptal, güvenlik).
  final bool danger;
}

const Map<RichKind, RichKindSpec> kRichSpecs = {
  RichKind.directMessage: RichKindSpec('generic'),
  RichKind.groupMessage: RichKindSpec('generic'),
  RichKind.photoMessage: RichKindSpec('generic'),
  RichKind.messageBurst: RichKindSpec('generic'),
  RichKind.eventTomorrow: RichKindSpec('event'),
  RichKind.eventSoon: RichKindSpec('event_soon'),
  RichKind.eventUpdate: RichKindSpec('event_update'),
  RichKind.eventApproved: RichKindSpec('event_ok'),
  RichKind.eventCancelled: RichKindSpec('event_cancel', danger: true),
  RichKind.announcement: RichKindSpec('announcement'),
  RichKind.deptAnnouncement: RichKindSpec('dept'),
  RichKind.academicAnnouncement: RichKindSpec('academic'),
  RichKind.news: RichKindSpec('news'),
  RichKind.examReminder: RichKindSpec('exam'),
  RichKind.classSoon: RichKindSpec('class'),
  RichKind.homework: RichKindSpec('homework'),
  RichKind.menuToday: RichKindSpec('menu'),
  RichKind.pollNew: RichKindSpec('poll'),
  RichKind.pollClosing: RichKindSpec('poll'),
  RichKind.postLike: RichKindSpec('like'),
  RichKind.newFollower: RichKindSpec('follow'),
  RichKind.followRequest: RichKindSpec('follow'),
  RichKind.followAccepted: RichKindSpec('follow_ok'),
  RichKind.newDeviceLogin: RichKindSpec('device', danger: true),
  RichKind.passwordChanged: RichKindSpec('password', danger: true),
  RichKind.twoFaChanged: RichKindSpec('twofa', danger: true),
  RichKind.sessionReplaced: RichKindSpec('session', danger: true),
  RichKind.supportReply: RichKindSpec('support'),
  RichKind.generic: RichKindSpec('generic'),
};

/// Üst etiket (Android `subText`): sunucu `label` verdiyse o, yoksa türe göre sınıf adı.
String richHeaderLabel(RichCard c, AppLocalizations l) {
  if (c.label.isNotEmpty) return c.label;
  switch (c.kind) {
    case RichKind.directMessage:
      return l.notifRichChat;
    case RichKind.groupMessage:
      return l.notifRichClubRoom;
    case RichKind.photoMessage:
      return l.notifRichMedia;
    case RichKind.messageBurst:
      return l.notifRichNewMsgs('${c.count}');
    case RichKind.eventTomorrow:
    case RichKind.eventSoon:
    case RichKind.eventUpdate:
    case RichKind.eventApproved:
    case RichKind.eventCancelled:
      return l.notifRichEvent;
    case RichKind.announcement:
      return l.notifRichAnnouncement;
    case RichKind.deptAnnouncement:
      return l.notifRichDept;
    case RichKind.academicAnnouncement:
    case RichKind.examReminder:
      return l.notifRichAcademic;
    case RichKind.classSoon:
      return l.notifRichClass;
    case RichKind.homework:
      return l.notifRichHomework;
    case RichKind.news:
      return l.notifRichNews;
    case RichKind.menuToday:
      return l.notifRichMenu;
    case RichKind.pollNew:
    case RichKind.pollClosing:
      return l.notifRichPoll;
    case RichKind.postLike:
    case RichKind.newFollower:
    case RichKind.followRequest:
    case RichKind.followAccepted:
      return l.notifRichSocial;
    case RichKind.newDeviceLogin:
    case RichKind.passwordChanged:
    case RichKind.twoFaChanged:
    case RichKind.sessionReplaced:
      return l.notifRichSecurity;
    case RichKind.supportReply:
      return l.notifRichSupport;
    case RichKind.generic:
      return '';
  }
}
