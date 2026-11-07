import 'dart:convert';

import 'package:bu_kampus/core/accounts/account_store.dart';
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/accounts/account_sheet.dart';
import 'package:bu_kampus/features/auth/auth_landing_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

String _b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
String _jwt(int id) => '${_b64('{"alg":"none"}')}.${_b64('{"sub":"$id"}')}.sig';

Future<Session> _session(FakeBackend b, {int count = 3, bool expireSecond = false}) async {
  mockSecureStorage();
  b.handlers.add((req, path) {
    if (path != '/auth/me') return null;
    final auth = req.headers['Authorization'] ?? '';
    final sub = RegExp(r'"sub":"(\d+)"').firstMatch(utf8.decode(base64Url.decode(base64Url.normalize(auth.split('.')[1]))))?.group(1);
    return FakeResult.json({'id': int.parse(sub!), 'displayName': 'Hesap $sub', 'email': 'k$sub@gmail.com'});
  });
  final s = Session(ApiClient(client: b.client, retryDelay: Duration.zero), accounts: AccountStore(kv: MemoryAccountKv()));
  for (var i = 1; i <= count; i++) {
    await s.accounts.upsert(i, Tokens(_jwt(i), 'r$i'), displayName: 'Hesap $i', username: 'kullanici$i', email: 'k$i@gmail.com');
  }
  if (expireSecond) await s.accounts.markExpired(2);
  await s.accounts.setActive(1);
  s.api.tokens = Tokens(_jwt(1), 'r1');
  s.state = SessionState.signedIn;
  s.userId = 1;
  return s;
}

Widget _app(Session s, {String lang = 'tr', double textScale = 1}) => MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: BuTheme.light(),
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(child: TextButton(onPressed: () => showAccountSheet(c, s), child: const Text('AC'))),
        ),
      ),
    );

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('AC'));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('liste: hesaplar, etkin hesapta onay simgesi, hesap ekle', (t) async {
    useScreen(t, kPhoneMedium);
    final s = (await t.runAsync(() => _session(FakeBackend())))!;
    await t.pumpWidget(_app(s));
    await _open(t);
    expect(find.text('Hesap 1'), findsOneWidget);
    expect(find.text('Hesap 2'), findsOneWidget);
    expect(find.text('@kullanici3'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-active-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-active-2')), findsNothing);
    expect(find.text('Hesap ekle'), findsOneWidget);
    expect(find.textContaining('yalnızca etkin hesaba'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('oturumu dolmus hesap "Oturum süresi doldu" ile isaretli; secilince giris ekrani acilir, digerleri etkilenmez', (t) async {
    useScreen(t, kPhoneMedium);
    final b = FakeBackend();
    final s = (await t.runAsync(() => _session(b, expireSecond: true)))!;
    await t.pumpWidget(_app(s));
    await _open(t);
    expect(find.text('Oturum süresi doldu'), findsOneWidget);
    await t.tap(find.text('Hesap 2'));
    await t.pumpAndSettle();
    expect(find.byType(AuthLandingPage), findsOneWidget);
    expect(find.byKey(const ValueKey('relogin-hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-account-back')), findsOneWidget);
    expect(s.userId, 1);
    expect(s.accounts.byId(3)!.expired, isFalse);
    expect(b.count('/auth/logout'), 0);
    // Geri: iptal, mevcut oturum açık.
    await t.tap(find.byKey(const ValueKey('add-account-back')));
    await t.pumpAndSettle();
    expect(find.byType(AuthLandingPage), findsNothing);
    expect(s.state, SessionState.signedIn);
  });

  testWidgets('hesap ekle: giris ekrani "hesap ekleme" kipinde acilir, geri iptal eder', (t) async {
    useScreen(t, kPhoneMedium);
    final s = (await t.runAsync(() => _session(FakeBackend())))!;
    await t.pumpWidget(_app(s));
    await _open(t);
    await t.tap(find.byKey(const ValueKey('account-add')));
    await t.pumpAndSettle();
    expect(find.byType(AuthLandingPage), findsOneWidget);
    expect(find.textContaining('Mevcut hesabın açık kalır'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('add-account-back')));
    await t.pumpAndSettle();
    expect(s.userId, 1);
  });

  testWidgets('baska hesaba dokununca gecilir', (t) async {
    useScreen(t, kPhoneMedium);
    final b = FakeBackend();
    final s = (await t.runAsync(() => _session(b)))!;
    await t.pumpWidget(_app(s));
    await _open(t);
    await t.runAsync(() async {
      await t.tap(find.text('Hesap 3'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await t.pumpAndSettle();
    expect(s.userId, 3);
    expect(s.accountEpoch, 1);
    expect(b.count('/auth/logout'), 0);
  });

  testWidgets('kaldir: onay sayfasi, etkin olmayan hesap listeden silinir ve sunucuda oturumu kapanir', (t) async {
    useScreen(t, kPhoneMedium);
    final b = FakeBackend();
    final s = (await t.runAsync(() => _session(b)))!;
    await t.pumpWidget(_app(s));
    await _open(t);
    await t.tap(find.byKey(const ValueKey('account-more-2')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('account-remove-2')));
    await t.pumpAndSettle();
    expect(find.text('Hesap kaldırılsın mı?'), findsOneWidget);
    // Vazgec: hicbir sey olmaz.
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(s.accounts.has(2), isTrue);
    await t.tap(find.byKey(const ValueKey('account-more-2')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('account-remove-2')));
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await t.tap(find.text('Kaldır'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pumpAndSettle();
    expect(s.accounts.has(2), isFalse);
    expect(s.accounts.has(1), isTrue);
    expect(b.bodies['POST /auth/logout'], {'refreshToken': 'r2'});
    expect(s.userId, 1);
    expect(find.text('Hesap 2'), findsNothing);
  });

  testWidgets('5 hesap: "Hesap ekle" pasif ve sinir mesaji gorunur', (t) async {
    useScreen(t, kPhoneMedium);
    final s = (await t.runAsync(() => _session(FakeBackend(), count: 5)))!;
    await t.pumpWidget(_app(s));
    await _open(t);
    expect(find.byKey(const ValueKey('account-limit')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('account-add')));
    await t.pumpAndSettle();
    expect(find.byType(AuthLandingPage), findsNothing);
  });

  for (final lang in ['tr', 'ar']) {
    testWidgets('320 dp, yazi olcegi 1.3, $lang: tasma yok', (t) async {
      useScreen(t, kPhoneSmall);
      final s = (await t.runAsync(() => _session(FakeBackend(), count: 5, expireSecond: true)))!;
      await t.pumpWidget(_app(s, lang: lang, textScale: 1.3));
      await _open(t);
      expect(find.byKey(const ValueKey('account-row-1')), findsOneWidget);
      expect(t.takeException(), isNull);
      // Dokunma hedefleri >= 44 dp.
      final more = t.getSize(find.byKey(const ValueKey('account-more-1')));
      expect(more.width, greaterThanOrEqualTo(44));
      expect(more.height, greaterThanOrEqualTo(44));
    });
  }
}
