import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/auth/otp_code_boxes.dart';
import 'package:bu_kampus/features/auth/widgets/auth_motion.dart';
import 'package:bu_kampus/features/auth/widgets/auth_ref.dart';
import 'package:bu_kampus/features/platform/qr_scan_page.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// P2-DA (tur 2: ince detay + animasyon): kimlik akisi ve sistem ekranlari. Her animasyon icin
/// (i) baslangic/bitis, (ii) "animasyonlari azalt" acikken aninda, (iii) tekrar oynamama, (iv) dokunma/semantik.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  Widget reduce(Widget child, {bool on = true}) => MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: on),
        child: child,
      );

  /// Adim cubugundaki i. parcanin doluluk orani (ScaleX).
  double fill(WidgetTester tester, int i) {
    final f = find.descendant(of: find.byKey(ValueKey('auth-step-fill-$i')), matching: find.byType(Transform));
    final m = tester.widget<Transform>(f.first).transform;
    return m.storage[0];
  }

  group('AuthStepBar', () {
    testWidgets('ilerleyince yeni parca soldan dolar (ara kare), geri gidince bosalir', (tester) async {
      useScreen(tester, kPhoneMedium);
      var step = 0;
      late StateSetter set;
      await tester.pumpWidget(buildApp(Scaffold(
        body: StatefulBuilder(builder: (c, s) {
          set = s;
          return Padding(padding: const EdgeInsets.all(16), child: AuthStepBar(step: step, steps: 3));
        }),
      )));
      await tester.pump();
      expect(fill(tester, 0), closeTo(1, .001));
      expect(fill(tester, 1), closeTo(0, .001));
      expect(fill(tester, 2), closeTo(0, .001));
      set(() => step = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final mid = fill(tester, 1);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(fill(tester, 1), closeTo(1, .001));
      expect(fill(tester, 2), closeTo(0, .001));
      set(() => step = 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fill(tester, 1), closeTo(0, .001));
      expect(fill(tester, 0), closeTo(1, .001));
      await unmount(tester);
    });

    testWidgets('azalt aciksa ilk karede son durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      var step = 0;
      late StateSetter set;
      await tester.pumpWidget(reduce(buildApp(Scaffold(
        body: StatefulBuilder(builder: (c, s) {
          set = s;
          return AuthStepBar(step: step, steps: 3);
        }),
      ))));
      await tester.pump();
      set(() => step = 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(fill(tester, 2), closeTo(1, .001));
      await unmount(tester);
    });
  });

  group('OtpCodeBoxes', () {
    testWidgets('yeni rakam kucukten yerine oturur; sonunda tam olcek', (tester) async {
      useScreen(tester, kPhoneMedium);
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(buildApp(Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: OtpCodeBoxes(controller: c, onCompleted: () {})))));
      await settle(tester, const Duration(milliseconds: 300));
      c.text = '7';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final digit = find.ancestor(of: find.text('7'), matching: find.byType(ScaleTransition)).first;
      final s = tester.widget<ScaleTransition>(digit).scale.value;
      expect(s, lessThan(1));
      expect(s, greaterThan(.5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<ScaleTransition>(digit).scale.value, closeTo(1, .001));
      // Ayni rakam yeniden cizilince (baska bir kutu yazilirken) tekrar oynamaz.
      c.text = '75';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<ScaleTransition>(find.ancestor(of: find.text('7'), matching: find.byType(ScaleTransition)).first).scale.value, closeTo(1, .001));
      await unmount(tester);
    });

    testWidgets('azalt aciksa rakam aninda tam olcek', (tester) async {
      useScreen(tester, kPhoneMedium);
      final c = TextEditingController(text: '4');
      addTearDown(c.dispose);
      await tester.pumpWidget(reduce(buildApp(Scaffold(body: OtpCodeBoxes(controller: c, onCompleted: () {})))));
      await tester.pump();
      final digit = find.ancestor(of: find.text('4'), matching: find.byType(ScaleTransition)).first;
      expect(tester.widget<ScaleTransition>(digit).scale.value, 1);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      testWidgets('basari: kutular yesil dolgu + yesil cerceve (${b.name})', (tester) async {
        useScreen(tester, kPhoneMedium);
        final tk = b == Brightness.dark ? BuTokens.dark : BuTokens.light;
        final c = TextEditingController(text: '123456');
        addTearDown(c.dispose);
        await tester.pumpWidget(buildApp(
          Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: OtpCodeBoxes(controller: c, onCompleted: () {}, enabled: false, success: true))),
          brightness: b,
        ));
        await settle(tester, const Duration(milliseconds: 600));
        final f = find.descendant(of: find.byType(OtpCodeBoxes), matching: find.byType(AnimatedContainer));
        for (var i = 0; i < 6; i++) {
          final d = tester.widget<AnimatedContainer>(f.at(i)).decoration! as BoxDecoration;
          expect(d.color, tk.okSoft);
          expect((d.border! as Border).top.color, tk.ok);
        }
        await unmount(tester);
      });
    }
  });

  group('RefButton', () {
    testWidgets('etiket <-> yukleniyor yumusak gecer; busy iken dokunma kapali', (tester) async {
      useScreen(tester, kPhoneMedium);
      var busy = false;
      var taps = 0;
      late StateSetter set;
      await tester.pumpWidget(buildApp(Scaffold(
        body: StatefulBuilder(builder: (c, s) {
          set = s;
          return RefButton(label: 'Giris yap', busyLabel: 'Giris yapiliyor', busy: busy, onPressed: () => taps++);
        }),
      )));
      await tester.pump();
      expect(find.text('Giris yap'), findsOneWidget);
      set(() => busy = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Gecis ortasinda iki icerik de agacta (capraz solma).
      expect(find.text('Giris yap'), findsOneWidget);
      expect(find.text('Giris yapiliyor'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Giris yap'), findsNothing);
      await tester.tap(find.byType(RefButton), warnIfMissed: false);
      expect(taps, 0);
      await unmount(tester);
    });
  });

  group('Durum ekranlari: nefes', () {
    double iconScale(WidgetTester tester) {
      final f = find.ancestor(of: find.byIcon(LucideIcons.wrench), matching: find.byType(ScaleTransition));
      // StaggerItem'in kendi ScaleTransition'i yoktur; yalnizca nefes ScaleTransition'i.
      return tester.widget<ScaleTransition>(f.first).scale.value;
    }

    testWidgets('bakim: simge ince nefes alir (<= 1,06), sonunda durur (surekli dongu yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(MaintenanceScreen(onRetry: () {})));
      await tester.pump(const Duration(milliseconds: 900));
      final seen = <double>{};
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        seen.add(double.parse(iconScale(tester).toStringAsFixed(3)));
      }
      expect(seen.length, greaterThan(3));
      expect(seen.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(1.06));
      expect(seen.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(1.0));
      // Sonlu: ~6,4 sn sonra denetleyici durur, pumpAndSettle biter.
      await tester.pumpAndSettle(const Duration(milliseconds: 200), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
      expect(iconScale(tester), closeTo(1, .001));
      await unmount(tester);
    });

    testWidgets('azalt aciksa nefes yok (ScaleTransition olusmaz)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(reduce(buildApp(MaintenanceScreen(onRetry: () {}))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.ancestor(of: find.byIcon(LucideIcons.wrench), matching: find.byType(ScaleTransition)), findsNothing);
      await unmount(tester);
    });

    testWidgets('guncelleme ekraninda nefes yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: 'https://example.com', latest: '1.1.0', current: '1.0.2')));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.ancestor(of: find.byIcon(LucideIcons.smartphone), matching: find.byType(ScaleTransition)), findsNothing);
      await unmount(tester);
    });
  });

  group('QrScanPage', () {
    QrScanPage page({Future<String?> Function(String)? onSubmit}) => QrScanPage(
          permissionService: FakePermissionService(initial: {AppPermission.camera: PermState.granted}),
          scannerBuilder: (_) => const ColoredBox(color: Colors.black),
          onSubmit: onSubmit,
        );

    testWidgets('cerceve ilk gorunumde oturur; tarama cizgisi sonludur (pumpAndSettle biter)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(page()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('qr-lock-check')), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 200), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
      await unmount(tester);
    });

    testWidgets('basarili okuma: onay isareti belirir, kodla kapanir', (tester) async {
      useScreen(tester, kPhoneMedium);
      String? result;
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => result = await Navigator.push<String>(c, MaterialPageRoute(builder: (_) => page(onSubmit: (_) async => null))),
              child: const Text('ac'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 600));
      double checkScale() => tester.widget<AnimatedScale>(find.ancestor(of: find.byKey(const ValueKey('qr-lock-check')), matching: find.byType(AnimatedScale)).first).scale;
      expect(checkScale(), 0);
      await tester.enterText(find.byType(TextField).last, 'KOD-7');
      await tester.pump();
      final submit = find.byWidgetPredicate((w) => w is GateArrowButton || w is BuButton);
      await tester.tap(submit.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(checkScale(), 1);
      await settle(tester, const Duration(milliseconds: 1500));
      expect(result, 'KOD-7');
      await unmount(tester);
    });
  });
}
