// QA alani 1, ikinci tur: parametrik durum matrisi (yukleniyor / bos / hata / 401 / 403 / 429 / 5xx / cevrimdisi x
// tr-en-ar x acik-koyu x 320-390 x yazi olcegi 1.3) + eksik kalan alanlarin davranis testleri.
import 'package:bu_kampus/core/oauth/real_email_api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/devices_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/features/profile/password_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/profil2_my_data_page.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/profile/two_factor_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_notif_prefs.dart';

Widget _app(Widget home, {required Locale locale, required Brightness brightness, required double scale}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: home,
  );
}

typedef _Build = Widget Function(Session s);

/// Matris durumlari: ad -> arka uc kurulumu.
final _states = <String, void Function(FakeBackend b)>{
  'bos-varsayilan': (b) {},
  'yukleniyor': (b) => b.delay = const Duration(milliseconds: 900),
  'hata-500': (b) => b.handlers.add((r, p) => const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500)),
  'hata-503-db': (b) => b.handlers.add((r, p) => const FakeResult.json({'code': 'DB_TIMEOUT', 'message': ''}, status: 503)),
  'hata-401': (b) => b.handlers.add((r, p) => const FakeResult.json({'code': 'UNAUTHORIZED', 'message': 'Oturum gecersiz.'}, status: 401)),
  'hata-403': (b) => b.handlers.add((r, p) => const FakeResult.json({'code': 'FORBIDDEN', 'message': 'Yetkiniz yok.'}, status: 403)),
  'hata-409': (b) => b.handlers.add((r, p) => const FakeResult.json({'code': 'CONFLICT', 'message': 'Cakisma.'}, status: 409)),
  'hata-422': (b) => b.handlers.add((r, p) => const FakeResult.json({'code': 'UNPROCESSABLE', 'message': 'Gecersiz.'}, status: 422)),
  'hata-429': (b) => b.handlers.add((r, p) => const FakeResult.json({'code': 'RATE_LIMITED', 'message': 'Cok fazla deneme.'}, status: 429)),
  'cevrimdisi': (b) => b.offline = true,
};

final _pages = <String, _Build>{
  'login': (s) => LoginPage(session: s),
  'register': (s) => RegisterPage(session: s),
  'forgot': (s) => ForgotPasswordPage(session: s, initialEmail: 'ayse@gmail.com'),
  'verify': (s) => VerifyCodePage(session: s, email: 'ayse@gmail.com'),
  'reset-code': (s) => ResetCodePage(session: s, email: 'ayse@gmail.com'),
  'new-password': (s) => NewPasswordPage(session: s, email: 'ayse@gmail.com', resetToken: 't'),
  'settings': (s) => SettingsPage(session: s, themeController: ThemeController()),
  'account-security': (s) => AccountSecurityPage(session: s),
  'password': (s) => PasswordPage(session: s),
  'two-factor': (s) => TwoFactorPage(session: s),
  'devices': (s) => DevicesPage(session: s),
  'blocked': (s) => BlockedUsersPage(session: s),
  'privacy': (s) => PrivacyDataPage(session: s),
  'my-data': (s) => MyDataPage(session: s),
  'delete-account': (s) => DeleteAccountPage(session: s),
  'notification-prefs': (s) => NotificationPrefsPage(session: s),
  'legal-list': (s) => LegalListPage(session: s),
  'legal-doc': (s) => LegalDocPage(session: s, type: 'TERMS'),
};

void main() {
  setUpAll(loadTestFonts);

  final envs = <(String, Locale, Brightness, Size, double)>[
    ('tr-acik-390', const Locale('tr'), Brightness.light, const Size(390, 844), 1.0),
    ('ar-koyu-320-1.3', const Locale('ar'), Brightness.dark, const Size(320, 640), 1.3),
    ('en-koyu-390-1.3', const Locale('en'), Brightness.dark, const Size(390, 844), 1.3),
  ];

  group('durum matrisi: ekran x durum x ortam (tasma/cokme yok)', () {
    for (final page in _pages.entries) {
      for (final st in _states.entries) {
        for (final env in envs) {
          testWidgets('${page.key} | ${st.key} | ${env.$1}', (t) async {
            useScreen(t, env.$4);
            final b = FakeBackend();
            st.value(b);
            final s = makeSession(b);
            await t.pumpWidget(_app(page.value(s), locale: env.$2, brightness: env.$3, scale: env.$5));
            await settle(t, const Duration(milliseconds: 700));
            expect(t.takeException(), isNull);
            await unmount(t);
          });
        }
      }
    }
  });

  group('gercek e-posta yumusak adim: 3 gun erteleme', () {
    setUp(mockSecureStorage);

    testWidgets('erteleme yok > false; snoozeNow sonrasi 3 gun boyunca true, sonra false; baska kullaniciya sizmaz', (t) async {
      final now = DateTime(2026, 11, 6, 12);
      await t.runAsync(() async {
        expect(await RealEmailSoftSkip.isSnoozed(7, now: now), isFalse);
        await RealEmailSoftSkip.snoozeNow(7, now: now);
        expect(await RealEmailSoftSkip.isSnoozed(7, now: now.add(const Duration(days: 2, hours: 23))), isTrue);
        expect(await RealEmailSoftSkip.isSnoozed(7, now: now.add(const Duration(days: 3, minutes: 1))), isFalse);
        expect(await RealEmailSoftSkip.isSnoozed(8, now: now.add(const Duration(hours: 1))), isFalse);
      });
    });
  });

  group('bildirim tercihleri: gunun menusu', () {
    testWidgets('sunucu varsayilani ACIK (mealMenu true): anahtar acik gorunur; kapatinca yalniz mealMenu:false gider', (t) async {
      useScreen(t, const Size(390, 2600));
      final b = FakeBackend();
      final p = FakeNotifPrefs(b);
      p.state['mealMenu'] = true; // backend V1461 varsayilani
      await t.pumpWidget(_app(NotificationPrefsPage(session: makeSession(b)), locale: const Locale('tr'), brightness: Brightness.light, scale: 1));
      await settle(t);
      final row = find.ancestor(of: find.text('Günlük menü'), matching: find.byType(Row)).first;
      final sw = find.descendant(of: row, matching: find.byType(Switch));
      expect(t.widget<Switch>(sw).value, isTrue);
      await t.tap(sw);
      await settle(t);
      expect(p.puts.last, {'mealMenu': false});
      await unmount(t);
    });
  });
}
