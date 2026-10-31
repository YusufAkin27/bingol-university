// UPDATEGATE: zorunlu güncelleme ekranı ve kapı. Mağaza bağlantısı önceliği (market:// / itms-apps:// sonra https),
// bağlantı yokken ölü düğme yerine metin, sunucu metni, öne dönüşte yeniden kontrol, küçük ekran/büyük yazı,
// 3 dil ve açık/koyu tema.
import 'dart:ui' as ui;

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/app_gate.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _market = 'market://details?id=tr.com.bukampus.app';
const _play = 'https://play.google.com/store/apps/details?id=tr.com.bukampus.app';
const _itms = 'itms-apps://apps.apple.com/app/id6740123456';
const _apple = 'https://apps.apple.com/app/id6740123456';

/// Açılan adresleri kaydeder; [result] ile her adres için başarı döndürür.
class _Launcher {
  final List<String> opened = [];
  bool Function(Uri) result = (_) => true;
  bool throws = false;

  Future<bool> call(Uri uri) async {
    opened.add(uri.toString());
    if (throws) throw Exception('launch');
    return result(uri);
  }
}

Widget _localized(Widget home, {Locale locale = const Locale('tr'), Brightness brightness = Brightness.light, double scale = 1}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
  );
}

void main() {
  setUpAll(loadTestFonts);

  late _Launcher launcher;
  setUp(() {
    launcher = _Launcher();
    storeLauncher = launcher.call;
  });
  tearDown(() => storeLauncher = (uri) async => false);

  group('decideGate: yeni alanlar', () {
    test('marketUrl ve message geçerliyse taşınır', () {
      final d = decideGate({
        'updateRequired': true,
        'storeUrl': _play,
        'marketUrl': _market,
        'message': '  Önemli düzeltme.  ',
        'latestVersion': '2.0.5',
      }, null);
      expect(d.kind, GateKind.updateRequired);
      expect(d.storeUrl, _play);
      expect(d.marketUrl, _market);
      expect(d.message, 'Önemli düzeltme.');
    });

    test('iOS itms-apps kabul edilir', () {
      expect(decideGate({'updateRequired': true, 'marketUrl': _itms}, null).marketUrl, _itms);
    });

    test('güvensiz şemalar atılır', () {
      for (final bad in [
        'http://play.google.com/x',
        'javascript:alert(1)',
        'intent://details?id=x#Intent;scheme=market;end',
        'market://evil?id=x',
        'market://details',
        'itms-apps://evil.example/app',
        'tel:112',
        'https://play.google.com/store',
        '',
      ]) {
        expect(decideGate({'updateRequired': true, 'marketUrl': bad}, null).marketUrl, isNull, reason: bad);
      }
    });

    test('boş/yalnız boşluk mesaj null; çok uzun mesaj kırpılır; eski sunucu (alan yok) sorunsuz', () {
      expect(decideGate({'updateRequired': true, 'message': '   '}, null).message, isNull);
      expect(decideGate({'updateRequired': true, 'message': 5}, null).message, isNull);
      expect(decideGate({'updateRequired': true, 'message': 'x' * 900}, null).message!.length, kMaxUpdateMessage);
      final old = decideGate({'updateRequired': true, 'storeUrl': 'https://s.example/a'}, null);
      expect(old.marketUrl, isNull);
      expect(old.message, isNull);
      expect(old.storeUrl, 'https://s.example/a');
    });
  });

  group('öne dönüşte yeniden kontrol', () {
    test('ilk kez ya da 15 dakika geçince; öncesinde değil', () {
      final now = DateTime(2026, 11, 1, 12);
      expect(shouldRecheckOnResume(null, now), isTrue);
      expect(shouldRecheckOnResume(now.subtract(const Duration(minutes: 14)), now), isFalse);
      expect(shouldRecheckOnResume(now.subtract(const Duration(minutes: 15)), now), isTrue);
      expect(shouldRecheckOnResume(now.subtract(const Duration(days: 3)), now), isTrue);
    });
  });

  group('openStoreLinks', () {
    test('önce doğrudan şema, başarılıysa https denenmez', () async {
      expect(await openStoreLinks(marketUrl: _market, storeUrl: _play), isTrue);
      expect(launcher.opened, [_market]);
    });

    test('doğrudan şema açılamazsa https mağaza adresine düşer', () async {
      launcher.result = (u) => u.scheme == 'https';
      expect(await openStoreLinks(marketUrl: _market, storeUrl: _play), isTrue);
      expect(launcher.opened, [_market, _play]);
    });

    test('doğrudan şema istisna atarsa https denenir', () async {
      launcher.throws = true;
      expect(await openStoreLinks(marketUrl: _itms, storeUrl: _apple), isFalse); // ikisi de atar
      expect(launcher.opened, [_itms, _apple]);
    });

    test('adres yoksa ya da güvensizse hiçbir şey açılmaz', () async {
      expect(await openStoreLinks(), isFalse);
      expect(await openStoreLinks(marketUrl: 'javascript:1', storeUrl: 'http://x.example'), isFalse);
      expect(launcher.opened, isEmpty);
    });

    test('yalnız https verilirse (eski sunucu) onu açar; openStore uyumlu', () async {
      expect(await openStoreLinks(storeUrl: _play), isTrue);
      await openStore(_apple);
      expect(launcher.opened, [_play, _apple]);
    });
  });

  group('UpdateRequiredScreen', () {
    testWidgets('market adresi varken Güncelle önce onu açar', (tester) async {
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: _play, marketUrl: _market)));
      await tester.tap(find.text('Güncelle'));
      await tester.pump();
      expect(launcher.opened, [_market]);
      expect(find.byKey(const ValueKey('update-from-store')), findsNothing);
    });

    testWidgets('yalnız https varsa onu açar', (tester) async {
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: _apple)));
      await tester.tap(find.text('Güncelle'));
      await tester.pump();
      expect(launcher.opened, [_apple]);
    });

    testWidgets('yalnız market şeması varsa da düğme çıkar (iOS kimliği, https yok)', (tester) async {
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: null, marketUrl: _itms)));
      expect(find.text('Güncelle'), findsOneWidget);
      await tester.tap(find.text('Güncelle'));
      await tester.pump();
      expect(launcher.opened, [_itms]);
    });

    testWidgets('hiç adres yoksa ölü düğme yok; "Mağazadan güncelleyin" yazısı var', (tester) async {
      var n = 0;
      await tester.pumpWidget(buildApp(UpdateRequiredScreen(storeUrl: null, onRetry: () => n++)));
      expect(find.text('Güncelle'), findsNothing);
      expect(find.byKey(const ValueKey('update-from-store')), findsOneWidget);
      expect(find.text('Mağazadan güncelleyin'), findsOneWidget);
      // Çıkış yolu: Tekrar kontrol et
      await tester.tap(find.text('Tekrar kontrol et'));
      expect(n, 1);
      expect(launcher.opened, isEmpty);
    });

    testWidgets('güvensiz market şeması düğme üretmez', (tester) async {
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: 'http://x.example', marketUrl: 'javascript:1')));
      expect(find.text('Güncelle'), findsNothing);
      expect(find.text('Mağazadan güncelleyin'), findsOneWidget);
    });

    testWidgets('sunucu mesajı varsayılan açıklamanın yerine tek paragraf olarak görünür', (tester) async {
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: _play, message: 'Önemli güvenlik düzeltmesi yayınlandı.')));
      expect(find.text('Önemli güvenlik düzeltmesi yayınlandı.'), findsOneWidget);
      expect(find.text('Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemeniz gerekiyor.'), findsNothing);
    });

    testWidgets('mesaj yoksa ya da boşsa varsayılan açıklama', (tester) async {
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: _play)));
      expect(find.text('Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemeniz gerekiyor.'), findsOneWidget);
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: _play, message: '  ')));
      expect(find.text('Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemeniz gerekiyor.'), findsOneWidget);
    });

    testWidgets('geri tuşu ekranı kapatmaz (PopScope canPop: false)', (tester) async {
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: _play)));
      final pop = tester.widget<PopScope>(find.byType(PopScope).first);
      expect(pop.canPop, isFalse);
    });

    for (final locale in const [Locale('tr'), Locale('en'), Locale('ar')]) {
      for (final b in Brightness.values) {
        testWidgets('320 dp, yazı x1,3: taşma yok (${locale.languageCode}, ${b.name}), bağlantısız + uzun mesaj', (tester) async {
          useScreen(tester, const Size(320, 640));
          final long = ('Önemli bir düzeltme yayınlandı; lütfen uygulamayı en kısa sürede güncelleyin. ' * 4).substring(0, 240);
          for (final screen in <Widget>[
            UpdateRequiredScreen(storeUrl: _play, marketUrl: _market, message: long, latest: '2.0.5', current: '2.0.4', onRetry: () {}),
            UpdateRequiredScreen(storeUrl: null, message: long, latest: '2.0.5', current: '2.0.4', onRetry: () {}),
          ]) {
            await tester.pumpWidget(_localized(screen, locale: locale, brightness: b, scale: 1.3));
            await tester.pump(const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);
            final l10n = AppLocalizations.of(tester.element(find.byType(UpdateRequiredScreen)))!;
            expect(find.text(l10n.updateRequiredTitle), findsOneWidget);
            expect(find.text(l10n.commonUpdate).evaluate().length + find.text(l10n.updateRequiredFromStore).evaluate().length, 1);
            if (locale.languageCode == 'ar') {
              expect(Directionality.of(tester.element(find.byType(UpdateRequiredScreen))), ui.TextDirection.rtl);
            }
          }
        });
      }
    }
  });

  group('AppGate: öne dönüşte kontrol', () {
    FakeBackend backend({bool required = true, String? message}) {
      final b = FakeBackend();
      b.on('/app/version*', {
        'updateRequired': required,
        'updateAvailable': required,
        'latestVersion': '9.9.9',
        'storeUrl': _play,
        'marketUrl': _market,
        'message': message,
      });
      return b;
    }

    testWidgets('açılışta zorunlu güncelleme ekranı; sunucu metni gösterilir', (tester) async {
      mockSecureStorage();
      final b = backend(message: 'Lütfen güncelleyin.');
      await tester.pumpWidget(buildApp(AppGate(api: ApiClient(client: b.client, retryDelay: Duration.zero), child: const Text('uygulama'))));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Güncelleme gerekli'), findsOneWidget);
      expect(find.text('Lütfen güncelleyin.'), findsOneWidget);
      expect(find.text('uygulama'), findsNothing);
      await tester.tap(find.text('Güncelle'));
      await tester.pump();
      expect(launcher.opened, [_market]);
      await unmount(tester);
    });

    testWidgets('kilit açıkken her öne dönüşte yeniden sorulur; bayrak kalkınca ekran açılır', (tester) async {
      mockSecureStorage();
      final b = backend();
      await tester.pumpWidget(buildApp(AppGate(api: ApiClient(client: b.client, retryDelay: Duration.zero), child: const Text('uygulama'))));
      await settle(tester, const Duration(milliseconds: 500));
      final first = b.count('/app/version');
      expect(first, greaterThanOrEqualTo(1));
      expect(find.text('Güncelleme gerekli'), findsOneWidget);

      b.on('/app/version*', {'updateRequired': false, 'updateAvailable': false, 'latestVersion': '9.9.9'});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('/app/version'), greaterThan(first), reason: 'öne dönüşte sürüm yeniden soruldu');
      expect(find.text('Güncelleme gerekli'), findsNothing);
      expect(find.text('uygulama'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kilit yokken 15 dakika dolmadan öne dönüş yeni istek atmaz', (tester) async {
      mockSecureStorage();
      final b = backend(required: false);
      await tester.pumpWidget(buildApp(AppGate(api: ApiClient(client: b.client, retryDelay: Duration.zero), child: const Text('uygulama'))));
      await settle(tester, const Duration(milliseconds: 500));
      final first = b.count('/app/version');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('/app/version'), first);
      await unmount(tester);
    });

    testWidgets('çevrimdışıyken açılış kilitlemez (fail-open)', (tester) async {
      mockSecureStorage();
      final b = backend()..offline = true;
      await tester.pumpWidget(buildApp(AppGate(api: ApiClient(client: b.client, retryDelay: Duration.zero), child: const Text('uygulama'))));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Güncelleme gerekli'), findsNothing);
      expect(find.text('uygulama'), findsOneWidget);
      await unmount(tester);
    });
  });
}
