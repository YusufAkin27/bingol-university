import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/profile_photo_setup_page.dart';
import 'package:bu_kampus/features/auth/profile_setup_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Zorunlu "bölümünü seç" adımı: ProfileSetupPage (yalnız bölüm + sınıf) ve ProfileCompletionGate (kapı).
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  FakeBackend backend() {
    final b = FakeBackend();
    fakeCatalog(b);
    return b;
  }

  group('isProfileComplete', () {
    test('bölüm ve sınıf dolu olmalı; classYear eski kullanıcılar için sınıf sayılır', () {
      expect(isProfileComplete({'department': 'Biyoloji', 'grade': '2'}), isTrue);
      expect(isProfileComplete({'department': 'Biyoloji', 'grade': 'PREP'}), isTrue);
      expect(isProfileComplete({'department': 'Biyoloji', 'classYear': 3}), isTrue);
      expect(isProfileComplete({'department': 'Biyoloji'}), isFalse);
      expect(isProfileComplete({'department': 'Biyoloji', 'grade': ''}), isFalse);
      expect(isProfileComplete({'department': '  ', 'grade': '2'}), isFalse);
      expect(isProfileComplete({'grade': '2'}), isFalse);
      expect(isProfileComplete({'department': null, 'grade': null}), isFalse);
      // Ad kontrolü yok.
      expect(isProfileComplete({'displayName': '', 'department': 'Biyoloji', 'grade': '1'}), isTrue);
    });
  });

  group('ProfileSetupPage', () {
    testWidgets('yalnız bölüm ve sınıf; ad alanı, geri oku ve kapatma yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      await tester.pumpWidget(buildApp(ProfileSetupPage(session: makeSession(b), onDone: () {})));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Bölümünüzü seçin'), findsOneWidget);
      expect(find.text('Bölüm seçin'), findsOneWidget);
      expect(find.text('Sınıf seçin'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.bySemanticsLabel('Geri'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(CloseButton), findsNothing);
      expect(find.text('Çıkış yap'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('eksikse alan altında hata, istek atılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      await tester.pumpWidget(buildApp(ProfileSetupPage(session: makeSession(b), onDone: () => fail('kapanmamalı'))));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
      await tester.pump();
      expect(find.text('Bölümünüzü seçin.'), findsOneWidget);
      expect(find.text('Sınıfınızı seçin.'), findsOneWidget);
      expect(b.count('PATCH /users/me'), 0);
      // Yalnız bölüm seçilince sınıf hatası kalır.
      await tester.tap(find.text('Bölüm seçin'));
      await pickFromSearch(tester, 'bilg', 'Bilgisayar Mühendisliği');
      await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
      await tester.pump();
      expect(find.text('Sınıfınızı seçin.'), findsOneWidget);
      expect(find.text('Bölümünüzü seçin.'), findsNothing);
      expect(b.count('PATCH /users/me'), 0);
      await unmount(tester);
    });

    testWidgets('geçerli gövde: faculty + department + grade (ad gönderilmez); başarıda onDone', (tester) async {
      useScreen(tester, const Size(390, 1200));
      final b = backend();
      var done = 0;
      await tester.pumpWidget(buildApp(ProfileSetupPage(session: makeSession(b), onDone: () => done++)));
      await settle(tester, const Duration(milliseconds: 400));
      await fillAcademic(tester);
      await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
      await settle(tester, const Duration(milliseconds: 600));
      final body = b.bodies['PATCH /users/me'] as Map;
      expect(body['faculty'], 'Mühendislik Fakültesi');
      expect(body['department'], 'Bilgisayar Mühendisliği');
      expect(body['grade'], '3');
      expect(body.containsKey('displayName'), isFalse);
      expect(done, 1);
      await unmount(tester);
    });

    testWidgets('sunucu hatası alan altında bantla gösterilir; onDone çağrılmaz', (tester) async {
      useScreen(tester, const Size(390, 1200));
      final b = backend()..fail('/users/me', status: 429, code: 'RATE_LIMITED', message: 'Çok fazla deneme.');
      await tester.pumpWidget(buildApp(ProfileSetupPage(session: makeSession(b), onDone: () => fail('kapanmamalı'))));
      await settle(tester, const Duration(milliseconds: 400));
      await fillAcademic(tester);
      await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Çok fazla deneme'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sistem geri tuşu sayfayı kapatmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      await tester.pumpWidget(buildApp(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute<void>(builder: (_) => ProfileSetupPage(session: makeSession(b), onDone: () {}))),
              child: const Text('aç'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('aç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('"Çıkış yap" oturumu kapatır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(ProfileSetupPage(session: s, onDone: () {})));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.ensureVisible(find.byKey(const ValueKey('profile-setup-signout')));
      await tester.tap(find.byKey(const ValueKey('profile-setup-signout')));
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
            testWidgets('taşma yok | $lang ${dark ? 'koyu' : 'açık'} ${size.width.toInt()} x$scale (hata açık)', (tester) async {
              useScreen(tester, size);
              final b = backend();
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
                home: ProfileSetupPage(session: makeSession(b), onDone: () {}),
              ));
              await settle(tester, const Duration(milliseconds: 500));
              await tester.ensureVisible(find.byKey(const ValueKey('profile-setup-submit')));
              await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
              await tester.pump(const Duration(milliseconds: 400));
              expect(tester.takeException(), isNull);
              await unmount(tester);
            });
          }
        }
      }
    }
  });

  group('ProfileCompletionGate', () {
    Widget gate(Session s, {Duration timeout = const Duration(seconds: 3)}) => buildApp(
          ProfileCompletionGate(session: s, loadTimeout: timeout, child: const Scaffold(body: Text('KABUK'))),
        );

    testWidgets('bölüm/sınıf eksik: kabuk yerine ProfileSetupPage', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..on('/users/me', {'id': 1, 'displayName': 'Ayşe', 'department': null, 'grade': null});
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      expect(find.text('KABUK'), findsNothing);
      await unmount(tester);
    });

    testWidgets('yalnız sınıf eksik: yine açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..on('/users/me', {'id': 1, 'department': 'Biyoloji', 'grade': ''});
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('profil dolu: ana ekran, kapı açılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..on('/users/me', {'id': 1, 'department': 'Biyoloji', 'grade': '2'});
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('KABUK'), findsOneWidget);
      expect(find.byType(ProfileSetupPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('kaydedince (fotoğraf yok) önce isteğe bağlı fotoğraf adımı, atlayınca ana ekran; bir daha sorulmaz', (tester) async {
      useScreen(tester, const Size(390, 1200));
      final b = backend()..on('/users/me', {'id': 1, 'department': null, 'grade': null});
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await fillAcademic(tester);
      await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(ProfilePhotoSetupPage), findsOneWidget);
      expect(find.text('KABUK'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('photo-setup-skip')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('KABUK'), findsOneWidget);
      expect(find.byType(ProfilePhotoSetupPage), findsNothing);
      expect(find.byType(ProfileSetupPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('çevrimdışı: kapı kabuğu engellemez; bağlantı gelince eksikse açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()
        ..network('/users/me');
      final s = makeSession(b);
      await tester.pumpWidget(gate(s));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('KABUK'), findsOneWidget);
      expect(find.byType(ProfileSetupPage), findsNothing);
      // Bağlantı döner: profil eksik, kapı kapanır.
      b.on('/users/me', {'id': 1, 'department': null, 'grade': null});
      s.api.connectivity.reconnects.value++;
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      expect(find.text('KABUK'), findsNothing);
      await unmount(tester);
    });

    testWidgets('yavaş yanıt: zaman aşımında kabuk açılır, sonradan eksik çıkarsa kapı kapanır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(seconds: 2))
        ..on('/users/me', {'id': 1, 'department': null, 'grade': null});
      await tester.pumpWidget(gate(makeSession(b), timeout: const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('KABUK'), findsNothing); // karar anı: düz zemin
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('KABUK'), findsOneWidget);
      await settle(tester, const Duration(seconds: 3));
      expect(find.byType(ProfileSetupPage), findsOneWidget);
      await unmount(tester);
    });
  });
}
