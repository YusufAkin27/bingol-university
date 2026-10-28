import 'package:bu_kampus/core/identifier.dart';
import 'package:bu_kampus/core/pending_verification.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Finder _suffix() => find.text('@bingol.edu.tr');

Future<void> _fillLogin(WidgetTester tester, String id, String pw) async {
  await tester.enterText(find.byType(TextFormField).at(0), id);
  await tester.enterText(find.byType(TextFormField).at(1), pw);
  await tester.tap(find.text('Giriş yap'));
}

void main() {
  setUpAll(loadTestFonts);

  group('istemci dogrulama', () {
    test('okul numarasi 6-12 hane', () {
      expect(validateIdentifier('226051015'), isNull);
      expect(validateIdentifier('226 051-015'), isNull);
      expect(validateIdentifier('12345'), 'Okul numarasını kontrol edin.');
      expect(validateIdentifier('1234567890123'), 'Okul numarasını kontrol edin.');
      expect(validateIdentifier('22605a015'), 'Okul numarasını kontrol edin.');
      expect(validateIdentifier(''), isNotNull);
    });
    test('e-posta bingol.edu.tr olmali', () {
      expect(validateIdentifier('ayse.yilmaz@bingol.edu.tr'), isNull);
      expect(validateIdentifier('a@ogr.bingol.edu.tr'), isNull);
      expect(validateIdentifier('a@gmail.com'), isNotNull);
      expect(validateIdentifier('a@evilbingol.edu.tr'), isNotNull);
    });
    test('normalize ve tam e-posta', () {
      expect(normalizeIdentifier(' 226-051 015 '), '226051015');
      expect(fullEmail('226051015'), '226051015@bingol.edu.tr');
      expect(fullEmail(' Ayse@Bingol.edu.tr'), 'ayse@bingol.edu.tr');
    });
  });

  group('giris', () {
    testWidgets('rakam yazinca sonek gorunur, @ yazinca kaybolur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 200));
      expect(_suffix(), findsNothing);
      expect(find.text('Okul e-postanız'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), '226051015');
      await tester.pump();
      expect(_suffix(), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), '226051015@bingol.edu.tr');
      await tester.pump();
      expect(_suffix(), findsNothing);
      final f = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(f.keyboardType, TextInputType.emailAddress);
      await unmount(tester);
    });

    testWidgets('gecersiz numara hata verir, istek atilmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await _fillLogin(tester, '12345', 'Sifre1234');
      await tester.pump();
      expect(find.text('Okul numarasını kontrol edin.'), findsOneWidget);
      expect(b.count('/auth/login'), 0);
      await unmount(tester);
    });

    testWidgets('numara govdede aynen gider; basarida oturum acilir', (tester) async {
      final b = FakeBackend()..on('/auth/login', {'accessToken': 'a', 'refreshToken': 'r'});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await _fillLogin(tester, '226 051 015', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 400));
      expect((b.bodies['POST /auth/login'] as Map)['email'], '226051015');
      expect(s.state, SessionState.signedIn);
      await unmount(tester);
    });

    testWidgets('tam e-posta govdede e-posta olarak gider', (tester) async {
      final b = FakeBackend()..on('/auth/login', {'accessToken': 'a', 'refreshToken': 'r'});
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await _fillLogin(tester, 'Ayse@bingol.edu.tr', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 400));
      expect((b.bodies['POST /auth/login'] as Map)['email'], 'ayse@bingol.edu.tr');
      await unmount(tester);
    });

    testWidgets('EMAIL_NOT_VERIFIED: resend-code + dogrulama sayfasi + bekleyen kayit', (tester) async {
      final b = FakeBackend()..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED');
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await _fillLogin(tester, '226051015', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('/auth/resend-code'), 1);
      expect((b.bodies['POST /auth/resend-code'] as Map)['email'], '226051015');
      expect(find.byType(VerifyCodePage), findsOneWidget);
      expect(find.textContaining('E-postanı doğrula'), findsOneWidget);
      expect(find.textContaining('226051015@bingol.edu.tr adresine gönderildi'), findsOneWidget);
      expect(find.text('Başka hesapla giriş yap'), findsOneWidget);
      expect((await s.pending.load())?.identifier, '226051015');
      await unmount(tester);
    });

    testWidgets('resend 429 cooldown sessizce yutulur', (tester) async {
      final b = FakeBackend()
        ..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED')
        ..fail('/auth/resend-code', status: 429, code: 'RESEND_COOLDOWN', message: 'Bekleyin.');
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await _fillLogin(tester, '226051015', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(VerifyCodePage), findsOneWidget);
      expect(find.text('Bekleyin.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('yanlis sifre genel hata, dogrulama sayfasi acilmaz', (tester) async {
      final b = FakeBackend()
        ..fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'Bilgiler hatalı.');
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await _fillLogin(tester, '226051015', 'yanlis');
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
      await _fillLogin(tester, '226051015', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 500));
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 600));
      expect((b.bodies['POST /auth/verify-email'] as Map)['email'], '226051015');
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
      await _fillLogin(tester, '226051015', 'Sifre1234');
      await settle(tester, const Duration(milliseconds: 500));
      b.on('/auth/login', {'accessToken': 'a', 'refreshToken': 'r'});
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('/auth/login'), 2);
      expect((b.bodies['POST /auth/login'] as Map)['email'], '226051015@bingol.edu.tr');
      expect(s.state, SessionState.signedIn);
      await unmount(tester);
    });
  });

  group('bekleyen dogrulama', () {
    test('kaydet / sil / 72 saat sonra otomatik silinir', () async {
      var now = DateTime(2026, 1, 1, 10);
      final st = PendingVerificationStore.memory(now: () => now);
      expect(await st.load(), isNull);
      await st.save('226051015');
      final p = await st.load();
      expect(p!.identifier, '226051015');
      expect(p.email, '226051015@bingol.edu.tr');
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
      await s.pending.save('226051015');
      await tester.pumpWidget(buildApp(LoginPage(session: s)));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Doğrulamayı tamamla'), findsOneWidget);
      expect(find.text('226051015@bingol.edu.tr'), findsOneWidget);
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
      await s.pending.save('226051015');
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
    testWidgets('tum alanlar tek istekte; numara govdede; dogrulama sayfasi tam e-postayi gosterir', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      fakeCatalog(b);
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(RegisterPage(session: s)));
      await settle(tester, const Duration(milliseconds: 300));
      await fillAcademic(tester);
      await tester.tap(find.text('Devam'));
      await tester.pump(const Duration(milliseconds: 400));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ayşe Yılmaz');
      await tester.enterText(fields.at(1), '226051015');
      await tester.pump();
      expect(_suffix(), findsOneWidget);
      await tester.tap(find.text('Devam'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextFormField).first, 'Sifre1234');
      await tester.pump();
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('/auth/register'), 1);
      final body = b.bodies['POST /auth/register'] as Map;
      expect(body['email'], '226051015');
      expect(body['displayName'], 'Ayşe Yılmaz');
      expect(body['password'], 'Sifre1234');
      expect(body['acceptTerms'], true);
      expect(body['department'], isNotNull);
      expect(body['grade'], '3');
      expect(find.byType(VerifyCodePage), findsOneWidget);
      expect(find.textContaining('226051015@bingol.edu.tr adresine gönderildi'), findsOneWidget);
      expect((await s.pending.load())?.identifier, '226051015');
      await unmount(tester);
    });

    testWidgets('gecersiz numara kayitta reddedilir', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      // Kayıt 3 adımlı sihirbaz: numara 2. adımda doğrulanır, geçersizse 3. adıma geçilmez.
      await fillAcademic(tester);
      await tester.tap(find.text('Devam'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextFormField).at(0), 'Ayşe Yılmaz');
      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await tester.pump();
      await tester.tap(find.text('Devam'));
      await tester.pump();
      expect(find.text('Okul numarasını kontrol edin.'), findsOneWidget);
      expect(find.text('Adım 2/3'), findsOneWidget);
      expect(b.count('/auth/register'), 0);
      await unmount(tester);
    });
  });

  group('sifremi unuttum', () {
    testWidgets('numarayla kod ister; kod ekraninda tam e-posta gorunur', (tester) async {
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(ForgotPasswordPage(session: makeSession(b, signedIn: false))));
      await tester.enterText(find.byType(TextFormField), '226051015');
      await tester.tap(find.text('Kod gönder'));
      await settle(tester, const Duration(milliseconds: 600));
      expect((b.bodies['POST /auth/forgot-password'] as Map)['email'], '226051015');
      expect(find.byType(ResetCodePage), findsOneWidget);
      expect(find.text('226051015@bingol.edu.tr adresine gönderdiğimiz 6 haneli kodu girin.'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('tasma matrisi', () {
    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('numara + sonek + bant | ${br.name} ${size.width.toInt()}', (tester) async {
          useScreen(tester, size);
          final b = FakeBackend();
          final s = makeSession(b, signedIn: false);
          await s.pending.save('226051015');
          await tester.pumpWidget(buildApp(LoginPage(session: s), brightness: br, size: size));
          await settle(tester, const Duration(milliseconds: 300));
          await tester.enterText(find.byType(TextFormField).at(0), '226051015');
          await tester.enterText(find.byType(TextFormField).at(1), 'x');
          await tester.pump();
          expect(tester.takeException(), isNull);
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
