import 'package:bu_kampus/core/oauth/real_email_api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/profile_setup_page.dart';
import 'package:bu_kampus/features/auth/real_email_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Apple "E-postamı gizle" hesabı için "Gerçek e-posta adresiniz" adımı: API modeli, sayfa akışı (e-posta -> kod -> başarı),
/// hata yolları, profil kapısı yönlendirmesi (zorunlu / yumuşak / 403 sinyali) ve yerleşim matrisi.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  const real = 'gercek.kisi@gmail.com';

  /// Sunucu davranışı: start/verify için dinamik işleyici (yanıtlar `startReply`/`verifyReply` ile değiştirilir).
  FakeBackend backend({
    FakeResult? startReply,
    FakeResult? verifyReply,
  }) {
    final b = FakeBackend();
    fakeCatalog(b);
    b.handlers.add((req, path) {
      if (req.method == 'POST' && path == '/users/me/email/start') {
        return startReply ??
            const FakeResult.json({'sent': true, 'emailMasked': 'g***@gmail.com', 'expiresInSeconds': 600, 'resendInSeconds': 180});
      }
      if (req.method == 'POST' && path == '/users/me/email/verify') {
        return verifyReply ??
            const FakeResult.json({'email': real, 'emailVerified': true, 'emailNeedsReal': false, 'realEmailRequired': false});
      }
      return null;
    });
    return b;
  }

  Widget page(Session s, {bool mandatory = true, VoidCallback? onDone, VoidCallback? onSkip}) => buildApp(
        RealEmailPage(session: s, mandatory: mandatory, onDone: onDone ?? () {}, onSkip: onSkip),
      );

  Future<void> enterEmail(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField).first, text);
    await tester.pump();
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.text('Kod gönder'));
    await settle(tester, const Duration(milliseconds: 600));
  }

  group('RealEmailStatus / isRelayEmail', () {
    test('alanlar yoksa gerekmez; required yalnız needsReal iken anlamlı', () {
      expect(RealEmailStatus.fromJson(null).needsReal, isFalse);
      expect(RealEmailStatus.fromJson({'id': 1}).needsReal, isFalse);
      expect(RealEmailStatus.fromJson({'emailNeedsReal': false, 'realEmailRequired': true}).required, isFalse);
      final soft = RealEmailStatus.fromJson({'emailNeedsReal': true, 'realEmailRequired': false});
      expect(soft.needsReal, isTrue);
      expect(soft.required, isFalse);
      final hard = RealEmailStatus.fromJson({'emailNeedsReal': true, 'realEmailRequired': true});
      expect(hard.required, isTrue);
    });

    test('röle alan adı büyük/küçük harf duyarsız; alt alan adı hilesi röle sayılmaz', () {
      expect(isRelayEmail('abc@privaterelay.appleid.com'), isTrue);
      expect(isRelayEmail(' ABC@PrivateRelay.AppleID.com '), isTrue);
      expect(isRelayEmail('abc@icloud.com'), isFalse);
      expect(isRelayEmail('abc@evil-privaterelay.appleid.com'), isFalse);
      expect(isRelayEmail(null), isFalse);
      expect(isRelayEmail('yok'), isFalse);
    });
  });

  group('RealEmailPage', () {
    testWidgets('zorunlu: açıklama, e-posta alanı (örnek ipucu yok), Kod gönder, Çıkış yap; atlama ve geri yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(page(makeSession(backend())));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Gerçek e-posta adresiniz'), findsOneWidget);
      expect(find.textContaining('Gizli Apple adresiniz'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('E-posta'), findsOneWidget);
      expect(find.textContaining('@gmail'), findsNothing);
      expect(find.textContaining('ornek'), findsNothing);
      expect(find.text('Kod gönder'), findsOneWidget);
      expect(find.text('Çıkış yap'), findsOneWidget);
      expect(find.text('Şimdi değil'), findsNothing);
      expect(find.bySemanticsLabel('Geri'), findsNothing);
      await unmount(tester);
    });

    testWidgets('yumuşak adım: "Şimdi değil" onSkip çağırır, Çıkış yap yok, isteğe bağlı notu var', (tester) async {
      useScreen(tester, kPhoneMedium);
      var skipped = 0;
      await tester.pumpWidget(page(makeSession(backend()), mandatory: false, onSkip: () => skipped++));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.textContaining('zorunlu değil'), findsOneWidget);
      expect(find.text('Çıkış yap'), findsNothing);
      await tester.tap(find.text('Şimdi değil'));
      await tester.pump();
      expect(skipped, 1);
      await unmount(tester);
    });

    testWidgets('geçersiz e-posta ve gizli adres: istek atılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      await tester.pumpWidget(page(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await enterEmail(tester, 'ayse');
      await tapSend(tester);
      expect(b.count('POST /users/me/email/start'), 0);
      await enterEmail(tester, 'abc123@privaterelay.appleid.com');
      await tapSend(tester);
      expect(find.textContaining('Gizli (geçici) bir adres kullanılamaz'), findsOneWidget);
      expect(b.count('POST /users/me/email/start'), 0);
      await unmount(tester);
    });

    testWidgets('tam akış: e-posta -> kod -> başarı; oturum e-postası güncellenir, Devam et onDone çağırır', (tester) async {
      useScreen(tester, const Size(390, 1000));
      final b = backend();
      final s = makeSession(b);
      var done = 0;
      await tester.pumpWidget(page(s, onDone: () => done++));
      await settle(tester, const Duration(milliseconds: 400));

      await enterEmail(tester, '  Gercek.Kisi@Gmail.com ');
      await tapSend(tester);
      expect((b.bodies['POST /users/me/email/start'] as Map)['email'], real);
      expect(find.text('Kodu girin'), findsOneWidget);
      expect(find.textContaining(real), findsWidgets);
      expect(find.textContaining('spam'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 900));
      expect((b.bodies['POST /users/me/email/verify'] as Map)['code'], '123456');
      expect(s.email, real);
      expect(find.text('E-postanız güncellendi'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Devam et'));
      await tester.pump();
      expect(done, 1);
      await unmount(tester);
    });

    testWidgets('yanlış kod hata bandı gösterir ve sayfada kalır; hesap e-postası değişmez', (tester) async {
      useScreen(tester, const Size(390, 1000));
      final b = backend(verifyReply: const FakeResult.json({'code': 'INVALID_CODE', 'message': 'Kod geçersiz veya süresi dolmuş.'}, status: 400));
      final s = makeSession(b);
      await tester.pumpWidget(page(s));
      await settle(tester, const Duration(milliseconds: 400));
      await enterEmail(tester, real);
      await tapSend(tester);
      await tester.enterText(find.byType(EditableText).first, '000000');
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.textContaining('Kod geçersiz'), findsWidgets);
      expect(find.text('Kodu girin'), findsOneWidget);
      expect(s.email, 'ayse@bingol.edu.tr');
      await unmount(tester);
    });

    testWidgets('EMAIL_UNAVAILABLE: e-posta adımına dönülür, alan altında açıklama', (tester) async {
      useScreen(tester, const Size(390, 1000));
      final b = backend(verifyReply: const FakeResult.json({'code': 'EMAIL_UNAVAILABLE', 'message': 'x'}, status: 409));
      await tester.pumpWidget(page(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await enterEmail(tester, real);
      await tapSend(tester);
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Gerçek e-posta adresiniz'), findsOneWidget);
      expect(find.textContaining('Bu e-posta adresi kullanılamıyor'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('start 400 EMAIL_ALIAS_NOT_ALLOWED / sunucu röle reddi alan altında gösterilir', (tester) async {
      useScreen(tester, const Size(390, 1000));
      final b = backend(startReply: const FakeResult.json({'code': 'EMAIL_RELAY_NOT_ALLOWED', 'message': 'x'}, status: 400));
      await tester.pumpWidget(page(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await enterEmail(tester, 'ali@gmail.com');
      await tapSend(tester);
      expect(find.textContaining('Gizli (geçici) bir adres kullanılamaz'), findsOneWidget);
      expect(find.text('Kodu girin'), findsNothing);
      await unmount(tester);
    });

    testWidgets('start 429 RESEND_COOLDOWN: kod zaten gitmiştir, kod adımına geçilir', (tester) async {
      useScreen(tester, const Size(390, 1000));
      final b = backend(startReply: const FakeResult.json({'code': 'RESEND_COOLDOWN', 'message': 'bekleyin'}, status: 429));
      await tester.pumpWidget(page(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await enterEmail(tester, real);
      await tapSend(tester);
      expect(find.text('Kodu girin'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('"E-postayı değiştir" e-posta adımına döner', (tester) async {
      useScreen(tester, const Size(390, 1000));
      await tester.pumpWidget(page(makeSession(backend())));
      await settle(tester, const Duration(milliseconds: 400));
      await enterEmail(tester, real);
      await tapSend(tester);
      expect(find.text('Kodu girin'), findsOneWidget);
      await tester.tap(find.text('E-postayı değiştir'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Gerçek e-posta adresiniz'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('"Çıkış yap" oturumu kapatır (zorunlu kapı tek çıkış)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final s = makeSession(backend());
      await tester.pumpWidget(page(s));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Çıkış yap'));
      await tester.tap(find.text('Çıkış yap'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(s.state, SessionState.signedOut);
      await unmount(tester);
    });

    for (final lang in ['tr', 'ar']) {
      for (final dark in [false, true]) {
        for (final size in [kPhoneSmall, kPhoneMedium]) {
          for (final scale in [1.0, 1.3]) {
            testWidgets('taşma yok | $lang ${dark ? 'koyu' : 'açık'} ${size.width.toInt()} x$scale (e-posta, kod, başarı)', (tester) async {
              useScreen(tester, size);
              final b = backend();
              final s = makeSession(b);
              await tester.pumpWidget(MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: BuTheme.forLocale(Brightness.light, lang),
                darkTheme: BuTheme.forLocale(Brightness.dark, lang),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                locale: Locale(lang),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RealEmailPage(session: s, mandatory: lang == 'tr', onDone: () {}, onSkip: () {}),
              ));
              await settle(tester, const Duration(milliseconds: 500));
              expect(tester.takeException(), isNull);
              // geçersiz gönderim: hata metni yerleşimi bozmaz
              await tester.enterText(find.byType(TextFormField).first, 'abc123@privaterelay.appleid.com');
              await tester.ensureVisible(find.byType(TextFormField).first);
              await tester.pump();
              final send = find.text(lang == 'tr' ? 'Kod gönder' : 'إرسال الرمز');
              await tester.ensureVisible(send);
              await tester.tap(send);
              await tester.pump(const Duration(milliseconds: 400));
              expect(tester.takeException(), isNull);
              // geçerli gönderim -> kod adımı
              await tester.enterText(find.byType(TextFormField).first, real);
              await tester.pump();
              await tester.tap(send);
              await settle(tester, const Duration(milliseconds: 700));
              expect(tester.takeException(), isNull);
              await unmount(tester);
            });
          }
        }
      }
    }
  });

  group('ProfileCompletionGate + gerçek e-posta', () {
    Widget gate(Session s) => buildApp(
          ProfileCompletionGate(session: s, child: const Scaffold(body: Text('KABUK'))),
        );

    Map<String, dynamic> me(Map<String, dynamic> extra) =>
        {'id': 1, 'profileCompleted': true, 'department': 'Biyoloji', 'grade': '2', ...extra};

    testWidgets('emailNeedsReal + realEmailRequired: kabuk yerine ZORUNLU adım (atlama yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..on('/users/me', me({'emailNeedsReal': true, 'realEmailRequired': true}));
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(RealEmailPage), findsOneWidget);
      expect(find.text('KABUK'), findsNothing);
      expect(find.text('Şimdi değil'), findsNothing);
      expect(find.text('Çıkış yap'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yalnız emailNeedsReal (mevcut hesap): yumuşak adım; "Şimdi değil" kabuğa geçirir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..on('/users/me', me({'emailNeedsReal': true, 'realEmailRequired': false}));
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(RealEmailPage), findsOneWidget);
      expect(find.text('Şimdi değil'), findsOneWidget);
      await tester.tap(find.text('Şimdi değil'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('KABUK'), findsOneWidget);
      expect(find.byType(RealEmailPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('alanlar yok / false: adım hiç gösterilmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..on('/users/me', me({'emailNeedsReal': false, 'realEmailRequired': false}));
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('KABUK'), findsOneWidget);
      expect(find.byType(RealEmailPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('doğrulama bitince kabuk açılır', (tester) async {
      useScreen(tester, const Size(390, 1000));
      final b = backend()..on('/users/me', me({'emailNeedsReal': true, 'realEmailRequired': true}));
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 500));
      await enterEmail(tester, real);
      await tapSend(tester);
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.text('Devam et'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('KABUK'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kabuk açıkken bir uç 403 REAL_EMAIL_REQUIRED döner: zorunlu adım açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..on('/users/me', me({}));
      final s = makeSession(b);
      await tester.pumpWidget(gate(s));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('KABUK'), findsOneWidget);
      b.fail('/posts', status: 403, code: 'REAL_EMAIL_REQUIRED', message: 'Gerçek e-posta ekleyin');
      try {
        await s.api.post('/posts', {});
      } catch (_) {}
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(RealEmailPage), findsOneWidget);
      expect(find.text('KABUK'), findsNothing);
      expect(find.text('Şimdi değil'), findsNothing);
      await unmount(tester);
    });

    testWidgets('profil de eksikse önce profil (onboarding), gerçek e-posta ondan sonra', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()
        ..on('/users/me', {'id': 1, 'profileCompleted': false, 'emailNeedsReal': true, 'realEmailRequired': true});
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(RealEmailPage), findsNothing);
      expect(find.text('KABUK'), findsNothing);
      expect(find.text('Önce tanışalım.'), findsOneWidget);
      await unmount(tester);
    });
  });
}
