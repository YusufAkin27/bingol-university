/// Push / bildirim `data` yükü -> hedef ekran eşlemesi (SAF FONKSİYON; UI'siz test edilir).
/// Hem [PushRouter] (push dokunuşu, yerel hatırlatma dokunuşu) hem bildirim listesi bunu kullanır.
/// Bilinmeyen / bozuk yük [PushDest.notifications] olur; hiçbir durumda exception fırlatmaz.
enum PushDest {
  conversation,

  /// Sohbet sekmesi (liste): yönetici üyeliği kaldırdı (`CONVERSATION_REMOVED`), açılacak sohbet yok.
  chatList,
  event,
  community,
  news,
  post,
  poll,
  user,

  /// Kampüs Forum konusu ([PushTarget.id] = konu kimliği; [PushTarget.commentId] varsa o yoruma gider).
  forumTopic,

  /// Yalnız yorum kimliği bilinen forum bildirimi ([PushTarget.id] = yorum kimliği): konu `GET /forum/comments/{id}` ile çözülür.
  forumComment,

  /// Gelen takip istekleri ekranı (`FOLLOW_REQUESTS`; GİZLİ hesap istek aldı). Kimliksiz geçerlidir.
  followRequests,
  timetable,
  exams,

  /// Öğrencinin ders ayrıntısı (Derslerim): akademisyen duyuruları, yoklama ve devamsızlık uyarıları ([PushTarget.id] = ders kimliği).
  course,
  ticket,
  feedback,
  accountSecurity,

  /// Cihazlarım (Hesap ve güvenlik > Cihazlarım): yeni cihaz girişi bildirimi (`target=SECURITY`, `value=devices`,
  /// `securityKind=NEW_DEVICE`) ve `targetType=DEVICES`.
  devices,
  meal,

  /// Kampanya `target=URL`: yalnız https adresi, dış tarayıcıda açılır ([PushTarget.url]).
  url,
  notifications,
}

class PushTarget {
  const PushTarget(this.dest, {this.id, this.commentId, this.url});

  final PushDest dest;
  final int? id;
  final int? commentId;

  /// Yalnız [PushDest.url] için: doğrulanmış https adresi.
  final String? url;

  @override
  bool operator ==(Object other) =>
      other is PushTarget &&
      other.dest == dest &&
      other.id == id &&
      other.commentId == commentId &&
      other.url == url;

  @override
  int get hashCode => Object.hash(dest, id, commentId, url);

  @override
  String toString() =>
      'PushTarget($dest, $id${commentId != null ? ', c$commentId' : ''})';
}

/// Yerel hatırlatma (Android intent ekstrası / iOS bildirim userInfo) yükünde İZİN VERİLEN anahtarlar.
/// `type`/`event` gibi durum değiştiren anahtarlar BİLEREK yoktur: bunlar yalnız sunucudan gelen FCM yükünde
/// anlamlıdır (A4-01: dışa açık launcher aktivitesine başka bir uygulama sahte yük basabilir).
const Set<String> kLocalReminderPayloadKeys = {
  'targetType',
  'targetId',
  'conversationId',
  'eventId',
  'postId',
  'communityId',
  'newsId',
  'ticketId',
  'pollId',
  'userId',
  'examId',
};

/// Yerel hatırlatma yükünde bir değerin en çok uzunluğu.
const int kLocalReminderValueMax = 200;

/// Yerel kaynaklı (güvenilmeyen) yükü beyaz listeye indirger: bilinmeyen anahtarlar atılır, değerler metne çevrilip
/// [kLocalReminderValueMax] ile sınırlanır (daha uzun/boş/iç içe değerin anahtarı atılır). Exception fırlatmaz.
Map<String, dynamic> sanitizeLocalReminderPayload(Map<dynamic, dynamic>? raw) {
  final out = <String, dynamic>{};
  if (raw == null) return out;
  for (final e in raw.entries) {
    final k = '${e.key}';
    if (!kLocalReminderPayloadKeys.contains(k)) continue;
    final v = e.value;
    if (v is! String && v is! num) continue;
    final text = '$v';
    if (text.isEmpty || text.length > kLocalReminderValueMax) continue;
    out[k] = text;
  }
  return out;
}

/// Kampüs Forum bildirimi mi? (`type` FORUM_* ya da `targetType` FORUM_TOPIC/FORUM_COMMENT). Sunucu forum
/// bildirimlerinde kişi avatarı yollamaz (anonim yazar): kart kişi değil forum karosu çizer.
bool isForumPush(Map<String, dynamic>? data) {
  final d = data ?? const <String, dynamic>{};
  String up(Object? v) => '${v ?? ''}'.trim().toUpperCase();
  return up(d['type']).startsWith('FORUM_') || up(d['targetType'] ?? d['target']).startsWith('FORUM');
}

