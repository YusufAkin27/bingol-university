import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/help/help_code_page.dart';
import 'package:bu_kampus/features/auth/help/help_form_page.dart';
import 'package:bu_kampus/features/system/suspended_gate.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Askıya alınmış hesap kapısı: 403 ACCOUNT_SUSPENDED (giriş, refresh ya da herhangi bir uç) oturumu yerelde kapatır ve
/// kök Navigator YERİNE tek ekran gösterilir; ekrandan başka bölüme gidilemez; destek talebi herkese açık uçla gönderilir.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  const shell = 'KABUK-ICERIK';

  Widget app(Session s, {TextDirection? dir, double scale = 1}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        home: const Scaffold(body: Center(child: Text(shell))),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: dir ?? Directionality.of(context),
            child: SuspendedGate(session: s, child: child!),
          ),
        ),
      );

  Session signedIn(FakeBackend b) {
    final s = makeSession(b);
    s.api.tokens = Tokens('a.b.c', 'refresh');
    return s;
  }

  Future<void> suspendViaApi(WidgetTester tester, Session s) async {
    await tester.runAsync(() async {
      try {
        await s.api.get('/users/me');
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester, const Duration(milliseconds: 900));
  }

  testWidgets('korumalı uçta 403 ACCOUNT_SUSPENDED: oturum kapanır, kabuk yerine tek askı ekranı', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()..fail('/users/me', status: 403, code: 'ACCOUNT_SUSPENDED', message: 'Hesabınız askıya alınmıştır.');
    final s = signedIn(b);
    await tester.pumpWidget(app(s));
    expect(find.text(shell), findsOneWidget);

    await suspendViaApi(tester, s);

    expect(s.suspended.value, isNotNull);
    expect(s.api.tokens, isNull, reason: 'oturum yerelde temizlenir');
    expect(s.state, SessionState.signedOut);
    expect(find.text(shell), findsNothing, reason: 'kök Navigator/kabuk kurulmaz');
    expect(find.text('Hesabınız askıya alındı'), findsOneWidget);
    expect(find.textContaining('bizimle iletişime geçin'), findsOneWidget);
    expect(find.text('Destek talebi oluştur'), findsOneWidget);
    expect(find.text('Farklı hesapla giriş yap'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('giriş yanıtında 403 ACCOUNT_SUSPENDED: askı ekranı, e-posta yalnız bellekte', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()..fail('/auth/login', status: 403, code: 'ACCOUNT_SUSPENDED');
    final s = makeSession(b, signedIn: false);
    await tester.pumpWidget(app(s));
    await tester.runAsync(() async {
      await expectLater(s.login('askili@gmail.com', 'Parola-123'), throwsA(isA<ApiError>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester, const Duration(milliseconds: 900));
    expect(s.suspended.value?.email, 'askili@gmail.com');
    expect(find.text('Hesabınız askıya alındı'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('yanlış parolada genel hata: askı ekranı AÇILMAZ', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()..fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS');
    final s = makeSession(b, signedIn: false);
    await tester.pumpWidget(app(s));
    await tester.runAsync(() async {
      await expectLater(s.login('x@gmail.com', 'yanlis'), throwsA(isA<ApiError>()));
    });
    await settle(tester, const Duration(milliseconds: 300));
    expect(s.suspended.value, isNull);
    expect(find.text(shell), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('geri tuşu ve sistem geri hareketi başka bölüm açmaz; ekran kalır', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = makeSession(FakeBackend());
    await tester.pumpWidget(app(s));
    s.notifyAccountSuspended();
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Hesabınız askıya alındı'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester, const Duration(milliseconds: 400));

    expect(find.text('Hesabınız askıya alındı'), findsOneWidget);
    expect(find.text(shell), findsNothing);
    // Askı sürerken yinelenen bildirimler (soket + HTTP) ekranı çoğaltmaz.
    s.notifyAccountSuspended();
    await settle(tester, const Duration(milliseconds: 200));
    expect(find.text('Hesabınız askıya alındı'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('destek talebi: e-posta ön dolu ve salt okunur, herkese açık uç, oturumsuz; kod adımına geçer', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()..on('/public/support/tickets', {'status': 'CODE_SENT', 'expiresInMinutes': 10}, status: 202);
    final s = makeSession(b);
    await tester.pumpWidget(app(s));
    s.notifyAccountSuspended();
    await settle(tester, const Duration(milliseconds: 800));

    await tester.tap(find.text('Destek talebi oluştur'));
    await settle(tester, const Duration(milliseconds: 800));

    expect(find.byType(HelpFormPage), findsOneWidget);
    expect(find.text('Askıya alma itirazı'), findsOneWidget);
    final fields = find.byType(TextFormField);
    final emailField = tester.widget<TextFormField>(fields.at(1));
    expect(emailField.enabled, isFalse, reason: 'e-posta salt okunur');
    expect(tester.widget<EditableText>(find.descendant(of: fields.at(1), matching: find.byType(EditableText))).controller.text,
        'ayse@bingol.edu.tr');

    await tester.ensureVisible(find.text('Devam'));
    await tester.tap(find.text('Devam'));
    await settle(tester, const Duration(milliseconds: 900));

    final body = b.bodies['POST /public/support/tickets']! as Map;
    expect(body['email'], 'ayse@bingol.edu.tr');
    expect(body['category'], 'ACCOUNT');
    expect(body['website'], '');
    expect((body['message'] as String), contains('itiraz'));
    expect(find.byType(HelpCodePage), findsOneWidget);
    expect(find.text(shell), findsNothing);
    await unmount(tester);
  });

  testWidgets('iletişim: sunucudaki destek e-postasıyla mailto; açılamazsa adres gösterilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()..on('/app/info', {'supportEmail': 'yardim@bingol.edu.tr'});
    final s = makeSession(b);
    Uri? opened;
    suspendedMailLauncher = (u) async {
      opened = u;
      return false;
    };
    addTearDown(() => suspendedMailLauncher = (u) async => false);
    await tester.pumpWidget(app(s));
    s.notifyAccountSuspended();
    await settle(tester, const Duration(milliseconds: 800));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.text('yardim@bingol.edu.tr'), findsOneWidget);

    await tester.tap(find.text('E-posta ile iletişime geç'));
    await settle(tester, const Duration(milliseconds: 400));

    expect(opened.toString(), startsWith('mailto:yardim@bingol.edu.tr?subject='));
    expect(find.textContaining('yardim@bingol.edu.tr'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('farklı hesapla giriş: ekran kapanır, gerekçe/bayrak saklanmaz', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = makeSession(FakeBackend());
    await tester.pumpWidget(app(s));
    s.notifyAccountSuspended();
    await settle(tester, const Duration(milliseconds: 800));

    await tester.tap(find.text('Farklı hesapla giriş yap'));
    await settle(tester, const Duration(milliseconds: 400));

    expect(s.suspended.value, isNull);
    expect(find.text('Hesabınız askıya alındı'), findsNothing);
    expect(find.text(shell), findsOneWidget);
    await unmount(tester);
  });

  for (final size in [kPhoneSmall, kPhoneMedium]) {
    for (final rtl in [false, true]) {
      testWidgets('taşma yok: ${size.width.toInt()} px, yazı 1,3x, ${rtl ? 'RTL' : 'LTR'}; düğmeler >= 44 dp', (tester) async {
        useScreen(tester, size);
        final s = makeSession(FakeBackend());
        await tester.pumpWidget(app(s, dir: rtl ? TextDirection.rtl : TextDirection.ltr, scale: 1.3));
        s.notifyAccountSuspended();
        await settle(tester, const Duration(milliseconds: 900));
        expect(tester.takeException(), isNull);
        for (final bt in find.byType(BuButton).evaluate()) {
          expect(tester.getSize(find.byWidget(bt.widget)).height, greaterThanOrEqualTo(44));
        }
        await unmount(tester);
      });
    }
  }
}
