import 'package:bu_kampus/widgets/bu_swipe_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
