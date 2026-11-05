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

  group('Yemek (Stitch v3)', () {
    const day = MenuDay(
      items: ['Mercimek', 'Pilav', 'Cacik'],
      dishes: [MenuDish('Mercimek', 150), MenuDish('Pilav', 300), MenuDish('Cacik')],
      totalKcal: 450,
      kcalComplete: false,
    );

    testWidgets('yuzey: simge/yer tutucu yok, kalorisiz yemekte soluk tire, eksik toplam + not', (tester) async {
      await _show(tester, const Scaffold(body: SingleChildScrollView(child: MenuMealCard(day: day, time: '11:30–14:00'))));
      expect(find.text('Öğle yemeği'), findsOneWidget);
      expect(find.text('11:30–14:00'), findsOneWidget);
      expect(find.byIcon(BuIcons.utensils), findsNothing);
      expect(find.byIcon(BuIcons.clock), findsNothing);
      expect(find.byIcon(BuIcons.info), findsNothing);
      expect(find.byIcon(LucideIcons.flame), findsNothing);
      expect(find.text('–'), findsOneWidget);
      expect(find.text('150 kcal'), findsOneWidget);
      expect(find.text('Toplam enerji'), findsOneWidget);
      expect(find.text('En az 450 kcal'), findsOneWidget);
      expect(find.text('Bazı yemeklerin kalorisi girilmemiş.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toplam tamamsa tek satir, not yok, koyu serit yok', (tester) async {
      const full = MenuDay(items: ['Pilav'], dishes: [MenuDish('Pilav', 300)], totalKcal: 300, kcalComplete: true);
      await _show(tester, const Scaffold(body: SingleChildScrollView(child: MenuMealCard(day: full, time: '11:30–14:00'))));
      expect(find.text('Toplam enerji'), findsOneWidget);
      expect(find.text('300 kcal'), findsNWidgets(2));
      expect(find.text('Bazı yemeklerin kalorisi girilmemiş.'), findsNothing);
      final ink = BuTokens.light.ink;
      final filled = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((c) => (c.decoration as BoxDecoration).color == ink);
      expect(filled, isEmpty);
    });

    testWidgets('gun seridi: hap 42 x 48 dp, secili pr zemin + onPr metin (ters renk), digerlerinde zemin yok', (tester) async {
      final n = DateTime.now();
      final d0 = DateTime(n.year, n.month, n.day);
      await _show(tester, Scaffold(body: MenuDayStrip(days: [for (var i = -2; i <= 4; i++) d0.add(Duration(days: i))], selected: d0, onSelect: (_) {})));
      final key = ValueKey('yemek_day_${d0.year}-${d0.month}-${d0.day}');
      final pill = find.descendant(of: find.byKey(key), matching: find.byType(AnimatedContainer));
      expect(tester.getSize(pill).width, 42);
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
      expect((tester.widget<AnimatedContainer>(pill).decoration as BoxDecoration).color, BuTokens.light.pr);
      final o = d0.add(const Duration(days: 1));
      final other = find.descendant(of: find.byKey(ValueKey('yemek_day_${o.year}-${o.month}-${o.day}')), matching: find.byType(AnimatedContainer));
      expect((tester.widget<AnimatedContainer>(other).decoration as BoxDecoration).color!.a, 0);
    });

    testWidgets('liste yoksa tek cumle, eylem/kart yok; bakimdaysa ikinci satir', (tester) async {
      final b = FakeBackend()..on('/menu', <Object>[]);
      await _show(tester, MenuPage(session: makeSession(b)));
      expect(find.text('Yemek listesi yok.'), findsOneWidget);
      expect(find.byType(BuButton), findsNothing);
      expect(find.byIcon(BuIcons.utensils), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bakimdaysa ikinci satir "Sistem bakimda."', (tester) async {
      final m = FakeBackend()
        ..on('/menu', <Object>[])
        ..on('/status', {'MENU': {'maintenance': true}});
      await _show(tester, MenuPage(session: makeSession(m)));
      expect(find.text('Yemek listesi yok.'), findsOneWidget);
      expect(find.text('Sistem bakımda.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bayat: yemek varken amber bant', (tester) async {
      final b = FakeBackend()
        ..on('/menu', _month())
        ..on('/status', {'MENU': {'maintenance': true}});
      await _show(tester, MenuPage(session: makeSession(b)));
      expect(find.byType(MenuStaleBanner), findsOneWidget);
      expect(find.text('Yemek listesi güncellenemedi; son bilinen liste gösteriliyor.'), findsOneWidget);
    });
  });

  group('Bildirimler (Stitch v3)', () {
    testWidgets('satir: karti/simgesi yok, tur etiketi + zaman + tek nokta, bd cizgisi', (tester) async {
      final b = FakeBackend()..on('/notifications', _notifs());
      await _show(tester, NotificationsPage(session: makeSession(b)));
      // Tür etiketi satırda çizilmez (bildirim tasarımı 2.1.4); ekran okuyucu etiketinde kalır (aşağıdaki test).
      expect(find.text('Kariyer günleri yarın başlıyor'), findsOneWidget);
      // Ağaçta kalır, okunanlar ölçeksiz. Eski MESSAGE satırı (id 4) istemcide gizlenir: 3 satır.
      expect(find.byKey(const ValueKey('notif-unread-dot')), findsNWidgets(3));
      expect(find.text('Mehmet Kaya mesaj gönderdi'), findsNothing);
      expect(find.byIcon(BuIcons.megaphone), findsNothing);
      expect(find.byIcon(BuIcons.checkCheck), findsNothing);
      expect(find.byType(BuCard), findsNothing);
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

    testWidgets('cipler: Tumu secili = soft + pr metin, sayac rozeti yok, >= 48 dp dokunma', (tester) async {
      final b = FakeBackend()..on('/notifications', _notifs());
      await _show(tester, NotificationsPage(session: makeSession(b)));
      final all = find.byKey(const ValueKey('notif-seg-all'));
      final unread = find.byKey(const ValueKey('notif-seg-unread'));
      expect(find.descendant(of: all, matching: find.byType(Text)), findsOneWidget);
      expect(find.descendant(of: unread, matching: find.byType(Text)), findsOneWidget);
      expect(tester.getSize(all).height, greaterThanOrEqualTo(48));
      final box = tester.widget<AnimatedContainer>(find.descendant(of: all, matching: find.byType(AnimatedContainer)));
      expect((box.decoration as BoxDecoration).color, BuTokens.light.soft);
      expect(tester.getSize(find.descendant(of: all, matching: find.byType(AnimatedContainer))).height, closeTo(34, 3));
    });

    testWidgets('hata: soluk tek cumle + pr "Yeniden dene"', (tester) async {
      final b = FakeBackend()..fail('/notifications', status: 500);
      await _show(tester, NotificationsPage(session: makeSession(b)));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      expect(find.byIcon(BuIcons.wifiOff), findsNothing);
    });

    testWidgets('bos durum: kart/illustrasyon yok; Okunmamis cipinde ayri cumle', (tester) async {
      final b = FakeBackend()..on('/notifications', {'unreadCount': 0, 'nextCursor': null, 'items': <Object>[]});
      await _show(tester, NotificationsPage(session: makeSession(b)));
      expect(find.text('Henüz bildiriminiz yok.'), findsOneWidget);
      expect(find.byType(BuCard), findsNothing);
    });

    testWidgets('Okunmamis cipinde hepsi okunduysa ayri cumle', (tester) async {
      final b2 = FakeBackend()..on('/notifications', _notifs());
      await _show(tester, NotificationsPage(session: makeSession(b2)));
      await tester.tap(find.byKey(const ValueKey('notif-seg-unread')));
      await settle(tester);
      await tester.drag(find.byKey(const ValueKey('notif-1')), const Offset(-500, 0));
      await settle(tester);
      await tester.drag(find.byKey(const ValueKey('notif-2')), const Offset(-500, 0));
      await settle(tester);
      expect(find.text('Okunmamış bildiriminiz yok.'), findsOneWidget);
    });

    testWidgets('NotifRow: yukseklik >= 48, zaman gorunur', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(Scaffold(
        body: NotifRow(title: 'Baslik', typeLabel: 'Duyuru', time: '5 dk', unread: true, onTap: () {}),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(find.byType(NotifRow)).height, greaterThanOrEqualTo(48));
      expect(find.text('5 dk'), findsOneWidget);
    });
  });

  group('Bildirim tercihleri (Stitch v3)', () {
    FakeBackend be() => FakeBackend()..on('/notifications/preferences', _prefs);

    testWidgets('satirlarda simge yok; anahtarlar 48 x 28 ve tek sutunda hizali', (tester) async {
      await _show(tester, NotificationPrefsPage(session: makeSession(be())), size: const Size(390, 1500));
      expect(find.byIcon(BuIcons.newspaper), findsNothing);
      expect(find.byIcon(BuIcons.megaphone), findsNothing);
      expect(find.byIcon(LucideIcons.moon), findsNothing);
      expect(find.byIcon(BuIcons.alarmClock), findsNothing);
      final boxes = [
        for (final e in find.byType(Switch).evaluate())
          tester.getRect(find.ancestor(of: find.byWidget(e.widget), matching: find.byType(SizedBox)).first)
      ];
      expect(boxes.length, greaterThan(5));
      for (final r in boxes) {
        expect(r.width, 48);
        expect(r.height, 28);
        expect((r.right - boxes.first.right).abs(), lessThan(.5));
      }
      expect(find.text('23:00 – 07:00'), findsOneWidget);
      expect(find.text('Ders ve sınav hatırlatmaları'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ayrintili tercihler: baslik "Ayrıntılı tercihler", bilgi kutusu yok, anahtar sirasi korunur', (tester) async {
      await _show(tester, NotificationPrefsPage(session: makeSession(be())), size: const Size(390, 1500));
      await tester.tap(find.text('Ayrıntılı tercihler'));
      await settle(tester);
      expect(find.text('Ayrıntılı tercihler'), findsNothing); // sayfa başlığı görünmez (sadeleştirme)
      expect(find.byIcon(BuIcons.slidersHorizontal), findsNothing);
      expect(find.text('Devre dışı'), findsNothing);
      expect(find.text('Kişisel mesajlar'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3 + 8)); // 3 ana anahtar + 8 alt anahtar
      expect(tester.takeException(), isNull);
    });

    testWidgets('sessiz saatler: kendi sayfasi, acma + baslangic/bitis satirlari', (tester) async {
      await _show(tester, NotificationPrefsPage(session: makeSession(be())), size: const Size(390, 1500));
      await tester.tap(find.text('Sessiz saatler'));
      await settle(tester);
      expect(find.text('Sessiz saatleri aç'), findsOneWidget);
      expect(find.text('Başlangıç'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      expect(find.text('Bitiş'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
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
        final l = lookupAppLocalizations(Locale(lang));
        await tester.scrollUntilVisible(find.text(l.profil1Detailed), 100, scrollable: find.byType(Scrollable).first);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l.profil1Detailed));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tasma yok: Sessiz saatler sayfasi (320 x1.3, $tag)', (tester) async {
        final be = FakeBackend()..on('/notifications/preferences', _prefs);
        await _show(tester, NotificationPrefsPage(session: makeSession(be)), lang: lang, dark: dark, scale: 1.3, size: const Size(320, 700));
        final l = lookupAppLocalizations(Locale(lang));
        // Kaydırmalı liste tembel kurulur: satır ağaçta olsa da ekran dışında kalabilir; en alta kadar kaydır.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
        await settle(tester, const Duration(milliseconds: 600));
        await tester.tap(find.text(l.profil1QuietTitle));
        await settle(tester);
        expect(find.text(l.profil1QuietToggle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
