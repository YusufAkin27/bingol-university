import 'package:bu_kampus/core/analytics.dart';
import 'package:bu_kampus/core/app_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compareVersions', () {
    expect(compareVersions('1.0.0', '1.0.1'), -1);
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(compareVersions('2.0.0', '1.9.9'), 1);
    expect(compareVersions('1.10.0', '1.9.0'), 1);
  });

  test('isSafeStoreUrl yalnizca https', () {
    expect(isSafeStoreUrl('https://apps.apple.com/x'), isTrue);
    expect(isSafeStoreUrl('http://apps.apple.com/x'), isFalse);
    expect(isSafeStoreUrl('javascript:alert(1)'), isFalse);
    expect(isSafeStoreUrl(null), isFalse);
  });

  test('decideGate', () {
    final d = decideGate(
      {'updateRequired': true, 'storeUrl': 'https://s.example/a', 'latestVersion': '2.0.0'},
      {'maintenance': {'enabled': true, 'message': 'Bakim'}, 'banner': ' Duyuru '},
      current: '1.0.0',
    );
    expect(d.kind, GateKind.updateRequired);
    expect(d.maintenance, isTrue);
    expect(d.maintenanceMessage, 'Bakim');
    expect(d.banner, 'Duyuru');
    expect(decideGate({'updateAvailable': true}, null).kind, GateKind.updateAvailable);
    expect(decideGate({'latestVersion': '1.0.1'}, null, current: '1.0.0').kind, GateKind.updateAvailable);
    expect(decideGate(null, null).kind, GateKind.none);
    expect(decideGate({'updateRequired': true, 'storeUrl': 'http://x'}, null).storeUrl, isNull);
  });

  test('guncelleme iletisi gunde bir', () {
    final now = DateTime(2026, 1, 2, 12);
    expect(shouldShowUpdateNotice(null, now), isTrue);
    expect(shouldShowUpdateNotice(now.subtract(const Duration(hours: 3)), now), isFalse);
    expect(shouldShowUpdateNotice(now.subtract(const Duration(days: 1)), now), isTrue);
  });

  test('analytics isSafe', () {
    expect(Analytics.isSafe('home'), isTrue);
    expect(Analytics.isSafe('a@b.com'), isFalse);
    expect(Analytics.isSafe({'q': 'x@y'}), isFalse);
  });
}
