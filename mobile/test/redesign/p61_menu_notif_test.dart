import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/features/menu/menu_models.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/menu/menu_parts.dart';
import 'package:bu_kampus/features/notifications/notif_row.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Tur 3 (minimal) MENU grubu: Yemek, Bildirimler, Bildirim tercihleri + Ayrintili tercihler.
/// Kontroller: sade icerik (suslu ogeler yok), tek vurgu, 320 dp x1.3 / 3 dil / acik+koyu tasma matrisi.

String _d(int offset) {
  final n = DateTime.now().add(Duration(days: offset));
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> _month({bool kcal = true}) => [
      for (var o = -2; o <= 6; o++)
        {
          'date': _d(o),
          'items': ['Mercimek çorbası', 'Orman kebabı ve çok uzun bir yemek adı burada', 'Pirinç pilavı', 'Cacık'],
          'dishes': [
            {'name': 'Mercimek çorbası', 'kcal': kcal ? 160 : null},
            {'name': 'Orman kebabı ve çok uzun bir yemek adı burada', 'kcal': kcal ? 420 : null},
            {'name': 'Pirinç pilavı', 'kcal': kcal ? 280 : null},
            {'name': 'Cacık', 'kcal': null},
          ],
          'totalKcal': kcal ? 860 : null,
          'kcalComplete': false,
        },
    ];

Map<String, dynamic> _notifs() {
  final now = DateTime.now();
  return {
    'unreadCount': 2,
    'nextCursor': null,
    'items': [
      {'id': 1, 'type': 'ANNOUNCEMENT', 'title': 'Ders ekleme-bırakma tarihleri duyuruldu ve çok uzun bir başlık', 'body': 'Ayrıntılar için akademik takvime bakın.', 'read': false, 'createdAt': now.toIso8601String()},
      {'id': 2, 'type': 'EVENT', 'title': 'Kariyer günleri yarın başlıyor', 'read': false, 'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String()},
      {'id': 3, 'type': 'POST_LIKE', 'title': 'Gönderini beğendi', 'read': true, 'createdAt': now.subtract(const Duration(days: 1)).toIso8601String()},
      {'id': 4, 'type': 'MESSAGE', 'title': 'Mehmet Kaya mesaj gönderdi', 'read': true, 'createdAt': '2020-01-01T10:00:00'},
    ],
  };
}

const _prefs = {
  'news': true,
  'announcements': true,
  'events': true,
  'communities': false,
  'messages': true,
  'polls': true,
  'quietHours': {'enabled': true, 'start': '23:00', 'end': '07:00', 'timezone': 'Europe/Istanbul'},
  'subtypes': {
    'MESSAGE_DIRECT': true,
    'MESSAGE_GROUP': true,
    'EVENT_REMINDER': true,
    'EVENT_UPDATE': true,
    'EVENT_ADMISSION': true,
    'COMMUNITY_POST': true,
    'COMMUNITY_ROLE': true,
    'COMMUNITY_JOIN': true,
  },
};

Widget _app(Widget home, {String lang = 'tr', bool dark = false, double scale = 1}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.forLocale(Brightness.light, lang),
    darkTheme: BuTheme.forLocale(Brightness.dark, lang),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(lang),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
}

Future<void> _show(WidgetTester tester, Widget home, {String lang = 'tr', bool dark = false, double scale = 1, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
  addTearDown(() => LocaleController.current = null);
  await tester.pumpWidget(_app(home, lang: lang, dark: dark, scale: scale));
  await settle(tester, const Duration(milliseconds: 1200));
}

void main() {
  setUpAll(loadTestFonts);

  group('Yemek (sade)', () {
    const day = MenuDay(
      items: ['Mercimek', 'Pilav', 'Cacik'],
      dishes: [MenuDish('Mercimek', 150), MenuDish('Pilav', 300), MenuDish('Cacik')],
      totalKcal: 450,
      kcalComplete: false,
    );

    testWidgets('fotografsiz kart: suslu yer tutucu, saat simgesi ve kalorisiz tire yok', (tester) async {
      await _show(tester, const Scaffold(body: SingleChildScrollView(child: MenuMealCard(day: day, photo: null, time: '11:30 – 14:00'))));
      expect(find.text('Öğle yemeği'), findsOneWidget);
      expect(find.text('11:30 – 14:00'), findsOneWidget);
      expect(find.byIcon(LucideIcons.utensils), findsNothing);
      expect(find.byIcon(LucideIcons.clock), findsNothing);
      expect(find.byIcon(LucideIcons.info), findsNothing);
      expect(find.byIcon(LucideIcons.flame), findsNothing);
      expect(find.text('-'), findsNothing);
      expect(find.text('Cacik'), findsOneWidget);
      expect(find.text('150 kcal'), findsOneWidget);
      expect(find.text('En az 450 kcal'), findsOneWidget);
      // Kalorisiz yemekte "kcal" yalnız 2 satirda + toplamda gorunur.
      expect(find.textContaining('kcal'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('toplam tamamsa koyu serit yok: Toplam satiri sakin metin', (tester) async {
      const full = MenuDay(items: ['Pilav'], dishes: [MenuDish('Pilav', 300)], totalKcal: 300, kcalComplete: true);
      await _show(tester, const Scaffold(body: SingleChildScrollView(child: MenuMealCard(day: full, photo: null, time: '11:30'))));
      expect(find.text('Toplam'), findsOneWidget);
      expect(find.text('300 kcal'), findsNWidgets(2));
      // Mürekkep (ink) dolgulu kutu yok.
      final ink = BuTokens.light.ink;
      final filled = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.color == ink;
      });
      expect(filled, isEmpty);
    });

    testWidgets('gun etiketi simgesiz, liste yoksa kart/hap yok ve tek cumle', (tester) async {
      final b = FakeBackend()..on('/menu', <Object>[]);
      await _show(tester, MenuPage(session: makeSession(b)));
      expect(find.text('Yemek listesi yok.'), findsOneWidget);
      expect(find.byType(BuButton), findsNothing); // bakimda degilse eylem yok
      expect(find.byIcon(LucideIcons.calendar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bakimdaysa tek cumle + tek eylem', (tester) async {
      final b = FakeBackend()
        ..on('/menu', <Object>[])
        ..on('/status', {'MENU': {'maintenance': true}});
      await _show(tester, MenuPage(session: makeSession(b)));
      expect(find.text('Sistem bakımda.'), findsWidgets);
      expect(find.byType(BuButton), findsOneWidget);
    });
  });

  group('Bildirimler (sade)', () {
    testWidgets('satir: tur etiketi ekranda yok, zaman var, tek nokta, tek simge tonu', (tester) async {
      final b = FakeBackend()..on('/notifications', _notifs());
      await _show(tester, NotificationsPage(session: makeSession(b)));
      expect(find.text('Duyuru'), findsNothing); // tur etiketi cizilmez (simge anlatir)
      expect(find.text('Kariyer günleri yarın başlıyor'), findsOneWidget);
      expect(find.byKey(const ValueKey('notif-unread-dot')), findsNWidgets(4)); // agacta kalir, okunanlar olceksiz
      // Simge kutularinin hepsi ayni (bilgi) zeminde.
      final infoSoft = BuTokens.light.infoSoft;
      final tiles = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.color == infoSoft;
      });
      expect(tiles.length, 4);
      expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
      expect(find.byIcon(LucideIcons.pointer), findsNothing);
      expect(find.byIcon(LucideIcons.circleCheck), findsNothing);
      // "N yeni" grup sayaci kalkti.
      expect(find.textContaining(' yeni'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('anlamsal etiket: okunmamis + tur + zaman', (tester) async {
      final b = FakeBackend()..on('/notifications', _notifs());
      await _show(tester, NotificationsPage(session: makeSession(b)));
      final sem = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Duyuru')), findsWidgets);
      sem.dispose();
    });

    testWidgets('filtre: Tumu sayacsiz, Okunmamis sayisi yalniz > 0', (tester) async {
      final b = FakeBackend()..on('/notifications', _notifs());
      await _show(tester, NotificationsPage(session: makeSession(b)));
      final all = find.descendant(of: find.byKey(const ValueKey('notif-seg-all')), matching: find.byType(Text));
      final unread = find.descendant(of: find.byKey(const ValueKey('notif-seg-unread')), matching: find.byType(Text));
      expect(all, findsOneWidget);
      expect(unread, findsNWidgets(2));
      expect(tester.getSize(find.byKey(const ValueKey('notif-seg-all'))).height, greaterThanOrEqualTo(48));
    });

    testWidgets('hata: tek cumle + tek eylem', (tester) async {
      final b = FakeBackend()..fail('/notifications', status: 500);
      await _show(tester, NotificationsPage(session: makeSession(b)));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      expect(find.byType(BuButton), findsOneWidget);
      expect(find.byIcon(LucideIcons.wifiOff), findsNothing);
    });

    testWidgets('bos durum: kart icinde kart yok', (tester) async {
      final b = FakeBackend()..on('/notifications', {'unreadCount': 0, 'nextCursor': null, 'items': <Object>[]});
      await _show(tester, NotificationsPage(session: makeSession(b)));
      expect(find.text('Bildirim yok'), findsOneWidget);
      expect(find.byType(BuCard), findsNothing);
    });

    testWidgets('NotifRow: dokunma alani >= 48 ve tek satir basligin zamani', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(Scaffold(
        body: NotifRow(icon: LucideIcons.bell, title: 'Baslik', typeLabel: 'Duyuru', time: '5 dk', unread: true, onTap: () {}),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(find.byType(NotifRow)).height, greaterThanOrEqualTo(48));
      expect(find.text('5 dk'), findsOneWidget);
    });
  });

  group('Bildirim tercihleri (sade)', () {
    FakeBackend be() => FakeBackend()..on('/notifications/preferences', _prefs);

    testWidgets('satirlarda simge karosu yok; anahtarlar tek sutunda hizali', (tester) async {
      await _show(tester, NotificationPrefsPage(session: makeSession(be())), size: const Size(390, 1400));
      expect(find.byIcon(LucideIcons.newspaper), findsNothing);
      expect(find.byIcon(LucideIcons.megaphone), findsNothing);
      expect(find.byIcon(LucideIcons.moon), findsNothing);
      expect(find.byIcon(LucideIcons.alarmClock), findsNothing);
      final switches = [for (final e in find.byType(Switch).evaluate()) tester.getRect(find.byWidget(e.widget))];
      expect(switches.length, greaterThan(5));
      final right = switches.first.right;
      for (final r in switches) {
        expect((r.right - right).abs(), lessThan(.5), reason: 'tum anahtarlar ayni sag kenarda');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('ayrintili tercihler: baslik "Ayrıntılı tercihler", bilgi kutusu ve rozet yok, anahtar sirasi korunur', (tester) async {
      await _show(tester, NotificationPrefsPage(session: makeSession(be())), size: const Size(390, 1400));
      await tester.tap(find.text('Ayrıntılı tercihler'));
      await settle(tester);
      expect(find.text('Ayrıntılı tercihler'), findsOneWidget); // yalniz basliktaki (onceki sayfa asagida kalir)
      expect(find.byIcon(LucideIcons.slidersHorizontal), findsNothing);
      expect(find.text('Devre dışı'), findsNothing);
      expect(find.text('Kişisel mesajlar'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3 + 8)); // 3 ana anahtar + 8 alt anahtar
      expect(tester.takeException(), isNull);
    });
  });

  // Tasma matrisi: 320 dp, yazi x1.3, 3 dil, acik + koyu.
  for (final lang in ['tr', 'en', 'ar']) {
    for (final dark in [false, true]) {
      final tag = '$lang ${dark ? 'koyu' : 'acik'}';
      testWidgets('tasma yok: Yemek dolu (320 x1.3, $tag)', (tester) async {
        final b = FakeBackend()..on('/menu', _month());
        await _show(tester, MenuPage(session: makeSession(b)), lang: lang, dark: dark, scale: 1.3, size: const Size(320, 700));
        expect(find.byType(MenuMealCard), findsOneWidget);
        expect(tester.takeException(), isNull);
        final n = DateTime.now().add(const Duration(days: 1));
        await tester.tap(find.byKey(ValueKey('yemek_day_${n.year}-${n.month}-${n.day}')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });

      testWidgets('tasma yok: Yemek kalorisiz + bos (320 x1.3, $tag)', (tester) async {
        final b = FakeBackend()..on('/menu', _month(kcal: false));
        await _show(tester, MenuPage(session: makeSession(b)), lang: lang, dark: dark, scale: 1.3, size: const Size(320, 700));
        expect(tester.takeException(), isNull);
        final e = FakeBackend()..on('/menu', <Object>[]);
        await _show(tester, MenuPage(session: makeSession(e)), lang: lang, dark: dark, scale: 1.3, size: const Size(320, 700));
        expect(tester.takeException(), isNull);
      });

      testWidgets('tasma yok: Bildirimler dolu/bos/hata (320 x1.3, $tag)', (tester) async {
        for (final be in [
          FakeBackend()..on('/notifications', _notifs()),
          FakeBackend()..on('/notifications', {'unreadCount': 0, 'nextCursor': null, 'items': <Object>[]}),
          FakeBackend()..fail('/notifications', status: 500),
        ]) {
          await _show(tester, NotificationsPage(session: makeSession(be)), lang: lang, dark: dark, scale: 1.3, size: const Size(320, 700));
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('tasma yok: Bildirim tercihleri + Ayrintili (320 x1.3, $tag)', (tester) async {
        final be = FakeBackend()..on('/notifications/preferences', _prefs);
        await _show(tester, NotificationPrefsPage(session: makeSession(be)), lang: lang, dark: dark, scale: 1.3, size: const Size(320, 700));
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await settle(tester, const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        final l = lookupAppLocalizations(Locale(lang));
        await tester.drag(find.byType(ListView).first, const Offset(0, 400));
        await settle(tester, const Duration(milliseconds: 600));
        await tester.ensureVisible(find.text(l.profil1Detailed));
        await tester.tap(find.text(l.profil1Detailed));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
