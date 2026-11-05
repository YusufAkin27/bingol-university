import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Uygulama her açıldığında (giriş, kayıt, yeniden açılış) ilk sekme KEŞFET'tir; geri tuşu Ana Sayfa'ya götürür.
void main() {
  Future<void> pumpShell(WidgetTester tester, {int? initialTab}) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend();
    final session = makeSession(b);
    await tester.pumpWidget(buildApp(initialTab == null
        ? AppShell(session: session, themeController: ThemeController())
        : AppShell(initialTab: initialTab, session: session, themeController: ThemeController())));
    await settle(tester);
  }

  int navIndex(WidgetTester tester) => tester.widget<FloatingNav>(find.byType(FloatingNav)).index;

  testWidgets('varsayilan acilis sekmesi Kesfet', (tester) async {
    await pumpShell(tester);
    expect(navIndex(tester), AppTab.discover);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('initialTab ile Ana Sayfa ya da baska sekme acilabilir', (tester) async {
    await pumpShell(tester, initialTab: AppTab.home);
    expect(navIndex(tester), AppTab.home);
    await unmount(tester);
  });
}
