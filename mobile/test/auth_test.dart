import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/features/auth/auth_widgets.dart';

void main() {
  test('e-posta yalnızca bingol.edu.tr ve alt alanlarını kabul eder', () {
    expect(validateEmail('ayse@bingol.edu.tr'), isNull);
    expect(validateEmail(' Ayse@OGR.Bingol.edu.tr '), isNull);
    expect(validateEmail('ayse@gmail.com'), isNotNull);
    expect(validateEmail('ayse@evilbingol.edu.tr'), isNotNull);
    expect(validateEmail(''), isNotNull);
  });

  test('yeni şifre 8-72 karakter olmalı', () {
    expect(validateNewPassword('kisa'), isNotNull);
    expect(validateNewPassword('Sifre1234x'), isNull);
    expect(validateNewPassword('a' * 73), isNotNull);
  });
}
