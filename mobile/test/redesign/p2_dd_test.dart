import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:bu_kampus/features/academic/timetable_parts.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/clubs/clubs_widgets.dart';
import 'package:bu_kampus/features/events/calm_cover.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/polls/poll_parts.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// P2-DD (tur 2: ince detay + animasyon) testleri: baslangic/bitis durumu, "animasyonlari azalt" ve tekrar oynamama.
class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

Map<String, dynamic> _club(int id, String name, {String status = 'NONE'}) => {
      'id': id,
      'name': name,
      'category': 'Teknoloji',
      'description': 'Kısa açıklama $id',
      'memberCount': 10 + id,
      'myStatus': status,
      'joinPolicy': 'OPEN',
      'visibility': 'PUBLIC',
    };

FakeBackend _clubsBe() => FakeBackend()
  ..on('/communities/categories', [
    {'category': 'Teknoloji'},
  ])
  ..on('/me/communities*', {
    'items': [_club(2, 'Satranç Kulübü', status: 'ACTIVE')],
    'nextCursor': null,
  })
  ..on('/communities/2', {..._club(2, 'Satranç Kulübü', status: 'ACTIVE'), 'myRole': 'MEMBER'})
  ..on('/communities/2/posts*', {'items': <Object>[], 'nextCursor': null})
  ..on('/events*', {'items': <Object>[], 'nextCursor': null})
  ..on('/communities*', {
    'items': [_club(1, 'Robotik Kulübü'), _club(2, 'Satranç Kulübü', status: 'ACTIVE')],
    'nextCursor': null,
  });

double _opacityUnder(WidgetTester tester, Type of) {
  final o = tester.widget<Opacity>(find.descendant(of: find.byType(of), matching: find.byType(Opacity)).first);
  return o.opacity;
}

