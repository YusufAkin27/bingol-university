import 'package:bu_kampus/core/idempotency_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Idempotency-Key: 100 bin anahtar benzersiz, biçim korunur', () {
    final keys = <String>{for (var i = 0; i < 100000; i++) newIdempotencyKey('p')};
    expect(keys.length, 100000);
    expect(keys.every((k) => RegExp(r'^p[0-9a-z]+-[0-9a-z]+$').hasMatch(k)), isTrue);
    expect(newIdempotencyKey().startsWith('k'), isTrue);
  });
}