int? _id(Object? v) {
  final n = v == null ? null : int.tryParse('$v');
  return n != null && n > 0 ? n : null;
}

/// Yalnız `https://` + ana makine adı olan adres; aksi halde null (kullanıcı bilgisi içeren adresler reddedilir).
String? _httpsUrl(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  if (t.isEmpty || t.length > 2000) return null;
  final u = Uri.tryParse(t);
  if (u == null || u.scheme.toLowerCase() != 'https' || u.host.isEmpty || u.userInfo.isNotEmpty) return null;
  return u.toString();
}

/// Bilerek eşlenmeyenler (Bildirimler listesi açılır): MESSAGE_IMAGE (targetId görsel/ek kimliği, sohbet kimliği yük
/// içinde yok) ve BOARD_NOTICE (targetId pano duyurusu kimliği, oda kimliği yok): güvenli bir ekran çözülemez.
/// `targetType` -> hedef. Önek eşleşmeleri: POLL_*, POST_*, EVENT_*, ACADEMIC_*.
PushDest? _destOf(String t) {
  switch (t) {
    case 'CONVERSATION':
    case 'MESSAGE':
    case 'CHAT':
      return PushDest.conversation;
    case 'COMMUNITY':
    case 'CLUB':
      return PushDest.community;
    case 'NEWS':
    case 'ANNOUNCEMENT':
      return PushDest.news;
    case 'COMMENT':
    case 'COMMENT_REPLY':
    case 'COMMENT_LIKE':
    case 'FEED_POST':
    case 'FEED_COMMENT':
      return PushDest.post;
    case 'USER':
    case 'USER_AVATAR': // moderasyon: targetId = avatar sahibinin kullanıcı kimliği (bildirim alıcısı); profil ekranı
    case 'USER_FOLLOW':
    case 'FOLLOW':
      return PushDest.user;
    case 'FOLLOW_REQUESTS':
    case 'FOLLOW_REQUEST':
      return PushDest.followRequests;
    case 'STORY':
      // Hikâyeler kaldırıldı: eski bildirim sahibinin profiline gider.
      return PushDest.user;
    case 'MEAL':
    case 'MENU':
      return PushDest.meal;
    case 'SECURITY':
    case 'ACCOUNT_SECURITY':
      return PushDest.accountSecurity;
    case 'DEVICES':
      return PushDest.devices;
    case 'TICKET':
      return PushDest.ticket;
    case 'FEEDBACK':
      return PushDest.feedback;
    case 'EXAM':
    case 'EXAM_REMINDER':
      return PushDest.exams;
    case 'COURSE':
    case 'CLASS':
    case 'TIMETABLE':
    case 'CLASS_REMINDER':
      return PushDest.timetable;
  }
  if (t.startsWith('POLL')) return PushDest.poll;
  if (t.startsWith('POST')) return PushDest.post;
  if (t.startsWith('EVENT')) return PushDest.event;
  if (t.startsWith('COMMUNITY')) return PushDest.community;
  if (t.startsWith('ACADEMIC_EXAM')) return PushDest.exams;
  if (t.startsWith('ACADEMIC')) return PushDest.timetable;
  return null;
}

