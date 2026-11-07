import 'package:bu_kampus/features/events/event_parts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bitmiş / iptal etkinlik kuralı: mutlak (UTC) anlarla karşılaştırma, yerel saat dilimi sonucu değiştirmez.
void main() {
  final now = DateTime.utc(2026, 11, 7, 10, 0);

  Map<String, dynamic> ev(String status, String endsAt) => {'status': status, 'endsAt': endsAt};

  test('devam eden etkinlik bitmemiştir, bitiş anı geçince biter', () {
    expect(eventHasEnded(ev('ACTIVE', '2026-11-07T10:00:01Z'), now: now), isFalse);
    expect(eventHasEnded(ev('ACTIVE', '2026-11-07T10:00:00Z'), now: now), isTrue);
    expect(eventHasEnded(ev('ACTIVE', '2026-11-07T09:00:00Z'), now: now), isTrue);
  });

  test('saat dilimi ofseti mutlak anı değiştirmez (İstanbul +03:00 yazımı)', () {
    // 2026-11-07T12:59+03:00 == 09:59Z -> now (10:00Z) için geçmiş
    expect(eventHasEnded(ev('ACTIVE', '2026-11-07T12:59:00+03:00'), now: now), isTrue);
    expect(eventHasEnded(ev('ACTIVE', '2026-11-07T13:01:00+03:00'), now: now), isFalse);
  });

  test('iptal edilen etkinlik "bitmiş" sayılmaz ama süresi dolmuş (expired) sayılır', () {
    final c = ev('CANCELLED', '2026-11-07T12:00:00Z');
    expect(eventHasEnded(c, now: now), isFalse);
    expect(eventIsExpired(c, now: now), isTrue);
    expect(eventIsExpired(ev('ACTIVE', '2026-11-07T12:00:00Z'), now: now), isFalse);
  });

  test('bitiş bilinmiyorsa gizlenmez', () {
    expect(eventHasEnded({'status': 'ACTIVE'}, now: now), isFalse);
    expect(eventHasEnded({'status': 'ACTIVE', 'endsAt': 'bozuk'}, now: now), isFalse);
  });

  test('bildirim durumu: sunucu alanı öncelikli, yoksa yük içindeki eventEndsAt', () {
    expect(eventNotifState({'type': 'EVENT', 'eventState': 'CANCELLED'}, const {}, now: now), 'CANCELLED');
    expect(eventNotifState({'type': 'EVENT'}, {'eventEndsAt': '2026-11-07T09:00:00Z'}, now: now), 'ENDED');
    expect(eventNotifState({'type': 'EVENT'}, {'eventEndsAt': '2026-11-07T11:00:00Z'}, now: now), isNull);
    expect(eventNotifState({'type': 'NEWS', 'eventState': 'ENDED'}, const {}, now: now), isNull);
  });
}
