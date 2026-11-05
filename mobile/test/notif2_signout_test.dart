import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/active_conversation.dart';
import 'package:bu_kampus/core/push/push_privacy.dart';
import 'package:bu_kampus/core/push/push_registrar.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_service.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Çıkış yaşam döngüsü (ayrı dosya: PushService oturum kapatma statik köprü durumunu değiştirir).
void main() {
  setUpAll(loadTestFonts);

  const channels = ['bu_kampus/push_actions', 'bu_kampus/notify', 'bu_kampus/badge'];
  setUp(() {
    PushRouter.resetForTest();
    final m = TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    for (final c in channels) {
      m.setMockMethodCallHandler(MethodChannel(c), (call) async => null);
    }
  });
  tearDown(() {
    PushRouter.resetForTest();
    final m = TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    for (final c in channels) {
      m.setMockMethodCallHandler(MethodChannel(c), null);
    }
  });

  testWidgets('çıkış: DELETE /devices/{jeton} çağrılır, kayıt sıfırlanır, "içeriği gizle" yerel değeri sıfırlanır', (tester) async {
      final sent = <bool>[];
      final old = PushPrivacy.sink;
      PushPrivacy.sink = (v) async => sent.add(v);
      addTearDown(() => PushPrivacy.sink = old);
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = makeSession(b);
      PushRouter.session = s;
      s.api.tokens = Tokens('access', 'refresh');
      await tester.pumpWidget(MaterialApp(navigatorKey: rootNavigatorKey, theme: BuTheme.light(), home: const Scaffold(body: Text('kabuk'))));
      final push = PushService(s, active: ActiveConversation.test());
      await pumped(tester, push.onSignedIn());
      await pumped(tester, push.registerToken('tok-9'));
      await pumped(tester, push.onSignedOut());
      expect(b.requests, contains('DELETE /devices/tok-9'));
      expect(push.registrar.token, isNull);
      expect(push.registrar.state, PushRegState.idle);
      expect(sent.last, isFalse);
      // Kanca iki kez (beforeSignOut + durum değişimi) gelse de silme bir kez gider.
      await pumped(tester, push.onSignedOut());
      expect(b.requests.where((r) => r == 'DELETE /devices/tok-9').length, 1);
    });
}

/// Sahte ağ yanıtları sahte zamanla ilerler: başlatılan işi çerçeve ilerleterek bitirir, sonucu döndürür.
Future<T> pumped<T>(WidgetTester tester, Future<T> f) async {
  await settle(tester, const Duration(milliseconds: 600));
  return f;
}
