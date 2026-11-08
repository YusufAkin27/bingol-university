import 'package:bu_kampus/core/nav.dart' show rootNavigatorKey;
import 'package:bu_kampus/widgets/bu_swipe_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  globalTests();
  Widget host(VoidCallback onBack, {TextDirection dir = TextDirection.ltr}) => MaterialApp(
        home: Directionality(
          textDirection: dir,
          child: BuSwipeBack(onBack: onBack, child: const Scaffold(body: SizedBox.expand())),
        ),
      );

  testWidgets('soldan saga yatay cekince geri doner', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(() => n++));
    await tester.fling(find.byType(Scaffold), const Offset(240, 10), 800);
    await tester.pumpAndSettle();
    expect(n, 1);
  });

  testWidgets('kisa ya da dikey hareket geri dondurmez; sagdan sola donmez', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(() => n++));
    await tester.fling(find.byType(Scaffold), const Offset(40, 0), 800);
    await tester.fling(find.byType(Scaffold), const Offset(0, 300), 800);
    await tester.fling(find.byType(Scaffold), const Offset(-240, 0), 800);
    await tester.pumpAndSettle();
    expect(n, 0);
  });

  testWidgets('Arapca (RTL): sagdan sola cekince geri doner', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(() => n++, dir: TextDirection.rtl));
    await tester.fling(find.byType(Scaffold), const Offset(-240, 0), 800);
    await tester.pumpAndSettle();
    expect(n, 1);
  });
}

void globalTests() {
  group('BuGlobalSwipeBack (iOS)', () {
    Widget app() => MaterialApp(
          navigatorKey: rootNavigatorKey,
          builder: (c, child) => BuGlobalSwipeBack(child: child ?? const SizedBox.shrink()),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('ikinci')))),
                  child: const Text('ac'),
                ),
              ),
            ),
          ),
        );

    testWidgets('ikinci sayfada soldan saga cekince onceki sayfaya doner; kokte hicbir sey olmaz', (tester) async {
      await tester.pumpWidget(app());
      await tester.fling(find.text('ac'), const Offset(300, 0), 900); // kokte: sayfa yok, hata yok
      await tester.pumpAndSettle();
      expect(find.text('ac'), findsOneWidget);
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();
      expect(find.text('ikinci'), findsOneWidget);
      await tester.dragFrom(const Offset(200, 300), const Offset(300, 0));
      await tester.fling(find.text('ikinci'), const Offset(300, 0), 900);
      await tester.pumpAndSettle();
      expect(find.text('ac'), findsOneWidget);
      expect(find.text('ikinci'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android: genel kaydirma kapali', (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();
      await tester.fling(find.text('ikinci'), const Offset(300, 0), 900);
      await tester.pumpAndSettle();
      expect(find.text('ikinci'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
