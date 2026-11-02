import 'package:bu_kampus/core/analytics.dart';
import 'package:bu_kampus/core/analytics_screens.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/push_banner.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/core/push/rich/rich_actions.dart';
import 'package:bu_kampus/core/push/rich/rich_card.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/campus_map/campus_category_page.dart';
import 'package:bu_kampus/features/campus_map/campus_home_card.dart';
import 'package:bu_kampus/features/campus_map/campus_local_store.dart';
import 'package:bu_kampus/features/campus_map/campus_location.dart';
import 'package:bu_kampus/features/campus_map/campus_map_controller.dart';
import 'package:bu_kampus/features/campus_map/campus_map_page.dart';
import 'package:bu_kampus/features/campus_map/campus_nav.dart';
import 'package:bu_kampus/features/campus_map/campus_place_page.dart';
import 'package:bu_kampus/features/campus_map/campus_search_page.dart';
import 'package:bu_kampus/features/home/home_layout.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/notifications/notif_card.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'campus_map/campus_fixtures.dart';
import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// Entegrasyon: bildirim + kampüs haritası + kullanım istatistikleri + hareket sistemi bir arada.
String _iso(Duration ago) => DateTime.now().subtract(ago).toIso8601String();

Future<void> _pumpMs(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<CampusMapController> _ready() async {
  final c = CampusMapController(repo: FakeCampusRepo(), location: FakeCampusLocationService(perm: CampusPerm.deniedForever));
  await c.start();
  return c;
}

List<Map<String, dynamic>> _q() => Analytics.instance.queue;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);
  // Singleton'ın periyodik zamanlayıcısı gerçek bölgede kurulsun (testWidgets sahte zamanında bekleyen zamanlayıcı kalmasın).
  setUpAll(() => Analytics.instance.attach(makeSession(FakeBackend())));
  setUp(() async {
    mockSecureStorage();
    await CampusLocalStore.clear();
    await HomeLayoutStore.clear();
    Analytics.instance.discard();
    await Analytics.instance.setEnabled(true);
    CampusLocationService.instance = FakeCampusLocationService(perm: CampusPerm.deniedForever);
  });
  tearDown(() async {
    Analytics.instance.discard();
    await HomeLayoutStore.clear();
  });

  group('ekran eşlemesi: kampüs sayfaları', () {
    test('dört kampüs sayfası kararlı anahtara eşlenir', () {
      final m = screenWidgetKeys;
      expect(m[CampusMapPage], 'campus_map');
      expect(m[CampusSearchPage], 'campus_search');
      expect(m[CampusCategoryPage], 'campus_category');
      expect(m[CampusPlacePage], 'campus_place');
    });
  });

  group('backend NotifCard uyumu (resolveRichKind)', () {
    RichKind k(Map<String, dynamic> d, [List<String> actions = const []]) =>
        resolveRichKind(d, actions, count: 1, style: RichImageStyle.none);

    test('card alanı alt tür/eylem ipuçlarından önce gelir (EVENT_HOUR, POLL_CLOSING, iptal, 2FA açıldı)', () {
      expect(k({'card': 'EVENT_HOUR', 'type': 'EVENT', 'subtype': 'EVENT_REMINDER'}), RichKind.eventSoon);
      expect(k({'card': 'EVENT_DAY', 'type': 'EVENT', 'subtype': 'EVENT_REMINDER'}), RichKind.eventTomorrow);
      expect(k({'card': 'POLL_CLOSING', 'type': 'ANNOUNCEMENT', 'subtype': 'POLL'}), RichKind.pollClosing);
      expect(k({'card': 'POLL_NEW', 'type': 'ANNOUNCEMENT', 'subtype': 'POLL'}), RichKind.pollNew);
      expect(k({'card': 'EVENT_CANCELLED', 'type': 'EVENT', 'subtype': 'EVENT_UPDATE'}), RichKind.eventCancelled);
      expect(k({'card': 'SECURITY_2FA_ON', 'type': 'SYSTEM', 'channelId': 'security'}, ['view']), RichKind.twoFaChanged);
      expect(k({'card': 'SECURITY_NEW_DEVICE', 'type': 'SYSTEM'}), RichKind.newDeviceLogin);
      expect(k({'card': 'SUPPORT_TICKET', 'type': 'SYSTEM'}), RichKind.supportReply);
      expect(k({'card': 'UNIT_ANNOUNCEMENT', 'type': 'ANNOUNCEMENT'}), RichKind.deptAnnouncement);
      expect(k({'card': 'MENU_TODAY', 'type': 'ANNOUNCEMENT'}), RichKind.menuToday);
      expect(k({'card': 'chat_group'}), RichKind.groupMessage, reason: 'küçük harf de kabul');
    });

    test('bilinmeyen/boş card eski yola düşer; bozuk değer exception atmaz', () {
      expect(k({'card': 'YOK_BOYLE_KART', 'type': 'EVENT', 'subtype': 'EVENT_REMINDER'}, ['qr_checkin']), RichKind.eventSoon);
      expect(k({'card': '', 'type': 'NEWS'}), RichKind.news);
      expect(k({'card': null, 'channelId': 'security'}, ['not_me']), RichKind.newDeviceLogin);
      expect(k({'card': 42}), RichKind.generic);
    });

    test('backend kart adlarının tamamı bir kart türüne eşlenir', () {
      const names = [
        'CHAT_DM', 'CHAT_GROUP', 'CHAT_PHOTO', 'CHAT_MANY', 'EVENT_DAY', 'EVENT_HOUR', 'EVENT_CHANGED', 'EVENT_ADMISSION',
        'EVENT_CANCELLED', 'ANNOUNCEMENT', 'UNIT_ANNOUNCEMENT', 'ACADEMIC_ANNOUNCEMENT', 'NEWS', 'EXAM_REMINDER',
        'MENU_TODAY', 'POLL_NEW', 'POLL_CLOSING', 'POST_LIKE', 'USER_FOLLOW', 'FOLLOW_REQUEST', 'FOLLOW_ACCEPTED',
        'SECURITY_NEW_DEVICE', 'SECURITY_PASSWORD', 'SECURITY_2FA_OFF', 'SECURITY_2FA_ON', 'SECURITY_SESSION', 'SUPPORT_TICKET',
      ];
      for (final n in names) {
        expect(richKindOfCard(n), isNotNull, reason: n);
        expect(richKindOfCard(n), isNot(RichKind.generic), reason: n);
      }
      expect(kBackendCardKinds.keys.toSet(), names.toSet());
    });

    test('kart satırı: notifKindOf satırdaki card alanını da kullanır', () {
      expect(notifKindOf({'type': 'ANNOUNCEMENT', 'card': 'POLL_CLOSING'}, const {}), RichKind.pollClosing);
      expect(notifKindOf({'type': 'SYSTEM'}, {'card': 'SECURITY_PASSWORD'}), RichKind.passwordChanged);
      expect(notifKindOf({'type': 'EVENT', 'subtype': 'EVENT_ADMISSION'}, const {}), RichKind.eventApproved);
    });

    test('backend targetType=SECURITY hesap ve güvenlik ekranına; UNIT_NEWS/MENU henüz bildirim listesine düşer (güvenli)', () {
      expect(resolvePushTarget({'targetType': 'SECURITY', 'target': 'SECURITY'}).dest, PushDest.accountSecurity);
      expect(resolvePushTarget({'targetType': 'UNIT_NEWS', 'targetId': '4'}).dest, PushDest.notifications);
      expect(resolvePushTarget({'targetType': 'MENU', 'targetId': '2026-11-03'}).dest, PushDest.notifications);
    });

    test('takip isteği: backend requestId/userId ile kabul-red isteği kurulur', () {
      final accept = planRichAction('accept', {'requestId': '33'});
      expect(accept, isA<HttpPlan>());
      expect((accept as HttpPlan).path, '/users/me/follow-requests/33/accept');
      final reject = planRichAction('reject', {'userId': '33', 'requestId': '33'}) as HttpPlan;
      expect(reject.path, '/users/me/follow-requests/33/decline');
      expect((planRichAction('follow_back', {'userId': '9'}) as HttpPlan).path, '/users/9/follow');
    });
  });

  group('kullanım istatistiği: bildirim + harita', () {
    testWidgets('bildirim listesinde hedefsiz satıra dokunmak notification_open {kind} yazar; metin/kimlik yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/notifications', {
          'unreadCount': 1,
          'nextCursor': null,
          'items': [
            {
              'id': 3,
              'type': 'ANNOUNCEMENT',
              'subtype': 'ACADEMIC_ANNOUNCEMENT',
              'title': 'Gizli akademik başlık',
              'body': 'Gizli gövde metni',
              'read': false,
              'createdAt': _iso(const Duration(minutes: 70)),
            },
          ],
        });
      final s = makeSession(b);
      Analytics.instance.attach(s);
      await tester.pumpWidget(buildApp(NotificationsPage(session: s)));
      await settle(tester);
      await tester.tap(find.text('Gizli akademik başlık'));
      await settle(tester);
      final ev = _q().where((e) => e['name'] == 'notification_open').toList();
      expect(ev, hasLength(1));
      expect(ev.single['props'], {'kind': 'notifications'});
      expect(_q().toString(), isNot(contains('Gizli')));
      await unmount(tester);
    });

    testWidgets('PushRouter.open (push/şerit/zengin eylem yolu) hedef türünü yazar, kimlik yazmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/notifications', {'unreadCount': 0, 'nextCursor': null, 'items': []});
      final s = makeSession(b);
      Analytics.instance.attach(s);
      PushRouter.session = s;
      addTearDown(() => PushRouter.session = null);
      await tester.pumpWidget(MaterialApp(navigatorKey: rootNavigatorKey, theme: BuTheme.light(), home: const Scaffold(body: Text('kabuk'))));
      await PushRouter.open({'targetType': 'ACCOUNT_SECURITY'});
      await tester.pump(const Duration(milliseconds: 100));
      final ev = _q().where((e) => e['name'] == 'notification_open').toList();
      expect(ev, hasLength(1));
      expect(ev.single['props'], {'kind': resolvePushTarget({'targetType': 'ACCOUNT_SECURITY'}).dest.name});
      await PushRouter.open({'conversationId': '555'});
      expect(_q().toString(), isNot(contains('555')));
      expect(_q().where((e) => e['name'] == 'notification_open').length, 2);
    });

    test('kampüs kategori etiketi güvenli ve kısa', () {
      expect(campusKindLabel('faculty'), 'faculty');
      expect(campusKindLabel('Yurt & Konut'), 'yurt_konut');
      expect(campusKindLabel(''), 'other');
      expect(campusKindLabel('a' * 90).length, 40);
    });

    testWidgets('yer detayı map_place_open {kind: kategori} yazar; Paylaş share {kind: campus_place} yazar (ad/koordinat yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final s = makeSession(FakeBackend());
      Analytics.instance.attach(s);
      final c = await _ready();
      final place = c.places.first;
      await tester.pumpWidget(p00App(CampusPlacePage(controller: c, place: place, tileProvider: NoTiles()), scaffold: false));
      await _pumpMs(tester);
      final open = _q().where((e) => e['name'] == 'map_place_open').toList();
      expect(open, hasLength(1));
      expect(open.single['props'], {'kind': 'faculty'});
      await tester.ensureVisible(find.text('Paylaş'));
      await _pumpMs(tester, 300);
      await tester.tap(find.text('Paylaş'));
      await _pumpMs(tester);
      final share = _q().where((e) => e['name'] == 'share').toList();
      expect(share, hasLength(1));
      expect(share.single['props'], {'kind': 'campus_place'});
      expect(_q().toString(), isNot(contains('Mühendislik')));
      expect(_q().toString(), isNot(contains('38.89')));
      await tester.pump(const Duration(seconds: 6));
      c.dispose();
    });
  });

  group('ana sayfa kartı -> harita sayfası', () {
    testWidgets('kart çipine dokununca harita sayfası açılır ve ekran anahtarı campus_map olur', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = FakeBackend()
        ..on('/menu/today', {'date': '2026-01-01', 'items': ['Mercimek çorbası']})
        ..on('/campus/map', campusMapJson())
        ..on('/campus/places?limit=500', campusPlacesJson());
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: s, onOpenTab: (i, {newsType}) {}))));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(CampusHomeCard), findsOneWidget);
      await tester.ensureVisible(find.text('Yemekhane'));
      await tester.tap(find.text('Yemekhane'));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(CampusMapPage), findsOneWidget);
      expect(screenWidgetKeys[tester.widget(find.byType(CampusMapPage)).runtimeType], 'campus_map');
      await unmount(tester);
    });
  });

  group('hareket: azaltılmış harekette yeni yüzeyler', () {
    testWidgets('kampüs ana sayfası azaltılmış harekette hatasız açılır (durum geçişi yalnız solma)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final c = await _ready();
      final repo = FakeCampusRepo();
      await tester.pumpWidget(p00App(CampusMapPage(repository: repo, controller: c, tileProvider: NoTiles()), scaffold: false, disableAnimations: true));
      await _pumpMs(tester, 300);
      expect(find.byType(CampusMapPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('kampüs arama sayfası: boş -> sonuç geçişi azaltılmış harekette de çalışır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final c = await _ready();
      await tester.pumpWidget(p00App(CampusSearchPage(controller: c, tileProvider: NoTiles()), scaffold: false, disableAnimations: true));
      await _pumpMs(tester, 300);
      await tester.enterText(find.byType(TextField), 'kütüphane');
      await _pumpMs(tester, 300);
      expect(find.textContaining('Merkez Kütüphane'), findsWidgets);
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('şerit: normalde üstten kayarak iner, azaltılmış harekette yerinde solar', (tester) async {
      Future<(double, double)> sample(bool reduced) async {
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(p00App(const Text('kabuk'), disableAnimations: reduced).copyWithNavigatorKey());
        final center = PushBannerCenter();
        center.show(BannerItem(key: 'k', title: 'Ayşe', body: 'selam', data: const {'conversationId': '1'}), onTap: (_) {});
        await tester.pump(const Duration(milliseconds: 60));
        final early = tester.getTopLeft(find.text('Ayşe')).dy;
        await tester.pump(const Duration(milliseconds: 400));
        final late = tester.getTopLeft(find.text('Ayşe')).dy;
        center.hide();
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        return (early, late);
      }

      final normal = await sample(false);
      expect(normal.$1, lessThan(normal.$2), reason: 'normal harekette kayarak iner');
      final reduced = await sample(true);
      expect(reduced.$1, reduced.$2, reason: 'azaltılmış harekette kayma yok (yalnız solma)');
    });

    testWidgets('şerit: süre dolunca önce çıkış animasyonu (~210 ms), sonra kalkar', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(p00App(const Text('kabuk')).copyWithNavigatorKey());
      final center = PushBannerCenter(duration: const Duration(seconds: 1));
      center.show(BannerItem(key: 'k', title: 'Ayşe', body: 'selam', data: const {'conversationId': '1'}), onTap: (_) {});
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Ayşe'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700)); // 1 sn doldu: çıkış başladı
      await tester.pump(const Duration(milliseconds: 100));
      expect(center.leaving.value, isTrue);
      expect(find.text('Ayşe'), findsOneWidget, reason: 'çıkış sürüyor');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ayşe'), findsNothing);
      expect(center.leaving.value, isFalse);
    });
  });
}

extension on Widget {
  /// Kök gezgin anahtarını MaterialApp'e bağlar (şerit bindirmesi için).
  Widget copyWithNavigatorKey() {
    final app = this as MaterialApp;
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: app.theme,
      locale: app.locale,
      supportedLocales: app.supportedLocales,
      localizationsDelegates: app.localizationsDelegates,
      builder: app.builder,
      home: app.home,
    );
  }
}
