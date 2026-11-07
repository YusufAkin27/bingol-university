import 'session.dart';

/// Zil ve kalp sayaçlarını sunucudan eşitler (iki merkez birbirinden bağımsız, sunucuda hesaplanır).
/// `GET /notifications/unread-counts` -> {social, information, pendingFollowRequests, pendingMembershipRequests}.
/// Eski sunucuda uç yoksa `/me/summary` alanlarına (`unreadSocial`/`unreadInformation`) düşülür; onlar da yoksa
/// sayaçlara dokunulmaz (yanlış sayı göstermektense eski değer kalır).
Future<void> refreshNotificationCounts(Session s) async {
  try {
    final r = await s.api.get('/notifications/unread-counts', force: true);
    if (r is Map && applyNotificationCounts(s, r)) return;
  } catch (_) {
    // uç yok / ağ yok: özet uca düş
  }
  try {
    final m = await s.api.get('/me/summary', force: true);
    if (m is Map) applyNotificationCounts(s, m);
  } catch (_) {}
}

/// Sunucu yanıtını sayaçlara yazar; tanınan alan yoksa false.
bool applyNotificationCounts(Session s, Map r) {
  int? n(String k) => (r[k] as num?)?.toInt();
  final info = n('information') ?? n('unreadInformation');
  final soc = n('social') ?? n('unreadSocial');
  if (info == null && soc == null) return false;
  if (info != null) s.badges.notifications.value = info;
  if (soc != null) s.badges.social.value = soc;
  final fr = n('pendingFollowRequests');
  final mr = n('pendingMembershipRequests');
  if (fr != null || mr != null) s.badges.socialPending.value = (fr ?? 0) + (mr ?? 0);
  return true;
}
