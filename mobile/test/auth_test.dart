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

  test('yeni şifre tam 6 rakam olmalı ve kolay tahmin edilmemeli', () {
    expect(validateNewPassword('kisa'), isNotNull);
    expect(validateNewPassword('12345'), isNotNull);
    expect(validateNewPassword('4819520'), isNotNull);
    expect(validateNewPassword('48195a'), isNotNull);
    expect(validateNewPassword('Sifre1234x'), isNotNull);
    expect(validateNewPassword('481952'), isNull);
    expect(validateNewPassword('111111'), isNotNull);
    expect(validateNewPassword('123456'), isNotNull);
  });
}
