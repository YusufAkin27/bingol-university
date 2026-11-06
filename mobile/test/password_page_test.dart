import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/reset_success_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/password_page.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Şifre sayfası: şifre güncelleme + "Şifreni mi unuttun?" (doğrulama kodu ile sıfırlama) akışları.
/// Ekran görüntüsü için `PW_SHOTS_OUT=<klasör>` verilir (yoksa görüntü alınmaz).
final _shotKey = GlobalKey();

Widget _app(Widget page, {Brightness brightness = Brightness.light, Size? size}) {
  final app = buildApp(page, brightness: brightness, size: size);
  return RepaintBoundary(key: _shotKey, child: app);
}

Future<void> _shot(WidgetTester t, String name) async {
  final out = Platform.environment['PW_SHOTS_OUT'];
  if (out == null || out.isEmpty) return;
  await t.runAsync(() async {
    final b = _shotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    await Directory(out).create(recursive: true);
    await File('$out/$name.png').writeAsBytes(data!.buffer.asUint8List());
  });
}

Finder _field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(ValueKey(key)));
  await t.pump();
  await t.tap(find.byKey(ValueKey(key)));
}

void main() {
  setUpAll(loadTestFonts);

  group('Şifre sayfası: güncelle', () {
    testWidgets('iki bölüm var: şifre formu ve Şifreni mi unuttun; hesabın e-postası salt okunur gösterilir', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(_app(PasswordPage(session: makeSession(FakeBackend())), size: kPhoneMedium));
      await settle(t);
      expect(find.byKey(const ValueKey('pw-current')), findsOneWidget);
      expect(find.byKey(const ValueKey('pw-submit')), findsOneWidget);
      expect(find.byKey(const ValueKey('pw-forgot-send')), findsOneWidget);
      expect(find.textContaining('UNUTTUN'), findsOneWidget);
      expect(find.text('Kod ayse@bingol.edu.tr adresine gönderilir.'), findsOneWidget);
      // E-posta girişi yok: yalnız 3 şifre alanı.
      expect(find.byType(TextField), findsNWidgets(3));
      await _shot(t, 'pw_tr_light_390');
      await unmount(t);
    });

    testWidgets('başarı: gövde doğru gider, yeni token çifti oturuma yazılır, sayfa kapanır', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..on('/auth/change-password', {'accessToken': 'yeniA', 'refreshToken': 'yeniR', 'expiresInSeconds': 900});
      final s = makeSession(b);
      await t.pumpWidget(_app(AccountSecurityPage(session: s), size: kPhoneMedium));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('sec-password')));
      await settle(t, const Duration(milliseconds: 600));
      await t.enterText(_field('pw-current'), 'eskiSifre1');
      await t.enterText(_field('pw-new'), 'YeniSifre123');
      await t.enterText(_field('pw-repeat'), 'YeniSifre123');
      await _tap(t, 'pw-submit');
      await settle(t, const Duration(milliseconds: 600));
      expect(b.bodies['POST /auth/change-password'], {'currentPassword': 'eskiSifre1', 'newPassword': 'YeniSifre123'});
      expect(s.api.tokens?.access, 'yeniA');
      expect(find.byType(PasswordPage), findsNothing); // başarıda geri dönülür
      expect(find.byType(AccountSecurityPage), findsOneWidget);
      expect(find.text('Şifren güncellendi.'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('kural hataları sunucuya gitmez: kısa, aynı şifre, uyuşmayan tekrar', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      await t.pumpWidget(_app(PasswordPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t);
      await t.enterText(_field('pw-current'), 'abcdef');
      await t.enterText(_field('pw-new'), 'abc');
      await t.enterText(_field('pw-repeat'), 'abd');
      await _tap(t, 'pw-submit');
      await settle(t);
      expect(find.text('Şifre en az 6 karakter olmalı.'), findsOneWidget);
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      await t.enterText(_field('pw-new'), 'abcdef');
      await t.enterText(_field('pw-repeat'), 'abcdef');
      await _tap(t, 'pw-submit');
      await settle(t);
      expect(find.text('Yeni şifre mevcut şifreyle aynı olamaz.'), findsOneWidget);
      expect(b.count('/auth/change-password'), 0);
      await _shot(t, 'pw_tr_light_390_hata');
      await unmount(t);
    });

    testWidgets('429 sınırı: hata bildirimi, sayfa açık kalır', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/change-password', status: 429, code: 'RATE_LIMITED', message: 'Çok fazla deneme.');
      await t.pumpWidget(_app(PasswordPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t);
      await t.enterText(_field('pw-current'), 'eskiSifre1');
      await t.enterText(_field('pw-new'), 'YeniSifre123');
      await t.enterText(_field('pw-repeat'), 'YeniSifre123');
      await _tap(t, 'pw-submit');
      await settle(t, const Duration(milliseconds: 600));
      expect(find.textContaining('Çok fazla deneme.'), findsOneWidget);
      expect(find.byType(PasswordPage), findsOneWidget);
      await unmount(t);
    });
  });

  group('Şifre sayfası: şifremi unuttum (kod ile sıfırlama)', () {
    testWidgets('kod gönder -> yanlış kod -> doğru kod -> yeni şifre -> başarı; oturum kapanır', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/verify-reset-code', status: 400, code: 'INVALID_CODE', message: 'Kod geçersiz.');
      final s = makeSession(b);
      await t.pumpWidget(_app(PasswordPage(session: s), size: kPhoneMedium));
      await settle(t);

      // 1) Kod, hesabın kendi adresine gider (e-posta alanı yok).
      await _tap(t, 'pw-forgot-send');
      await settle(t, const Duration(milliseconds: 600));
      expect(b.bodies['POST /auth/forgot-password'], {'email': 'ayse@bingol.edu.tr'});
      expect(find.byType(ResetCodePage), findsOneWidget);
      expect(find.text('ayse@bingol.edu.tr adresine gönderdiğimiz 6 haneli kodu girin.'), findsOneWidget);
      expect(find.text('E-postayı değiştir'), findsNothing); // oturum açıkken adres değiştirilemez
      expect(find.textContaining('Yeniden gönder'), findsOneWidget);
      await _shot(t, 'pw_kod_tr_light_390');

      // 2) Yanlış kod: hata, kutular temizlenir.
      await t.enterText(find.byType(EditableText).first, '123456');
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('Kod geçersiz.'), findsOneWidget);
      expect(find.byType(NewPasswordPage), findsNothing);
      expect(b.bodies['POST /auth/verify-reset-code'], {'email': 'ayse@bingol.edu.tr', 'code': '123456'});

      // 3) Doğru kod: yeni şifre adımı.
      b
        ..reset('/auth/verify-reset-code')
        ..on('/auth/verify-reset-code', {'resetToken': 'tok'});
      await t.enterText(find.byType(EditableText).first, '654321');
      await settle(t, const Duration(milliseconds: 700));
      expect(find.byType(NewPasswordPage), findsOneWidget);

      // 4) Yeni şifre.
      final f = find.byType(TextFormField);
      await t.enterText(f.at(0), 'YeniSifre123');
      await t.enterText(f.at(1), 'YeniSifre123');
      await t.ensureVisible(find.text('Şifreyi güncelle'));
      await t.tap(find.text('Şifreyi güncelle'));
      await settle(t, const Duration(milliseconds: 800));
      expect(b.bodies['POST /auth/reset-password'],
          {'email': 'ayse@bingol.edu.tr', 'resetToken': 'tok', 'newPassword': 'YeniSifre123', 'client': 'mobile'});

      // 5) Başarı: sunucu tüm oturumları kapattı; yerel oturum da kapanır ve metin bunu söyler.
      expect(find.byType(ResetSuccessPage), findsOneWidget);
      expect(find.text('Şifren güncellendi'), findsOneWidget);
      expect(find.textContaining('tüm cihazlardaki oturumlar'), findsOneWidget);
      expect(s.state, SessionState.signedOut);
      await _shot(t, 'pw_basari_tr_light_390');
      await unmount(t);
    });

    testWidgets('kod gönderilemezse sayfada hata görünür, kod sayfası açılmaz (429)', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/forgot-password', status: 429, code: 'RATE_LIMITED', message: 'Çok fazla istek.');
      await t.pumpWidget(_app(PasswordPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t);
      await _tap(t, 'pw-forgot-send');
      await settle(t, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('pw-forgot-error')), findsOneWidget);
      expect(find.textContaining('Çok fazla istek.'), findsOneWidget);
      expect(find.byType(ResetCodePage), findsNothing);
      await unmount(t);
    });

    testWidgets('çevrimdışı: ağ hatası metni, düğme tekrar aktif', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..offline = true;
      await t.pumpWidget(_app(PasswordPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t);
      await _tap(t, 'pw-forgot-send');
      await settle(t, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('pw-forgot-error')), findsOneWidget);
      expect(find.byType(ResetCodePage), findsNothing);
      expect(t.widget<BuButton>(find.byKey(const ValueKey('pw-forgot-send'))).onPressed, isNotNull);
      await unmount(t);
    });

    testWidgets('yeniden gönder yeni istek atar; anahtar süresi dolunca Şifre sayfasına dönülüp not gösterilir', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()
        ..on('/auth/verify-reset-code', {'resetToken': 'tok'})
        ..fail('/auth/reset-password', status: 400, code: 'INVALID_CODE', message: 'Süre doldu.');
      await t.pumpWidget(_app(PasswordPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t);
      await _tap(t, 'pw-forgot-send');
      await settle(t, const Duration(milliseconds: 600));
      await t.enterText(find.byType(EditableText).first, '123456');
      await settle(t, const Duration(milliseconds: 700));
      final f = find.byType(TextFormField);
      await t.enterText(f.at(0), 'YeniSifre123');
      await t.enterText(f.at(1), 'YeniSifre123');
      await t.ensureVisible(find.text('Şifreyi güncelle'));
      await t.tap(find.text('Şifreyi güncelle'));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.byType(PasswordPage), findsOneWidget);
      expect(find.byType(NewPasswordPage), findsNothing);
      expect(find.text('Doğrulama süresi doldu. Yeni bir kod iste.'), findsOneWidget);
      await unmount(t);
    });
  });

  group('Şifre sayfası: taşma matrisi', () {
    for (final br in Brightness.values) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('${br.name} ${size.width.toInt()} x$scale', (t) async {
            useScreen(t, size);
            t.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
            await t.pumpWidget(_app(PasswordPage(session: makeSession(FakeBackend())), brightness: br, size: size));
            await settle(t);
            expect(t.takeException(), isNull);
            // Hata satırları da taşmamalı.
            await t.enterText(_field('pw-current'), 'a');
            await t.enterText(_field('pw-new'), 'b');
            await t.enterText(_field('pw-repeat'), 'c');
            await _tap(t, 'pw-submit');
            await settle(t);
            expect(t.takeException(), isNull);
            await _shot(t, 'pw_${br.name}_${size.width.toInt()}_x$scale');
            await unmount(t);
          });
        }
      }
    }

    testWidgets('ar RTL taşma yok', (t) async {
      useScreen(t, kPhoneSmall);
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.light(),
        locale: const Locale('ar'),
        home: PasswordPage(session: makeSession(FakeBackend())),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: kPhoneSmall),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Align(alignment: Alignment.topLeft, child: SizedBox(width: kPhoneSmall.width, height: kPhoneSmall.height, child: child)),
          ),
        ),
      ));
      await settle(t);
      expect(t.takeException(), isNull);
      await unmount(t);
    });
  });
}
