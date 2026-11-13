
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/auth/help/help_code_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/password_page.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/support/support_feedback_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// QA-CH turu: push URL hedefi, çift Bildirimler yığılması, geri bildirim platformu, ayarlar izin/silme satırları,
/// yardım kodu ağ hatası, giriş doğrulanmamış akışı, şifre 72 bayt kuralı.
void main() {
  setUpAll(loadTestFonts);

  group('push target=URL', () {
    PushTarget r(Map<String, dynamic> d) => resolvePushTarget(d);

    test('geçerli https adresi PushDest.url olur; kimlik/anahtar gerekmez', () {
      final t = r({'target': 'URL', 'value': 'https://www.bingol.edu.tr/duyuru?id=5'});
      expect(t.dest, PushDest.url);
      expect(t.url, 'https://www.bingol.edu.tr/duyuru?id=5');
      expect(r({'targetType': 'URL', 'targetId': 'https://bukampus.com.tr'}).dest, PushDest.url);
    });

    test('http, javascript, kullanıcı bilgili, ana makinesiz ve boş adres Bildirimler listesine düşer', () {
      const n = PushTarget(PushDest.notifications);
      expect(r({'target': 'URL', 'value': 'http://x.y'}), n);
      expect(r({'target': 'URL', 'value': 'javascript:alert(1)'}), n);
      expect(r({'target': 'URL', 'value': 'https://user:pw@x.y'}), n);
      expect(r({'target': 'URL', 'value': 'https:///yol'}), n);
      expect(r({'target': 'URL', 'value': ''}), n);
      expect(r({'target': 'URL'}), n);
      expect(r({'target': 'URL', 'value': 'https://${'a' * 2100}.com'}), n);
    });
  });

  group('PushRouter.open', () {
    testWidgets('açılamayan hedef: listFallback=false iken Bildirimler üstüne ikinci sayfa yığılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/notifications', {
          'unreadCount': 1,
          'nextCursor': null,
          'items': [
            {
              'id': 1,
              'type': 'ANNOUNCEMENT',
              'title': 'Kapanan sohbet bildirimi',
              'read': false,
              'createdAt': DateTime.now().toIso8601String(),
              'data': {'conversationId': '9'},
            },
          ],
        });
      b.fail('/conversations/9', status: 404, code: 'NOT_FOUND');
      final s = makeSession(b);
      PushRouter.session = s;
      addTearDown(() => PushRouter.session = null);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        home: NotificationsPage(session: s),
      ));
      await settle(tester);
      await tester.tap(find.text('Kapanan sohbet bildirimi'));
      await settle(tester);
      expect(find.byType(NotificationsPage), findsOneWidget, reason: 'ikinci Bildirimler sayfası yığılmamalı');
      expect(find.text('Bu bildirimin hedefi açılamadı.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('listFallback varsayılan: dışarıdan (push) açılamayan hedef Bildirimler listesini açar ve false döner', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/notifications', {'items': <Object>[], 'unreadCount': 0, 'nextCursor': null})
        ..fail('/conversations/9', status: 404, code: 'NOT_FOUND');
      final s = makeSession(b);
      PushRouter.session = s;
      addTearDown(() => PushRouter.session = null);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        home: const Scaffold(body: Text('kabuk')),
      ));
      late Future<bool> res;
      await tester.runAsync(() async {
        res = PushRouter.open({'conversationId': '9'});
        expect(await res, isFalse);
      });
      await settle(tester);
      // Silinmis/erisilemeyen hedef (404): alakasiz listeye dusmek yerine "icerik artik yok" toast'i (G7, push_router).
      expect(find.byType(NotificationsPage), findsNothing);
      expect(find.text('Bu içerik artık mevcut değil.'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('geri bildirim platformu', () {
    Future<Map> send(WidgetTester t) async {
      useScreen(t, const Size(390, 1400));
      final b = FakeBackend()
        ..on('/feedback', {'id': 1})
        ..on('/feedback/mine', {'items': <Object>[], 'nextCursor': null});
      await t.pumpWidget(buildApp(FeedbackPage(session: makeSession(b))));
      await settle(t, const Duration(milliseconds: 700));
      await t.enterText(find.byType(TextField).first, 'Konu');
      await t.enterText(find.byType(TextField).at(1), 'Mesaj');
      await t.pump();
      await t.tap(find.text('Gönder').last);
      await settle(t, const Duration(milliseconds: 600));
      final body = b.bodies['POST /feedback']! as Map;
      await unmount(t);
      return body;
    }

    testWidgets('Android cihaz ANDROID raporlar', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final Map body;
      try {
        body = await send(t);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(body['platform'], 'ANDROID');
      expect(body['appVersion'], isA<String>());
    });

    testWidgets('iOS cihaz IOS raporlar (ANDROID sabiti kalktı)', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final Map body;
      try {
        body = await send(t);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(body['platform'], 'IOS');
    });
  });

  group('Ayarlar', () {
    Future<void> pumpSettings(WidgetTester t, FakeBackend b) async {
      useScreen(t, const Size(390, 1600));
      await t.pumpWidget(buildApp(SettingsPage(session: makeSession(b), themeController: ThemeController())));
      await settle(t, const Duration(milliseconds: 600));
    }

    testWidgets('"Bildirim izni" satırı yalnız bilgi toastı değil, sistem ayarlarını açar', (t) async {
      final prev = PermissionService.instance;
      final fake = FakePermissionService(initial: {AppPermission.notifications: PermState.granted});
      PermissionService.instance = fake;
      addTearDown(() => PermissionService.instance = prev);
      await pumpSettings(t, FakeBackend());
      await t.ensureVisible(find.byKey(const ValueKey('settings-push')));
      await t.tap(find.byKey(const ValueKey('settings-push')));
      await settle(t);
      expect(fake.settingsOpened, 1);
      await unmount(t);
    });

    testWidgets('Ayarlarda "Hesabımı sil" satırı yok (hesap silme Verilerim sayfasında kalır)', (t) async {
      await pumpSettings(t, FakeBackend());
      expect(find.byKey(const ValueKey('settings-delete-account')), findsNothing);
      await unmount(t);
    });

    testWidgets('Ayarlarda "Tüm cihazlardan çık" satırı yok (Hesap güvenliği > Cihazlarıma taşındı)', (t) async {
      await pumpSettings(t, FakeBackend());
      expect(find.byKey(const ValueKey('settings-logout-all')), findsNothing);
      await unmount(t);
    });
  });

  group('yardım kodu', () {
    testWidgets('ağ hatası "kod yanlış" demez ve yazılan kodu silmez; yanlış kod (400) siler', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()..network('/public/support/tickets/verify');
      await t.pumpWidget(buildApp(HelpCodePage(session: makeSession(b), email: 'elif@gmail.com', resend: () async {})));
      await settle(t, const Duration(milliseconds: 900));
      await t.enterText(find.byType(EditableText).first, '528412');
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Kod hatalı veya süresi dolmuş.'), findsNothing);
      expect(tester0(t).controller.text, '528412');
      b.fail('/public/support/tickets/verify', status: 400, code: 'INVALID_CODE', message: 'x');
      await t.enterText(find.byType(EditableText).first, '111111');
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Kod hatalı veya süresi dolmuş.'), findsOneWidget);
      expect(tester0(t).controller.text, isEmpty);
      await unmount(t);
    });
  });

  group('giriş: doğrulanmamış hesap', () {
    testWidgets('kod yeniden gönderilemezse (5xx) doğrulama ekranına düşmez, hata gösterilir', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()
        ..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED', message: 'x')
        ..fail('/auth/resend-code', status: 500, code: 'SERVER_ERROR');
      await t.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await settle(t, const Duration(milliseconds: 900));
      await t.enterText(find.byType(TextFormField).at(0), 'ogr.test@gmail.com');
      await t.enterText(find.byType(TextFormField).at(1), 'Sifre123');
      await t.pump();
      await t.tap(find.text('Giriş yap').last);
      await settle(t, const Duration(milliseconds: 900));
      expect(b.count('POST /auth/resend-code'), greaterThan(0));
      expect(find.byType(VerifyCodePage), findsNothing);
      await unmount(t);
    });

    testWidgets('429 (kod az önce gitmiş): doğrulama ekranına geçilir', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()
        ..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED', message: 'x')
        ..fail('/auth/resend-code', status: 429, code: 'TOO_MANY_REQUESTS');
      await t.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await settle(t, const Duration(milliseconds: 900));
      await t.enterText(find.byType(TextFormField).at(0), 'ogr.test@gmail.com');
      await t.enterText(find.byType(TextFormField).at(1), 'Sifre123');
      await t.pump();
      await t.tap(find.text('Giriş yap').last);
      await settle(t, const Duration(milliseconds: 1200));
      expect(find.byType(VerifyCodePage), findsOneWidget);
      await unmount(t);
    });
  });

  group('sohbet bilgisi dönüşü', () {
    testWidgets('bilgi sayfasında engelleyip dönünce yazma alanı hemen engelli çubuğuna döner', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend()
        ..on('/conversations/1/messages?size=30', {'items': <Object>[], 'nextCursor': null})
        ..on('/conversations/1', {
          'conversation': {'id': 1},
          'members': [
            {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
            {'userId': 11, 'displayName': 'Ali Veli'},
          ],
        })
        ..on('/users/11', {'id': 11, 'displayName': 'Ali Veli'})
        ..on('/users/11/presence', {'online': true})
        ..on('/users/11/block', {});
      await t.pumpWidget(buildApp(ChatDetailPage(
        session: makeSession(b),
        connectRealtime: false,
        conversation: <String, dynamic>{
          'id': 1,
          'type': 'DIRECT',
          'title': 'Ali Veli',
          'peer': {'id': 11, 'displayName': 'Ali Veli'},
        },
      )));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('chatBlockedBar')), findsNothing);
      await t.tap(find.text('Ali Veli').first);
      await settle(t, const Duration(milliseconds: 600));
      final block = find.byKey(const ValueKey('info-block'));
      await t.ensureVisible(block);
      await t.tap(block);
      await settle(t);
      await t.tap(find.text('Engelle').last);
      await settle(t);
      expect(b.count('POST /users/11/block'), 1);
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('chatBlockedBar')), findsOneWidget);
      await unmount(t);
    });
  });

  group('şifre değiştir', () {
    testWidgets('72 bayt kuralı: 40 Türkçe karakter (80 bayt) yerelde reddedilir, istek atılmaz', (t) async {
      useScreen(t, const Size(390, 1600));
      final b = FakeBackend();
      await t.pumpWidget(buildApp(PasswordPage(session: makeSession(b))));
      await settle(t, const Duration(milliseconds: 600));
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'EskiSifre1');
      await t.enterText(fields.at(1), 'ş' * 40);
      await t.enterText(fields.at(2), 'ş' * 40);
      await t.pump();
      await t.tap(find.text('Şifreyi güncelle').last);
      await settle(t);
      expect(find.textContaining('72 bayt'), findsWidgets);
      expect(b.count('POST /auth/change-password'), 0);
      await unmount(t);
    });
  });
}

EditableText tester0(WidgetTester t) => t.widget<EditableText>(find.byType(EditableText).first);
