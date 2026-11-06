import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'kb_harness.dart';

Widget _form({int fields = 25, VoidCallback? onTap, ScrollController? c}) => BuFormScaffold(
      controller: c,
      action: BuButton(key: const ValueKey('save'), label: 'Kaydet', onPressed: onTap ?? () {}),
      children: [
        for (var i = 0; i < fields; i++)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(key: ValueKey('f$i'), decoration: InputDecoration(hintText: 'Alan $i'))),
      ],
    );

void main() {
  group('BuFormScaffold', () {
    for (final size in [kSe, kPhoneMedium]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('klavye acik/kapali: Kaydet klavyenin ustunde ve dokunulabilir ${size.width.toInt()}x${size.height.toInt()} x$scale', (tester) async {
          setupScreen(tester, size, bottomSafe: 34);
          var taps = 0;
          await tester.pumpWidget(buildApp(scaled(_form(onTap: () => taps++), scale), size: size));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectAboveKeyboard(tester, find.byKey(const ValueKey('save')), size, 0);

          await tester.tap(find.byKey(const ValueKey('f0')));
          await setKeyboard(tester, 300);
          expect(tester.takeException(), isNull);
          expectAboveKeyboard(tester, find.byKey(const ValueKey('save')), size, 300);
          await tester.tap(find.byKey(const ValueKey('save')));
          expect(taps, 1);

          // Klavye kapaninca normale doner.
          await setKeyboard(tester, 0);
          expectAboveKeyboard(tester, find.byKey(const ValueKey('save')), size, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('klavye acikken son alana kaydirilir', (tester) async {
      setupScreen(tester, kSe);
      await tester.pumpWidget(buildApp(_form(), size: kSe));
      await tester.tap(find.byKey(const ValueKey('f0')));
      await setKeyboard(tester, 280);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('f24')), 200, scrollable: find.byType(Scrollable).first);
      expectAboveKeyboard(tester, find.byKey(const ValueKey('f24')), kSe, 280);
      expect(tester.takeException(), isNull);
    });

    testWidgets('klavyeyi art arda ac/kapa: istisna yok', (tester) async {
      setupScreen(tester, kSe);
      await tester.pumpWidget(buildApp(_form(), size: kSe));
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(ValueKey('f${i % 2}')));
        await setKeyboard(tester, 300);
        await setKeyboard(tester, 0);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('bos alana dokunma odagi birakir', (tester) async {
      setupScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        const BuFormScaffold(children: [TextField(key: ValueKey('a')), SizedBox(height: 300)]),
        size: kPhoneMedium,
      ));
      await tester.tap(find.byKey(const ValueKey('a')));
      await tester.pump();
      final et = tester.widget<EditableText>(find.byType(EditableText));
      expect(et.focusNode.hasFocus, isTrue);
      await tester.tapAt(const Offset(200, 600));
      await tester.pump();
      expect(et.focusNode.hasFocus, isFalse);
    });

    testWidgets('surukleyince klavye kapanir (onDrag)', (tester) async {
      setupScreen(tester, kSe);
      await tester.pumpWidget(buildApp(_form(), size: kSe));
      await tester.tap(find.byKey(const ValueKey('f0')));
      await setKeyboard(tester, 280);
      final et = tester.widget<EditableText>(find.byType(EditableText).first);
      expect(et.focusNode.hasFocus, isTrue);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -120));
      await tester.pump();
      expect(et.focusNode.hasFocus, isFalse);
    });
  });

  group('BuFormActionBar', () {
    testWidgets('home indicator payi: klavye acikken ek bosluk birikmez (cift bosluk yok)', (tester) async {
      setupScreen(tester, kPhoneMedium, bottomSafe: 34);
      await tester.pumpWidget(buildApp(_form(fields: 2), size: kPhoneMedium));
      await tester.pumpAndSettle();
      final closed = tester.getRect(find.byKey(const ValueKey('save'))).bottom;
      expect(closed, lessThanOrEqualTo(kPhoneMedium.height - 34 + .5));
      await tester.tap(find.byKey(const ValueKey('f0')));
      await setKeyboard(tester, 300);
      final open = tester.getRect(find.byKey(const ValueKey('save'))).bottom;
      // Klavye acikken dugme klavyeye bar ic boslugu (10 dp) kadar yakin; 34 dp'lik ek bosluk BIRIKMEZ.
      expect(kPhoneMedium.height - 300 - open, lessThan(12));
    });
  });

  group('BuKeyboard', () {
    testWidgets('inset/isOpen viewInsets bottom degerini yansitir', (tester) async {
      setupScreen(tester, kPhoneMedium);
      double? v;
      bool? open;
      await tester.pumpWidget(buildApp(
        Builder(builder: (c) {
          v = BuKeyboard.inset(c);
          open = BuKeyboard.isOpen(c);
          return const SizedBox();
        }),
        size: kPhoneMedium,
      ));
      expect(v, 0);
      expect(open, isFalse);
      await setKeyboard(tester, 250);
      expect(v, 250);
      expect(open, isTrue);
    });

    testWidgets('ensureVisible: kaydirilabilir icinde ogeyi gorunur kilar, kaydirilabilir yoksa sessiz', (tester) async {
      setupScreen(tester, kSe);
      final key = GlobalKey();
      await tester.pumpWidget(buildApp(
        Scaffold(body: SingleChildScrollView(child: Column(children: [const SizedBox(height: 1500), SizedBox(key: key, height: 40, child: const Text('son'))]))),
        size: kSe,
      ));
      BuKeyboard.ensureVisible(key.currentContext!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getRect(find.text('son')).bottom, lessThanOrEqualTo(kSe.height));
      // Kaydirilabilir olmayan agac: istisna yok.
      final key2 = GlobalKey();
      await tester.pumpWidget(buildApp(Center(child: SizedBox(key: key2)), size: kSe));
      BuKeyboard.ensureVisible(key2.currentContext!);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      // Bekleyen ikinci hizalama zamanlayicisi bitsin.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('showBuFormSheet', () {
    Future<void> open(WidgetTester tester, {Size size = kSe}) async {
      setupScreen(tester, size);
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showBuFormSheet<String>(
                  c,
                  title: 'Form',
                  builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < 6; i++) TextField(key: ValueKey('s$i')),
                  ]),
                  actions: [BuButton(key: const ValueKey('sheetSave'), label: 'Kaydet', onPressed: () => Navigator.of(c, rootNavigator: true).pop('ok'))],
                ),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
        size: size,
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('klavye acikken sabit eylem klavyenin ustunde, govde kaydirilir, tasma yok', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('s0')));
      await setKeyboard(tester, 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectAboveKeyboard(tester, find.byKey(const ValueKey('sheetSave')), kSe, 280);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('s5')), 100, scrollable: find.byType(Scrollable).last);
      expectAboveKeyboard(tester, find.byKey(const ValueKey('s5')), kSe, 280);
    });

    testWidgets('kapaninca odak temizlenir (klavye acik kalmaz)', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('s1')));
      await tester.pump();
      final et = tester.widget<EditableText>(find.byType(EditableText).at(1));
      expect(et.focusNode.hasFocus, isTrue);
      await tester.tap(find.byKey(const ValueKey('sheetSave')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('s1')), findsNothing);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>(), isNull);
    });
  });

  group('BuFocusRouteObserver', () {
    testWidgets('sayfa itilince odak birakilir; geri donuste klavye yeniden acilmaz', (tester) async {
      setupScreen(tester, kPhoneMedium);
      final fn = FocusNode();
      addTearDown(fn.dispose);
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [BuFocusRouteObserver()],
        home: Builder(
          builder: (c) => Scaffold(
            body: Column(children: [
              TextField(key: const ValueKey('x'), focusNode: fn),
              TextButton(
                onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(body: TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('geri'))))),
                child: const Text('git'),
              ),
            ]),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('x')));
      await tester.pump();
      expect(fn.hasFocus, isTrue);
      await tester.tap(find.text('git'));
      await tester.pumpAndSettle();
      expect(fn.hasFocus, isFalse);
      await tester.tap(find.text('geri'));
      await tester.pumpAndSettle();
      expect(fn.hasFocus, isFalse);
    });
  });
}
