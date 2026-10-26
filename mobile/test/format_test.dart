import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/widgets/common.dart';

void main() {
  test('fmtDate', () {
    expect(fmtDate('2026-10-26'), '26.10.2026');
    expect(fmtDate('2026-10-26T10:30:00'), '26.10.2026');
    expect(fmtDate(null), '');
    expect(fmtDate('abc'), 'abc');
  });

  test('longDate', () {
    expect(longDate(DateTime(2026, 10, 26)), '26 Ekim, Pazartesi');
    expect(longDate(DateTime(2026, 1, 4)), '4 Ocak, Pazar');
  });

  test('niceDate', () {
    expect(niceDate('2026-10-26'), '26 Ekim 2026');
    expect(niceDate('2026-03-05T12:00:00'), '5 Mart 2026');
    expect(niceDate(null), '');
    expect(niceDate('bozuk'), 'bozuk');
  });

  test('relativeTime', () {
    String iso(Duration ago) => DateTime.now().subtract(ago).toIso8601String();
    expect(relativeTime(null), '');
    expect(relativeTime('bozuk'), '');
    expect(relativeTime(iso(const Duration(seconds: 10))), 'şimdi');
    expect(relativeTime(iso(const Duration(minutes: 5, seconds: 5))), '5 dk önce');
    expect(relativeTime(iso(const Duration(hours: 3, minutes: 1))), '3 sa önce');
    expect(relativeTime(iso(const Duration(days: 2, hours: 1))), '2 gün önce');
    final old = DateTime.now().subtract(const Duration(days: 30));
    expect(relativeTime(old.toIso8601String()), niceDate(old.toIso8601String()));
  });
}
