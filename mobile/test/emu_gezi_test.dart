import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/clubs/club_detail_parts.dart';
import 'package:bu_kampus/features/polls/anket_widgets.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// EMU-GEZI: emulatorde gercek veriyle gezilirken bulunan gorunum kusurlarinin testleri.
void main() {
  group('trUpper dil duyarli', () {
    tearDown(() => LocaleController.current = null);

    LocaleController lc(String lang) => LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;

    test('Turkce: i -> I-nokta, dotless -> I', () {
      LocaleController.current = lc('tr');
      expect(trUpper('cum ilk kasim'), 'CUM İLK KASİM');
      expect(trUpper('ışık'), 'IŞIK');
    });

    test('Ingilizce: Fri -> FRI (noktali I yok)', () {
      LocaleController.current = lc('en');
      expect(trUpper('Fri'), 'FRI');
      expect(trUpper('Tuesday'), 'TUESDAY');
    });

    test('Arapca: Latin harf buyur, Arap harfi degismez', () {
      LocaleController.current = lc('ar');
      expect(trUpper('abc'), 'ABC');
      expect(trUpper('أحمد'), 'أحمد');
    });

    test('temsilci yoksa eski Turkce davranis', () {
      LocaleController.current = null;
      expect(trUpper('bildirim'), 'BİLDİRİM');
    });
  });

  group('Anket bos kutusu', () {
    testWidgets('sekme adini tekrar eden rozet/ikinci simge yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(const Scaffold(
        body: AnketEmptyCard(icon: Icons.how_to_vote, title: 'Baslik', body: 'Aciklama'),
      )));
      await tester.pump();
      expect(find.text('Baslik'), findsOneWidget);
      expect(find.text('Aciklama'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget, reason: 'yalniz tek yuvarlak simge');
    });
  });

  group('Kulup sekme seridi', () {
    ClubTabsDelegate d(Brightness b, {int index = 0}) =>
        ClubTabsDelegate(labels: const ['A', 'B'], index: index, onChanged: (_) {}, brightness: b);

    test('tema parlakligi degisince yeniden kurulur', () {
      expect(d(Brightness.dark).shouldRebuild(d(Brightness.light)), isTrue);
      expect(d(Brightness.light).shouldRebuild(d(Brightness.light)), isFalse);
      expect(d(Brightness.light, index: 1).shouldRebuild(d(Brightness.light)), isTrue);
    });
  });

  group('Ana kabuk durum cubugu ortusu', () {
    testWidgets('ortu var, dokunmayi gecirir ve anlamsal dugum eklemez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(AppShell(session: makeSession(b), themeController: ThemeController())));
      await settle(tester);
      final scrim = find.byKey(const ValueKey('status-bar-scrim'));
      expect(scrim, findsOneWidget);
      expect(find.ancestor(of: scrim, matching: find.byType(IgnorePointer)), findsWidgets);
      expect(tester.getTopLeft(scrim).dy, 0);
      expect(tester.getSize(scrim).width, 390);
    });

    for (final br in Brightness.values) {
      testWidgets('durum cubugu simgesi ${br.name} temada tema parlakligina gore sabitlenir', (tester) async {
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(buildApp(
          AppShell(session: makeSession(FakeBackend()), themeController: ThemeController()),
          brightness: br,
        ));
        await settle(tester);
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
        expect(region.value.statusBarIconBrightness, br == Brightness.dark ? Brightness.light : Brightness.dark);
      });
    }
  });
}
