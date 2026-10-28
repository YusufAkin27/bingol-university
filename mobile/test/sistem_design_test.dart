import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/auth/permissions_page.dart';
import 'package:bu_kampus/features/platform/qr_scan_page.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:bu_kampus/widgets/common.dart';
import 'package:bu_kampus/widgets/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void _noErr(WidgetTester t) {
  final e = t.takeException();
  if (e != null) fail('$e');
}

Future<void> _pump(WidgetTester tester, Widget w, {Brightness b = Brightness.light, Size size = kPhoneMedium, bool rtl = false}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(
    rtl ? Directionality(textDirection: TextDirection.rtl, child: w) : w,
    brightness: b,
    size: size,
  ));
  await settle(tester, const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  // Her sistem ekrani: 3 ekran boyutu x acik/koyu x LTR/RTL, tasma yok.
  final screens = <String, Widget Function()>{
    'UpdateRequired': () => const UpdateRequiredScreen(storeUrl: 'https://example.com', latest: '1.1.0', current: '1.0.2'),
    'AccessBlocked': () => AccessBlockedScreen(onRetry: () {}),
    'Maintenance': () => MaintenanceScreen(onRetry: () {}),
    'Offline': () => OfflineScreen(onRetry: () {}),
    'ErrorView net': () => Scaffold(body: ErrorView(error: ApiError(0, 'NETWORK', ''), onRetry: () {})),
    'ErrorView genel': () => Scaffold(body: ErrorView(error: ApiError(500, 'X', ''), onRetry: () {})),
    'EmptyView': () => Scaffold(body: EmptyView(icon: LucideIcons.bell, text: 'Yeni bildirimler burada görünecek.', title: 'Bildirim yok')),
    'EmptyView eylemli': () => Scaffold(
        body: EmptyView(icon: LucideIcons.messageSquare, text: 'Birini bulup ilk mesajı gönderin.', title: 'Henüz sohbet yok', actionLabel: 'Yeni sohbet', onAction: () {})),
    'StaleBanner': () => const Scaffold(body: Padding(padding: EdgeInsets.all(20), child: StaleBanner(text: 'Bazı özellikler geçici olarak kullanılamayabilir.'))),
    'QrScanPage': () => const QrScanPage(),
    'PermissionsPage': () => PermissionsPage(service: FakePermissionService(), onFinished: () {}),
  };

  for (final e in screens.entries) {
    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        for (final rtl in [false, true]) {
          testWidgets('${e.key} ${b.name} ${size.width.toInt()}${rtl ? ' rtl' : ''}: tasma yok', (tester) async {
            await _pump(tester, e.value(), b: b, size: size, rtl: rtl);
            _noErr(tester);
            await unmount(tester);
            _noErr(tester);
          });
        }
      }
    }
  }

  group('icerik', () {
    testWidgets('guncelleme: surum satiri ve Magazada ac', (tester) async {
      await _pump(tester, const UpdateRequiredScreen(storeUrl: 'https://example.com', latest: '1.1.0', current: '1.0.2'));
      expect(find.text('Güncelleme gerekli'), findsOneWidget);
      expect(find.text('Yüklü sürüm 1.0.2 · Gerekli sürüm 1.1.0'), findsOneWidget);
      expect(find.text('Mağazada aç'), findsOneWidget);
    });

    testWidgets('guncelleme: guvensiz magaza adresinde dugme yok', (tester) async {
      await _pump(tester, const UpdateRequiredScreen(storeUrl: 'http://x.com'));
      expect(find.text('Mağazada aç'), findsNothing);
    });

    testWidgets('erisim engeli: kod satiri ve Tekrar dene geri cagrisi', (tester) async {
      var n = 0;
      await _pump(tester, AccessBlockedScreen(onRetry: () => n++));
      expect(find.text('Hata kodu: ACCESS_BLOCKED'), findsOneWidget);
      await tester.tap(find.text('Tekrar dene'));
      expect(n, 1);
    });

    testWidgets('bakim ve baglanti yok: Yeniden dene', (tester) async {
      var n = 0;
      await _pump(tester, MaintenanceScreen(onRetry: () => n++));
      expect(find.text('Sistem bakımda'), findsOneWidget);
      await tester.tap(find.text('Yeniden dene'));
      expect(n, 1);
      await _pump(tester, OfflineScreen(onRetry: () => n++));
      expect(find.text('Bağlantı yok'), findsOneWidget);
      await tester.tap(find.text('Yeniden dene'));
      expect(n, 2);
    });

    testWidgets('ErrorView: ag hatasi Baglanti yok, digeri Bir seyler ters gitti; yeniden dene calisir', (tester) async {
      var n = 0;
      await _pump(tester, Scaffold(body: ErrorView(error: ApiError(0, 'NETWORK', ''), onRetry: () => n++)));
      expect(find.text('Bağlantı yok'), findsOneWidget);
      await tester.tap(find.text('Yeniden dene'));
      expect(n, 1);
      await _pump(tester, Scaffold(body: ErrorView(error: Exception('x'), onRetry: () => n++)));
      expect(find.text('Bir şeyler ters gitti'), findsOneWidget);
    });

    testWidgets('EmptyView eylem dugmesi', (tester) async {
      var n = 0;
      await _pump(tester, Scaffold(body: EmptyView(icon: LucideIcons.bell, text: 'a', title: 'b', actionLabel: 'Yeni sohbet', onAction: () => n++)));
      await tester.tap(find.text('Yeni sohbet'));
      expect(n, 1);
    });

    testWidgets('QR: kamera yokken elle giris + Yoklamayi gonder; kod geri doner', (tester) async {
      String? result;
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await Navigator.push<String>(c, MaterialPageRoute(builder: (_) => const QrScanPage())),
              child: const Text('ac'),
            ),
          ),
        ),
        size: kPhoneSmall,
      ));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Kodu elle gir'), findsOneWidget);
      expect(find.text('veya'), findsOneWidget);
      expect(find.textContaining('Yoklama etkinlik saatinde'), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' k7m4qx ');
      await tester.tap(find.text('Yoklamayı gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(result, 'k7m4qx');
      _noErr(tester);
    });
  });

  group('ReportSheet gorunum', () {
    testWidgets('5 sebep, Vazgec kapatir, secili radyo erisilebilir', (tester) async {
      final s = makeSession(FakeBackend());
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(onPressed: () => ReportSheet.show(c, s, targetType: 'POST', targetId: 1, title: 'Gönderiyi şikâyet et'), child: const Text('aç')),
          ),
        ),
        size: kPhoneSmall,
      ));
      await tester.tap(find.text('aç'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Gönderiyi şikâyet et'), findsOneWidget);
      for (final r in ['Spam veya reklam', 'Taciz veya zorbalık', 'Uygunsuz içerik', 'Başkasını taklit', 'Diğer']) {
        expect(find.text(r), findsOneWidget);
      }
      final h = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('Spam veya reklam')),
        matchesSemantics(label: 'Spam veya reklam', hasCheckedState: true, isChecked: true, isInMutuallyExclusiveGroup: true, isButton: true, hasTapAction: true, hasEnabledState: true, isEnabled: true),
      );
      h.dispose();
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Gönderiyi şikâyet et'), findsNothing);
      _noErr(tester);
    });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('${b.name}${rtl ? ' rtl' : ''} 320: tasma yok', (tester) async {
          final s = makeSession(FakeBackend());
          useScreen(tester, kPhoneSmall);
          await tester.pumpWidget(buildApp(
            Builder(
              builder: (c) => Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Scaffold(body: TextButton(onPressed: () => ReportSheet.show(c, s, targetType: 'USER', targetId: 1), child: const Text('aç'))),
              ),
            ),
            brightness: b,
            size: kPhoneSmall,
          ));
          await tester.tap(find.text('aç'));
          await settle(tester, const Duration(milliseconds: 600));
          _noErr(tester);
          await unmount(tester);
        });
      }
    }
  });
}
