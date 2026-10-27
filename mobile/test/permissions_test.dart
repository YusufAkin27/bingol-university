import 'package:bu_kampus/core/permissions/ensure_permission.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/auth/permissions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void _noErrors(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

FakePermissionService _fake({Map<AppPermission, PermState>? initial}) => FakePermissionService(initial: initial);

Future<void> _pumpPage(WidgetTester tester, Widget page, {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(page, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  setUp(() async {
    await const FlutterSecureStorage().delete(key: 'perms_onboarded');
  });

  group('PostLoginGate', () {
    testWidgets('izin sayfasi yalniz bir kez cikar; Simdi degil atlar', (tester) async {
      final svc = _fake();
      Widget app() => PostLoginGate(service: svc, child: const Scaffold(body: Text('KABUK')));

      await _pumpPage(tester, app());
      expect(find.text('Birkaç izin'), findsOneWidget);
      expect(find.text('KABUK'), findsNothing);

      await tester.tap(find.text('Şimdi değil'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('KABUK'), findsOneWidget);
      expect(svc.requested, isEmpty);

      // Yeniden açılış (ya da başka hesapla giriş): bayrak kalıcı, sayfa tekrar çıkmaz.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpPage(tester, app());
      expect(find.text('Birkaç izin'), findsNothing);
      expect(find.text('KABUK'), findsOneWidget);
      _noErrors(tester);
    });

    testWidgets('Devam da bayragi isaretler', (tester) async {
      await _pumpPage(tester, PostLoginGate(service: _fake(), child: const Text('KABUK')));
      await tester.tap(find.text('Devam'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('KABUK'), findsOneWidget);
      expect(await PermissionOnboarding.isDone(), isTrue);
    });

    testWidgets('bildirim izni verilince geri cagri tetiklenir', (tester) async {
      var granted = 0;
      await _pumpPage(
        tester,
        PostLoginGate(service: _fake(), onNotificationsGranted: () => granted++, child: const Text('KABUK')),
      );
      await tester.tap(find.text('İzin ver').first); // Bildirimler ilk satır
      await settle(tester, const Duration(milliseconds: 400));
      expect(granted, 1);
    });
  });

  group('PermissionsPage', () {
    testWidgets('verildi / reddedildi / kalici ret durumlari', (tester) async {
      final svc = _fake()
        ..willAnswer(AppPermission.contacts, PermState.permanentlyDenied);
      final granted = <AppPermission>[];
      await _pumpPage(tester, PermissionsPage(service: svc, onFinished: () {}, onGranted: granted.add));
      expect(find.text('İzin ver'), findsNWidgets(2));

      await tester.tap(find.text('İzin ver').at(0)); // bildirim -> verildi
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Verildi'), findsOneWidget);
      expect(granted, [AppPermission.notifications]);

      await tester.tap(find.text('İzin ver').at(0)); // rehber -> kalici ret
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Ayarlardan aç'), findsOneWidget);
      expect(find.text('Reddedildi'), findsOneWidget);
      expect(granted.length, 1);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.tap(find.text('Ayarlardan aç'));
      await tester.pump();
      expect(svc.settingsOpened, 1);
      _noErrors(tester);
    });

    testWidgets('onceden verilmis izinler Verildi gorunur; hepsi tamsa Basla', (tester) async {
      final svc = _fake(initial: {
        AppPermission.notifications: PermState.granted,
        AppPermission.contacts: PermState.granted,
      });
      await _pumpPage(tester, PermissionsPage(service: svc, onFinished: () {}));
      expect(find.text('Verildi'), findsNWidgets(2));
      expect(find.text('Başla'), findsOneWidget);
      expect(find.text('Şimdi değil'), findsNothing);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('tasma yok ${b.name} ${size.width.toInt()}', (tester) async {
          final svc = _fake(initial: {
            AppPermission.notifications: PermState.permanentlyDenied,
          });
          await _pumpPage(tester, PermissionsPage(service: svc, onFinished: () {}), b: b, size: size);
          expect(find.text('Ayarlardan aç'), findsOneWidget);
          _noErrors(tester);
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pump();
          await tester.tap(find.text('İzin ver'));
          await settle(tester, const Duration(milliseconds: 400));
          _noErrors(tester);
        });
      }
    }
  });

  group('ensurePermission', () {
    Future<bool?> run(WidgetTester tester, FakePermissionService svc, Future<void> Function() interact) async {
      bool? result;
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => result = await ensurePermission(c, AppPermission.camera, service: svc),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
        size: kPhoneMedium,
      ));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 400));
      await interact();
      await settle(tester, const Duration(milliseconds: 500));
      return result;
    }

    testWidgets('izin varsa sheet cikmaz, true doner', (tester) async {
      final svc = _fake(initial: {AppPermission.camera: PermState.granted});
      final r = await run(tester, svc, () async {});
      expect(r, isTrue);
      expect(find.text('Devam'), findsNothing);
      expect(svc.requested, isEmpty);
    });

    testWidgets('gerekce -> sistem istegi -> true', (tester) async {
      final svc = _fake();
      final r = await run(tester, svc, () async {
        expect(find.textContaining('kameraya erişmemiz'), findsOneWidget);
        await tester.tap(find.text('Devam'));
      });
      expect(r, isTrue);
      expect(svc.requested, [AppPermission.camera]);
    });

    testWidgets('gerekce reddedilirse istek yapilmaz', (tester) async {
      final svc = _fake();
      final r = await run(tester, svc, () async {
        await tester.tap(find.text('Şimdi değil'));
      });
      expect(r, isFalse);
      expect(svc.requested, isEmpty);
    });

    testWidgets('sistem reddederse mesaj + Ayarlardan ac', (tester) async {
      final svc = _fake()..willAnswer(AppPermission.camera, PermState.permanentlyDenied);
      final r = await run(tester, svc, () async {
        await tester.tap(find.text('Devam'));
        await settle(tester, const Duration(milliseconds: 500));
        expect(find.textContaining('izni verilmedi'), findsOneWidget);
        await tester.tap(find.text('Ayarlardan aç'));
      });
      expect(r, isFalse);
      expect(svc.settingsOpened, 1);
    });

    testWidgets('onceden kalici ret dogrudan Ayarlar sheeti', (tester) async {
      final svc = _fake(initial: {AppPermission.camera: PermState.permanentlyDenied});
      final r = await run(tester, svc, () async {
        expect(find.text('Ayarlardan aç'), findsOneWidget);
        await tester.tap(find.text('Kapat'));
      });
      expect(r, isFalse);
      expect(svc.requested, isEmpty);
      expect(svc.settingsOpened, 0);
    });

    test('platform yoksa (unavailable) engellenmez', () {
      expect(PermState.unavailable.usable, isTrue);
      expect(PermState.denied.usable, isFalse);
    });
  });
}