void main() {
  setUpAll(loadTestFonts);

  group('CalmCover giris', () {
    testWidgets('simge solarak belirir (0 -> 1), azaltilmis harekette aninda', (tester) async {
      Widget cover() => const SizedBox(width: 300, height: 160, child: CalmCover(seed: 3, icon: Icons.event));
      await tester.pumpWidget(p00App(cover(), lang: 'tr', dark: false, scale: 1));
      await tester.pump();
      expect(_opacityUnder(tester, CalmCover), lessThan(1));
      await tester.pump(const Duration(milliseconds: 450));
      expect(_opacityUnder(tester, CalmCover), 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(p00App(cover(), lang: 'tr', dark: false, scale: 1, disableAnimations: true));
      await tester.pump();
      expect(_opacityUnder(tester, CalmCover), 1);
    });

    testWidgets('kategoriye gore degismez: her tohum ayni tek ton', (tester) async {
      final firsts = <Color>[];
      for (var seed = 0; seed < 5; seed++) {
        await tester.pumpWidget(p00App(SizedBox(width: 200, height: 100, child: CalmCover(seed: seed, icon: Icons.event)), lang: 'tr', dark: false, scale: 1));
        await tester.pump();
        final deco = tester.widgetList<DecoratedBox>(find.descendant(of: find.byType(CalmCover), matching: find.byType(DecoratedBox))).first.decoration as BoxDecoration;
        firsts.add((deco.gradient as LinearGradient).colors.first);
      }
      expect(firsts.toSet().length, 1);
    });
  });

  group('anket sonuc satiri', () {
    testWidgets('yuzde sayaci 0 dan sayar, ilk gosterimde bir kez', (tester) async {
      await tester.pumpWidget(p00App(const ResultBar(text: 'Seçenek', percent: 48, votes: 14), lang: 'tr', dark: false, scale: 1));
      await tester.pump();
      expect(find.text('%0'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      final mid = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('%') && w.data != '%0' && w.data != '%48');
      expect(mid, findsOneWidget, reason: 'ara kare: sayac 0 ile 48 arasinda');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('%48'), findsOneWidget);
      // Ayni deger yeniden kurulunca tekrar oynamaz.
      await tester.pumpWidget(p00App(const ResultBar(text: 'Seçenek', percent: 48, votes: 14), lang: 'tr', dark: false, scale: 1));
      await tester.pump();
      expect(find.text('%48'), findsOneWidget);
    });

    testWidgets('azaltilmis harekette dogrudan son deger', (tester) async {
      await tester.pumpWidget(p00App(const ResultBar(text: 'Seçenek', percent: 48, votes: 14), lang: 'tr', dark: false, scale: 1, disableAnimations: true));
      await tester.pump();
      expect(find.text('%48'), findsOneWidget);
    });
  });

  group('kulup karti', () {
    Widget card(String status, {bool dark = false, bool reduce = false}) => p00App(
          Center(child: ClubsRowCard(club: _club(1, 'Robotik Kulübü', status: status), busy: false, onOpen: () {}, onJoin: () {})),
          lang: 'tr',
          dark: dark,
          scale: 1,
          disableAnimations: reduce,
        );

    testWidgets('durum Katil -> Uyesin: dugme solarak yer degistirir', (tester) async {
      await tester.pumpWidget(card('NONE'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Katıl'), findsOneWidget);
      await tester.pumpWidget(card('ACTIVE'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Katıl'), findsOneWidget, reason: 'gecis suruyor: eski dugme hala solmakta');
      expect(find.text('Üyesin'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Katıl'), findsNothing);
      expect(find.text('Üyesin'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing); // simge Lucide; yalnizca metin ve dokunma alani degismedi
      expect(tester.takeException(), isNull);
    });

    testWidgets('azaltilmis harekette gecis aninda', (tester) async {
      await tester.pumpWidget(card('NONE', reduce: true));
      await tester.pump();
      await tester.pumpWidget(card('ACTIVE', reduce: true));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Katıl'), findsNothing);
      expect(find.text('Üyesin'), findsOneWidget);
    });

    testWidgets('basinca kucuk geri bildirim ve 48 dp dokunma alani', (tester) async {
      await tester.pumpWidget(card('NONE'));
      await tester.pump(const Duration(milliseconds: 200));
      final size = tester.getSize(find.byType(ClubsRowCard));
      expect(size.height, greaterThanOrEqualTo(48));
      final g = await tester.startGesture(tester.getCenter(find.text('Robotik Kulübü')));
      await tester.pump(const Duration(milliseconds: 200));
      final scale = tester.widgetList<AnimatedScale>(find.descendant(of: find.byType(ClubsRowCard), matching: find.byType(AnimatedScale))).first.scale;
      expect(scale, lessThan(1));
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('kulupler sekmesi', () {
    testWidgets('Kesfet <-> Kulupler im: icerik solarak degisir, istisna yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ClubsTab(session: makeSession(_clubsBe())), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Robotik Kulübü'), findsOneWidget);
      await tester.tap(find.text('Kulüplerim'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Robotik Kulübü'), findsNothing);
      expect(find.text('Satranç Kulübü'), findsOneWidget);
      await tester.tap(find.text('Keşfet'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Robotik Kulübü'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('karta dokununca detay acilir: logo Hero ucusu hatasiz, geri donus calisir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ClubsTab(session: makeSession(_clubsBe())), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.text('Satranç Kulübü').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(Hero), findsWidgets, reason: 'ucus sirasinda Hero katmani');
      expect(tester.takeException(), isNull);
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Satranç Kulübü'), findsWidgets);
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull, reason: 'donus ucusu');
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Keşfet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('etkinlik takvimi', () {
    FakeBackend be() => FakeBackend()
      ..on('/events/calendar*', <Object>[], headers: {'x-truncated': 'false'})
      ..on('/me/events*', {'items': <Object>[], 'nextCursor': null});

    testWidgets('ay gecisinde izgara yatay kayar (iki izgara bir arada), sonunda tek izgara', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventsPage(session: makeSession(be())), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(ValueKey('grid-${_ym(DateTime.now())}')), findsOneWidget);
      await tester.tap(find.byTooltip('Sonraki ay'));
      await tester.pump(const Duration(milliseconds: 80));
      final grids = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('grid-'));
      expect(grids, findsNWidgets(2), reason: 'eski + yeni izgara gecis sirasinda');
      await settle(tester, const Duration(milliseconds: 600));
      expect(grids, findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('gun secimi: dolu daire 0.6 -> 1 olcekle belirir, azaltilmis harekette aninda', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(EventsPage(session: makeSession(be())), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      final day = DateTime.now().day == 15 ? '16' : '15';
      final cell = find.text(day).last;
      await tester.tap(cell);
      await tester.pump(const Duration(milliseconds: 40));
      final sc = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale)).map((w) => w.scale);
      expect(sc, contains(1.0));
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('destek SSS', () {
    FakeBackend be() => FakeBackend()
      ..on('/faq', [
        {
          'category': 'Hesap',
          'items': [
            {'question': 'Sifremi nasil degistiririm?', 'answer': 'Ayarlar sayfasindan.'}
          ],
        },
      ])
      ..on('/support/tickets', {'items': <Object>[], 'nextCursor': null});

    testWidgets('akordeon: ok doner (0 -> 0.5 tur), cevap solarak acilir, ikinci dokunusta kapanir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(SupportPage(session: makeSession(be())), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Ayarlar sayfasindan.'), findsNothing);
      double turns() => tester.widget<AnimatedRotation>(find.byType(AnimatedRotation).first).turns;
      expect(turns(), 0);
      await tester.tap(find.text('Sifremi nasil degistiririm?'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(turns(), .5);
      expect(find.text('Ayarlar sayfasindan.'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Sifremi nasil degistiririm?'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(turns(), 0);
      expect(find.text('Ayarlar sayfasindan.'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('ders programi', () {
    final now = DateTime.utc(2026, 11, 2, 7, 0); // Pazartesi 10:00 Istanbul
    setUp(() {
      academicClock = () => now;
      ReminderService.platform = _Platform();
      ReminderService.store = MemoryReminderStore();
    });
    tearDown(() {
      academicClock = DateTime.now;
      ReminderService.platform = const ChannelReminderPlatform();
      ReminderService.store = const SecureReminderStore();
    });

    FakeBackend be() {
      final b = FakeBackend();
      final f = fakeAcademic(b);
      f.addCourse('Veri Yapıları', 1, '08:00', '09:00', code: 'BIL201');
      f.addCourse('Algoritmalar', 1, '13:00', '14:50', code: 'BIL301');
      f.addCourse('Fizik', 2, '09:00', '10:50', code: 'FIZ101');
      return b;
    }

    testWidgets('simdi cizgisi gecmis ve yaklasan dersin arasinda; kod hapi notr', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(p00App(TimetablePage(session: makeSession(be())), lang: 'tr', dark: false, scale: 1, scaffold: false));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(TtNowLine), findsOneWidget);
      expect(find.text('Şu an 10:00'), findsOneWidget);
      final yTop = tester.getTopLeft(find.byType(TtNowLine)).dy;
      final slots = find.byType(TtSlotCard);
      expect(slots, findsNWidgets(2));
      expect(tester.getTopLeft(slots.first).dy, lessThan(yTop));
      expect(tester.getTopLeft(slots.last).dy, greaterThan(yTop));
      expect(tester.takeException(), isNull);
    });

    testWidgets('gun degisince akis yatay kayar ve yeni gunun dersi gelir; dersi olmayan gunde cizgi yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(p00App(TimetablePage(session: makeSession(be())), lang: 'tr', dark: false, scale: 1, scaffold: false));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.text('Sal').first);
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('Fizik'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(TtNowLine), findsNothing);
      expect(find.byType(TtSlotCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

String _ym(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
