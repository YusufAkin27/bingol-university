import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/profil2_my_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Widget _rtl(Widget page, Size size, bool dark) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('ar'),
      home: page,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(alignment: Alignment.topLeft, child: SizedBox(width: size.width, height: size.height, child: child)),
        ),
      ),
    );

FakeBackend _backend() => FakeBackend()
  ..on('/users/me/privacy', {
    'avatar': 'EVERYONE',
    'bio': 'SHARED_CONTEXT',
    'department': 'EVERYONE',
    'faculty': 'ONLY_ME',
    'classYear': 'SHARED_CONTEXT',
    'avatarHiddenByModeration': false,
  })
  ..on('/users/me', {'id': 1, 'showEmail': false, 'language': 'tr'});

void main() {
  setUpAll(loadTestFonts);

  group('Gizlilik', () {
    testWidgets('alan seçimi anında PATCH eder', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend();
      await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Gizlilik ve engellenenler'), findsOneWidget);
      expect(find.text('Ortak bağlam'), findsNWidgets(5)); // her alanın 3 parçalı seçicisinde bir tane
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('privacy-select-avatar')), matching: find.text('Yalnızca ben')));
      await settle(tester);
      expect(b.bodies['PATCH /users/me/privacy'], {'avatar': 'ONLY_ME'});
      await unmount(tester);
    });

    testWidgets('kayıt hatasında eski değere döner', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend();
      await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      b.fail('/users/me/privacy', status: 500);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('privacy-select-faculty')), matching: find.text('Herkes')));
      await settle(tester);
      // Hata bildirimi ("Tekrar dene" ile) gösterilir.
      expect(find.text('Değişiklik kaydedilemedi.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('e-posta anahtarı PATCH /users/me {showEmail}', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend();
      await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('privacy-email-switch')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('privacy-email-switch')));
      await settle(tester);
      expect(b.bodies['PATCH /users/me'], {'showEmail': true});
      await unmount(tester);
    });

    testWidgets('moderasyonla gizlenen avatar uyarısı', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend()..on('/users/me/privacy', {'avatarHiddenByModeration': true});
      await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.byKey(const ValueKey('privacy-avatar-moderated')), findsOneWidget);
      await unmount(tester);
    });

    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('320 ${dark ? 'koyu' : 'acik'} x$scale taşma yok', (tester) async {
          useScreen(tester, kPhoneSmall);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(_backend())),
              brightness: dark ? Brightness.dark : Brightness.light, size: kPhoneSmall));
          await settle(tester);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }

    testWidgets('ar RTL 320 taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(_rtl(PrivacyDataPage(session: makeSession(_backend())), kPhoneSmall, false));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Verilerim', () {
    testWidgets('KVKK verisi panoya konur ve süre sonunda panodan silinir', (tester) async {
      useScreen(tester, kPhoneMedium);
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
        if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': clip};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final old = kExportClipboardTtl;
      kExportClipboardTtl = const Duration(seconds: 5);
      addTearDown(() => kExportClipboardTtl = old);
      final b = FakeBackend()..on('/users/me/export', {'profile': {'id': 1}});
      await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('my-data-download')));
      await settle(tester);
      expect(clip, contains('"profile"'));
      expect(find.textContaining('30 saniye'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(clip, '');
      await unmount(tester);
    });

    testWidgets('pano başka metne dönüştüyse silinmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
        if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': clip};
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final old = kExportClipboardTtl;
      kExportClipboardTtl = const Duration(seconds: 5);
      addTearDown(() => kExportClipboardTtl = old);
      final b = FakeBackend()..on('/users/me/export', {'profile': {'id': 1}});
      await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('my-data-download')));
      await settle(tester);
      clip = 'kullanici baska bir sey kopyaladi';
      await tester.pump(const Duration(seconds: 6));
      expect(clip, 'kullanici baska bir sey kopyaladi');
      await unmount(tester);
    });

    testWidgets('indir düğmesi export çağırır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final old = kExportClipboardTtl;
      kExportClipboardTtl = Duration.zero;
      addTearDown(() => kExportClipboardTtl = old);
      final b = FakeBackend()..on('/users/me/export', {'profile': {'id': 1}});
      await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('JSON dosyası olarak hazırlanır'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-data-download')));
      await settle(tester);
      expect(b.count('GET /users/me/export'), 1);
      await tester.pump();
      await unmount(tester);
    });

    for (final dark in [false, true]) {
      testWidgets('320 x2 ${dark ? 'koyu' : 'acik'} taşma yok', (tester) async {
        useScreen(tester, kPhoneSmall);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(FakeBackend())),
            brightness: dark ? Brightness.dark : Brightness.light, size: kPhoneSmall));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('ar RTL taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(_rtl(MyDataPage(session: makeSession(FakeBackend())), kPhoneSmall, true));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Hesabı sil', () {
    testWidgets('onay kutusu olmadan devam edilemez; yanlış şifre hata gösterir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/users/me', status: 403, code: 'WRONG_PASSWORD');
      await tester.pumpWidget(buildApp(DeleteAccountPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      final cont = find.byKey(const ValueKey('delete-continue'));
      expect(tester.widget<InkWell>(find.descendant(of: cont, matching: find.byType(InkWell)).first).onTap, isNull);
      await tester.tap(find.byKey(const ValueKey('delete-ack')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(cont);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Silmeyi onayla'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('delete-password')), 'yanlis123');
      await tester.tap(find.byKey(const ValueKey('delete-submit')));
      await settle(tester);
      expect(b.bodies['DELETE /users/me'], {'password': 'yanlis123'});
      expect(find.byKey(const ValueKey('delete-error')), findsOneWidget);
      await unmount(tester);
    });

    for (final dark in [false, true]) {
      testWidgets('320 x2 klavye ${dark ? 'koyu' : 'acik'} taşma yok', (tester) async {
        useScreen(tester, kPhoneSmall);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(buildApp(DeleteAccountPage(session: makeSession(FakeBackend())),
            brightness: dark ? Brightness.dark : Brightness.light, size: kPhoneSmall));
        await settle(tester);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('delete-ack')), 100,
            scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.byKey(const ValueKey('delete-ack')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('delete-ack')));
        await settle(tester, const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const ValueKey('delete-continue')));
        await settle(tester, const Duration(milliseconds: 600));
        tester.view.viewInsets = const FakeViewPadding(bottom: 260); // klavye açılır
        await settle(tester, const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('delete-submit')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('ar RTL taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(_rtl(DeleteAccountPage(session: makeSession(FakeBackend())), kPhoneSmall, false));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Hesap ve güvenlik', () {
    Future<void> fill(WidgetTester tester, {String cur = 'eskiSifre1', String nw = 'YeniSifre123', String rep = 'YeniSifre123'}) async {
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('sec-current')), matching: find.byType(TextField)), cur);
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('sec-new')), matching: find.byType(TextField)), nw);
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('sec-repeat')), matching: find.byType(TextField)), rep);
    }

    testWidgets('e-posta ve çıkış satırı görünür', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(AccountSecurityPage(session: makeSession(FakeBackend())), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('ayse@bingol.edu.tr'), findsOneWidget);
      expect(find.text('Tüm cihazlardan çıkış yap'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('eşleşmeyen şifre sunucuya gitmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(AccountSecurityPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await fill(tester, rep: 'baska12345');
      await tester.ensureVisible(find.byKey(const ValueKey('sec-submit')));
      await tester.tap(find.byKey(const ValueKey('sec-submit')));
      await settle(tester);
      expect(find.text('•  Şifreler eşleşmiyor.'), findsOneWidget);
      expect(b.count('POST /auth/change-password'), 0);
      await unmount(tester);
    });

    testWidgets('başarıda doğru gövde gönderilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(AccountSecurityPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('sec-submit')));
      await tester.tap(find.byKey(const ValueKey('sec-submit')));
      await settle(tester);
      expect(b.bodies['POST /auth/change-password'], {'currentPassword': 'eskiSifre1', 'newPassword': 'YeniSifre123'});
      expect(find.text('Şifren güncellendi.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yanlış mevcut şifre alanın altında gösterilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/change-password', status: 403, code: 'WRONG_PASSWORD');
      await tester.pumpWidget(buildApp(AccountSecurityPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('sec-submit')));
      await tester.tap(find.byKey(const ValueKey('sec-submit')));
      await settle(tester);
      expect(find.byKey(const ValueKey('sec-errors')), findsOneWidget);
      expect(find.text('•  Mevcut şifre hatalı.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('uç yoksa (404) genel hata', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/auth/change-password', status: 404, code: 'NOT_FOUND');
      await tester.pumpWidget(buildApp(AccountSecurityPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('sec-submit')));
      await tester.tap(find.byKey(const ValueKey('sec-submit')));
      await settle(tester);
      expect(find.text('Şifre güncellenemedi. Lütfen daha sonra tekrar deneyin.'), findsOneWidget);
      await unmount(tester);
    });

    for (final dark in [false, true]) {
      testWidgets('320 x2 ${dark ? 'koyu' : 'acik'} taşma yok', (tester) async {
        useScreen(tester, kPhoneSmall);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(buildApp(AccountSecurityPage(session: makeSession(FakeBackend())),
            brightness: dark ? Brightness.dark : Brightness.light, size: kPhoneSmall));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('ar RTL taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(_rtl(AccountSecurityPage(session: makeSession(FakeBackend())), kPhoneSmall, true));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
