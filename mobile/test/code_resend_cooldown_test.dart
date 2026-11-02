import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/resend_cooldown.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/auth/widgets/auth_controls.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Kod "yeniden iste" bekleme sayacı: 3:00 başlar, sunucunun süresiyle başlar/ayarlanır, 0'da düğme açılır.
Widget _app(Widget home) => MaterialApp(
      theme: BuTheme.light(),
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

Widget _row({int initial = kCodeResendSeconds, ResendCooldownStore? store, GlobalKey<AuthResendRowState>? k, VoidCallback? onResend}) =>
    _app(Scaffold(
      body: Builder(
        builder: (c) {
          final l = AppLocalizations.of(c)!;
          return AuthResendRow(
            key: k,
            onResend: onResend ?? () {},
            waitingLabel: (s) => l.authResendCountdown(formatResendClock(s)),
            waitingSemantics: (m) => l.authResendWaitA11y('$m'),
            resendLabel: l.authResendCode,
            initialSeconds: initial,
            store: store,
            flow: store == null ? null : 'verify',
            identity: store == null ? null : 'a@bingol.edu.tr',
          );
        },
      ),
    ));

void main() {
  group('formatResendClock / sabit', () {
    test('d:ss biçimi ve varsayılan 180 sn', () {
      expect(kCodeResendSeconds, 180);
      expect(formatResendClock(180), '3:00');
      expect(formatResendClock(179), '2:59');
      expect(formatResendClock(61), '1:01');
      expect(formatResendClock(9), '0:09');
      expect(formatResendClock(0), '0:00');
      expect(formatResendClock(-5), '0:00');
    });
  });

  group('ResendCooldownStore', () {
    test('start sunucu süresiyle bitiş anı tutar; süre dolunca 0, kayıt yoksa null', () async {
      var now = DateTime(2026, 11, 2, 12);
      final st = ResendCooldownStore.memory(now: () => now);
      expect(st.peek('verify', 'a@bingol.edu.tr'), isNull);
      await st.start('verify', 'A@bingol.edu.tr', seconds: 100);
      expect(st.peek('verify', 'a@bingol.edu.tr'), 100);
      now = now.add(const Duration(seconds: 40));
      expect(await st.remaining('verify', 'a@bingol.edu.tr'), 60);
      now = now.add(const Duration(seconds: 61));
      expect(st.peek('verify', 'a@bingol.edu.tr'), 0);
      // akışlar ve adresler bağımsız
      await st.start('reset', 'a@bingol.edu.tr');
      expect(st.peek('reset', 'a@bingol.edu.tr'), 180);
      expect(st.peek('verify', 'b@bingol.edu.tr'), isNull);
      await st.clearAll();
      expect(st.peek('reset', 'a@bingol.edu.tr'), isNull);
    });

    test('geçersiz süre (0/negatif) varsayılan 180 sn olur', () async {
      final st = ResendCooldownStore.memory();
      await st.start('verify', 'a@bingol.edu.tr', seconds: 0);
      expect(st.peek('verify', 'a@bingol.edu.tr'), 180);
    });
  });

  group('AuthResendRow', () {
    testWidgets('3:00 ile başlar, saniye saniye azalır, 0 olunca "Kodu yeniden gönder" aktif olur', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_row(onResend: () => taps++));
      expect(find.text('Yeniden gönder (3:00)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Yeniden gönder (2:59)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 119));
      expect(find.text('Yeniden gönder (1:00)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Yeniden gönder (0:01)'), findsOneWidget);
      expect(find.text('Kodu yeniden gönder'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Kodu yeniden gönder'), findsOneWidget);
      await tester.tap(find.text('Kodu yeniden gönder'));
      expect(taps, 1);
    });

    testWidgets('sunucu süresiyle başlar (örn. 95 sn = 1:35) ve restart(sunucu süresi) sayacı ayarlar', (tester) async {
      final key = GlobalKey<AuthResendRowState>();
      await tester.pumpWidget(_row(initial: 95, k: key));
      expect(find.text('Yeniden gönder (1:35)'), findsOneWidget);
      key.currentState!.restart(120);
      await tester.pump();
      expect(find.text('Yeniden gönder (2:00)'), findsOneWidget);
      key.currentState!.restart(); // süre yoksa varsayılan (initialSeconds)
      await tester.pump();
      expect(find.text('Yeniden gönder (1:35)'), findsOneWidget);
      key.currentState!.makeReady();
      await tester.pumpAndSettle();
      expect(find.text('Kodu yeniden gönder'), findsOneWidget);
    });

    testWidgets('kalıcı depodaki kalan süreden devam eder (uygulama kapanıp açılınca)', (tester) async {
      final st = ResendCooldownStore.memory();
      await st.start('verify', 'a@bingol.edu.tr', seconds: 100);
      await tester.pumpWidget(_row(store: st));
      expect(find.textContaining('Yeniden gönder (1:4'), findsOneWidget); // 100 sn: 1:40 (en çok 1 sn sapma)
    });

    testWidgets('depoda süresi dolmuş kayıt varsa düğme hemen açık gelir', (tester) async {
      var now = DateTime(2026, 11, 2, 12);
      final st = ResendCooldownStore.memory(now: () => now);
      await st.start('verify', 'a@bingol.edu.tr', seconds: 30);
      now = now.add(const Duration(minutes: 5));
      await tester.pumpWidget(_row(store: st));
      expect(find.text('Kodu yeniden gönder'), findsOneWidget);
    });

    testWidgets('ekran okuyucu özeti dakikada bir değişir (her saniye okunmaz)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_row());
      expect(find.bySemanticsLabel('Kodu yeniden göndermek için en çok 3 dakika bekleyin'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.bySemanticsLabel('Kodu yeniden göndermek için en çok 3 dakika bekleyin'), findsOneWidget);
      await tester.pump(const Duration(seconds: 100)); // 50 sn kaldı: özet 1 dakika
      expect(find.bySemanticsLabel('Kodu yeniden göndermek için en çok 1 dakika bekleyin'), findsOneWidget);
      handle.dispose();
    });
  });

  group('akışlar', () {
    testWidgets('verify: ilk görünüm 3:00; süre dolunca gönder -> sunucunun resendAfterSeconds değeriyle yeniden başlar', (tester) async {
      final b = FakeBackend()..on('/auth/resend-code', {'message': 'ok', 'resendAfterSeconds': 120});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(_app(VerifyCodePage(session: s, email: 'a@bingol.edu.tr')));
      expect(find.textContaining('Yeniden gönder (3:00)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 181));
      await tester.ensureVisible(find.text('Kodu yeniden gönder'));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(b.count('/auth/resend-code'), 1);
      expect(find.textContaining('Yeniden gönder (2:00)'), findsOneWidget);
      expect(s.resendCooldown.peek('verify', 'a@bingol.edu.tr'), inInclusiveRange(119, 120));
      await unmount(tester);
    });

    testWidgets('verify: sunucu 429 RESEND_COOLDOWN + Retry-After dönerse sayaç kalan süreye ayarlanır (eski istemci erken denemesi)', (tester) async {
      final b = FakeBackend()
        ..on('/auth/resend-code', {'code': 'RESEND_COOLDOWN', 'message': 'Yeni kod istemek için 95 saniye bekleyin.', 'retryAfterSeconds': 95},
            status: 429, headers: {'retry-after': '95'});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(_app(VerifyCodePage(session: s, email: 'a@bingol.edu.tr')));
      await tester.pump(const Duration(seconds: 181));
      await tester.ensureVisible(find.text('Kodu yeniden gönder'));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Yeni kod istemek için 95 saniye bekleyin.'), findsOneWidget);
      expect(find.textContaining('Yeniden gönder (1:35)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('reset: gönderim sunucu süresiyle başlar, 429 kalan süreyi uygular', (tester) async {
      final b = FakeBackend()
        ..on('/auth/forgot-password', {'code': 'RESEND_COOLDOWN', 'message': 'bekleyin 40', 'retryAfterSeconds': 40},
            status: 429, headers: {'retry-after': '40'});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(_app(ResetCodePage(session: s, email: 'a@bingol.edu.tr')));
      expect(find.textContaining('Yeniden gönder (3:00)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 181));
      await tester.ensureVisible(find.text('Kodu yeniden gönder'));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.textContaining('Yeniden gönder (0:40)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('forgot: kod az önce gönderildiyse (429) hata yerine kod ekranı açılır ve sayaç kalan süreyle sürer', (tester) async {
      final b = FakeBackend()
        ..on('/auth/forgot-password', {'code': 'RESEND_COOLDOWN', 'message': 'bekleyin', 'retryAfterSeconds': 100},
            status: 429, headers: {'retry-after': '100'});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(_app(ForgotPasswordPage(session: s)));
      await tester.enterText(find.byType(TextFormField), 'ayse@bingol.edu.tr');
      await tester.tap(find.text('Kod gönder'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(ResetCodePage), findsOneWidget);
      expect(find.textContaining('Yeniden gönder (1:4'), findsOneWidget); // 100 sn = 1:40
      await unmount(tester);
    });

    test('Session.resendCode: yanıttaki resendAfterSeconds okunur, yoksa 180; kalıcı sayaç başlar', () async {
      final b = FakeBackend()..on('/auth/resend-code', {'message': 'ok', 'resendAfterSeconds': 150});
      final s = makeSession(b, signedIn: false);
      expect(await s.resendCode('a@bingol.edu.tr'), 150);
      expect(s.resendCooldown.peek('verify', 'a@bingol.edu.tr'), inInclusiveRange(149, 150));
      b.on('/auth/forgot-password', {'message': 'ok'});
      expect(await s.forgotPassword('a@bingol.edu.tr'), 180);
      expect(s.resendCooldown.peek('reset', 'a@bingol.edu.tr'), inInclusiveRange(179, 180));
    });

    test('ApiError.retryAfter başlık yoksa gövdedeki retryAfterSeconds değerinden okunur', () async {
      final b = FakeBackend()
        ..on('/auth/resend-code', {'code': 'RESEND_COOLDOWN', 'message': 'x', 'retryAfterSeconds': 77}, status: 429);
      final s = makeSession(b, signedIn: false);
      try {
        await s.resendCode('a@bingol.edu.tr');
        fail('429 bekleniyordu');
      } on ApiError catch (e) {
        expect(e.code, 'RESEND_COOLDOWN');
        expect(e.retryAfter, 77);
      }
      expect(s.resendCooldown.peek('verify', 'a@bingol.edu.tr'), inInclusiveRange(76, 77));
    });
  });
}
