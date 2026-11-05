import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p00_support.dart';

/// PREMIUM MONOCHROME tema yonetimi: varsayilan koyu, Sistem/Acik/Koyu gecisi anlik, gecis ekran durumunu
/// (yazilmis metin, kaydirma konumu, sekme/state) SIFIRLAMAZ ve iki temada da birincil dugme AA kontrastlidir.
class _Probe extends StatefulWidget {
  const _Probe({required this.text, required this.scroll});

  final TextEditingController text;
  final ScrollController scroll;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int taps = 0; // widget state: tema degisince korunmali
  static int created = 0;

  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          TextField(key: const ValueKey('field'), controller: widget.text),
          FilledButton(key: const ValueKey('btn'), onPressed: () => setState(() => taps++), child: Text('tap $taps')),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('list'),
              controller: widget.scroll,
              itemCount: 200,
              itemBuilder: (_, i) => SizedBox(height: 48, child: Text('satir $i')),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  test('varsayilan tema Premium Black (koyu); Sistem/Acik/Koyu secenekleri durur', () {
    expect(ThemeController().mode, ThemeMode.dark);
    expect(ThemeController.defaultMode, ThemeMode.dark);
    expect(ThemeMode.values, containsAll([ThemeMode.system, ThemeMode.light, ThemeMode.dark]));
  });

  testWidgets('tema degisince yazilan metin, kaydirma konumu ve state korunur (yeniden baslatma yok)', (tester) async {
    final mode = ValueNotifier(ThemeMode.dark);
    final text = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      text.dispose();
      scroll.dispose();
      mode.dispose();
    });
    final created0 = _ProbeState.created;
    await tester.pumpWidget(ValueListenableBuilder<ThemeMode>(
      valueListenable: mode,
      builder: (_, m, __) => MaterialApp(
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: m,
        home: _Probe(text: text, scroll: scroll),
      ),
    ));
    BuTokens tk() => tester.element(find.byKey(const ValueKey('btn'))).bu;
    expect(tk().bg, BuTokens.dark.bg);

    await tester.enterText(find.byKey(const ValueKey('field')), 'merhaba');
    await tester.tap(find.byKey(const ValueKey('btn')));
    await tester.pump();
    scroll.jumpTo(1234);
    await tester.pump();
    expect(find.text('tap 1'), findsOneWidget);

    for (final next in [ThemeMode.light, ThemeMode.system, ThemeMode.dark, ThemeMode.light]) {
      mode.value = next;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250)); // AnimatedTheme gecisi
      expect(text.text, 'merhaba', reason: '$next: metin');
      expect(scroll.offset, 1234, reason: '$next: kaydirma');
      expect(find.text('tap 1'), findsOneWidget, reason: '$next: state');
    }
    expect(tk().bg, BuTokens.light.bg);
    expect(_ProbeState.created, created0 + 1, reason: 'alt agac yeniden kurulmadi (tek initState)');
  });

  testWidgets('Sistem secili iken platform parlakligi degisince tema anlik uyar', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final text = TextEditingController();
    final scroll = ScrollController();
    addTearDown(() {
      text.dispose();
      scroll.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      theme: BuTheme.light(),
      darkTheme: BuTheme.dark(),
      themeMode: ThemeMode.system,
      home: _Probe(text: text, scroll: scroll),
    ));
    BuTokens tk() => tester.element(find.byKey(const ValueKey('btn'))).bu;
    expect(tk().bg, BuTokens.dark.bg);
    await tester.enterText(find.byKey(const ValueKey('field')), 'x');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tk().bg, BuTokens.light.bg);
    expect(text.text, 'x');
  });

  for (final b in Brightness.values) {
    testWidgets('${b.name}: birincil dugme (FilledButton) zemin/yazi >= 4.5 ve yuzeyler tema belirtecinde', (tester) async {
      final t = b == Brightness.dark ? BuTokens.dark : BuTokens.light;
      final th = b == Brightness.dark ? BuTheme.dark() : BuTheme.light();
      await tester.pumpWidget(MaterialApp(
        theme: th,
        home: Scaffold(body: Center(child: FilledButton(onPressed: () {}, child: const Text('Devam')))),
      ));
      final btn = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = btn.style?.backgroundColor?.resolve({}) ?? th.colorScheme.primary;
      final fg = btn.style?.foregroundColor?.resolve({}) ?? th.colorScheme.onPrimary;
      expect(bg, t.pr);
      expect(fg, t.onPr);
      expect(p00Contrast(fg, bg), greaterThanOrEqualTo(7));
      expect(th.scaffoldBackgroundColor, t.bg);
      expect(th.cardTheme.color, t.sf);
      expect(th.dialogTheme.backgroundColor, t.sf3);
      expect(th.snackBarTheme.backgroundColor, t.sf3);
      expect(th.bottomSheetTheme.backgroundColor, t.sf3);
      // Sistem cubugu ikonlari temaya uyar.
      expect(th.appBarTheme.systemOverlayStyle!.statusBarIconBrightness, b == Brightness.dark ? Brightness.light : Brightness.dark);
    });
  }
}
