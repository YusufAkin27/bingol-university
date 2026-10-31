import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/menu/menu_models.dart';
import 'package:bu_kampus/features/menu/menu_parts.dart';
import 'package:bu_kampus/features/news/icerik_parts.dart' show newsHero;
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/notifications/notif_row.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// P2-DB (tur 2): Ana Sayfa haber seridi, hizli erisim girisi, haber Hero'su, haber detay cubugu, yemek gun
/// seridi + kalori sayaci, bildirim okundu gecisi. Her animasyon icin: baslangic/bitis, animasyonlari azalt,
/// tekrar oynamama.
void main() {
  setUpAll(loadTestFonts);

  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  group('haber seridi', () {
    Widget strip() => Scaffold(
          body: Center(
            child: HomeNewsStrip(
              height: 120,
              itemCount: 4,
              itemBuilder: (_, i) => SizedBox(key: ValueKey('card$i'), width: 280, child: const ColoredBox(color: Colors.grey)),
            ),
          ),
        );

    List<double> edgeOpacities(WidgetTester tester) => [
          for (final o in tester.widgetList<Opacity>(find.descendant(of: find.byType(HomeNewsStrip), matching: find.byType(Opacity)))) o.opacity,
        ];

    testWidgets('kenar solmasi: basta yalniz bitis kenari, kaydirinca baslangic da gorunur', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(strip()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(edgeOpacities(tester), [0.0, 1.0]);
      await tester.drag(find.byType(HomeNewsStrip), const Offset(-200, 0));
      await tester.pump(const Duration(milliseconds: 50));
      final o = edgeOpacities(tester);
      expect(o[0], 1.0);
      expect(o[1], 1.0);
      // En sona kadar kaydir: bitis kenari kaybolur.
      await tester.fling(find.byType(HomeNewsStrip), const Offset(-2000, 0), 3000);
      await tester.pumpAndSettle();
      expect(edgeOpacities(tester)[1], 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('baslangic kenarindan cikan kart hafifce kuculur, dokunma alani bozulmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(strip()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byKey(const ValueKey('card0'))).width, 280);
      await tester.drag(find.byType(HomeNewsStrip), const Offset(-146, 0)); // yarim kart adimi (292 / 2)
      await tester.pump();
      final w = tester.getRect(find.byKey(const ValueKey('card0'))).width;
      expect(w, lessThan(280));
      expect(w, greaterThan(280 * .93)); // en cok %6
      // Ikinci kart henuz tam boyda.
      expect(tester.getRect(find.byKey(const ValueKey('card1'))).width, 280);
    });

    testWidgets('animasyonlari azalt: kart kuculmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      reduceMotion(tester);
      await tester.pumpWidget(buildApp(strip()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.drag(find.byType(HomeNewsStrip), const Offset(-146, 0));
      await tester.pump();
      expect(tester.getRect(find.byKey(const ValueKey('card0'))).width, 280);
    });
  });

  group('hizli erisim girisi', () {
    Widget grid() => Scaffold(
          body: HomeQuickGrid(
            labels: const ['Haberler', 'Yemek', 'Etkinlikler', 'Anketler', 'Program'],
            tiles: [
              for (final s in ['Haberler', 'Yemek', 'Etkinlikler', 'Anketler', 'Program'])
                HomeQuickTile(icon: LucideIcons.newspaper, label: s, tone: HomeTone.blue, onTap: () {}),
            ],
          ),
        );

    double opacityOf(WidgetTester tester, int i) {
      final f = find.ancestor(of: find.byType(HomeQuickTile).at(i), matching: find.byType(FadeTransition)).first;
      return tester.widget<FadeTransition>(f).opacity.value;
    }

    testWidgets('karolar sirayla belirir, sonunda hepsi tam gorunur ve yenilemede tekrar oynamaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(grid()));
      await tester.pump();
      expect(opacityOf(tester, 4), 0);
      await tester.pump(const Duration(milliseconds: 220));
      // Ilk karo ilerlemis, son karo henuz baslamamis ya da geride.
      expect(opacityOf(tester, 0), greaterThan(opacityOf(tester, 4)));
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 5; i++) {
        expect(opacityOf(tester, i), 1);
      }
      // Ayni durumla yeniden kurulum (yenileme) animasyonu bastan oynatmaz.
      await tester.pumpWidget(buildApp(grid()));
      await tester.pump();
      expect(opacityOf(tester, 4), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('animasyonlari azalt: aninda gorunur', (tester) async {
      useScreen(tester, const Size(390, 844));
      reduceMotion(tester);
      await tester.pumpWidget(buildApp(grid()));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        expect(opacityOf(tester, i), 1);
      }
    });

    testWidgets('bes karo tek vurgu tonunda (ayni ikon rengi), dokunma hedefi >= 48', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(grid()));
      await tester.pump(const Duration(seconds: 1));
      final colors = {for (final i in tester.widgetList<Icon>(find.byType(Icon))) i.color};
      expect(colors.length, 1);
      for (var k = 0; k < 5; k++) {
        expect(tester.getSize(find.byType(HomeQuickTile).at(k)).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('haber Hero', () {
    Widget app() => MaterialApp(
          theme: BuTheme.light(),
          home: Builder(
            builder: (c) => Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    c,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: SizedBox(width: 400, height: 300, child: newsHero(id: 5, child: const ColoredBox(color: Colors.blue, child: SizedBox.expand()))),
                      ),
                    ),
                  ),
                  child: SizedBox(width: 100, height: 80, child: newsHero(id: 5, radius: 20, child: const ColoredBox(color: Colors.blue, child: SizedBox.expand()))),
                ),
              ),
            ),
          ),
        );

    double maxRadius(WidgetTester tester) {
      var m = 0.0;
      for (final c in tester.widgetList<ClipRRect>(find.byType(ClipRRect))) {
        final r = c.borderRadius.resolve(TextDirection.ltr).topLeft.x;
        if (r > m) m = r;
      }
      return m;
    }

    testWidgets('ucusta kose yaricapi kartta 20 -> kapakta 0, donuste 0 -> 20', (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final early = maxRadius(tester);
      await tester.pump(const Duration(milliseconds: 160));
      final late = maxRadius(tester);
      expect(early, greaterThan(late)); // gidis: yaricap azalir
      await tester.pumpAndSettle();
      expect(maxRadius(tester), 0);
      // Geri
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final p1 = maxRadius(tester);
      await tester.pump(const Duration(milliseconds: 160));
      final p2 = maxRadius(tester);
      expect(p2, greaterThan(p1)); // donus: yaricap artar
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('haber detay cubugu', () {
    testWidgets('kapaksiz haber: kaydirinca ince alt cizgi ve baslik belirir', (tester) async {
      useScreen(tester, const Size(390, 700));
      final b = FakeBackend()
        ..on('/news/1', {
          'id': 1,
          'content': List.generate(40, (i) => 'Paragraf $i. Uzun bir haber metni satiri burada devam ediyor ve devam ediyor.').join('\n'),
          'url': 'https://www.bingol.edu.tr/x',
        })
        ..on('/bookmarks/news/ids', {'ids': <int>[]});
      final item = {'id': 1, 'title': 'Deneme haber basligi', 'type': 'HABER', 'publishedDate': '2026-01-01'};
      await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(b), item: item)));
      await settle(tester, const Duration(milliseconds: 600));
      double hair() => tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('news-bar-hairline'))).opacity;
      expect(hair(), 0);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(hair(), 1);
      // Basa donunce yeniden gizlenir.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 800));
      await tester.pump(const Duration(milliseconds: 400));
      expect(hair(), 0);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('yemek', () {
    testWidgets('gun seridi: secili gunun yazisi renkle birlikte animasyonlu (AnimatedDefaultTextStyle)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final today = DateTime.now();
      final d0 = DateTime(today.year, today.month, today.day);
      final days = [for (var i = -2; i <= 4; i++) d0.add(Duration(days: i))];
      var selected = d0;
      DateTime? picked;
      await tester.pumpWidget(buildApp(StatefulBuilder(
        builder: (c, set) => Scaffold(
          body: MenuDayStrip(
            days: days,
            selected: selected,
            onSelect: (d) => set(() {
              picked = d;
              selected = d;
            }),
          ),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      Color dayNumColor(DateTime d) {
        final f = find.descendant(
          of: find.byKey(ValueKey('yemek_day_${d.year}-${d.month}-${d.day}')),
          matching: find.byType(AnimatedDefaultTextStyle),
        );
        return tester.widget<AnimatedDefaultTextStyle>(f.last).style.color!;
      }

      final target = d0.add(const Duration(days: 2));
      final before = dayNumColor(target);
      await tester.tap(find.byKey(ValueKey('yemek_day_${target.year}-${target.month}-${target.day}')));
      await tester.pump();
      expect(picked, target);
      expect(dayNumColor(target), isNot(before)); // hedef renk degisti
      // Ara karede gercek (cizilen) renk hedef ile baslangic arasinda.
      await tester.pump(const Duration(milliseconds: 60));
      final rendered = DefaultTextStyle.of(tester.element(find.descendant(of: find.byKey(ValueKey('yemek_day_${target.year}-${target.month}-${target.day}')), matching: find.text('${target.day}')))).style.color!;
      expect(rendered, isNot(dayNumColor(target)));
      await tester.pump(const Duration(milliseconds: 300));
      final done = DefaultTextStyle.of(tester.element(find.descendant(of: find.byKey(ValueKey('yemek_day_${target.year}-${target.month}-${target.day}')), matching: find.text('${target.day}')))).style.color!;
      expect(done, dayNumColor(target));
      expect(tester.getSize(find.byKey(ValueKey('yemek_day_${target.year}-${target.month}-${target.day}'))).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    MenuDay full() => const MenuDay(
          items: ['Mercimek', 'Pilav'],
          dishes: [MenuDish('Mercimek', 150), MenuDish('Pilav', 300)],
          totalKcal: 450,
          kcalComplete: true,
        );

    testWidgets('toplam kalori 0dan sayarak oturur', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: MenuMealCard(day: full(), photo: null, time: '11:30')))));
      await tester.pump();
      expect(find.text('450 kcal'), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('450 kcal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('animasyonlari azalt: toplam aninda', (tester) async {
      useScreen(tester, const Size(390, 844));
      reduceMotion(tester);
      await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: MenuMealCard(day: full(), photo: null, time: '11:30')))));
      await tester.pump();
      expect(find.text('450 kcal'), findsOneWidget);
    });
  });

  group('bildirim satiri', () {
    Widget row(bool unread) => Scaffold(
          body: NotifRow(
            icon: LucideIcons.bell,
            title: 'Baslik',
            typeLabel: 'Duyuru',
            time: '5 dk',
            unread: unread,
            unreadLabel: 'Okunmamis',
            onTap: () {},
          ),
        );

    double dot(WidgetTester tester) => tester.getRect(find.descendant(of: find.byKey(const ValueKey('notif-unread-dot')), matching: find.byType(DecoratedBox))).width;

    testWidgets('okundu olunca nokta kuculerek kaybolur; satir yeniden kurulmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(row(true)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(dot(tester), 12);
      await tester.pumpWidget(buildApp(row(false)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(dot(tester), allOf(greaterThan(0), lessThan(12)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(dot(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('animasyonlari azalt: nokta aninda kaybolur', (tester) async {
      useScreen(tester, const Size(390, 844));
      reduceMotion(tester);
      await tester.pumpWidget(buildApp(row(true)));
      await tester.pump();
      await tester.pumpWidget(buildApp(row(false)));
      await tester.pump(const Duration(milliseconds: 1));
      expect(dot(tester), 0);
    });

    testWidgets('anlamsal etiket ve dokunma alani korunur', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(row(true)));
      await tester.pump(const Duration(milliseconds: 300));
      final h = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Okunmamis')), findsOneWidget);
      h.dispose();
      expect(tester.getSize(find.byType(NotifRow)).height, greaterThanOrEqualTo(48));
    });
  });
}
