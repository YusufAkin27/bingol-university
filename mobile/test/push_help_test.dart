import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/push/push_health.dart';
import 'package:bu_kampus/core/push/push_registrar.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/notifications/push_help_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

class _FakeSource implements PushHealthSource {
  _FakeSource(this.health);
  PushHealth health;
  int reregisters = 0, notifOpened = 0, batteryOpened = 0;

  @override
  Future<PushHealth> read() async => health;

  @override
  Future<void> reregister() async {
    reregisters++;
    health = const PushHealth(supported: true, osAllowed: true, registration: PushRegState.registered, isAndroid: true, manufacturer: 'xiaomi');
  }

  @override
  Future<bool> openNotificationSettings() async {
    notifOpened++;
    return true;
  }

  @override
  Future<bool> openBatterySettings() async {
    batteryOpened++;
    return true;
  }
}

Widget _app(PushHealthSource s) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BuTheme.light(),
      home: PushHelpPage(source: s),
    );

void main() {
  setUpAll(loadTestFonts);

  test('PushHealth.allGood yalniz izin + kanal + kayit tamamken', () {
    const ok = PushHealth(supported: true, osAllowed: true, registration: PushRegState.registered);
    expect(ok.allGood, isTrue);
    expect(const PushHealth(supported: true, osAllowed: false, registration: PushRegState.registered).allGood, isFalse);
    expect(const PushHealth(supported: true, osAllowed: true, blockedChannels: ['chat'], registration: PushRegState.registered).allGood, isFalse);
    expect(const PushHealth(supported: true, osAllowed: true, registration: PushRegState.failed).allGood, isFalse);
    expect(const PushHealth(supported: false, osAllowed: true, registration: PushRegState.registered).allGood, isFalse);
    expect(const PushHealth(supported: true, osAllowed: true, manufacturer: 'xiaomi').aggressiveOem, isTrue);
    expect(const PushHealth(supported: true, osAllowed: true, manufacturer: 'google').aggressiveOem, isFalse);
  });

  testWidgets('sorunlu cihaz: izin kapali + kayit yok -> uyari, ayar ve yeniden kaydet eylemleri', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final src = _FakeSource(const PushHealth(
      supported: true,
      osAllowed: false,
      blockedChannels: ['chat'],
      registration: PushRegState.failed,
      manufacturer: 'xiaomi',
      isAndroid: true,
    ));
    await tester.pumpWidget(_app(src));
    await tester.pumpAndSettle();

    expect(find.text('Bildirimler çalışmıyor mu?'), findsOneWidget); // baslik
    expect(find.textContaining('engelleyen bir şey var'), findsOneWidget);
    expect(find.textContaining('Mesajlar kategorisi'), findsOneWidget);
    expect(find.text('Pil ve arka plan'), findsOneWidget);
    expect(find.textContaining('Otomatik başlatma'), findsOneWidget); // OEM metni

    // Izin satirindaki "Ayarlardan aç" (kanal satirinda da var): ilki
    await tester.tap(find.text('Ayarlardan aç').first);
    await tester.pumpAndSettle();
    expect(src.notifOpened, 1);

    await tester.ensureVisible(find.text('Pil ayarlarını aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pil ayarlarını aç'));
    await tester.pumpAndSettle();
    expect(src.batteryOpened, 1);
  });

  testWidgets('kayit hatasi: Yeniden kaydet cagrilir ve ozet duzelir', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final src = _FakeSource(const PushHealth(supported: true, osAllowed: true, registration: PushRegState.failed, isAndroid: true));
    await tester.pumpWidget(_app(src));
    await tester.pumpAndSettle();
    expect(find.text('Yeniden kaydet'), findsOneWidget);
    await tester.tap(find.text('Yeniden kaydet'));
    await tester.pumpAndSettle();
    expect(src.reregisters, 1);
    expect(find.textContaining('her şey yolunda'), findsOneWidget);
    expect(find.text('Yeniden kaydet'), findsNothing);
  });

  testWidgets('Bildirim tercihleri: yardim baglantisi yardim ekranini acar', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prevPerm = PermissionService.instance;
    PermissionService.instance = FakePermissionService(initial: {AppPermission.notifications: PermState.granted});
    addTearDown(() => PermissionService.instance = prevPerm);
    final b = FakeBackend()..on('/notifications/preferences', {'news': true, 'announcements': true, 'events': true, 'communities': true, 'messages': true});
    await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(b))));
    await tester.pumpAndSettle();
    expect(find.text('Bildirimler çalışmıyor mu?'), findsOneWidget);
    await tester.tap(find.text('Bildirimler çalışmıyor mu?'));
    await tester.pumpAndSettle();
    expect(find.byType(PushHelpPage), findsOneWidget);
    expect(find.textContaining('Bildirim izni'), findsWidgets);
  });

  testWidgets('Bildirim tercihleri: mesaj onizlemesi anahtari yalniz sunucu gonderirse gorunur ve kismi govde yollar', (tester) async {
    tester.view.physicalSize = const Size(1170, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prevPerm = PermissionService.instance;
    PermissionService.instance = FakePermissionService(initial: {AppPermission.notifications: PermState.granted});
    addTearDown(() => PermissionService.instance = prevPerm);
    final base = {'news': true, 'announcements': true, 'events': true, 'communities': true, 'messages': true};

    final none = FakeBackend()..on('/notifications/preferences', base);
    await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(none))));
    await tester.pumpAndSettle();
    expect(find.text('Bildirimde mesaj önizlemesi'), findsNothing);

    final b = FakeBackend()..on('/notifications/preferences', {...base, 'messagePreview': false});
    await tester.pumpWidget(buildApp(NotificationPrefsPage(key: const ValueKey('second'), session: makeSession(b))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Bildirimde mesaj önizlemesi'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Bildirimde mesaj önizlemesi'), findsOneWidget);
    await tester.tap(find.text('Bildirimde mesaj önizlemesi'));
    await tester.pumpAndSettle();
    expect(b.bodies['PUT /notifications/preferences'], {'messagePreview': true});
  });
}
