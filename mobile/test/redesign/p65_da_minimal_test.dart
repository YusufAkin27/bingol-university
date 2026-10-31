import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/permissions_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/auth/widgets/auth_ref.dart';
import 'package:bu_kampus/features/legal/legal_reaccept.dart';
import 'package:bu_kampus/features/legal/legal_reaccept_page.dart';
import 'package:bu_kampus/features/platform/qr_scan_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// P3-DA (minimal tur): karşılama, izinler, durum ekranları, kayıt, sözleşmeler, QR. Davranış değişmedi;
/// görünüm sözleşmeleri: tek birincil düğme, sakin ikincil, bilgi kutusu/rozet/ek hap yok, tek ton, taşma yok.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  Future<void> welcome(WidgetTester tester, {Size size = kPhoneMedium, Brightness b = Brightness.light}) async {
    useScreen(tester, size);
    LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
    addTearDown(() => LocaleController.current = null);
    await tester.pumpWidget(buildApp(WelcomePage(onLogin: () {}, onRegister: () {}), brightness: b, size: size));
    await settle(tester, const Duration(milliseconds: 1200));
  }

  group('Karşılama', () {
    testWidgets('tek dolgulu düğme (Giriş yap) + sakin ikincil (Kayıt ol)', (tester) async {
      await welcome(tester);
      final kinds = tester.widgetList<RefButton>(find.byType(RefButton)).map((b) => b.kind).toList();
      expect(kinds, [RefButtonKind.primary, RefButtonKind.ghost]);
      // İkincil düğme dolgusuz ve çerçevesiz: ekranda tek vurgu.
      final ghost = find.widgetWithText(RefButton, 'Kayıt ol');
      expect(ghost, findsOneWidget);
      final m = tester.widget<Material>(find.descendant(of: ghost, matching: find.byType(Material)).first);
      expect(m.color, Colors.transparent);
      await unmount(tester);
    });

    testWidgets('üç özellik satırı yalnız başlık: alt açıklama, sürüm ve bilgi kutusu yok', (tester) async {
      await welcome(tester);
      expect(find.text('Haberler ve duyurular'), findsOneWidget);
      expect(find.text('Günün yemek listesi'), findsOneWidget);
      expect(find.text('Kulüpler ve etkinlikler'), findsOneWidget);
      expect(find.textContaining('Anlık bildirimler'), findsNothing);
      expect(find.textContaining('Günlük kalori'), findsNothing);
      expect(find.byType(RefCard), findsNothing);
      expect(find.byIcon(LucideIcons.shieldCheck), findsNothing);
      // Kayıt notu tek sakin satır olarak durur.
      expect(find.textContaining('bingol.edu.tr', findRichText: true), findsOneWidget);
      await unmount(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      testWidgets('ekrana sığar: kaydırma gerekmez veya taşma yok (${size.width.toInt()})', (tester) async {
        await welcome(tester, size: size);
        expect(tester.takeException(), isNull);
        final btn = tester.getRect(find.byType(RefButton).first);
        expect(btn.height, greaterThanOrEqualTo(48));
        expect(btn.left, 20, reason: 'yatay kenar 20 dp');
        await unmount(tester);
      });
    }
  });

  group('İzinler', () {
    Future<void> perms(WidgetTester tester, Map<AppPermission, PermState> m, {Brightness b = Brightness.light}) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(PermissionsPage(service: FakePermissionService(initial: m), onFinished: () {}), brightness: b));
      await settle(tester, const Duration(milliseconds: 900));
    }

    testWidgets('düz satırlar: kart/adım çubuğu yok, "İzin ver" outlined, tek dolgulu birincil düğme', (tester) async {
      await perms(tester, {});
      final buttons = tester.widgetList<BuButton>(find.byType(BuButton)).toList();
      expect(buttons.where((b) => b.kind == BuButtonKind.primary).length, 1, reason: 'yalnız alttaki Başla');
      expect(buttons.where((b) => b.kind == BuButtonKind.outline).length, 3);
      expect(find.textContaining('Adım'), findsNothing);
      expect(find.text('Şimdi değil'), findsOneWidget, reason: 'yalnız ilk durumda');
      expect(find.text('Atla'), findsNothing);
      await unmount(tester);
    });

    testWidgets('verildi: sağ üstte onay + Verildi; reddedildi: iki metin düğmesi; "Şimdi değil" kalkar', (tester) async {
      await perms(tester, {AppPermission.notifications: PermState.granted, AppPermission.contacts: PermState.permanentlyDenied});
      expect(find.text('Verildi'), findsOneWidget);
      expect(find.text('Reddedildi'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.text('Ayarlardan aç'), findsOneWidget);
      expect(find.text('Şimdi değil'), findsNothing);
      await unmount(tester);
    });

    testWidgets('yatay kenar 20 dp', (tester) async {
      await perms(tester, {});
      final title = tester.getRect(find.text('Birkaç izin'));
      expect(title.left, 20);
      await unmount(tester);
    });
  });

  group('Durum ekranları', () {
    testWidgets('bakım: üst şerit yok; simge + başlık + metin + tek düğme', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(MaintenanceScreen(onRetry: () {})));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(GateNoticeStrip), findsNothing);
      expect(find.byType(BuButton), findsOneWidget);
      expect(find.text('Sistem bakımda'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('erişim engeli: kod hapı yok, soluk tek satır; simge dangerSoft daire', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(AccessBlockedScreen(onRetry: () {})));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.textContaining('ACCESS_BLOCKED'), findsOneWidget);
      expect(find.byIcon(LucideIcons.terminal), findsNothing);
      final circle = find.byWidgetPredicate((w) => w is Container && w.constraints == const BoxConstraints.tightFor(width: 72, height: 72));
      expect((tester.widget<Container>(circle).decoration! as BoxDecoration).color, BuTokens.light.dangerSoft);
      expect(find.byType(BuButton), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('güncelleme: sürüm hapı yok, birincil + sakin yeniden kontrol', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(UpdateRequiredScreen(storeUrl: 'https://example.com', latest: '2.1.0', current: '2.0.3', onRetry: () {})));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Yüklü sürüm 2.0.3 · Gerekli sürüm 2.1.0'), findsOneWidget, reason: 'kutusuz tek satır, API değerleriyle');
      expect(find.byKey(const ValueKey('update-recheck')), findsOneWidget);
      final kinds = tester.widgetList<BuButton>(find.byType(BuButton)).map((b) => b.kind).toList();
      expect(kinds, [BuButtonKind.primary], reason: 'ikincil yeniden kontrol düz metin düğmesi');
      await unmount(tester);
    });
  });

  group('Kayıt', () {
    testWidgets('adım 1: bölüm başlığı tek (ayrıca "AKADEMİK BİLGİLER" etiketi yok), not tek sakin satır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()..on('/catalog/academic', {'version': 1, 'faculties': [], 'grades': []});
      final s = makeSession(be, signedIn: false);
      await tester.pumpWidget(buildApp(RegisterPage(session: s)));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('AKADEMİK BİLGİLER'), findsNothing);
      expect(find.text('Akademik bilgiler'), findsNothing);
      expect(find.byType(RefNote), findsOneWidget);
      expect(find.byType(RefIconTile), findsNothing);
      await unmount(tester);
    });
  });

  group('Sözleşmeler', () {
    testWidgets('liste: kart ve satır simgesi yok; satırlar ince ayırıcıyla', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/legal', [
          {'type': 'TERMS', 'title': 'Kullanım Koşulları', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
          {'type': 'PRIVACY', 'title': 'Gizlilik Politikası', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
          {'type': 'KVKK', 'title': 'KVKK Aydınlatma Metni', 'version': 3, 'publishedAt': '2026-10-12T09:00:00Z'},
        ]);
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(LegalListPage(session: s)));
      await settle(tester, const Duration(milliseconds: 800));
      for (final ic in [LucideIcons.gavel, LucideIcons.shield, LucideIcons.lockKeyhole]) {
        expect(find.byIcon(ic), findsNothing);
      }
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('Kullanım Koşulları'), findsOneWidget);
      await unmount(tester);
    });
  });

  // 320 dp genişlik + 1,3x yazı + RTL + açık/koyu: yeni/değişen ekranlarda taşma yok.
  group('320 dp / 1.3x yazı (tur 3)', () {
    LegalReaccept reaccept(bool enforced) => LegalReaccept(
        const [LegalItem('TERMS', 3), LegalItem('PRIVACY', 3), LegalItem('KVKK', 3), LegalItem('COMMUNITY_RULES', 3)],
        enforced: enforced);
    final pages = <String, Widget Function(Session s)>{
      'izinler': (s) => PermissionsPage(service: FakePermissionService(initial: const {}), onFinished: () {}),
      'izinler durumlu': (s) => PermissionsPage(
            service: FakePermissionService(initial: const {AppPermission.notifications: PermState.granted, AppPermission.contacts: PermState.permanentlyDenied}),
            onFinished: () {},
          ),
      'yeniden onay zorunlu': (s) => LegalReacceptPage(session: s, state: reaccept(true)),
      'yeniden onay ertelenebilir': (s) => LegalReacceptPage(session: s, state: reaccept(false)),
      'qr izin yok': (s) => QrScanPage(
            permissionService: FakePermissionService(initial: const {AppPermission.camera: PermState.permanentlyDenied}),
            scannerBuilder: (c) => const ColoredBox(color: Color(0xFF111111)),
          ),
      'qr kamera': (s) => QrScanPage(
            permissionService: FakePermissionService(initial: const {AppPermission.camera: PermState.granted}),
            scannerBuilder: (c) => const ColoredBox(color: Color(0xFF111111)),
          ),
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
              ]);
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
