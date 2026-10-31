import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/otp_code_boxes.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/reset_success_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// DA (mimar cilası): kimlik akışı + sistem durum ekranları. Davranış değişmedi; görünüm sözleşmeleri:
/// OTP kutuları eşit genişlik + hata durumu, dört durum ekranı ortak 88 dp simge karosu, sözleşme listesinde
/// dokunma dalgası görünür (dolgu Material'de), karşılama dil seçici dokunma hedefi, aşamalı giriş sonunda görünür.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  group('OtpCodeBoxes', () {
    Future<List<BoxDecoration>> boxes(WidgetTester tester, {required bool error, Brightness b = Brightness.light}) async {
      useScreen(tester, kPhoneMedium);
      final c = TextEditingController(text: '52');
      addTearDown(c.dispose);
      await tester.pumpWidget(buildApp(
        Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: OtpCodeBoxes(controller: c, onCompleted: () {}, hasError: error))),
        brightness: b,
      ));
      await settle(tester, const Duration(milliseconds: 400));
      final f = find.descendant(of: find.byType(OtpCodeBoxes), matching: find.byType(AnimatedContainer));
      expect(f, findsNWidgets(6));
      final widths = [for (var i = 0; i < 6; i++) tester.getSize(f.at(i)).width];
      // İlk kutu da diğerleriyle aynı genişlikte (eskiden ilk kutu 8 dp geniş çiziliyordu).
      for (final w in widths) {
        expect(w, closeTo(widths.first, .01));
      }
      return [for (var i = 0; i < 6; i++) (tester.widget<AnimatedContainer>(f.at(i)).decoration as BoxDecoration)];
    }

    testWidgets('altı kutu eşit genişlikte, hata yokken çerçevesiz', (tester) async {
      final d = await boxes(tester, error: false);
      expect(d.where((x) => x.color == BuTokens.light.sf2).length, greaterThanOrEqualTo(4));
    });

    for (final b in Brightness.values) {
      testWidgets('hata durumunda kutular kırmızı çerçeveli (${b.name})', (tester) async {
        final tk = b == Brightness.dark ? BuTokens.dark : BuTokens.light;
        final d = await boxes(tester, error: true, b: b);
        for (final x in d) {
          final border = x.border! as Border;
          expect(border.top.color, tk.danger.withValues(alpha: .55));
          expect(border.top.width, 1.5);
        }
        final texts = tester.widgetList<Text>(find.descendant(of: find.byType(OtpCodeBoxes), matching: find.text('5')));
        expect(texts.first.style?.color, tk.danger);
      });
    }
  });

  group('Durum ekranları', () {
    final screens = <String, Widget Function()>{
      'güncelleme': () => const UpdateRequiredScreen(storeUrl: 'https://example.com', latest: '1.1.0', current: '1.0.2'),
      'bakım': () => MaintenanceScreen(onRetry: () {}),
      'çevrimdışı': () => OfflineScreen(onRetry: () {}),
      'erişim engeli': () => AccessBlockedScreen(onRetry: () {}),
    };
    for (final e in screens.entries) {
      testWidgets('${e.key}: ortak 88 dp simge karosu ve sonunda tam görünür', (tester) async {
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(buildApp(e.value()));
        // Aşamalı giriş bitince (<= ~700 ms) hiçbir öğe saydam kalmaz.
        await settle(tester, const Duration(milliseconds: 900));
        final tile = find.byWidgetPredicate((w) => w is Container && w.constraints == const BoxConstraints.tightFor(width: 88, height: 88));
        expect(tile, findsOneWidget);
        expect(tester.getSize(tile), const Size(88, 88));
        for (final f in tester.widgetList<FadeTransition>(find.byType(FadeTransition))) {
          expect(f.opacity.value, 1.0);
        }
        // Eylem düğmesi alt kenardan >= 48 dp içeride, ekran içinde.
        final btn = tester.getRect(find.byType(BuButton).first);
        expect(btn.bottom, lessThanOrEqualTo(kPhoneMedium.height - 48 + .5));
        expect(btn.height, greaterThanOrEqualTo(48));
        await unmount(tester);
      });
    }

    testWidgets('"animasyonları azalt" açıkken durum ekranı ilk karede tam görünür', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
        child: buildApp(OfflineScreen(onRetry: () {})),
      ));
      await tester.pump();
      for (final f in tester.widgetList<FadeTransition>(find.byType(FadeTransition))) {
        expect(f.opacity.value, 1.0);
      }
      await unmount(tester);
    });
  });

  group('Sözleşme listesi', () {
    testWidgets('satırların dokunma dalgası görünür Material üstünde (dolgu Material rengidir)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/legal', [
          {'type': 'TERMS', 'title': 'Kullanım Koşulları', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
          {'type': 'PRIVACY', 'title': 'Gizlilik Politikası', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
        ]);
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(LegalListPage(session: s)));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Kullanım Koşulları'), findsOneWidget);
      final ink = find.byType(InkWell).first;
      final m = tester.widget<Material>(find.ancestor(of: ink, matching: find.byType(Material)).first);
      expect(m.color, BuTokens.light.sf, reason: 'InkWell dalgası, dolgusu olan Material üstünde çizilir');
      await unmount(tester);
    });
  });

  group('Karşılama', () {
    for (final size in [kPhoneSmall, kPhoneMedium]) {
      testWidgets('dil seçici dokunma hedefi >= 44x40, öğeler aşamalı girişten sonra görünür (${size.width.toInt()})', (tester) async {
        useScreen(tester, size);
        LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
        addTearDown(() => LocaleController.current = null);
        await tester.pumpWidget(buildApp(WelcomePage(onLogin: () {}, onRegister: () {})));
        await settle(tester, const Duration(milliseconds: 1200));
        for (final code in ['TR', 'EN', 'AR']) {
          final seg = find.ancestor(of: find.text(code), matching: find.byType(InkWell)).first;
          final r = tester.getRect(seg);
          expect(r.width, greaterThanOrEqualTo(44), reason: code);
          expect(r.height, greaterThanOrEqualTo(40), reason: code);
        }
        for (final f in tester.widgetList<FadeTransition>(find.byType(FadeTransition))) {
          expect(f.opacity.value, 1.0);
        }
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });

  // 320 dp genişlik + 1,3x yazı + RTL: kırpılma/taşma yok (RenderFlex taşması test istisnasıdır).
  group('320 dp / 1.3x yazı', () {
    final pages = <String, Widget Function(Session s)>{
      'karşılama': (s) => WelcomePage(onLogin: () {}, onRegister: () {}),
      'giriş': (s) => LoginPage(session: s),
      'kayıt adım 1': (s) => RegisterPage(session: s),
      'doğrulama kodu': (s) => VerifyCodePage(session: s, email: 'ad.soyad@bingol.edu.tr'),
      'şifremi unuttum': (s) => ForgotPasswordPage(session: s),
      'sıfırlama kodu': (s) => ResetCodePage(session: s, email: 'ad.soyad@bingol.edu.tr'),
      'yeni şifre': (s) => NewPasswordPage(session: s, email: 'ad.soyad@bingol.edu.tr', resetToken: 't'),
      'şifre güncellendi': (s) => const ResetSuccessPage(),
      'sözleşme listesi': (s) => LegalListPage(session: s),
      'güncelleme': (s) => const UpdateRequiredScreen(storeUrl: 'https://example.com', latest: '1.1.0', current: '1.0.2'),
      'bakım': (s) => MaintenanceScreen(onRetry: () {}),
      'çevrimdışı': (s) => OfflineScreen(onRetry: () {}),
      'erişim engeli': (s) => AccessBlockedScreen(onRetry: () {}),
    };
    for (final e in pages.entries) {
      for (final rtl in [false, true]) {
        for (final b in Brightness.values) {
          testWidgets('${e.key} ${b.name}${rtl ? ' rtl' : ''}', (tester) async {
            useScreen(tester, kPhoneSmall);
            LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
            addTearDown(() => LocaleController.current = null);
            final be = FakeBackend()
              ..on('/legal', [
                {'type': 'TERMS', 'title': 'Kullanım Koşulları ve Üyelik Sözleşmesi', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
              ])
              ..on('/catalog/academic', {'version': 1, 'faculties': [], 'grades': []});
            final s = makeSession(be, signedIn: false);
            await tester.pumpWidget(buildApp(
              Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: e.value(s),
                  ),
                ),
              ),
              brightness: b,
              size: kPhoneSmall,
            ));
            await settle(tester, const Duration(milliseconds: 1200));
            final err = tester.takeException();
            if (err != null) fail('$err');
            await unmount(tester);
            final err2 = tester.takeException();
            if (err2 != null) fail('$err2');
          });
        }
      }
    }
  });
}
