import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Biletin durumu (T1 "Biletim"): yalnız `GOING` (onaylı) katılımcıya bilet vardır.
enum TicketAvailability { valid, ended, cancelled, notGoing }

/// Bilet görünürlüğü: etkinlik haritası (`status`, `endsAt`, `myRsvp`) -> durum. Saf fonksiyon (test edilir).
/// Sunucu `GET /events/{id}/ticket` durumu da `state` ile bildirir; ikisi birlikte kullanılır.
TicketAvailability ticketAvailability(Map<String, dynamic> ev, {DateTime? now, String? serverState}) {
  if (ev['myRsvp'] != 'GOING') return TicketAvailability.notGoing;
  final status = ev['status'];
  if (serverState == 'CANCELLED' || (status != null && status != 'ACTIVE')) return TicketAvailability.cancelled;
  if (serverState == 'ENDED') return TicketAvailability.ended;
  final end = DateTime.tryParse('${ev['endsAt'] ?? ''}');
  if (end != null && !end.isAfter(now ?? DateTime.now())) return TicketAvailability.ended;
  return TicketAvailability.valid;
}

/// Çevrimdışı gösterim için son görülen bilet (hesap bazlı). Tek anahtar `event_ticket_v1`: `{uid, tickets:{id:{...}}}`.
/// Kullanıcı kimliği uyuşmazsa içerik yok sayılır; çıkış/hesap değişiminde [clear] ile silinir
/// (`registerUserDataCleaners`). QR kısa ömürlüdür: yalnız son görülen kod saklanır, süresi dolmuş olabilir.
abstract final class EventTicketStore {
  static const key = 'event_ticket_v1';
  static const maxTickets = 20;
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> _readAll(int uid) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return {};
      final m = jsonDecode(raw);
      if (m is! Map || m['uid'] != uid || m['tickets'] is! Map) return {};
      return Map<String, dynamic>.from(m['tickets'] as Map);
    } catch (_) {
      return {}; // bozuk kayıt: en iyi çaba, bilet yeniden indirilir
    }
  }

  static Future<Map<String, dynamic>?> load(int uid, int eventId) async {
    final t = (await _readAll(uid))['$eventId'];
    return t is Map ? Map<String, dynamic>.from(t) : null;
  }

  /// [info] sunucu bilet verisi; [qr] son QR yükü (yoksa null); [qrExpiresAt] ISO anı.
  static Future<void> save(int uid, int eventId, Map<String, dynamic> info, {String? qr, String? qrExpiresAt}) async {
    try {
      final all = await _readAll(uid);
      final prev = all['$eventId'];
      all['$eventId'] = {
        'info': info,
        'qr': qr ?? (prev is Map ? prev['qr'] : null),
        'qrExp': qr != null ? qrExpiresAt : (prev is Map ? prev['qrExp'] : null),
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      };
      if (all.length > maxTickets) {
        final keys = all.keys.toList()
          ..sort((a, b) => '${(all[a] as Map)['savedAt']}'.compareTo('${(all[b] as Map)['savedAt']}'));
        for (final k in keys.take(all.length - maxTickets)) {
          all.remove(k);
        }
      }
      await _storage.write(key: key, value: jsonEncode({'uid': uid, 'tickets': all}));
    } catch (_) {
      // Bilerek yutulur: önbellek yazılamazsa bilet yine çevrimiçi gösterilir.
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
