import 'dart:math';

import '../../../l10n/app_localizations.dart';
import 'rich_card.dart';

/// Bildirim eylemleri: kimlik -> etiket, eylem -> istek eşlemesi. SAF Dart (UI/eklenti yok), birim testle doğrulanır.

/// Tanımlı eylem kimlikleri (sözleşme). Bilinmeyen kimlik çizilmez/yok sayılır.
const Set<String> kRichActionIds = {
  'reply',
  'mark_read',
  'mute_1h',
  'view',
  'open',
  'calendar',
  'qr_checkin',
  'follow_back',
  'accept',
  'reject',
  'vote',
  'exam_card',
  'open_schedule',
  'not_me',
  'reset_password',
  'enable_2fa',
  'sign_out_device',
  'view_ticket',
};

/// Uygulamayı AÇMADAN (arka plan isolate'inde) istek atan eylemler.
const Set<String> kBackgroundActionIds = {'reply', 'mark_read', 'mute_1h', 'follow_back', 'accept', 'reject', 'not_me'};

/// Android bildirim başına en çok 3 eylem düğmesi görünür.
const int kMaxRichActions = 3;

/// Çizilecek eylem düğmesi.
class RichAction {
  const RichAction(this.id, this.label, {required this.background, this.input = false});

  final String id;
  final String label;

  /// true: uygulama açılmadan arka planda çalışır; false: uygulamayı açar.
  final bool background;

  /// Satır içi metin girişi (yalnız `reply`).
  final bool input;

  @override
  String toString() => 'RichAction($id, "$label", bg=$background, input=$input)';
}

/// Kart + dil -> çizilecek eylem düğmeleri (sıra = sunucunun `actions` sırası; bilinmeyen kimlik atılır).
/// Etiketler tasarımdaki birebir metinlerdir; bağlama göre değişenler:
/// birikim kartında reply = "Hızlı Yanıtla", mark_read = "Tümünü Aç" (sohbeti açar; açılınca zaten okunur);
/// etkinlik kartlarında view = "Detay"; "kabul edildi" kartında view = "Profili Gör"; destek kartında view_ticket.
List<RichAction> richActionsFor(RichCard c, AppLocalizations l) {
  final out = <RichAction>[];
  for (final id in c.actions) {
    if (!kRichActionIds.contains(id)) continue;
    final a = _make(id, c, l);
    if (a != null) out.add(a);
    if (out.length >= kMaxRichActions) break;
  }
  return out;
}

RichAction? _make(String id, RichCard c, AppLocalizations l) {
  final burst = c.kind == RichKind.messageBurst;
  switch (id) {
    case 'reply':
      return RichAction(id, burst ? l.notifActQuickReply : l.notifActReply, background: true, input: true);
    case 'mark_read':
      // Birikimde "Tümünü Aç": sohbeti açar (arka plan isteği yok); diğerlerinde arka planda okundu işaretler.
      return burst
          ? RichAction(id, l.notifActOpenAll, background: false)
          : RichAction(id, l.notifActMarkRead, background: true);
    case 'mute_1h':
      return RichAction(id, l.notifActMute1h, background: true);
    case 'view':
    case 'open':
      final label = switch (c.kind) {
        RichKind.eventTomorrow ||
        RichKind.eventSoon ||
        RichKind.eventUpdate ||
        RichKind.eventApproved ||
        RichKind.eventCancelled =>
          l.notifActDetail,
        RichKind.followAccepted || RichKind.newFollower => l.notifActProfile,
        _ => id == 'open' ? l.notifActOpen : l.notifActView,
      };
      return RichAction(id, label, background: false);
    case 'calendar':
      return RichAction(id, l.notifActCalendar, background: false);
    case 'qr_checkin':
      return RichAction(id, l.notifActQr, background: false);
    case 'follow_back':
      return RichAction(id, l.notifActFollowBack, background: true);
    case 'accept':
      return RichAction(id, l.notifActAccept, background: true);
    case 'reject':
      return RichAction(id, l.notifActReject, background: true);
    case 'vote':
      return RichAction(id, l.notifActVote, background: false);
    case 'exam_card':
      return RichAction(id, l.notifActExamCard, background: false);
    case 'open_schedule':
      return RichAction(id, l.notifActOpenSchedule, background: false);
    case 'not_me':
      return RichAction(id, l.notifActNotMe, background: true);
    case 'reset_password':
      return RichAction(id, l.notifActResetPw, background: false);
    case 'enable_2fa':
      return RichAction(id, l.notifActEnable2fa, background: false);
    case 'sign_out_device':
      return RichAction(id, l.notifActSignOutDevice, background: false);
    case 'view_ticket':
      return RichAction(id, l.notifActViewTicket, background: false);
  }
  return null;
}

// ---------------------------------------------------------------------------------------------------------------
// Eylem -> istek / yönlendirme eşlemesi

sealed class ActionPlan {
  const ActionPlan();
}

/// Arka planda atılacak API isteği (yol `/api` öneksizdir: `ApiClient` ekler).
class HttpPlan extends ActionPlan {
  const HttpPlan(this.method, this.path, {this.body, this.confirmation = false});

  final String method;
  final String path;
  final Object? body;

  /// Başarıda bildirim kaldırılırken ayrıca kısa bir onay bildirimi gösterilir (örn. `not_me`).
  final bool confirmation;

  @override
  String toString() => 'HttpPlan($method $path $body)';
}

/// Uygulamayı ilgili ekranda açar: [data] `PushRouter.open`'a verilir (hedef anahtarları).
class OpenPlan extends ActionPlan {
  const OpenPlan(this.data);

  final Map<String, dynamic> data;

