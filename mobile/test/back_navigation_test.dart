import 'dart:async';

import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Android geri tuşu: sistemin popRoute çağrısını taklit eder.
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: $e');
}

void main() {
  setUpAll(loadTestFonts);

  group('kabuk (AppShell) geri davranisi', () {
    var exits = 0;

    setUp(() {
      exits = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        },
      );
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> pumpShell(WidgetTester tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(AppShell(session: makeSession(b), themeController: ThemeController())));
      await settle(tester);
    }

    int navIndex(WidgetTester tester) => tester.widget<FloatingNav>(find.byType(FloatingNav)).index;

    testWidgets('sekmeden geri -> Ana Sayfa, cikis yok', (tester) async {
      final h = tester.ensureSemantics();
      await pumpShell(tester);
      for (final label in ['Keşfet', 'Sohbet', 'Kulüpler', 'Profil']) {
        await tester.tap(find.bySemanticsLabel(RegExp(label)).first);
        await settle(tester, const Duration(milliseconds: 400));
        expect(navIndex(tester), isNot(0));
        await back(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(navIndex(tester), 0, reason: '$label -> geri');
        expect(exits, 0);
        expect(find.text('Çıkmak için tekrar geri basın'), findsNothing);
      }
      noErr(tester);
      h.dispose();
      await unmount(tester);
    });

    testWidgets('Ana Sayfa: ilk basista toast, 2 sn icinde ikincide cikis', (tester) async {
      await pumpShell(tester);
      await back(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Çıkmak için tekrar geri basın'), findsOneWidget);
      expect(exits, 0);
      await tester.pump(const Duration(milliseconds: 600));
      await back(tester);
      await tester.pump();
      expect(exits, 1);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('2 sn gecerse ikinci basis yeniden toast gosterir', (tester) async {
      await tester.runAsync(() async {}); // gercek zaman referansi
      await pumpShell(tester);
      await back(tester);
      expect(exits, 0);
      // DateTime.now gercek saat: bekleyerek 2 sn sinirini asariz.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2100)));
      await tester.pump(const Duration(seconds: 3));
      await back(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(exits, 0);
      expect(find.text('Çıkmak için tekrar geri basın'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('ic sayfa aciksa once o kapanir; kabuk yerinde kalir', (tester) async {
      await pumpShell(tester);
      final ctx = tester.element(find.byType(FloatingNav));
      unawaited(Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('ic sayfa')))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ic sayfa'), findsOneWidget);
      await back(tester);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('ic sayfa'), findsNothing);
      expect(find.byType(FloatingNav), findsOneWidget);
      expect(exits, 0);
      expect(find.text('Çıkmak için tekrar geri basın'), findsNothing);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('arka arkaya hizli 10 geri: istisna yok, en fazla bir cikis', (tester) async {
      await pumpShell(tester);
      for (var i = 0; i < 10; i++) {
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 20));
      }
      noErr(tester);
      expect(find.byType(FloatingNav), findsOneWidget);
      await unmount(tester);
    });
  });

  group('diyalog / alt sayfa', () {
    Widget launcher(Future<void> Function(BuildContext) open) => Builder(
          builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => open(c), child: const Text('ac')))),
        );

    testWidgets('diyalog acikken geri yalniz diyalogu kapatir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(launcher((c) => showDialog<void>(
          context: c, builder: (_) => const AlertDialog(content: Text('diyalog'))))));
      await tester.tap(find.text('ac'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('diyalog'), findsOneWidget);
      await back(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('diyalog'), findsNothing);
      expect(find.text('ac'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('bottom sheet acikken geri yalniz sheet i kapatir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(launcher((c) => showModalBottomSheet<void>(
          context: c, builder: (_) => const SizedBox(height: 200, child: Text('sheet'))))));
      await tester.tap(find.text('ac'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('sheet'), findsOneWidget);
      await back(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('sheet'), findsNothing);
      expect(find.text('ac'), findsOneWidget);
      noErr(tester);
    });
  });

  group('ac-hemen-geri (istek bitmeden)', () {
    final pages = <String, Widget Function(FakeBackend)>{
      'Bildirimler': (b) => NotificationsPage(session: makeSession(b)),
      'Arama': (b) => SearchPage(session: makeSession(b)),
      'Haber detay': (b) => NewsDetailPage(session: makeSession(b), item: newsItem(1)),
      'Etkinlik detay': (b) => EventDetailPage(session: makeSession(b), eventId: 1),
      'Kulup detay': (b) => ClubDetailPage(session: makeSession(b), communityId: 1),
      'Sohbet detay': (b) => ChatDetailPage(
            session: makeSession(b),
            connectRealtime: false,
            conversation: const {
              'id': 1,
              'type': 'DIRECT',
              'title': 'Ali Veli',
              'peer': {'id': 11, 'displayName': 'Ali Veli'},
            },
          ),
      'Destek': (b) => SupportPage(session: makeSession(b)),
      'Yemek': (b) => MenuPage(session: makeSession(b)),
      'Engellenenler': (b) => BlockedUsersPage(session: makeSession(b)),
      'Ayarlar': (b) => SettingsPage(session: makeSession(b), themeController: ThemeController()),
    };

    for (final e in pages.entries) {
      testWidgets('${e.key}: ac, istek surerken geri, kalan istekler bitince istisna yok', (tester) async {
        useScreen(tester, kPhoneMedium);
        final b = FakeBackend(delay: const Duration(milliseconds: 300));
        await tester.pumpWidget(buildApp(Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => e.value(b))),
                child: const Text('ac'),
              ),
            ),
          ),
        )));
        await tester.tap(find.text('ac'));
        await tester.pump(const Duration(milliseconds: 60)); // gecis suruyor, istekler bitmedi
        await back(tester);
        await tester.pump(const Duration(milliseconds: 400));
        // Istekler sayfa kalktiktan sonra tamamlanir.
        await settle(tester, const Duration(seconds: 2));
        expect(find.text('ac'), findsOneWidget);
        noErr(tester);
      });
    }

    testWidgets('sayfa tam yuklenmisken de 10 hizli ac-geri dongusu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 100));
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(c).push(
                  MaterialPageRoute<void>(builder: (_) => NotificationsPage(session: makeSession(b)))),
              child: const Text('ac'),
            ),
          ),
        ),
      )));
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('ac'));
        await tester.pump(const Duration(milliseconds: 30));
        await back(tester);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('ac'), findsOneWidget);
      noErr(tester);
    });
  });
}
