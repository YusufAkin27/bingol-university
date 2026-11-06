import 'package:bu_kampus/core/identifier.dart';
import 'package:bu_kampus/core/pending_verification.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/auth/widgets/login_underline_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Istemci hicbir alan adi eklemez: eski "@bingol.edu.tr" soneki hicbir yerde gorunmez.
Finder _suffix() => find.text('@bingol.edu.tr');

Future<void> _fillLogin(WidgetTester tester, String id, String pw) async {
  await tester.enterText(find.byType(TextFormField).at(0), id);
  await tester.enterText(find.byType(TextFormField).at(1), pw);
  await tester.pump(const Duration(milliseconds: 700)); // aşamalı giriş animasyonu bitmeden dokunma isabet etmez
  await tester.tap(find.text('Giriş yap'));
}

void main() {
  setUpAll(loadTestFonts);

  group('istemci dogrulama', () {
    test('giris/sifirlama alani: yalniz e-posta bicimi; rakam-only reddedilir (alan adi eklenmez)', () {
      expect(validateIdentifier('226051015'), 'Geçerli bir e-posta adresi girin.');
      expect(validateIdentifier('226 051-015'), 'Geçerli bir e-posta adresi girin.');
      expect(validateIdentifier('ad.soyad'), 'Geçerli bir e-posta adresi girin.');
      expect(validateIdentifier(''), 'E-posta adresinizi girin.');
      expect(validateIdentifier('ayse.yilmaz@bingol.edu.tr'), isNull);
      expect(validateIdentifier('a@ogr.bingol.edu.tr'), isNull);
      expect(validateIdentifier('a@gmail.com'), isNull);
      expect(validateIdentifier('a@outlook.com'), isNull);
      expect(validateIdentifier('a@hotmail.com'), isNull);
      expect(validateIdentifier('a@yahoo.com'), isNull);
      expect(validateIdentifier('a@gmail'), 'Geçerli bir e-posta adresi girin.');
      expect(validateIdentifier('a@@gmail.com'), isNotNull);
    });
    test('kayit alani yalniz TAM e-posta kabul eder', () {
      const full = 'E-posta adresinizin tamamını yazın.';
      expect(validateRegisterEmail('226051015'), full);
      expect(validateRegisterEmail('226 051-015'), full);
      expect(validateRegisterEmail('ad.soyad'), full);
      expect(validateRegisterEmail(''), 'E-posta adresinizi girin.');
      expect(validateRegisterEmail('ayse.yilmaz@bingol.edu.tr'), isNull);
      expect(validateRegisterEmail('226051015@bingol.edu.tr'), isNull);
      expect(validateRegisterEmail('a@ogr.bingol.edu.tr'), isNull);
      expect(validateRegisterEmail('a@gmail.com'), isNull);
      expect(validateRegisterEmail('Ayse.Yilmaz@Outlook.com'), isNull);
      expect(validateRegisterEmail('a@hotmail.com'), isNull);
      expect(validateRegisterEmail('a@yahoo.com'), isNull);
      expect(validateRegisterEmail('a@gmail'), 'Geçerli bir e-posta adresi girin.');
      expect(validateRegisterEmail('a..b@gmail.com'), 'Geçerli bir e-posta adresi girin.');
    });
    test('normalize: yalniz bosluk temizler ve kucuk harfe cevirir; alan adi EKLEMEZ', () {
      expect(normalizeIdentifier(' 226-051 015 '), '226-051015');
      expect(normalizeIdentifier('226051015'), '226051015');
      expect(normalizeIdentifier(' Ayse@Bingol.edu.tr'), 'ayse@bingol.edu.tr');
      expect(normalizeIdentifier(' Ayse@Gmail.com'), 'ayse@gmail.com');
      expect(normalizeIdentifier('226051015@gmail.com'), '226051015@gmail.com');
      expect(normalizeIdentifier(null), '');
    });
  });

  group('giris', () {
    testWidgets('etiket yalniz E-posta; rakam yazilinca sonek/alan adi eklenmez; e-posta klavyesi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 200));
      expect(_suffix(), findsNothing);
      expect(find.text('E-posta'), findsOneWidget);
      expect(find.textContaining('okul numara'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(0), '266');
      await tester.pump();
      expect(_suffix(), findsNothing);
      expect(find.textContaining('bingol.edu.tr'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, '266');
      await tester.enterText(find.byType(TextFormField).at(0), 'ayse@gmail.com');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, 'ayse@gmail.com');
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).keyboardType, TextInputType.emailAddress);
      expect(_suffix(), findsNothing);
      await unmount(tester);
    });

    testWidgets('yalniz rakam gecersiz e-posta sayilir: hata verir, istek atilmaz, alan adi eklenmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await _fillLogin(tester, '226051015', 'Sifre1234');
      await tester.pump();
      expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
      expect(b.count('/auth/login'), 0);
      await unmount(tester);
    });

    testWidgets('tam e-posta (gmail) govdede kucuk harfle aynen gider; basarida oturum acilir', (tester) async {
      final b = FakeBackend()..on('/auth/login', {'accessToken': 'a', 'refreshToken': 'r'});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await _fillLogin(tester, ' Ayse.Yilmaz@Gmail.com ', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 400));
      expect((b.bodies['POST /auth/login'] as Map)['email'], 'ayse.yilmaz@gmail.com');
      expect(s.state, SessionState.signedIn);
      await unmount(tester);
    });

    testWidgets('gecersiz e-posta bicimi hata verir, istek atilmaz', (tester) async {
      final b = FakeBackend()..on('/auth/login', {'accessToken': 'a', 'refreshToken': 'r'});
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await _fillLogin(tester, 'ayse@gmail', 'Sifre1234');
      await tester.pump();
      expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
      expect(b.count('/auth/login'), 0);
      await unmount(tester);
    });

    testWidgets('EMAIL_NOT_VERIFIED: resend-code + dogrulama sayfasi + bekleyen kayit', (tester) async {
      final b = FakeBackend()..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED');
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await _fillLogin(tester, 'ali@gmail.com', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('/auth/resend-code'), 1);
      expect((b.bodies['POST /auth/resend-code'] as Map)['email'], 'ali@gmail.com');
      expect(find.byType(VerifyCodePage), findsOneWidget);
      expect(find.textContaining('E-postanı doğrula'), findsOneWidget);
      expect(find.textContaining('ali@gmail.com adresine gönderildi'), findsOneWidget);
      expect(find.text('Başka hesapla giriş yap'), findsOneWidget);
      expect((await s.pending.load())?.identifier, 'ali@gmail.com');
      await unmount(tester);
    });

    testWidgets('resend 429 cooldown sessizce yutulur', (tester) async {
      final b = FakeBackend()
        ..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED')
        ..fail('/auth/resend-code', status: 429, code: 'RESEND_COOLDOWN', message: 'Bekleyin.');
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await _fillLogin(tester, 'ali@gmail.com', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(VerifyCodePage), findsOneWidget);
      expect(find.text('Bekleyin.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('yanlis sifre genel hata, dogrulama sayfasi acilmaz', (tester) async {
      final b = FakeBackend()
        ..fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'Bilgiler hatalı.');
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await _fillLogin(tester, 'ali@gmail.com', 'yanlis');
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Bilgiler hatalı.'), findsOneWidget);
      expect(find.byType(VerifyCodePage), findsNothing);
      expect(b.count('/auth/resend-code'), 0);
      await unmount(tester);
    });

    testWidgets('dogrulama sonrasi otomatik giris (verify-email token doner)', (tester) async {
      final b = FakeBackend()
        ..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED')
        ..on('/auth/verify-email', {'accessToken': 'a', 'refreshToken': 'r'});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await _fillLogin(tester, 'ali@gmail.com', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 500));
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 600));
      expect((b.bodies['POST /auth/verify-email'] as Map)['email'], 'ali@gmail.com');
      // Parola kaniti: girişte girilen şifre doğrulama isteğine eklenir
      expect((b.bodies['POST /auth/verify-email'] as Map)['password'], 'Sifre1234');
      expect(s.state, SessionState.signedIn);
      expect(await s.pending.load(), isNull);
      await unmount(tester);
    });

    testWidgets('verify-email token donmezse bellekteki sifreyle bir kez giris yapilir', (tester) async {
      final b = FakeBackend()
        ..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED')
        ..on('/auth/verify-email', <String, dynamic>{});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await _fillLogin(tester, 'ali@gmail.com', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 500));
      b.on('/auth/login', {'accessToken': 'a', 'refreshToken': 'r'});
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('/auth/login'), 2);
      expect((b.bodies['POST /auth/login'] as Map)['email'], 'ali@gmail.com');
      expect(s.state, SessionState.signedIn);
      await unmount(tester);
    });
  });

  group('bekleyen dogrulama', () {
    test('kaydet / sil / 72 saat sonra otomatik silinir', () async {
      var now = DateTime(2026, 1, 1, 10);
      final st = PendingVerificationStore.memory(now: () => now);
      expect(await st.load(), isNull);
      await st.save('ali@gmail.com');
      final p = await st.load();
      expect(p!.identifier, 'ali@gmail.com');
      expect(p.email, 'ali@gmail.com');
      now = now.add(const Duration(hours: 71));
      expect(await st.load(), isNotNull);
      now = now.add(const Duration(hours: 2));
      expect(await st.load(), isNull);
      await st.save('a@bingol.edu.tr');
      await st.clear();
      expect(await st.load(), isNull);
    });

    testWidgets('giris ekraninda bant gorunur, dokununca dogrulama sayfasi acilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = makeSession(b, signedIn: false);
      await s.pending.save('ali@gmail.com');
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Doğrulamayı tamamla'), findsOneWidget);
      expect(find.text('E-postanı doğrula'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pending-verify-banner')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(VerifyCodePage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bekleyen kayit yoksa bant yok', (tester) async {
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Doğrulamayı tamamla'), findsNothing);
      await unmount(tester);
    });

    testWidgets('baska hesapla giris yap ilk ekrana doner', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = makeSession(b, signedIn: false);
      await s.pending.save('ali@gmail.com');
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('pending-verify-banner')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Başka hesapla giriş yap'));
      await tester.tap(find.text('Başka hesapla giriş yap'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(VerifyCodePage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('kayit', () {
    testWidgets('ad + e-posta (gmail) + sifre tek istekte; dogrulama sayfasi e-postayi gosterir', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(RegisterPage(session: s)));
      await settle(tester, const Duration(milliseconds: 300));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ayşe Yılmaz');
      // Alan herhangi bir geçerli e-postayı alır; sonek yoktur.
      await tester.enterText(fields.at(1), 'Ayse.Yilmaz@Gmail.com');
      await tester.pump();
      expect(_suffix(), findsNothing);
      await tester.enterText(fields.at(2), 'Sifre1234');
      await tester.pump();
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('/auth/register'), 1);
      final body = b.bodies['POST /auth/register'] as Map;
      expect(body['email'], 'ayse.yilmaz@gmail.com');
      expect(body['displayName'], 'Ayşe Yılmaz');
      expect(body['password'], 'Sifre1234');
      expect(body['acceptTerms'], true);
      expect(body.containsKey('department'), isFalse);
      expect(body.containsKey('grade'), isFalse);
      expect(find.byType(VerifyCodePage), findsOneWidget);
      expect(find.textContaining('ayse.yilmaz@gmail.com adresine gönderildi'), findsOneWidget);
      expect((await s.pending.load())?.identifier, 'ayse.yilmaz@gmail.com');
      await unmount(tester);
    });

    testWidgets('okul e-postasi ile kayit eskisi gibi calisir', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(RegisterPage(session: s)));
      await settle(tester, const Duration(milliseconds: 300));
      await fillRegister(tester);
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect((b.bodies['POST /auth/register'] as Map)['email'], '226051015@bingol.edu.tr');
      expect(find.byType(VerifyCodePage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('gecersiz e-posta bicimi kayitta reddedilir: istek yok', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      await fillRegister(tester, email: 'ayse@gmail');
      await tester.tap(find.text('Kayıt ol').last);
      await tester.pump();
      expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
      expect(b.count('/auth/register'), 0);
      await unmount(tester);
    });

    testWidgets('e-posta alani Ad soyad ve Sifre ile AYNI alt cizgili tasarimda; ornek adres/okul numarasi metni yok', (tester) async {
      useScreen(tester, const Size(390, 1800));
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(FakeBackend(), signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      final fields = tester.widgetList<LoginUnderlineField>(find.byType(LoginUnderlineField)).toList();
      expect(fields.length, 3);
      expect(fields.map((f) => f.boxed).toSet(), {false});
      expect(find.text('E-posta'), findsOneWidget);
      expect(find.textContaining('ad.soyad@gmail.com'), findsNothing);
      expect(find.textContaining('Örn.'), findsNothing);
      expect(find.textContaining('okul numara'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(1), '226051015');
      await tester.pump();
      expect(_suffix(), findsNothing);
      await unmount(tester);
    });

    testWidgets('yalniz rakam (okul numarasi) kayitta tam e-posta ister: istek yok', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      await fillRegister(tester, email: '226051015');
      await tester.tap(find.text('Kayıt ol').last);
      await tester.pump();
      expect(find.text('E-posta adresinizin tamamını yazın.'), findsOneWidget);
      expect(b.count('/auth/register'), 0);
      await unmount(tester);
    });

    testWidgets('+etiket: istemci istek atmadan reddeder, dogrulama sayfasi acilmaz', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend()..fail('/auth/register', status: 400, code: 'EMAIL_ALIAS_NOT_ALLOWED');
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      await fillRegister(tester, email: 'ayse+x@gmail.com');
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('/auth/register'), 0); // istemci denetimi: sunucuya gitmez
      expect(find.text('E-posta adresinde + etiketi kullanılamaz.'), findsWidgets);
      expect(find.byType(VerifyCodePage), findsNothing);
      await unmount(tester);
    });
  });

  group('sifremi unuttum', () {
    testWidgets('gmail ile kod ister; govdede e-posta aynen gider', (tester) async {
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(ForgotPasswordPage(session: makeSession(b, signedIn: false))));
      await tester.enterText(find.byType(TextFormField), 'Ayse@Gmail.com');
      await tester.tap(find.text('Kod gönder'));
      await settle(tester, const Duration(milliseconds: 600));
      expect((b.bodies['POST /auth/forgot-password'] as Map)['email'], 'ayse@gmail.com');
      expect(find.byType(ResetCodePage), findsOneWidget);
      expect(find.text('ayse@gmail.com adresine gönderdiğimiz 6 haneli kodu girin.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yalniz e-posta alani: okul numarasi metni yok, rakam yazilinca alan adi eklenmez ve istek atilmaz', (tester) async {
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(ForgotPasswordPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 200));
      expect(find.text('E-posta'), findsOneWidget);
      expect(find.textContaining('okul numara'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '226051015');
      await tester.pump();
      expect(_suffix(), findsNothing);
      await tester.tap(find.text('Kod gönder'));
      await tester.pump();
      expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
      expect(b.count('/auth/forgot-password'), 0);
      await unmount(tester);
    });
  });

  group('tasma matrisi', () {
    for (final br in Brightness.values) {
      testWidgets('kayit sayfasi + hata | ${br.name} 320 x1.3', (tester) async {
        useScreen(tester, kPhoneSmall);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final b = FakeBackend();
        await tester.pumpWidget(
            buildApp(RegisterPage(session: makeSession(b, signedIn: false)), brightness: br, size: kPhoneSmall));
        await settle(tester, const Duration(milliseconds: 300));
        await fillRegister(tester, email: 'ayse@gmail');
        await tester.ensureVisible(find.text('Kayıt ol').last);
        await tester.tap(find.text('Kayıt ol').last);
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('e-posta + bant | ${br.name} ${size.width.toInt()}', (tester) async {
          useScreen(tester, size);
          final b = FakeBackend();
          final s = makeSession(b, signedIn: false);
          await s.pending.save('ali@gmail.com');
          await tester.pumpWidget(buildApp(LoginPage(session: s), brightness: br, size: size));
          await settle(tester, const Duration(milliseconds: 300));
          await tester.enterText(find.byType(TextFormField).at(0), 'ali@gmail.com');
          await tester.enterText(find.byType(TextFormField).at(1), 'x');
          // Odaklanan alanı görünür kılan kaydırma animasyonu bitmeden dokunuşlar yok sayılır.
          await settle(tester, const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byKey(const ValueKey('pending-verify-banner')));
          await settle(tester, const Duration(milliseconds: 400));
          await tester.tap(find.byKey(const ValueKey('pending-verify-banner')));
          await settle(tester, const Duration(milliseconds: 500));
          expect(find.byType(VerifyCodePage), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });
}