  @override
  String toString() => 'OpenPlan($data)';
}

/// Tanımsız/eksik veri: hiçbir şey yapılmaz.
class NoopPlan extends ActionPlan {
  const NoopPlan();
}

int? _id(Object? v) {
  final n = v == null ? null : int.tryParse('$v');
  return n != null && n > 0 ? n : null;
}

String _up(Object? v) => '${v ?? ''}'.trim().toUpperCase();

/// Sohbet kimliği: `conversationId`, yoksa hedef türü sohbet olan `targetId`.
int? conversationIdOf(Map<String, dynamic> d) {
  final c = _id(d['conversationId']);
  if (c != null) return c;
  final t = _up(d['targetType'] ?? d['target']);
  if (t == 'CONVERSATION' || t == 'MESSAGE' || t == 'CHAT') return _id(d['targetId'] ?? d['value']);
  return null;
}

/// Kişi (gönderen/istek sahibi) kimliği.
int? personIdOf(Map<String, dynamic> d) {
  final direct = _id(d['requesterId']) ?? _id(d['senderId']) ?? _id(d['userId']);
  if (direct != null) return direct;
  final t = _up(d['targetType'] ?? d['target']);
  if (t == 'USER' || t == 'USER_FOLLOW' || t == 'FOLLOW' || t == 'FOLLOW_REQUEST' || t == 'FOLLOW_REQUESTS') {
    return _id(d['targetId'] ?? d['value']);
  }
  return null;
}

/// İstemci mesaj kimliği (en çok 64 karakter; çift gönderimi sunucu `clientId` ile ayıklar).
String richClientId([Random? rnd, int? micros]) {
  final r = rnd ?? Random.secure();
  final t = micros ?? DateTime.now().microsecondsSinceEpoch;
  return 'rn-$t-${r.nextInt(1 << 31).toRadixString(36)}';
}

/// Eylem -> plan. [input] satır içi yanıt metni (yalnız `reply`).
ActionPlan planRichAction(String actionId, Map<String, dynamic> d, {String? input, String? clientId}) {
  switch (actionId) {
    case 'reply':
      final c = conversationIdOf(d);
      final text = (input ?? '').trim();
      if (c == null || text.isEmpty) return const NoopPlan();
      return HttpPlan('POST', '/conversations/$c/messages', body: {'text': text, 'clientId': clientId ?? richClientId()});
    case 'mark_read':
      final c = conversationIdOf(d);
      if (c == null) return const NoopPlan();
      final m = _id(d['messageId']) ?? _id(d['lastMessageId']);
      // Sunucu `lastMessageId` ister: yoksa isteği atamayız, sohbeti açmak (açılınca okunur) tek güvenli yoldur.
      if (m == null) return OpenPlan({'conversationId': '$c'});
      return HttpPlan('POST', '/conversations/$c/read', body: {'lastMessageId': m});
    case 'mute_1h':
      final c = conversationIdOf(d);
      if (c == null) return const NoopPlan();
      return HttpPlan('PUT', '/conversations/$c/mute', body: {'durationMinutes': 60});
    case 'follow_back':
      final u = personIdOf(d);
      if (u == null) return const NoopPlan();
      return HttpPlan('POST', '/users/$u/follow');
    case 'accept':
      final u = personIdOf(d);
      if (u == null) return const NoopPlan();
      return HttpPlan('POST', '/users/me/follow-requests/$u/accept');
    case 'reject':
      final u = personIdOf(d);
      if (u == null) return const NoopPlan();
      return HttpPlan('POST', '/users/me/follow-requests/$u/decline');
    case 'not_me':
      return const HttpPlan('POST', '/security/not-me', body: <String, dynamic>{}, confirmation: true);
    default:
      final t = routeDataFor(actionId, d);
      return t == null ? const NoopPlan() : OpenPlan(t);
  }
}

/// Uygulamayı açan eylemler için `PushRouter.open` yükü (hedef anahtarları); eksik/bilinmeyen = null.
/// [route] anahtarı bu dosyaya özgü iç yönlendirmedir (`push_targets.dart` onu ekrana çevirir).
Map<String, dynamic>? routeDataFor(String actionId, Map<String, dynamic> d) {
  switch (actionId) {
    case 'view':
    case 'open':
      return Map<String, dynamic>.from(d);
    case 'calendar':
    case 'qr_checkin':
      final e = _id(d['eventId']) ?? _eventTargetId(d);
      return e == null ? Map<String, dynamic>.from(d) : {'eventId': '$e'};
    case 'vote':
      final p = _id(d['pollId']) ?? (_up(d['targetType']).startsWith('POLL') ? _id(d['targetId']) : null);
      return p == null ? Map<String, dynamic>.from(d) : {'pollId': '$p'};
    case 'exam_card':
      return {'targetType': 'EXAM', if (_id(d['targetId']) != null) 'targetId': '${d['targetId']}'};
    case 'open_schedule':
      return {'targetType': 'TIMETABLE'};
    case 'view_ticket':
      final t = _id(d['ticketId']) ?? (_up(d['targetType']) == 'TICKET' ? _id(d['targetId']) : null);
      return t == null ? Map<String, dynamic>.from(d) : {'targetType': 'TICKET', 'targetId': '$t'};
    case 'reset_password':
    case 'enable_2fa':
    case 'sign_out_device':
      return {'targetType': 'ACCOUNT_SECURITY'};
  }
  return null;
}

int? _eventTargetId(Map<String, dynamic> d) {
  final t = _up(d['targetType'] ?? d['target']);
  return t.startsWith('EVENT') ? _id(d['targetId'] ?? d['value']) : null;
}
