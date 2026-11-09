import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Rozet yoklaması (1 dk) arka planda durur, öne gelince yeniden kurulur (A5-05, Android arka plan zamanlayıcıları).
void main() {
  testWidgets('arka planda /me/summary yoklamasi calismaz, one gelince devam eder', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend();
    await tester.pumpWidget(buildApp(
      AppShell(initialTab: AppTab.home, session: makeSession(b), themeController: ThemeController()),
    ));
    await settle(tester);
    int n() => b.requests.where((r) => r.contains('/me/summary')).length;

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final before = n();
    await tester.pump(const Duration(minutes: 3));
    expect(n(), before, reason: 'arka planda yoklama olmamali');

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));
    final resumed = n();
    expect(resumed, greaterThan(before), reason: 'one gelince bir kez tazelenir');
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(n(), greaterThan(resumed), reason: 'zamanlayici yeniden kurulur');
    await unmount(tester);
  });
}
