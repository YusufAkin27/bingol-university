import 'package:bu_kampus/core/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('apiConfigValid', () {
    test('debug/test modunda her adres gecerli', () {
      expect(apiConfigValid(origin: 'http://10.0.2.2:8080', release: false), isTrue);
    });
    test('release: https gecerli', () {
      expect(apiConfigValid(origin: 'https://api.bingol.edu.tr', release: true), isTrue);
    });
    test('release: http varsayilan olarak reddedilir', () {
      expect(apiConfigValid(origin: 'http://10.0.2.2:8080', release: true), isFalse);
      expect(apiConfigValid(origin: 'http://192.168.1.220:8080', release: true), isFalse);
    });
    test('release: http yalniz ALLOW_INSECURE_API ile', () {
      expect(apiConfigValid(origin: 'http://192.168.1.220:8080', release: true, allowInsecure: true), isTrue);
    });
    test('release: bozuk adres reddedilir', () {
      expect(apiConfigValid(origin: '', release: true, allowInsecure: true), isFalse);
      expect(apiConfigValid(origin: 'ftp://x.y', release: true, allowInsecure: true), isFalse);
    });
  });
}
