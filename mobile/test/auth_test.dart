import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/features/auth/auth_widgets.dart';

void main() {
  test('e-posta: alan adı kısıtı yok, yalnız biçim denetlenir', () {
    expect(validateEmail('ayse@bingol.edu.tr'), isNull);
    expect(validateEmail(' Ayse@OGR.Bingol.edu.tr '), isNull);
    expect(validateEmail('ayse@gmail.com'), isNull);
    expect(validateEmail('ayse@outlook.com'), isNull);
    expect(validateEmail('ayse@hotmail.com'), isNull);
    expect(validateEmail('ayse@yahoo.com'), isNull);
    expect(validateEmail('ayse@gmail'), isNotNull);
    expect(validateEmail('ayse@'), isNotNull);
    expect(validateEmail('ayse gmail.com'), isNotNull);
    expect(validateEmail(''), isNotNull);
  });

  test('yeni şifre 8-72 karakter olmalı', () {
    expect(validateNewPassword('kisa'), isNotNull);
    expect(validateNewPassword('Sifre1234x'), isNull);
    expect(validateNewPassword('a' * 73), isNotNull);
  });
}
