import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bu_kampus/core/foreground_timer.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.onTick);
  final VoidCallback onTick;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with WidgetsBindingObserver, ForegroundTimer<_Probe> {
  @override
  void initState() {
    super.initState();
    startForegroundTimer(const Duration(minutes: 1), widget.onTick);
  }

  @override
  void dispose() {
    stopForegroundTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('arka planda durur, one gelince yeniden baslar, dispose iptal eder', (tester) async {
    var n = 0;
    await tester.pumpWidget(_Probe(() => n++));
    await tester.pump(const Duration(minutes: 1));
    expect(n, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 5));
    expect(n, 1, reason: 'arka planda yoklama yok');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(n, 2, reason: 'donuste hemen tazeler');
    await tester.pump(const Duration(minutes: 1));
    expect(n, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    expect(n, 3, reason: 'dispose sonrasi tik yok');
  });
}
