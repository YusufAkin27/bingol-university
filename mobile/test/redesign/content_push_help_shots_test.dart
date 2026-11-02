@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:bu_kampus/core/push/push_health.dart';
import 'package:bu_kampus/core/push/push_registrar.dart';
import 'package:bu_kampus/features/notifications/push_help_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_app.dart';
import 'p00_support.dart';

class _Health implements PushHealthSource {
  const _Health(this.good);
  final bool good;
  @override
  Future<PushHealth> read() async => PushHealth(supported: true, osAllowed: good,
    registration: good ? PushRegState.registered : PushRegState.failed,
    isAndroid: true, manufacturer: 'xiaomi');
  @override
  Future<void> reregister() async {}
  @override
  Future<bool> openNotificationSettings() async => true;
  @override
  Future<bool> openBatterySettings() async => true;
}

void main() {
  final output = Platform.environment['CONTENT_SHOTS_OUT'];
  setUpAll(loadTestFonts);
  for (final dark in [false, true]) {
    for (final good in [false, true]) {
      testWidgets('push help ${good ? 'ready' : 'attention'} ${dark ? 'dark' : 'light'}', skip: output == null, (tester) async {
        useScreen(tester, const Size(390, 844));
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key,
          child: p00App(PushHelpPage(source: _Health(good)), dark: dark, scaffold: false)));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(output!)..createSync(recursive: true);
          File('${dir.path}/push-help-${good ? 'ready' : 'attention'}-${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        });
        await unmount(tester);
      });
    }
  }
}