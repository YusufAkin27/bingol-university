import 'package:bu_kampus/core/platform/secure_view.dart';
import 'package:bu_kampus/features/chat/view_once_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/store_shots_images.dart';

// Tek gönderimlik fotoğraf görüntüleyicisi yerleşimi: içerik ekranın ORTASINDA, sağ-alta kayma yok, taşma yok.
// (iOS'ta gerçek cihazda görülen kayma "güvenli alan katmanı" yönteminden gelir; bkz. ChatSecureView.layerTrickDefault.
// Bu test Flutter tarafının yerleşiminin doğru olduğunu ve yerel katman kapalıyken hiçbir şeye dokunulmadığını kanıtlar.)

void main() {
  setUpAll(loadTestFonts);

  Future<void> open(WidgetTester tester, Size size, Brightness b, {String? caption, double scale = 1}) async {
    final be = FakeBackend()..onBytes('/conversations/1/media/50', storeImageBytes(0), once: true);
    useScreen(tester, size);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(buildApp(
        ViewOnceViewer(
            api: makeSession(be).api, conversationId: 1, attachmentId: 50, caption: caption, secureView: ChatSecureView(isIOS: false)),
        brightness: b,
        size: size));
    await settle(tester, const Duration(milliseconds: 800));
  }

  for (final size in [kPhoneSmall, kPhoneMedium]) {
    for (final b in Brightness.values) {
      for (final caption in [null, 'Kısa açıklama']) {
        testWidgets(
            '${size.width.toInt()} dp x1.3 ${b.name}${caption == null ? '' : ' + açıklama'}: fotoğraf alanı yatayda ortalı, ekran içinde, taşma yok',
            (tester) async {
          await open(tester, size, b, caption: caption, scale: 1.3);
          final box = find.byKey(const ValueKey('onceImageBox'));
          expect(box, findsOneWidget);
          final r = tester.getRect(box);
          // Yatayda ortalı (RTL/LTR fark etmez), ekran sınırları içinde.
          expect((r.center.dx - size.width / 2).abs(), lessThan(1.0), reason: 'yatayda kaymış: $r');
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(size.width));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.bottom, lessThanOrEqualTo(size.height));
          // Dikeyde üst çubuk ile alt ipucu arasındaki bantta: üste yapışmaz, sağ-alta kaçmaz.
          expect(r.center.dy, greaterThan(size.height * .25));
          expect(r.center.dy, lessThan(size.height * .75));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  }

  testWidgets('RTL: fotoğraf alanı yine ortada', (tester) async {
    final be = FakeBackend()..onBytes('/conversations/1/media/50', storeImageBytes(0), once: true);
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(
        Directionality(
            textDirection: TextDirection.rtl,
            child: ViewOnceViewer(api: makeSession(be).api, conversationId: 1, attachmentId: 50, secureView: ChatSecureView(isIOS: false))),
        size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 800));
    final r = tester.getRect(find.byKey(const ValueKey('onceImageBox')));
    expect((r.center.dx - kPhoneMedium.width / 2).abs(), lessThan(1.0));
    await unmount(tester);
  });
}
