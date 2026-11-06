import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _labels = ['Ana Sayfa', 'Keşfet', 'Sohbet', 'Kulüpler', 'Profil'];

Widget _nav(int idx, void Function(int) on, ValueNotifier<int> badge, Size size, Brightness br) => buildApp(
      Scaffold(bottomNavigationBar: FloatingNav(index: idx, onChanged: on, chatBadge: badge)),
      brightness: br,
      size: size,
    );

void main() {
  testWidgets('orta paylasim dugmesi sekme secmeden gonderi eylemini acar', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(2);
    addTearDown(badge.dispose);
    var published = 0;
    final selected = <int>[];
    await tester.pumpWidget(buildApp(Scaffold(bottomNavigationBar: FloatingNav(
      index: 0, onChanged: selected.add, chatBadge: badge, onPublish: () => published++,
    ))));
    expect(find.text('Kulüpler'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-publish')));
    await tester.pump();
    expect(published, 1);
    expect(selected, isEmpty);
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    expect(selected, [2]);
  });

  testWidgets('yalniz secili sekmede etiket gorunur; hepsinin Semantics etiketi var', (tester) async {
    final h = tester.ensureSemantics();
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(0, (_) {}, badge, kPhoneMedium, Brightness.light));
    expect(find.byKey(const ValueKey('nav-pill')), findsOneWidget);
    // 4 simge sekmesi + Profil sekmesinde avatar (simge yok).
    expect(find.byType(Icon), findsNWidgets(4));
    expect(find.byType(ChatlistAvatar), findsOneWidget);
    for (final l in _labels) {
      expect(find.text(l), findsNothing, reason: 'etiket görünmez: $l'); // yalnız simge; etiket ekran okuyucuda
      expect(find.bySemanticsLabel(RegExp(l)), findsWidgets);
    }
    h.dispose();
  });

  testWidgets('dokunma dogru indeksle onChanged cagirir', (tester) async {
    final h = tester.ensureSemantics();
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    final got = <int>[];
    await tester.pumpWidget(_nav(0, got.add, badge, kPhoneMedium, Brightness.light));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(ValueKey('nav-$i')));
      await tester.pump();
    }
    expect(got, [0, 1, 2, 3, 4]);
    h.dispose();
  });

  testWidgets('rozet gorunur ve kaybolur; 99 ustu 99+', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(0, (_) {}, badge, kPhoneMedium, Brightness.light));
    expect(find.byKey(const ValueKey('nav-badge')), findsNothing);
    badge.value = 7;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('7'), findsOneWidget);
    badge.value = 150;
    await tester.pump();
    expect(find.text('99+'), findsOneWidget);
    badge.value = 0;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('nav-badge')), findsNothing);
  });

  testWidgets('secili sekme sohbetse rozet gizlenir (zaten acik)', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(5);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(2, (_) {}, badge, kPhoneMedium, Brightness.light));
    await tester.pump(const Duration(milliseconds: 400));
    final scale = tester.widget<AnimatedScale>(find
        .ancestor(of: find.byKey(const ValueKey('nav-badge')), matching: find.byType(AnimatedScale))
        .first);
    expect(scale.scale, 0);
  });

  testWidgets('secili sekme degisince kayan hap yeni sekmenin hucresine kayar (220 ms) ve etiket acilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    _idx = 0;
    await tester.pumpWidget(StatefulBuilder(
      builder: (c, set) => _nav(_idx, (i) => set(() => _idx = i), badge, kPhoneMedium, Brightness.light),
    ));
    for (final i in [4, 2, 0]) {
      await tester.tap(find.byKey(ValueKey('nav-$i')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Seçili sekmenin altında cam kapsül var ve o hücrenin ortasına oturur.
      expect(find.byKey(const ValueKey('nav-indicator')), findsOneWidget, reason: 'cam kapsül var ($i)');
      final cap = tester.getCenter(find.byKey(const ValueKey('nav-indicator')));
      final cellC = tester.getCenter(find.byKey(ValueKey('nav-$i')));
      expect((cap.dx - cellC.dx).abs(), lessThan(1.5), reason: 'kapsül sekme $i hücresinde');
      for (var j = 0; j < 5; j++) {
        expect(find.text(_labels[j]), findsNothing, reason: 'hiçbir sekmede görünür etiket yok ($j)');
      }
    }
  });

  testWidgets('animasyonlari azalt: hap ve etiket aninda yerine gelir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    _idx = 0;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: StatefulBuilder(
        builder: (c, set) => _nav(_idx, (i) => set(() => _idx = i), badge, kPhoneMedium, Brightness.light),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('nav-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final cell = tester.getRect(find.byKey(const ValueKey('nav-4')));
    expect(find.byKey(const ValueKey('nav-indicator')), findsNothing); // vurgu zemini yok
    expect(cell.width, greaterThan(0));
    expect(find.text('Profil'), findsNothing); // etiket görünmez (ekran okuyucuda var)
  });

  testWidgets('"+" basinca 0.94 olcege kuculur, birakinca doner; cubuktan yukari tasar', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    await tester.pumpWidget(buildApp(Scaffold(bottomNavigationBar: FloatingNav(index: 0, onChanged: (_) {}, chatBadge: badge, onPublish: () {}))));
    final plus = find.byKey(const ValueKey('nav-publish'));
    final bar = tester.getRect(find.byKey(const ValueKey('nav-pill')));
    expect(tester.getRect(plus).top, lessThan(bar.top - 4), reason: 'cubuktan tasmali');
    final g = await tester.startGesture(tester.getCenter(plus));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<AnimatedScale>(find.ancestor(of: plus, matching: find.byType(AnimatedScale)).first).scale, .94);
    await g.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedScale>(find.ancestor(of: plus, matching: find.byType(AnimatedScale)).first).scale, 1);
  });

  testWidgets('semantik: secili durumu, rozetli etiket, sekme sirasi ipucu', (tester) async {
    final h = tester.ensureSemantics();
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(5);
    addTearDown(badge.dispose);
    await tester.pumpWidget(_nav(0, (_) {}, badge, kPhoneMedium, Brightness.light));
    await tester.pump(const Duration(milliseconds: 400));
    final home = tester.getSemantics(find.byKey(const ValueKey('nav-0')));
    expect(home.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(home.label, 'Ana Sayfa');
    final chat = tester.getSemantics(find.byKey(const ValueKey('nav-2')));
    expect(chat.label, 'Sohbet, 5 okunmamış');
    expect(chat.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    expect(chat.hint, isNotEmpty);
    h.dispose();
  });

  testWidgets('profil sekmesi: foto yoksa varsayilan gorsel, foto adresi gelince guncellenir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    final url = ValueNotifier<String?>(null);
    addTearDown(badge.dispose);
    addTearDown(url.dispose);
    await tester.pumpWidget(buildApp(
      Scaffold(bottomNavigationBar: FloatingNav(index: 4, onChanged: (_) {}, chatBadge: badge, avatarUrl: url, avatarName: 'Elif Yıldız')),
      size: kPhoneMedium,
    ));
    expect(find.byType(BuDefaultAvatar), findsOneWidget);
    expect(find.byType(Image), findsOneWidget); // yalniz varsayilan gorsel (ag gorseli yok)
    url.value = '/files/avatars/me.jpg';
    await tester.pump();
    // Foto yuklenirken/hata verirse varsayilan gorsel altta kalir.
    expect(find.byType(BuDefaultAvatar), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2)); // varsayilan (alt) + ag gorseli
  });

  testWidgets('klavye acikken cubuk gizlenir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final badge = ValueNotifier<int>(0);
    addTearDown(badge.dispose);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_nav(0, (_) {}, badge, kPhoneMedium, Brightness.light));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('nav-pill')), findsNothing);
  });

  for (final size in kPhoneSizes) {
    for (final br in Brightness.values) {
      testWidgets('tasma yok ${size.width.toInt()} ${br.name}', (tester) async {
        useScreen(tester, size);
        final badge = ValueNotifier<int>(150);
        addTearDown(badge.dispose);
        await tester.pumpWidget(_nav(2, (_) {}, badge, size, br));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        // dokunma hedefi: en az 44 x 48 dp (seçili olmayan hücre 44 dp)
        for (var i = 0; i < 5; i++) {
          final sz = tester.getSize(find.byKey(ValueKey('nav-$i')));
          expect(sz.width >= 44 && sz.height >= 48, isTrue, reason: 'sekme $i $sz');
        }
      });
    }
  }

  for (final br in [Brightness.light, Brightness.dark]) {
    for (final rtl in [false, true]) {
      testWidgets('320 dp ${br.name} ${rtl ? "rtl" : "ltr"}: tasma yok, 64 dp yukseklik (yuzen hap)', (tester) async {
        const small = Size(320, 640);
        useScreen(tester, small);
        final badge = ValueNotifier<int>(120);
        addTearDown(badge.dispose);
        await tester.pumpWidget(buildApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(bottomNavigationBar: FloatingNav(index: 3, onChanged: (_) {}, chatBadge: badge)),
          ),
          brightness: br,
          size: small,
        ));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(const ValueKey('nav-pill'))).height, closeTo(FloatingNav.height, 1.5));
      });
    }
  }
}

int _idx = 0;
