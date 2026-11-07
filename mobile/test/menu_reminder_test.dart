import 'package:bu_kampus/core/notify/local_reminders.dart';
import 'package:bu_kampus/features/menu/menu_reminder.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_notif_prefs.dart';

class _Backend implements LocalReminderBackend {
  final Map<String, List<LocalReminder>> groups = {};
  bool allowed = true;

  @override
  Future<void> replaceGroup(String group, List<LocalReminder> items) async => groups[group] = items;
  @override
  Future<void> upsert(String group, LocalReminder item) async {}
  @override
  Future<void> cancel(String group, int id) async {}
  @override
  Future<void> cancelGroup(String group) async => groups.remove(group);
  @override
  Future<void> cancelAll() async => groups.clear();
  @override
  Future<bool> notificationsAllowed() async => allowed;
  @override
  Future<Map<String, String>?> takeLaunchPayload() async => null;
}

void main() {
  setUpAll(loadTestFonts);
  final l = lookupAppLocalizations(const Locale('tr'));

  MenuReminderService make(_Backend b, MemoryMenuReminderStore s, DateTime now) =>
      MenuReminderService(store: s, reminders: LocalReminders(b, clock: () => now), clock: () => now);

  test('varsayılan KAPALI ve 11:30', () {
    const s = MenuReminderSettings();
    expect(s.enabled, isFalse);
    expect(s.minutes, 11 * 60 + 30);
    expect(MenuReminderSettings.fromJson(s.copyWith(enabled: true, minutes: 600).toJson()), const MenuReminderSettings(enabled: true, minutes: 600));
  });

  test('plan: kapalıyken boş; açıksa her gün seçilen saatte, geçmiş saat bugünden atlanır', () {
    final b = _Backend();
    final now = DateTime(2026, 11, 7, 12, 0); // 11:30 bugün geçti
    final svc = make(b, MemoryMenuReminderStore(), now);
    expect(svc.plan(const MenuReminderSettings(), l), isEmpty);
    final p = svc.plan(const MenuReminderSettings(enabled: true), l);
    expect(p.first.at, DateTime(2026, 11, 8, 11, 30));
    expect(p.length, MenuReminderService.days);
    expect(p.every((r) => r.at.hour == 11 && r.at.minute == 30), isTrue);
    expect(p.first.payload['targetType'], 'MENU');
    expect(p.map((r) => r.id).toSet().length, p.length);
    final early = make(b, MemoryMenuReminderStore(), DateTime(2026, 11, 7, 9, 0)).plan(const MenuReminderSettings(enabled: true), l);
    expect(early.first.at, DateTime(2026, 11, 7, 11, 30));
  });

  test('apply: açınca gruba yazılır, kapatınca grup silinir', () async {
    final b = _Backend();
    final store = MemoryMenuReminderStore();
    final svc = make(b, store, DateTime(2026, 11, 7, 9, 0));
    expect(await svc.apply(const MenuReminderSettings(enabled: true, minutes: 12 * 60)), isTrue);
    expect(store.value.enabled, isTrue);
    expect(b.groups[MenuReminderService.group], isNotEmpty);
    expect(b.groups[MenuReminderService.group]!.first.at.hour, 12);
    expect(await svc.apply(const MenuReminderSettings(enabled: false)), isTrue);
    expect(b.groups[MenuReminderService.group], isNull);
  });

  test('apply: izin yoksa istenir; verilmezse tercih KAPALI kalır ve zamanlanmaz', () async {
    final b = _Backend()..allowed = false;
    final store = MemoryMenuReminderStore();
    final svc = make(b, store, DateTime(2026, 11, 7, 9, 0));
    var asked = 0;
    final ok = await svc.apply(const MenuReminderSettings(enabled: true), requestPermission: () async {
      asked++;
      return false;
    });
    expect(ok, isFalse);
    expect(asked, 1);
    expect(store.value.enabled, isFalse);
    expect(b.groups[MenuReminderService.group], isNull);
    final ok2 = await svc.apply(const MenuReminderSettings(enabled: true), requestPermission: () async => true);
    expect(ok2, isTrue);
    expect(b.groups[MenuReminderService.group], isNotEmpty);
  });

  testWidgets('Ayarlar > Bildirimler: anahtar varsayılan kapalı; açınca saat satırı (11:30) çıkar ve kaydedilir', (tester) async {
    final be = _Backend();
    final store = MemoryMenuReminderStore();
    final prev = MenuReminderService.instance;
    MenuReminderService.instance = make(be, store, DateTime(2026, 11, 7, 9, 0));
    addTearDown(() => MenuReminderService.instance = prev);
    const size = Size(390, 2600);
    useScreen(tester, size);
    final b = FakeBackend();
    FakeNotifPrefs(b);
    await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(b)), size: size));
    await settle(tester);

    expect(find.text('Günlük menü hatırlatıcısı'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-reminder-time')), findsNothing);
    final row = find.byKey(const ValueKey('prefs-menu-reminder'));
    final sw = find.descendant(of: row, matching: find.byType(Switch));
    expect(tester.widget<Switch>(sw).value, isFalse);

    await tester.ensureVisible(sw);
    await tester.tap(sw);
    await settle(tester);
    expect(tester.widget<Switch>(sw).value, isTrue);
    expect(find.text('11:30'), findsOneWidget);
    expect(store.value.enabled, isTrue);
    expect(be.groups[MenuReminderService.group], isNotEmpty);

    await tester.tap(sw);
    await settle(tester);
    expect(store.value.enabled, isFalse);
    expect(be.groups[MenuReminderService.group], isNull);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
