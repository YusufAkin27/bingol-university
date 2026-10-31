/// Push / bildirim `data` yükü -> hedef ekran eşlemesi (SAF FONKSİYON; UI'siz test edilir).
/// Hem [PushRouter] (push dokunuşu, yerel hatırlatma dokunuşu) hem bildirim listesi bunu kullanır.
/// Bilinmeyen / bozuk yük [PushDest.notifications] olur; hiçbir durumda exception fırlatmaz.
enum PushDest {
  /// ÖLÜ: [resolvePushTarget] artık üretmez (sunucu `session_replaced` push'u hiç göndermez; oturum iptali 401/WS ile
  /// gelir, A4-01/A13-13). Yalnız `notifications_page.dart` (W2-I sahibi) hâlâ bu değere bakar; orası temizlenince
  /// bu değer de silinebilir.
  signOut,
  conversation,

  /// Sohbet sekmesi (liste): yönetici üyeliği kaldırdı (`CONVERSATION_REMOVED`), açılacak sohbet yok.
  chatList,
  event,
  community,
  news,
  post,
  poll,
  user,
  deptAnnouncement,
  timetable,
  exams,
  ticket,
  feedback,
  notifications,
}

class PushTarget {
  const PushTarget(this.dest, {this.id, this.commentId});

  final PushDest dest;
  final int? id;
  final int? commentId;

  @override
  bool operator ==(Object other) =>
      other is PushTarget && other.dest == dest && other.id == id && other.commentId == commentId;

  @override
  int get hashCode => Object.hash(dest, id, commentId);

  @override
  String toString() => 'PushTarget($dest, $id${commentId != null ? ', c$commentId' : ''})';
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
  'announcementId',
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

int? _id(Object? v) {
  final n = v == null ? null : int.tryParse('$v');
  return n != null && n > 0 ? n : null;
}

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
    case 'ANNOUNCEMENT_DEPT':
    case 'DEPT_ANNOUNCEMENT':
      return PushDest.deptAnnouncement;
    case 'COMMENT':
    case 'COMMENT_REPLY':
    case 'FEED_POST':
    case 'FEED_COMMENT':
      return PushDest.post;
    case 'USER':
    case 'USER_FOLLOW':
    case 'FOLLOW':
      return PushDest.user;
    case 'STORY':
      // Hikâyeler kaldırıldı: eski bildirim sahibinin profiline gider.
      return PushDest.user;
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
  if ('${d['event'] ?? ''}'.toUpperCase() == 'CONVERSATION_REMOVED') return const PushTarget(PushDest.chatList);

  final target = '${d['targetType'] ?? d['target'] ?? ''}'.trim().toUpperCase();
  final value = _id(d['targetId'] ?? d['value']);
  final commentId = _id(d['commentId']);

  final conversationId = _id(d['conversationId']);
  final pollId = _id(d['pollId']);
  final postId = _id(d['postId']);
  final eventId = _id(d['eventId']);
  final communityId = _id(d['communityId']);
  final newsId = _id(d['newsId']);
  final announcementId = _id(d['announcementId']);

  // Doğrudan anahtarlar (eski öncelik: sohbet yoksa anket, sonra gönderi).
  if (conversationId != null) return PushTarget(PushDest.conversation, id: conversationId);
  if (pollId != null) return PushTarget(PushDest.poll, id: pollId);
  if (postId != null) return PushTarget(PushDest.post, id: postId, commentId: commentId);

  final dest = _destOf(target);
  if (dest == PushDest.deptAnnouncement && (announcementId ?? value) != null) {
    return PushTarget(dest!, id: announcementId ?? value);
  }
  if (eventId != null) return PushTarget(PushDest.event, id: eventId);
  if (communityId != null && dest != PushDest.post) return PushTarget(PushDest.community, id: communityId);
  if (newsId != null) return PushTarget(PushDest.news, id: newsId);
  if (announcementId != null) return PushTarget(PushDest.deptAnnouncement, id: announcementId);

  if (dest != null) {
    switch (dest) {
      case PushDest.timetable:
      case PushDest.exams:
        return PushTarget(dest, id: value); // kimliksiz de geçerli: ilgili listeyi açar
      case PushDest.post:
        if (value != null) return PushTarget(dest, id: value, commentId: commentId);
      default:
        if (value != null) return PushTarget(dest, id: value);
    }
  }
  final userId = _id(d['userId']);
  if (userId != null && (dest == null || dest == PushDest.user)) return PushTarget(PushDest.user, id: userId);
  return const PushTarget(PushDest.notifications);
}
