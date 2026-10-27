import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_app.dart';

/// Gorsel denetim yardimcilari (B ajani): gercek Inter + Lucide yazi tipleri, PNG ve tasma denetimi.
///
/// `setUpAll(loadVisualFonts)` ile cagrilir. PNG'ler `build/shots/b/` altina yazilir (`VIS_SHOTS=1` iken).
Future<void> loadVisualFonts() async {
  await loadTestFonts();
  final cache = Platform.environment['PUB_CACHE'] ?? 'C:/pubcache';
  final dir = Directory('$cache/hosted/pub.dev');
  if (!dir.existsSync()) return;
  final lucide = dir.listSync().whereType<Directory>().where((d) => d.path.contains('lucide_icons_flutter-')).toList();
  if (lucide.isEmpty) return;
  final file = File('${lucide.first.path}/assets/lucide.ttf');
  if (!file.existsSync()) return;
  final loader = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

final bool kWriteShots = Platform.environment['VIS_SHOTS'] == '1';

final _boundary = GlobalKey();

/// Sayfayi tema/boyut/olcek/yon ile kurar.
Future<void> pumpVisual(
  WidgetTester tester,
  Widget page, {
  Brightness brightness = Brightness.light,
  Size size = kPhoneMedium,
  double scale = 1.0,
  bool rtl = false,
  Duration settleFor = const Duration(milliseconds: 800),
}) async {
  useScreen(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: page,
    builder: (context, child) => Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: _boundary, child: SizedBox(width: size.width, height: size.height, child: child)),
        ),
      ),
    ),
  ));
  await settle(tester, settleFor);
}

/// Sahnenin PNG'sini `build/shots/b/<name>.png` olarak yazar (VIS_SHOTS=1).
Future<void> shot(WidgetTester tester, String name) async {
  if (!kWriteShots) return;
  final ctx = _boundary.currentContext;
  if (ctx == null) return;
  final b = ctx.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await b.toImage(pixelRatio: 1.5);
    final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = Directory('build/shots/b')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(png.buffer.asUint8List());
  });
}

/// Tasma / layout istisnasi var mi: varsa test basarisiz olur (hangi widget oldugu yazilir).
final _details = <String>[];

void captureErrors() {
  _details.clear();
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    final info = d.informationCollector?.call().map((n) => n.toStringDeep()).join('\n') ?? '';
    _details.add('${d.exception}\n$info');
    prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
}

void expectNoErrors(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e\n${_details.join('\n---\n')}');
}
