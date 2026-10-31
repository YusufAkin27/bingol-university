import 'dart:io';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/profil2_my_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

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
    // A4-08 (W1-I T-099): KVKK verisi PANOYA konmaz; dosya olarak sistem paylaşımına verilir, yaşam döngüsüyle silinir.
    List<String> installFakes(WidgetTester tester, {bool deliverOk = true}) {
      final log = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method.startsWith('Clipboard.')) log.add('CLIP:${call.method}');
        return null;
      });
      final oldDeliver = ExportShare.deliver;
      final oldPurge = ExportShare.purge;
      final oldTtl = kExportFileTtl;
      ExportShare.deliver = (json, title) async {
        log.add('deliver:${json.contains('"profile"')}');
        return deliverOk;
      };
      ExportShare.purge = () async => log.add('purge');
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
        ExportShare.deliver = oldDeliver;
        ExportShare.purge = oldPurge;
        kExportFileTtl = oldTtl;
      });
      return log;
    }

    testWidgets('KVKK verisi panoya YAZILMAZ; paylaşıma verilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final log = installFakes(tester);
      final b = FakeBackend()..on('/users/me/export', {'profile': {'id': 1}});
      await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('my-data-download')));
      await settle(tester);
      expect(log, contains('deliver:true'));
      expect(log.where((e) => e.startsWith('CLIP:')), isEmpty, reason: 'pano hiç kullanılmamalı');
      expect(find.textContaining('panoya'), findsNothing);
      await unmount(tester);
    });

    testWidgets('paylaşımdan uygulamaya dönünce (resumed) dosya silinir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final log = installFakes(tester);
      final b = FakeBackend()..on('/users/me/export', {'profile': {'id': 1}});
      await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      log.clear(); // initState temizliğini say
      await tester.tap(find.byKey(const ValueKey('my-data-download')));
      await settle(tester);
      expect(log, ['deliver:true']);
      // Yalnız resumed (arka plana hiç gitmeden): silinmez.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(log, ['deliver:true']);
      // Paylaşım sayfası/hedef uygulama öne geçti, sonra dönüldü.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(log, ['deliver:true']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(log, ['deliver:true', 'purge']);
      // İkinci resumed ek silme üretmez (dosya yok).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(log, ['deliver:true', 'purge']);
      await unmount(tester);
    });

    testWidgets('yaşam döngüsü olmasa da süre dolunca (kExportFileTtl) dosya silinir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final log = installFakes(tester);
      final b = FakeBackend()..on('/users/me/export', {'profile': {'id': 1}});
      await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      kExportFileTtl = const Duration(seconds: 5);
      log.clear();
      await tester.tap(find.byKey(const ValueKey('my-data-download')));
      await settle(tester);
      expect(log, ['deliver:true']);
      await tester.pump(const Duration(seconds: 6));
      expect(log, ['deliver:true', 'purge']);
      await unmount(tester);
    });

    testWidgets('sayfa kapanınca (dispose) dosya silinir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final log = installFakes(tester);
      final b = FakeBackend()..on('/users/me/export', {'profile': {'id': 1}});
      await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('my-data-download')));
      await settle(tester);
      log.clear();
      await tester.pumpWidget(const SizedBox());
      expect(log, ['purge']);
    });

    testWidgets('paylaşım açılamazsa hata gösterilir, pano kullanılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final log = installFakes(tester, deliverOk: false);
      final b = FakeBackend()..on('/users/me/export', {'profile': {'id': 1}});
      await tester.pumpWidget(buildApp(MyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('my-data-download')));
      await settle(tester);
      expect(find.textContaining('hazırlanamadı'), findsOneWidget);
      expect(log.where((e) => e.startsWith('CLIP:')), isEmpty);
      // Başarısız teslimde yaşam döngüsü silmesi kurulmadı: resumed ek 'purge' üretmez.
      final before = log.where((e) => e == 'purge').length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(log.where((e) => e == 'purge').length, before);
      await unmount(tester);
    });

    test('ExportShare: dosya export/ altına yazılır, kanal çağrılır, purge dizini siler', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final tmp = await Directory.systemTemp.createTemp('bu_export_test');
      addTearDown(() async {
        ExportShare.baseDir = getTemporaryDirectory;
        messenger.setMockMethodCallHandler(ExportShare.channel, null);
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      ExportShare.baseDir = () async => tmp;
      String? sharedPath;
      messenger.setMockMethodCallHandler(ExportShare.channel, (call) async {
        expect(call.method, 'shareFile');
        sharedPath = (call.arguments as Map<Object?, Object?>)['path']! as String;
        expect(File(sharedPath!).existsSync(), isTrue);
        return true;
      });
      expect(await ExportShare.deliver('{"profile":{"id":1}}', 'Başlık'), isTrue);
      expect(sharedPath, contains('${Platform.pathSeparator}export${Platform.pathSeparator}'));
      expect(File(sharedPath!).readAsStringSync(), '{"profile":{"id":1}}');
      await ExportShare.purge();
      expect(Directory('${tmp.path}${Platform.pathSeparator}export').existsSync(), isFalse);
      // Yerel kod yok (MissingPluginException) => false ve kalıntı dosya yok.
      messenger.setMockMethodCallHandler(ExportShare.channel, null);
      expect(await ExportShare.deliver('{}', 't'), isFalse);
      expect(Directory('${tmp.path}${Platform.pathSeparator}export').existsSync(), isFalse);
    });

    testWidgets('indir düğmesi export çağırır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final old = kExportFileTtl;
      kExportFileTtl = Duration.zero;
      addTearDown(() => kExportFileTtl = old);
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
