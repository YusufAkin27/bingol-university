import 'dart:async';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/active_conversation.dart';
import 'package:bu_kampus/core/push/push_actions.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Bildirim yönlendirme + cihaz kaydı yaşam döngüsü (P-DT): oturum yokken dokunuş, tekrar işleme,
/// başka hesabın bildirimi, silinmiş içerik, jeton yenileme, izin geri alma, çıkışta silme.
void main() {
  setUpAll(loadTestFonts);
  // Yerel köprü kanalları testte sahte: yanıtsız kanal çağrısı widget testinde bekler (gerçek platform yok).
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

  late FakeBackend b;
  late Session s;

  /// Sahte ağ yanıtları sahte zamanla ilerler: başlatılan işi çerçeve ilerleterek bitirir, sonucu döndürür.
  Future<T> pumped<T>(WidgetTester tester, Future<T> f) async {
    await settle(tester, const Duration(milliseconds: 600));
    return f;
  }

  Future<void> pumpShell(WidgetTester tester, {bool signedIn = true}) async {
    useScreen(tester, kPhoneMedium);
    b = FakeBackend()..on('/notifications', {'items': <Object>[], 'unreadCount': 0, 'nextCursor': null});
    s = makeSession(b, signedIn: signedIn);
    PushRouter.session = s;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: BuTheme.light(),
      home: const Scaffold(body: Text('kabuk')),
    ));
  }

  group('oturum yokken dokunulan bildirim', () {
    testWidgets('yük saklanır, hiçbir sayfa açılmaz; giriş sonrası flushPending açar', (tester) async {
      await pumpShell(tester, signedIn: false);
      final r = await PushRouter.open({'targetType': 'ALIEN', 'targetId': '1'});
      await tester.pumpAndSettle();
      expect(r, isFalse);
      expect(PushRouter.hasPending, isTrue);
      expect(find.byType(NotificationsPage), findsNothing);

      s.state = SessionState.signedIn;
      s.userId = 1;
      final fut = PushRouter.flushPending();
      await tester.pumpAndSettle();
      await fut;
      expect(PushRouter.hasPending, isFalse);
      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('saklanan yük 30 dakikadan eskiyse açılmaz (bayat dokunuş)', (tester) async {
      await pumpShell(tester, signedIn: false);
      var now = DateTime(2026, 11, 5, 10);
      PushRouter.clock = () => now;
      await PushRouter.open({'targetType': 'ALIEN'});
      now = now.add(const Duration(minutes: 31));
      s.state = SessionState.signedIn;
      expect(await PushRouter.flushPending(), isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsNothing);
      expect(PushRouter.hasPending, isFalse);
    });

    testWidgets('oturum hiç yokken (session null) de yük atılmaz, saklanır', (tester) async {
      await pumpShell(tester);
      PushRouter.session = null;
      await PushRouter.open({'conversationId': '9'});
      expect(PushRouter.hasPending, isTrue);
      PushRouter.session = s;
      b.fail('/conversations/9', status: 404, code: 'NOT_FOUND');
      final fut = PushRouter.flushPending();
      await tester.pumpAndSettle();
      await fut;
      expect(find.byType(NotificationsPage), findsOneWidget); // erişilemeyen sohbet: liste
    });

    testWidgets('PushService.onSignedIn saklanan dokunuşu açar', (tester) async {
      await pumpShell(tester, signedIn: false);
      final push = PushService(s, active: ActiveConversation.test());
      await PushRouter.open({'targetType': 'ALIEN'});
      s.state = SessionState.signedIn;
      s.userId = 1;
      await pumped(tester, push.onSignedIn());
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
      await pumped(tester, push.onSignedOut());
    });
  });

  test('PushActions: oturum yokken yalnız "aç" dokunuşu yönlendiriciye (saklamaya) verilir; durum değiştiren eylem verilmez', () async {
    final be = FakeBackend();
    final session = makeSession(be, signedIn: false);
    final opened = <Map<String, dynamic>>[];
    final actions = PushActions(session, open: (d, {bool compose = false}) async => opened.add(d));
    expect(await actions.perform({'notificationAction': 'open', 'conversationId': '4'}), isFalse);
    expect(opened, hasLength(1));
    expect(await actions.perform({'conversationId': '4'}), isFalse); // eylem adı yoksa da "aç"
    expect(opened, hasLength(2));
    expect(await actions.perform({'notificationAction': 'mute_hour', 'conversationId': '4'}), isFalse);
    expect(opened, hasLength(2));
    expect(be.requests, isEmpty);
  });

  group('başka hesabın bildirimi', () {
    testWidgets('recipientId farklıysa açılmaz; aynıysa ya da yoksa açılır', (tester) async {
      await pumpShell(tester);
      s.userId = 1;
      expect(await PushRouter.open({'targetType': 'ALIEN', 'recipientId': '2'}), isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsNothing);

      await PushRouter.open({'targetType': 'ALIEN', 'recipientId': '1'});
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
    });
  });

  group('aynı bildirimin iki kez işlenmesi', () {
    testWidgets('aynı messageId kısa sürede ikinci kez sayfa açmaz; pencere sonrası açar', (tester) async {
      await pumpShell(tester);
      var now = DateTime(2026, 11, 5, 10);
      PushRouter.clock = () => now;
      final data = {'targetType': 'ALIEN', 'messageId': 'm-1'};
      await PushRouter.open(data);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);

      now = now.add(const Duration(seconds: 2));
      await PushRouter.open(data); // FCM + yerel köprü çift yolu / çift dokunuş
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);

      now = now.add(const Duration(seconds: 20));
      await PushRouter.open(data); // bilinçli yeniden dokunuş
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage, skipOffstage: false), findsNWidgets(2));
    });

    testWidgets('kimliksiz yük tekilleştirilmez (aynı hedefe bilinçli ikinci dokunuş geçerli)', (tester) async {
      await pumpShell(tester);
      await PushRouter.open({'targetType': 'ALIEN'});
      await PushRouter.open({'targetType': 'ALIEN'});
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage, skipOffstage: false), findsNWidgets(2));
    });

    testWidgets('LRU: 50 yeni kimlik sonrası en eski kimlik unutulur', (tester) async {
      await pumpShell(tester);
      Future<bool> tap(String id) async {
        shellTabRequest.value = 0;
        await PushRouter.open({'event': 'CONVERSATION_REMOVED', 'conversationId': '5', 'messageId': id});
        return shellTabRequest.value == 2; // sohbet listesi istendi = işlendi
      }

      expect(await tap('m0'), isTrue);
      expect(await tap('m0'), isFalse); // yinelenen
      for (var i = 1; i <= 50; i++) {
        expect(await tap('m$i'), isTrue);
      }
      expect(await tap('m0'), isTrue); // LRU'dan düştü: yeniden işlenir
      await tester.pump();
    });
  });

  group('silinmiş / erişilemeyen içerik', () {
    for (final c in [
      ('gönderi', {'postId': '9'}, '/posts/9'),
      ('haber', {'targetType': 'NEWS', 'targetId': '9'}, '/news/9'),
      ('kullanıcı', {'targetType': 'USER', 'targetId': '9'}, '/users/9'),
      ('sohbet', {'conversationId': '9'}, '/conversations/9'),
    ]) {
      testWidgets('${c.$1} 404: çökmez, kullanıcı sessiz kalmaz', (tester) async {
        await pumpShell(tester);
        b.fail(c.$3, status: 404, code: 'NOT_FOUND');
        // Sayfa rotaları kapanana kadar açık kalan hedefler (gönderi/kullanıcı) beklenmez.
        unawaited(PushRouter.open(Map<String, dynamic>.from(c.$2)));
        await settle(tester, const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        // Ya Bildirimler listesine düşer ya da açılan sayfa kendi hata durumunu gösterir (kabukta kalınmaz).
        expect(find.text('kabuk').hitTestable(), findsNothing);
      });
    }
  });

  group('cihaz kaydı yaşam döngüsü', () {
    late PushService push;

    testWidgets('PushService kaydı: jeton POST /devices ile gider', (tester) async {
      await pumpShell(tester);
      s.api.tokens = Tokens('access', 'refresh');
      push = PushService(s, active: ActiveConversation.test());
      await pumped(tester, push.registerToken('tok-1'));
      expect((b.bodies['POST /devices'] as Map)['fcmToken'], 'tok-1');
      expect(push.registrar.registered, isTrue);
    });

    testWidgets('jeton yenilenince yeni jeton kaydedilir, eski jetonun kaydı silinir (çift bildirim olmaz)', (tester) async {
      await pumpShell(tester);
      s.api.tokens = Tokens('access', 'refresh');
      push = PushService(s, active: ActiveConversation.test());
      await pumped(tester, push.registerToken('tok-old'));
      await pumped(tester, push.registerToken('tok-new'));
      await tester.pump();
      expect((b.bodies['POST /devices'] as Map)['fcmToken'], 'tok-new');
      expect(b.requests, contains('DELETE /devices/tok-old'));
      expect(b.requests.where((r) => r.startsWith('POST /devices')).length, 2);
    });

    testWidgets('aynı jeton yeniden bildirilirse tekrar kayıt / silme yok', (tester) async {
      await pumpShell(tester);
      push = PushService(s, active: ActiveConversation.test());
      await pumped(tester, push.registerToken('tok-1'));
      await pumped(tester, push.registerToken('tok-1'));
      expect(b.requests.where((r) => r.startsWith('POST /devices')).length, 1);
      expect(b.requests.where((r) => r.startsWith('DELETE /devices')), isEmpty);
    });

    testWidgets('oturum yokken jeton kaydedilmez', (tester) async {
      await pumpShell(tester, signedIn: false);
      push = PushService(s, active: ActiveConversation.test());
      await pumped(tester, push.registerToken('tok-1'));
      expect(b.requests.where((r) => r.contains('/devices')), isEmpty);
    });

    testWidgets('bildirim izni geri alınınca cihaz kaydı silinir; izin verilince yeniden kaydedilir', (tester) async {
      await pumpShell(tester);
      push = PushService(s, active: ActiveConversation.test());
      await pumped(tester, push.registerToken('tok-1'));
      expect(push.registrar.registered, isTrue);

      await pumped(tester, push.handlePermissionDenied());
      expect(b.requests, contains('DELETE /devices/tok-1'));
      expect(push.registrar.registered, isFalse);
      expect(push.registrar.needsRefresh, isTrue); // izin verilince refresh() yeniden kaydeder
      expect(push.permissionDenied, isTrue);

      // İkinci çağrı (zaten silindi): ağ isteği yok.
      final before = b.requests.length;
      await pumped(tester, push.handlePermissionDenied());
      expect(b.requests.length, before);

      await pumped(tester, push.registerToken('tok-1')); // izin tekrar verildi
      expect(b.requests.where((r) => r.startsWith('POST /devices')).length, 2);
      expect(push.registrar.registered, isTrue);
    });

    testWidgets('izin geri alma: silme başarısız olursa kayıt durumu korunur (sonra yeniden denenir)', (tester) async {
      await pumpShell(tester);
      push = PushService(s, active: ActiveConversation.test());
      await pumped(tester, push.registerToken('tok-1'));
      b.network('/devices/tok-1');
      await pumped(tester, push.handlePermissionDenied());
      expect(push.registrar.registered, isTrue);
    });
  });
}
