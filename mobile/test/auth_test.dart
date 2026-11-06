import 'package:bu_kampus/core/identifier.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/auth_widgets.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('giriş e-postası: alan adı kısıtı yok, yalnız biçim denetlenir', () {
    expect(validateIdentifier('ayse@bingol.edu.tr'), isNull);
    expect(validateIdentifier(' Ayse@OGR.Bingol.edu.tr '), isNull);
    expect(validateIdentifier('ayse@gmail.com'), isNull);
    expect(validateIdentifier('ayse@outlook.com'), isNull);
    expect(validateIdentifier('ayse@hotmail.com'), isNull);
    expect(validateIdentifier('ayse@yahoo.com'), isNull);
    expect(validateIdentifier('ayse@gmail'), isNotNull);
    expect(validateIdentifier('ayse@'), isNotNull);
    expect(validateIdentifier('ayse gmail.com'), isNotNull);
    expect(validateIdentifier(''), isNotNull);
  });

  test('kayıt e-postası: tam adres şart, +etiket istemcide reddedilir (sunucu EMAIL_ALIAS_NOT_ALLOWED)', () {
    expect(validateRegisterEmail('ayse@gmail.com'), isNull);
    expect(validateRegisterEmail('ayse.yilmaz@ogr.bingol.edu.tr'), isNull);
    expect(validateRegisterEmail('ayse+test@gmail.com'), isNotNull);
    expect(validateRegisterEmail('123456'), isNotNull); // okul numarası kısayolu kayıtta yok
    expect(validateRegisterEmail(''), isNotNull);
    expect(validateRegisterEmail('${'a' * 70}@gmail.com'), isNotNull);
  });

  testWidgets('yeni şifre 6-72 karakter ve en çok 72 bayt (dil duyarlı doğrulayıcı)', (t) async {
    late String? Function(String?) v;
    await t.pumpWidget(MaterialApp(
      theme: BuTheme.light(),
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (c) {
        v = newPasswordValidator(c);
        return const SizedBox();
      }),
    ));
    expect(v('kisa'), isNotNull);
    expect(v('Sifre1234x'), isNull);
    expect(v('a' * 72), isNull);
    expect(v('a' * 73), isNotNull);
    expect(v('ş' * 40), isNotNull); // 40 karakter ama 80 bayt
  });
}
