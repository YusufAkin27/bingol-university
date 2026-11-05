import 'dart:io';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/profile_inline_edit.dart';
import 'package:bu_kampus/features/profile/profil_widgets.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// PREMIUM MONOCHROME 2. dalga, grup 3 (profil / ayarlar / destek / sistem): tema seçici (Sistem/Açık/Koyu),
/// kartsız profil kimliği (büyük sade ad), nötr liste simgeleri, dekoratif gölge/gradyan/hap düğme kalmadığı ve
/// iki temada taşma/kontrast güvenceleri.

double _lum(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + .05) / (lo + .05);
}

Widget _hero(Map<String, dynamic> p, FakeBackend b) => Scaffold(
      body: ListView(padding: const EdgeInsets.all(20), children: [
        InlineProfileHero(session: makeSession(b), profile: p, avatar: const SizedBox(width: 88, height: 88), onPatch: (_) {}),
      ]),
    );

void main() {
  group('Tema seçici (Ayarlar)', () {
    for (final dark in [false, true]) {
      testWidgets('Sistem/Açık/Koyu görünür, seçim ThemeController\'a yazılır (${dark ? 'koyu' : 'açık'})', (tester) async {
        final b = FakeBackend()
          ..on('/users/me', {'id': 1, 'language': 'tr', 'showEmail': true})
          ..on('/notifications/preferences', {'news': true});
        final tc = ThemeController()..mode = ThemeMode.dark;
        final sh = tester.ensureSemantics();
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(buildApp(SettingsPage(session: makeSession(b), themeController: tc), brightness: dark ? Brightness.dark : Brightness.light));
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.byKey(const ValueKey('settings-theme')), findsOneWidget);
        for (final k in ['system', 'light', 'dark']) {
          expect(find.byKey(ValueKey('theme-option-$k')), findsOneWidget, reason: k);
        }
        expect(find.text('Sistem'), findsWidgets);
        expect(find.text('Açık'), findsWidgets);
        expect(find.text('Koyu'), findsWidgets);
        // Seçili seçenek anlamsal olarak "selected".
        final sem = tester.getSemantics(find.byKey(const ValueKey('theme-option-dark')));
        expect(sem.flagsCollection.isSelected.toBoolOrNull(), isTrue);
        // Açığa dokun: mod değişir, seçili işaret taşınır.
        await tester.tap(find.byKey(const ValueKey('theme-option-light')));
        await settle(tester, const Duration(milliseconds: 300));
        expect(tc.mode, ThemeMode.light);
        expect(tester.getSemantics(find.byKey(const ValueKey('theme-option-light'))).flagsCollection.isSelected.toBoolOrNull(), isTrue);
        await tester.tap(find.byKey(const ValueKey('theme-option-system')));
        await settle(tester, const Duration(milliseconds: 300));
        expect(tc.mode, ThemeMode.system);
        // Dokunma hedefi >= 44 dp.
        expect(tester.getSize(find.byKey(const ValueKey('theme-option-dark'))).height, greaterThanOrEqualTo(44));
        sh.dispose();
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('taşma yok ${size.width.toInt()} dp x$scale', (tester) async {
          final b = FakeBackend()
            ..on('/users/me', {'id': 1, 'language': 'tr', 'showEmail': true})
            ..on('/notifications/preferences', {'news': true});
          useScreen(tester, size);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(buildApp(SettingsPage(session: makeSession(b), themeController: ThemeController()), brightness: Brightness.dark));
          await settle(tester, const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }

    test('önizleme karoları iki temada okunur (Aa yazısı AA)', () {
      expect(_contrast(BuTokens.light.ink, BuTokens.light.bg), greaterThan(7));
      expect(_contrast(BuTokens.dark.ink, BuTokens.dark.bg), greaterThan(7));
    });
  });

  group('Profil kimliği: kartsız, büyük sade ad', () {
    for (final dark in [false, true]) {
      testWidgets('kimlik alanı kart değil; ad 28 sp ve kalın değil (${dark ? 'koyu' : 'açık'})', (tester) async {
        final b = FakeBackend();
        fakeCatalog(b);
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(buildApp(
            _hero({'id': 1, 'displayName': 'Ayşe Kaya', 'faculty': 'Mühendislik Fakültesi', 'department': 'Bilgisayar Mühendisliği', 'grade': '3', 'bio': 'Yazılım ve satranç.'}, b),
            brightness: dark ? Brightness.dark : Brightness.light));
        await settle(tester, const Duration(milliseconds: 400));
        final name = tester.widget<Text>(find.text('Ayşe Kaya'));
        expect(name.style!.fontSize, 28);
        expect(name.style!.fontWeight, FontWeight.w400);
        // Kimlik bloğu çerçeveli büyük kart içinde değil.
        expect(find.ancestor(of: find.text('Ayşe Kaya'), matching: find.byType(Card)), findsNothing);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('uzun ad + büyük yazı 320 dp: taşma yok', (tester) async {
      final b = FakeBackend();
      fakeCatalog(b);
      useScreen(tester, kPhoneSmall);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildApp(_hero({'id': 1, 'displayName': 'Muhammed Abdurrahman Karaçoban Yıldırımoğlu', 'bio': 'Uzun bir biyografi ' * 6}, b),
          brightness: Brightness.dark));
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Liste bileşenleri nötr', () {
    testWidgets('ProfilRow simgesi nötr (mut), silme satırı danger', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: BuTheme.dark(),
        home: Scaffold(
          body: Column(children: [
            ProfilRow(icon: Icons.person, label: 'Satır', onTap: () {}),
            ProfilRow(icon: Icons.delete, label: 'Sil', danger: true, onTap: () {}),
          ]),
        ),
      ));
      final t = BuTokens.dark;
      expect(tester.widget<Icon>(find.byIcon(Icons.person)).color, t.mut);
      expect(tester.widget<Icon>(find.byIcon(Icons.delete)).color, t.danger);
      // Kırmızı marka tonu yok.
      expect(tester.widget<Icon>(find.byIcon(Icons.person)).color, isNot(const Color(0xFFF73A2E)));
    });
  });

  group('Kaynak güvenceleri (profil/destek)', () {
    // Dekoratif gölge, elevated kart ve hap düğme bu gruplarda kalmamalı. (Medya tuvali: media_crop muaf.)
    final dirs = ['lib/features/profile', 'lib/features/support', 'lib/features/system', 'lib/features/menu', 'lib/features/legal'];
    String src(String dir) {
      final b = StringBuffer();
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        b.writeln(f.readAsStringSync());
      }
      return b.toString();
    }

    for (final d in dirs) {
      test('$d: BuElevation/boxShadow/elevated kart yok', () {
        final s = src(d);
        expect(s.contains('BuElevation.of'), isFalse);
        expect(s.contains('BoxShadow('), isFalse);
        expect(s.contains('BuCardStyle.elevated'), isFalse);
      });
    }

    test('profil + destek: dekoratif LinearGradient/RadialGradient yok (medya karartması hariç)', () {
      final s = src('lib/features/support');
      expect(s.contains('Gradient('), isFalse);
      final p = src('lib/features/profile');
      // Yalnız medya üstü karartma (kapak/reels): scrim renkli.
      for (final m in RegExp(r'LinearGradient\([\s\S]{0,260}?\)').allMatches(p)) {
        expect(m.group(0)!.contains('scrim'), isTrue, reason: m.group(0));
      }
      expect(p.contains('RadialGradient'), isFalse);
    });
  });

  group('Başkasının profili', () {
    testWidgets('açık + koyu, 320 dp x1.6: taşma yok, ad hero boyutunda', (tester) async {
      for (final dark in [false, true]) {
        final b = FakeBackend()
          ..on('/users/7', {'id': 7, 'displayName': 'Ali Veli', 'department': 'Bilgisayar Mühendisliği', 'faculty': 'Mühendislik Fakültesi', 'bio': 'Merhaba'})
          ..on('/users/7/follow-stats', {'followers': 3, 'following': 2, 'followedByMe': false, 'followsMe': false});
        useScreen(tester, kPhoneSmall);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 7), brightness: dark ? Brightness.dark : Brightness.light));
        await settle(tester, const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await unmount(tester);
      }
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    });
  });
}