/// Kampanya hedefi (`target`/`value`), yeni yük (`targetType`/`targetId`) ve doğrudan anahtarlar
/// (`conversationId`, `eventId`...) kabul edilir. Doğrudan anahtarlar önceliklidir.
PushTarget resolvePushTarget(Map<String, dynamic>? data) {
  final d = data ?? const <String, dynamic>{};
  // P08: yönetici sohbetten çıkardı/oda kaldırıldı: sohbet artık yok, kullanıcı listeye gider.
  if ('${d['event'] ?? ''}'.toUpperCase() == 'CONVERSATION_REMOVED')
    return const PushTarget(PushDest.chatList);

  final target = '${d['targetType'] ?? d['target'] ?? ''}'.trim().toUpperCase();
  final value = _id(d['targetId'] ?? d['value']);
  final commentId = _id(d['commentId']);

  final conversationId = _id(d['conversationId']);
  final pollId = _id(d['pollId']);
  final postId = _id(d['postId']);
  final eventId = _id(d['eventId']);
  final examId = _id(d['examId']);
  final courseId = _id(d['courseId']);
  final communityId = _id(d['communityId']);
  final newsId = _id(d['newsId']);

  // Doğrudan anahtarlar (eski öncelik: sohbet yoksa anket, sonra gönderi).
  if (conversationId != null)
    return PushTarget(PushDest.conversation, id: conversationId);
  if (pollId != null) return PushTarget(PushDest.poll, id: pollId);
  if (postId != null)
    return PushTarget(PushDest.post, id: postId, commentId: commentId);

  if (examId != null) return PushTarget(PushDest.exams, id: examId);
  // Akademisyen duyurusu/uyarısı: `targetType=ACADEMIC_COURSE` + `targetId` (ya da `courseId`) ders ayrıntısını açar.
  if (target == 'ACADEMIC_COURSE') {
    final cid = courseId ?? value;
    if (cid != null) return PushTarget(PushDest.course, id: cid);
    return const PushTarget(PushDest.notifications);
  }

  // Kampanya bağlantısı: yalnız geçerli https adresi (sunucu da https dayatır); diğer şemalar/bozuk metin listeye düşer.
  if (target == 'URL') {
    final u = _httpsUrl(d['value'] ?? d['targetId']);
    return u == null ? const PushTarget(PushDest.notifications) : PushTarget(PushDest.url, url: u);
  }

  // Kampüs Forum: `FORUM_TOPIC` / `FORUM_COMMENT` (+ `topicId`). Bilinmeyen FORUM_* türü yine de konuya, o da yoksa listeye düşer.
  final topicId = _id(d['topicId']);
  if (target.startsWith('FORUM') || (target.isEmpty && topicId != null)) {
    final comment = target == 'FORUM_COMMENT' ? value : commentId;
    final topic = topicId ?? (target == 'FORUM_TOPIC' ? value : null);
    if (topic != null) return PushTarget(PushDest.forumTopic, id: topic, commentId: comment);
    if (comment != null) return PushTarget(PushDest.forumComment, id: comment);
    return const PushTarget(PushDest.notifications);
  }

  // Yeni cihaz girişi: güvenlik hedefi + `devices` değeri (ya da securityKind NEW_DEVICE) Cihazlarım'a gider.
  final secValue = '${d['targetId'] ?? d['value'] ?? ''}'.trim().toLowerCase();
  if (target == 'DEVICES' ||
      ((target == 'SECURITY' || target == 'ACCOUNT_SECURITY') &&
          (secValue == 'devices' || '${d['securityKind'] ?? ''}'.toUpperCase() == 'NEW_DEVICE'))) {
    return const PushTarget(PushDest.devices);
  }

  // Moderasyon bildirimi (`moderation=1`) targetType=ANNOUNCEMENT: kimlik KULÜP duyurusunun (community_post) kimliğidir,
  // haber kimliği değil; haber detayı yanlış kaydı/404'ü açmasın, Bildirimler listesi açılır.
  if (target == 'ANNOUNCEMENT' && '${d['moderation'] ?? ''}'.trim().isNotEmpty && newsId == null) {
    return const PushTarget(PushDest.notifications);
  }

  final dest = _destOf(target);
  if (eventId != null) return PushTarget(PushDest.event, id: eventId);
  if (communityId != null && (dest == null || dest == PushDest.community))
    return PushTarget(PushDest.community, id: communityId);
  if (newsId != null) return PushTarget(PushDest.news, id: newsId);

  if (dest != null) {
    switch (dest) {
      case PushDest.timetable:
      case PushDest.exams:
        return PushTarget(dest,
            id: value); // kimliksiz de geçerli: ilgili listeyi açar
      case PushDest.meal:
      case PushDest.accountSecurity:
      case PushDest.devices:
      case PushDest.followRequests:
        return PushTarget(dest); // kimlik yok: istekler ekranı
      case PushDest.post:
        // Yorum hedefi (COMMENT*) gönderi kimliği (postId) taşımıyorsa `value` yorum kimliğidir: gönderi açılamaz.
        if (target.contains('COMMENT') && target != 'POST_COMMENT') break; // POST_COMMENT: targetId zaten gönderi kimliği (eski sözleşme)
        if (value != null)
          return PushTarget(dest, id: value, commentId: commentId);
      default:
        if (value != null) return PushTarget(dest, id: value);
    }
  }
  final userId = _id(d['userId']);
  if (userId != null && (dest == null || dest == PushDest.user))
    return PushTarget(PushDest.user, id: userId);
  return const PushTarget(PushDest.notifications);
}
