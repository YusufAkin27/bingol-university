import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/push_banner.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_service.dart';
import 'package:bu_kampus/core/push/rich/rich_notifications.dart';
import 'package:bu_kampus/core/push/rich/rich_notifier.dart';
import 'package:bu_kampus/core/push/rich/rich_card.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse, NotificationResponseType;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Ön plan şeridi (tasarım 08 üst kısım), zengin yük yönlendirmesi, arka plan oturumu ve eski yol regresyonu.

Future<PushBannerCenter> _mount(WidgetTester tester) async {
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(MaterialApp(
    navigatorKey: rootNavigatorKey,
    theme: BuTheme.light(),
    home: const Scaffold(body: Text('kabuk')),
  ));
  return PushBannerCenter();
}

void main() {
  setUpAll(loadTestFonts);

  group('bannerPresentation (saf)', () {
    test('sohbet = avatar + Yanıtla; etkinlik = tarih karosu + Detay; duyuru/haber = megafon', () {
      expect(bannerPresentation({'conversationId': '7'}), (lead: BannerLead.avatar, cta: BannerCta.reply));
      expect(bannerPresentation({'type': 'MESSAGE'}), (lead: BannerLead.avatar, cta: BannerCta.reply));
      expect(bannerPresentation({'type': 'EVENT', 'eventId': '3'}), (lead: BannerLead.dateTile, cta: BannerCta.detail));
      expect(bannerPresentation({'targetType': 'EVENT', 'targetId': '3'}), (lead: BannerLead.dateTile, cta: BannerCta.detail));
      expect(bannerPresentation({'type': 'ANNOUNCEMENT', 'targetType': 'ANNOUNCEMENT', 'targetId': '4'}), (lead: BannerLead.megaphone, cta: BannerCta.none));
      expect(bannerPresentation({'type': 'NEWS', 'newsId': '9'}), (lead: BannerLead.megaphone, cta: BannerCta.none));
    });

    test('kişi avatarı olan sosyal bildirim avatar gösterir, eylem hapı yok; bilinmeyen simge karosu', () {
      expect(bannerPresentation({'type': 'USER_FOLLOW', 'senderAvatarUrl': 'https://x/a.png'}), (lead: BannerLead.avatar, cta: BannerCta.none));
      expect(bannerPresentation({}), (lead: BannerLead.icon, cta: BannerCta.none));
    });
  });

  group('şerit (widget)', () {
    testWidgets('sohbet: avatar rozeti + "Yanıtla" hapı; hapa dokunmak sohbeti açar (kart ile aynı yol)', (tester) async {
      final center = await _mount(tester);
      Map<String, dynamic>? tapped;
      center.show(BannerItem(key: 'conv-1', title: 'Ayşe Yılmaz', body: 'Yarınki derse geliyor musun?', data: const {'conversationId': '1'}),
          onTap: (d) => tapped = d);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('BU KAMPÜS'), findsOneWidget);
      expect(find.text('şimdi'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Yanıtla'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('banner-cta')));
      await tester.pump();
      expect(tapped?['conversationId'], '1');
      expect(find.text('Ayşe Yılmaz'), findsNothing);
      center.hide();
      await tester.pump();
    });

    testWidgets('etkinlik: tarih karosu (KAS 2) + "Detay"', (tester) async {
      final center = await _mount(tester);
      center.show(
          BannerItem(key: 'EVENT-3', title: 'Yapay Zekâ Atölyesi', body: '14:00 · Konferans Salonu', data: const {
            'type': 'EVENT',
            'eventId': '3',
            'startsAt': '2026-11-02T12:00:00',
          }),
          onTap: (_) {});
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Detay'), findsOneWidget);
      expect(find.text('KAS'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      center.hide();
      await tester.pump();
    });

    testWidgets('etkinlik başlangıcı yoksa takvim simgeli karo', (tester) async {
      final center = await _mount(tester);
      center.show(BannerItem(key: 'EVENT-3', title: 'Etkinlik', body: 'x', data: const {'type': 'EVENT', 'eventId': '3'}), onTap: (_) {});
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Detay'), findsOneWidget);
      expect(find.text('KAS'), findsNothing);
      center.hide();
      await tester.pump();
    });

    testWidgets('duyuru: megafon karosu, eylem hapı yok', (tester) async {
      final center = await _mount(tester);
      center.show(
          BannerItem(key: 'a', title: 'Akademik takvim güncellendi', body: 'Bahar dönemi...', data: const {'type': 'ANNOUNCEMENT', 'targetType': 'ANNOUNCEMENT', 'targetId': '4'}),
          onTap: (_) {});
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Akademik takvim güncellendi'), findsOneWidget);
      expect(find.byKey(const ValueKey('banner-cta')), findsNothing);
      center.hide();
      await tester.pump();
    });

    testWidgets('kapatma (X) şeridi kaldırır, yönlendirme yapmaz', (tester) async {
      final center = await _mount(tester);
      var tapped = false;
      center.show(BannerItem(key: 'conv-1', title: 'Ayşe', body: 'merhaba', data: const {'conversationId': '1'}), onTap: (_) => tapped = true);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300)); // giriş animasyonu bitsin
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ayşe'), findsNothing);
      expect(tapped, isFalse);
      center.hide();
      await tester.pump();
    });

    testWidgets('birleşme: "+1 yeni mesaj daha" ve hap birlikte; boş gövdede başlık 2 satır', (tester) async {
      final center = await _mount(tester);
      void show(String body) => center.show(BannerItem(key: 'conv-1', title: 'Ayşe', body: body, data: const {'conversationId': '1'}), onTap: (_) {});
      show('a');
      show('b');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('+1 yeni mesaj daha'), findsOneWidget);
      expect(find.text('Yanıtla'), findsOneWidget);
      expect(tester.takeException(), isNull);
      center.hide();
      await tester.pump();
    });
  });

  group('PushService: zengin yük yönlendirmesi', () {
    late FakeBackend b;
    late PushService svc;

    Future<void> pumpShell(WidgetTester tester) async {
      useScreen(tester, kPhoneMedium);
      b = FakeBackend()..on('/notifications', {'items': <Object>[], 'unreadCount': 0, 'nextCursor': null});
      final s = makeSession(b);
      PushRouter.session = s;
      svc = PushService(s);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        home: const Scaffold(body: Text('kabuk')),
      ));
    }

    NotificationResponse resp({String? action, Map<String, String>? data, String? input}) => NotificationResponse(
          notificationResponseType: action == null ? NotificationResponseType.selectedNotification : NotificationResponseType.selectedNotificationAction,
          actionId: action,
          input: input,
          payload: richPayloadOf(RichCard.tryParse({'richChat': '1', 'title': 'T', 'body': 'B', ...?data})!),
        );

    testWidgets('bildirime dokunma: bilinmeyen hedef Bildirimler listesine düşer', (tester) async {
      await pumpShell(tester);
      await svc.handleRichResponse(resp(data: {'targetType': 'ALIEN', 'targetId': '1'}));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('arayüz açan eylem (şifre sıfırla) Hesap ve güvenlik ekranını açar', (tester) async {
      await pumpShell(tester);
      await svc.handleRichResponse(resp(action: 'reset_password', data: {'type': 'SYSTEM', 'channelId': 'security', 'subtype': 'PASSWORD_CHANGED'}));
      await tester.pumpAndSettle();
      expect(find.byType(AccountSecurityPage), findsOneWidget);
    });

    testWidgets('arka plan eylemi ana isolate\'te işlenmez (çift istek olmasın)', (tester) async {
      await pumpShell(tester);
      await svc.handleRichResponse(resp(action: 'reply', input: 'merhaba', data: {'type': 'MESSAGE', 'conversationId': '7', 'channelId': 'chat'}));
      await tester.pumpAndSettle();
      expect(b.requests.where((r) => r.startsWith('POST')), isEmpty);
      expect(find.byType(NotificationsPage), findsNothing);
    });

    testWidgets('bozuk/boş yük sessizce yok sayılır', (tester) async {
      await pumpShell(tester);
      await svc.handleRichResponse(const NotificationResponse(notificationResponseType: NotificationResponseType.selectedNotification, payload: 'bozuk{'));
      await svc.handleRichResponse(const NotificationResponse(notificationResponseType: NotificationResponseType.selectedNotification));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(NotificationsPage), findsNothing);
    });
  });

  group('arka plan oturumu (openBackgroundApi) + eylem yürütme', () {
    test('kayıtlı belirteçlerle istemci kurulur; yanıt eylemi POST /conversations/7/messages', () async {
      FlutterSecureStorage.setMockInitialValues({'access': 'A1', 'refresh': 'R1', 'app_language': 'en'});
      final be = FakeBackend();
      final api = await openBackgroundApi(client: ApiClient(client: be.client, retryDelay: Duration.zero));
      expect(api, isNotNull);
      expect(api!.tokens!.access, 'A1');
      expect(api.lang, 'en');
      final events = <String>[];
      final runner = buildRunner(_FakeNotifier(events), execOf(api));
      final r = await runner.run('reply', {'richChat': '1', 'title': 'T', 'body': 'B', 'type': 'MESSAGE', 'conversationId': '7', 'tag': 'conv:7'}, input: 'Geliyorum');
      expect(r.outcome.name, 'done');
      expect((be.bodies['POST /conversations/7/messages'] as Map)['text'], 'Geliyorum');
      expect(events, ['remove conv:7']);
    });

    test('oturum yoksa ya da çıkış işareti varsa null (eylem "gönderilemedi" ile biter)', () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await openBackgroundApi(client: ApiClient(client: FakeBackend().client)), isNull);
      FlutterSecureStorage.setMockInitialValues({'access': 'A', 'refresh': 'R', 'signed_out': '1'});
      expect(await openBackgroundApi(client: ApiClient(client: FakeBackend().client)), isNull);
      FlutterSecureStorage.setMockInitialValues({'access': 'A'});
      expect(await openBackgroundApi(client: ApiClient(client: FakeBackend().client)), isNull);
    });

    test('belirteç yenilenirse güvenli depoya geri yazılır (tek kullanımlık refresh)', () async {
      FlutterSecureStorage.setMockInitialValues({'access': 'OLD', 'refresh': 'R1'});
      final be = FakeBackend();
      var first = true;
      be.handlers.add((req, path) {
        if (path == '/conversations/7/read' && first) {
          first = false;
          return const FakeResult.json({'code': 'TOKEN_EXPIRED', 'message': ''}, status: 401);
        }
        if (path == '/auth/refresh') return const FakeResult.json({'accessToken': 'NEW', 'refreshToken': 'R2'});
        return null;
      });
      const storage = FlutterSecureStorage();
      final api = await openBackgroundApi(storage: storage, client: ApiClient(client: be.client, retryDelay: Duration.zero));
      final events = <String>[];
      final r = await buildRunner(_FakeNotifier(events), execOf(api!))
          .run('mark_read', {'richChat': '1', 'title': 'T', 'body': 'B', 'type': 'MESSAGE', 'conversationId': '7', 'messageId': '55', 'tag': 'conv:7'});
      expect(r.outcome.name, 'done');
      expect(await storage.read(key: 'access'), 'NEW');
      expect(await storage.read(key: 'refresh'), 'R2');
    });
  });

  group('eski yol regresyonu', () {
    test('richChat olmayan (notification bloklu) yük zengin yola GİRMEZ', () async {
      expect(RichCard.tryParse({'type': 'MESSAGE', 'title': 'A', 'body': 'x', 'conversationId': '1'}), isNull);
      // Arka plan işleyicisi richChat yoksa hiçbir şey çizmez ve eklentiye dokunmaz.
      expect(await handleRichBackgroundMessage({'type': 'MESSAGE', 'title': 'A', 'body': 'x'}), isFalse);
      expect(await handleRichBackgroundMessage({'richChat': '0', 'title': 'A'}), isFalse);
    });

    testWidgets('ön plan: standart yük (notification bloğu) başlık/gövdeyi korur; zengin veri-mesajı data\'dan okur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final s = makeSession(FakeBackend());
      final svc = PushService(s);
      await tester.pumpWidget(MaterialApp(navigatorKey: rootNavigatorKey, theme: BuTheme.light(), home: const Scaffold(body: Text('kabuk'))));
      PushBannerCenter.instance.hide();
      expect(svc.handleForeground(title: 'Ayşe', body: 'Yeni mesaj', data: {'conversationId': '1'}), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ayşe'), findsOneWidget);
      PushBannerCenter.instance.hide();
      await tester.pump();
      // Zengin veri-mesajı: başlık/gövde `data`'da (notification bloğu yok) — PushService._showBanner bunu okur.
      expect(svc.handleForeground(title: 'Elif', body: 'selam', data: {'richChat': '1', 'conversationId': '2', 'title': 'Elif', 'body': 'selam'}), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Elif'), findsOneWidget);
      PushBannerCenter.instance.hide();
      await tester.pump();
    });
  });
}

class _FakeNotifier extends RichNotifications {
  _FakeNotifier(this.events);

  final List<String> events;

  @override
  Future<void> remove(RichCard c) async => events.add('remove ${c.tag}');

  @override
  Future<void> showFailure(RichCard c, {l10n}) async => events.add('fail ${c.tag}');

  @override
  Future<void> showNotMeDone(RichCard c, {l10n}) async => events.add('confirm ${c.tag}');
}
