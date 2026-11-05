import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Sekmeler arası sağa/sola sürükleme (docs/MOBILE_MOTION_TABS.md): eşik 60 dp ya da hızlı fırlatma, eşik altı
/// geri dönme, RTL'de ters yön, sekme içeriğinin yeniden kurulmaması.
void main() {
  Future<void> pumpShell(WidgetTester tester, {TextDirection dir = TextDirection.ltr}) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend();
    await tester.pumpWidget(buildApp(Directionality(
      textDirection: dir,
      child: AppShell(initialTab: AppTab.home, session: makeSession(b), themeController: ThemeController()),
    )));
    await settle(tester);
  }

  int navIndex(WidgetTester tester) => tester.widget<FloatingNav>(find.byType(FloatingNav)).index;

  // Üst başlık/arama dışında, bölümlerin ortasında bir nokta (haber şeridi gibi yatay kaydırıcıların dışı).
  Offset spot(WidgetTester tester) => Offset(200, tester.view.physicalSize.height / tester.view.devicePixelRatio * .55);

  testWidgets('60 dp ustu sola surukleme sonraki sekmeye gecirir, saga surukleme geri dondurur', (tester) async {
    await pumpShell(tester);
    expect(navIndex(tester), 0);
    await tester.dragFrom(spot(tester), const Offset(-120, 0));
    await settle(tester, const Duration(milliseconds: 400));
    expect(navIndex(tester), 1);
    await tester.dragFrom(spot(tester), const Offset(140, 0));
    await settle(tester, const Duration(milliseconds: 400));
    expect(navIndex(tester), 0);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('esik alti surukleme sekmeyi degistirmez (140 ms yerine doner)', (tester) async {
    await pumpShell(tester);
    final g = await tester.startGesture(spot(tester));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await settle(tester, const Duration(milliseconds: 400));
    expect(navIndex(tester), 0);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('ilk sekmede saga surukleme yok sayilir; Profil sekmesinden sonra sola da', (tester) async {
    await pumpShell(tester);
    await tester.dragFrom(spot(tester), const Offset(150, 0));
    await settle(tester, const Duration(milliseconds: 400));
    expect(navIndex(tester), 0);
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(navIndex(tester), 4);
    await tester.dragFrom(spot(tester), const Offset(-150, 0));
    await settle(tester, const Duration(milliseconds: 400));
    expect(navIndex(tester), 4);
    await unmount(tester);
  });

  testWidgets('RTL: saga surukleme sonraki sekmedir', (tester) async {
    await pumpShell(tester, dir: TextDirection.rtl);
    await tester.dragFrom(spot(tester), const Offset(130, 0));
    await settle(tester, const Duration(milliseconds: 400));
    expect(navIndex(tester), 1);
    await unmount(tester);
  });

  testWidgets('sekme gecisinde Ana Sayfa yeniden kurulmaz (durum korunur)', (tester) async {
    await pumpShell(tester);
    final home = tester.state(find.byType(HomeTab));
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await settle(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(identical(home, tester.state(find.byType(HomeTab))), isTrue);
    expect(navIndex(tester), 0);
    await unmount(tester);
  });
}
