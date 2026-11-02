import 'dart:io';

import 'package:bu_kampus/core/analytics.dart';
import 'package:bu_kampus/core/analytics_screens.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/features/auth/reset_success_page.dart';
import 'package:bu_kampus/features/chat/media_camera_page.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_api.dart';
import 'package:bu_kampus/features/polls/poll_models.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/social_api.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/widgets/bu_motion_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _events = 'POST /analytics/events';

class _Clock {
  DateTime t = DateTime.utc(2026, 11, 2, 12);
  DateTime call() => t;
  void add(Duration d) => t = t.add(d);
}

/// Olay günlüğü tutan izleyici (ağ yok).
({ScreenTracker tracker, List<Map<String, dynamic>> log, _Clock clock}) _tracker() {
  final log = <Map<String, dynamic>>[];
  final clock = _Clock();
  final t = ScreenTracker(
    emit: (name, {String? screen, Map<String, dynamic>? props}) => log.add({'name': name, 'screen': screen, 'props': props}),
    now: clock.call,
  );
  return (tracker: t, log: log, clock: clock);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Singleton'ın 20 sn'lik zamanlayıcısı gerçek bölgede kurulsun (testWidgets sahte zamanında "bekleyen zamanlayıcı" olmasın).
  setUpAll(() => Analytics.instance.attach(makeSession(FakeBackend())));

  group('rota -> ekran anahtarı', () {
    testWidgets('eşlenmiş sayfa, bilinmeyen sayfa, kök, adlı rota, Scaffold sarmalı, diyalog', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      String? k(Route<dynamic> r) => screenKeyForRoute(r, ctx);

      expect(k(MaterialPageRoute<void>(builder: (_) => const ResetSuccessPage())), 'reset_success');
      expect(k(MaterialPageRoute<void>(builder: (_) => const MediaCameraPage())), 'media_camera');
      expect(k(BuPageRoute<void>(builder: (_) => const ResetSuccessPage())), 'reset_success'); // PageRouteBuilder
      expect(k(MaterialPageRoute<void>(builder: (_) => const SizedBox())), 'other');
      expect(k(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: ResetSuccessPage()))), 'reset_success');
      expect(k(MaterialPageRoute<void>(builder: (_) => const SizedBox(), settings: const RouteSettings(name: '/forgot-password'))),
          'forgot_password');
      expect(k(MaterialPageRoute<void>(builder: (_) => const SizedBox(), settings: const RouteSettings(name: '/'))), kRootScreen);
      // Oluşturucu fırlatırsa uygulama etkilenmez.
      expect(k(MaterialPageRoute<void>(builder: (_) => throw StateError('x'))), 'other');
      // Diyalog / alt sayfa tam ekran değildir.
      expect(k(DialogRoute<void>(context: ctx, builder: (_) => const SizedBox())), isNull);
      expect(k(ModalBottomSheetRoute<void>(builder: (_) => const SizedBox(), isScrollControlled: false)), isNull);
    });

    test('tüm anahtarlar [a-z0-9_]{1,40} ve benzersiz', () {
      final keys = screenWidgetKeys.values.toList();
      for (final k in keys) {
        expect(isValidScreenKey(k), isTrue, reason: k);
      }
      expect(keys.toSet().length, keys.length, reason: 'çift anahtar');
      for (final k in [...kTabScreens, kOtherScreen]) {
        expect(isValidScreenKey(k), isTrue);
        expect(keys.contains(k), isFalse, reason: 'sekme/other anahtarı sayfaya verilmemeli: $k');
      }
      expect(normalizeScreenKey('/events/42'), 'events_42');
      expect(normalizeScreenKey('///'), isNull);
      expect(normalizeScreenKey('A' * 60)!.length, 40);
    });

    test('lib/features içindeki her genel *Page sınıfı eşlemede (yeni ekran eklenince burada kırılır)', () {
      // Ekran olmayanlar: kapılar, durum görünümleri, kök sayfalar.
      const skip = {
        'AppGate', 'PostLoginGate', 'LegalReacceptGate', 'MenuPhotoGate', 'RefPage', 'AcademicErrorView', 'EmptyView',
        'ErrorView', 'LoadingView', 'ConfigErrorView', 'RenderErrorView', 'AccessBlockedScreen', 'MaintenanceScreen',
        'OfflineScreen', 'UpdateRequiredScreen', 'SplashScreen', 'BuIllustrationView', 'SistemStatusView', 'AnketArtView',
        'QrView', // widget, sayfa değil
      };
      final src = File('lib/core/analytics_screens.dart').readAsStringSync();
      final re = RegExp(r'^class ([A-Z]\w*Page)\b\w* extends (?:StatefulWidget|StatelessWidget)', multiLine: true);
      final missing = <String>[];
      for (final f in Directory('lib/features').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        for (final m in re.allMatches(f.readAsStringSync())) {
          final name = m.group(1)!;
          if (skip.contains(name)) continue;
          if (!RegExp('\\b$name:').hasMatch(src)) missing.add(name);
        }
      }
      expect(missing, isEmpty, reason: 'analytics_screens.dart içine ekleyin: $missing');
    });
  });

  group('ScreenTracker', () {
    test('ilk ekran from/ms taşımaz; sonrakiler from + ms taşır; zincir doğru', () {
      final x = _tracker();
      x.tracker.setRoute('news_list');
      x.clock.add(const Duration(seconds: 3));
      x.tracker.setRoute('news_detail');
      x.clock.add(const Duration(milliseconds: 1500));
      x.tracker.setRoute('news_list'); // geri dönüş
      expect(x.log.map((e) => e['screen']), ['news_list', 'news_detail', 'news_list']);
      expect(x.log[0]['props'], isEmpty);
      expect(x.log[1]['props'], {'from': 'news_list', 'ms': 3000});
      expect(x.log[2]['props'], {'from': 'news_detail', 'ms': 1500});
      expect(x.log.every((e) => e['name'] == 'screen_view'), isTrue);
    });

    test('aynı ekran yinelenmez; ekran yok (null) olay üretmez', () {
      final x = _tracker();
      x.tracker.setRoute(null);
      x.tracker.setRoute('search');
      x.tracker.setRoute('search');
      x.tracker.setRoute(null);
      expect(x.log, hasLength(1));
      expect(x.tracker.current, 'search');
    });

    test('arka planda geçen süre sayılmaz (duraklat/sürdür)', () {
      final x = _tracker();
      x.tracker.setRoute('events');
      x.clock.add(const Duration(seconds: 4));
      x.tracker.pause();
      x.clock.add(const Duration(minutes: 10)); // arka plan
      x.tracker.resume();
      x.clock.add(const Duration(seconds: 6));
      x.tracker.setRoute('event_detail');
      expect(x.log.last['props'], {'from': 'events', 'ms': 10000});
    });

    test('arka planda ekran değişirse yeni ekranın sayacı uygulama dönene dek işlemez', () {
      final x = _tracker();
      x.tracker.setRoute('a');
      x.tracker.pause();
      x.clock.add(const Duration(minutes: 5));
      x.tracker.setRoute('b'); // ör. push yönlendirmesi
      x.clock.add(const Duration(minutes: 5));
      x.tracker.resume();
      x.clock.add(const Duration(seconds: 2));
      x.tracker.setRoute('c');
      expect(x.log.last['props'], {'from': 'b', 'ms': 2000});
    });

    test('süre üst sınırı 30 dk', () {
      final x = _tracker();
      x.tracker.setRoute('a');
      x.clock.add(const Duration(hours: 5));
      x.tracker.setRoute('b');
      expect(x.log.last['props'], {'from': 'a', 'ms': 30 * 60 * 1000});
    });

    test('kök rota görünürken ekran = seçili sekme; sekme değişimi screen_view üretir; sayfa açıkken sekme beklemede', () {
      final x = _tracker();
      x.tracker.setRoute(kRootScreen);
      expect(x.log, isEmpty, reason: 'sekme yokken (giriş öncesi) olay yok');
      x.tracker.setTab('home');
      x.clock.add(const Duration(seconds: 2));
      x.tracker.setTab('chat');
      x.tracker.setRoute('chat_detail');
      x.tracker.setTab('profile'); // sayfa açıkken (push yönlendirmesi): olay yok
      expect(x.log.map((e) => e['screen']), ['home', 'chat', 'chat_detail']);
      x.tracker.setRoute(kRootScreen); // geri: yeni sekmeye döner
      expect(x.log.last['screen'], 'profile');
      expect(x.log.last['props'], containsPair('from', 'chat_detail'));
      expect(x.log[1]['props'], {'from': 'home', 'ms': 2000});
    });

    test('reset: yeni oturumun ilk ekranı from taşımaz', () {
      final x = _tracker();
      x.tracker.setRoute('a');
      x.tracker.reset();
      x.tracker.setRoute('b');
      expect(x.log.last['props'], isEmpty);
    });
  });

  group('AnalyticsNavigatorObserver', () {
    testWidgets('push/pop yığını ekranı izler; diyalog/alt sayfa görüntülenmez; popUntil tek olay', (tester) async {
      final x = _tracker();
      final obs = AnalyticsNavigatorObserver(tracker: x.tracker);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        navigatorObservers: [obs],
        theme: BuTheme.light(),
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox(),
      ));
      x.tracker.setTab('home');
      await tester.pump();
      expect(x.tracker.current, 'home'); // kök rota '/' -> sekme

      final nav = key.currentState!;
      nav.push(MaterialPageRoute<void>(builder: (_) => const ResetSuccessPage()));
      await tester.pumpAndSettle();
      expect(x.tracker.current, 'reset_success');

      // Diyalog ve alt sayfa: ekran değişmez.
      showDialog<void>(context: key.currentContext!, builder: (_) => const AlertDialog(title: Text('x')));
      await tester.pumpAndSettle();
      expect(x.tracker.current, 'reset_success');
      nav.pop();
      await tester.pumpAndSettle();
      showModalBottomSheet<void>(context: key.currentContext!, builder: (_) => const SizedBox(height: 50));
      await tester.pumpAndSettle();
      expect(x.tracker.current, 'reset_success');
      nav.pop();
      await tester.pumpAndSettle();

      nav.push(MaterialPageRoute<void>(builder: (_) => const MediaCameraPage()));
      await tester.pump();
      nav.push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
      await tester.pumpAndSettle();
      final before = x.log.length;
      nav.popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      expect(x.log.length, before + 1, reason: 'ara sayfalar sahte görüntüleme üretmez');
      expect(x.tracker.current, 'home');
      expect(x.log.map((e) => e['screen']).toList().sublist(0, 3), ['home', 'reset_success', 'media_camera']);
    });
  });

  group('Analytics olay kuyruğu', () {
    late FakeBackend backend;
    late Session session;
    late _Clock clock;
    late Analytics a;

    setUp(() async {
      mockSecureStorage();
      ConnectivityService.instance.reset();
      backend = FakeBackend();
      session = makeSession(backend);
      clock = _Clock();
      a = Analytics(now: clock.call, wireErrorLog: false);
      a.attach(session);
      await a.setEnabled(true);
    });

    tearDown(() => a.discard());

    List<Map> sent() {
      final out = <Map>[];
      for (final b in backend.bodyLog[_events] ?? const <Object?>[]) {
        out.addAll(((b as Map)['events'] as List).cast<Map>());
      }
      return out;
    }

    test('olay biçimi: ad, screen (normalize), props sınırları, at', () async {
      a.track('news_open', screen: 'News/Detail', props: {
        'kind': 'x' * 150,
        'n': 3,
        'ok': true,
        'a': 'a', 'b': 'b', 'c': 'c', 'd': 'd', // 5 anahtardan fazlası düşer
        'Bad Key': 'v',
        'obj': {'x': 1},
      });
      await a.flush();
      final e = sent().single;
      expect(e['name'], 'news_open');
      expect(e['screen'], 'news_detail');
      final p = e['props'] as Map;
      expect(p.length, lessThanOrEqualTo(5));
      expect((p['kind'] as String).length, 100);
      expect(p.containsKey('Bad Key'), isFalse);
      expect(p.containsKey('obj'), isFalse);
      expect(e['at'], '2026-11-02T12:00:00.000Z');
    });

    test('geçersiz ad ve "@" içeren değer olayı tümüyle düşürür', () async {
      a.track('News-Open');
      a.track('x' * 41);
      a.track('');
      a.track('share', props: {'to': 'ali@bingol.edu.tr'});
      a.track('share', screen: 'a@b');
      a.track('ok_event');
      await a.flush();
      expect(sent().map((e) => e['name']), ['ok_event']);
    });

    test('screen verilmezse görünen ekran yazılır', () async {
      a.screens.setRoute('menu');
      a.track('menu_view');
      await a.flush();
      expect(sent().last['screen'], 'menu');
    });

    test('kapalıyken olay kuyruğa alınmaz, bekleyenler silinir; ayar kalıcıdır', () async {
      a.track('a_event');
      expect(a.queue, hasLength(1));
      await a.setEnabled(false);
      expect(a.queue, isEmpty);
      a.track('b_event');
      a.screens.setRoute('x');
      expect(a.queue, isEmpty);
      await a.flush();
      expect(backend.count('/analytics/events'), 0);
      final b = Analytics(wireErrorLog: false);
      await b.load();
      expect(b.enabled, isFalse);
      await a.setEnabled(true);
      final c = Analytics(wireErrorLog: false);
      await c.load();
      expect(c.enabled, isTrue);
      a.track('c_event');
      expect(a.queue, hasLength(1));
    });

    test('oturum yokken biriktirme/gönderme yok (kayıt öncesi olaylar dahil)', () async {
      final out = Analytics(wireErrorLog: false)..attach(makeSession(backend, signedIn: false));
      out.track('register_step', props: {'step': 1});
      out.track('register_done');
      out.appOpen();
      expect(out.queue, isEmpty);
      await out.flush();
      expect(backend.count('/analytics/events'), 0);
    });

    test('toplu gönderim en çok 50 olay; kuyruk tavanı 200 (eskiler atılır)', () async {
      for (var i = 0; i < 260; i++) {
        a.track('e$i');
      }
      // 20'de otomatik gönderim tetiklenir; kalanı elle boşaltılır.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(backend.bodyLog[_events]!.every((b) => ((b as Map)['events'] as List).length <= Analytics.maxBatch), isTrue);
      expect(a.queue.length, lessThanOrEqualTo(Analytics.maxQueue));
    });

    test('dakikada en çok 25 istek (sunucu sınırı 30)', () async {
      for (var i = 0; i < 40; i++) {
        a.track('e');
        await a.flush();
      }
      expect(backend.count('/analytics/events'), Analytics.maxRequestsPerMinute);
      clock.add(const Duration(minutes: 1, seconds: 1));
      a.track('e');
      await a.flush();
      expect(backend.count('/analytics/events'), Analytics.maxRequestsPerMinute + 1);
    });

    test('hata: grup atılır (yeniden denenmez), geri çekilme süresince gönderim yok', () async {
      backend.network('/analytics/events');
      a.track('e1');
      await a.flush();
      expect(a.queue, isEmpty, reason: 'olay kaybı kabul');
      backend.reset('/analytics/events');
      a.track('e2');
      await a.flush();
      expect(backend.count('/analytics/events'), 1, reason: 'geri çekilmede');
      clock.add(const Duration(seconds: 31));
      await a.flush();
      expect(backend.count('/analytics/events'), 2);
      expect(sent().last['name'], 'e2');
    });

    test('429 Retry-After süresince beklenir', () async {
      backend.on('/analytics/events', {'code': 'RATE_LIMITED', 'message': ''}, status: 429, headers: {'retry-after': '90'});
      a.track('e1');
      await a.flush();
      backend.reset('/analytics/events');
      a.track('e2');
      clock.add(const Duration(seconds: 60));
      await a.flush();
      expect(backend.count('/analytics/events'), 1);
      clock.add(const Duration(seconds: 40));
      await a.flush();
      expect(backend.count('/analytics/events'), 2);
    });

    test('app_open oturumda bir kez; app_background süre (sn) taşır, kuyruğu boşaltır; dönüşte yeniden app_open', () async {
      a.appOpen();
      a.appOpen(); // çift çağrı tek olay
      clock.add(const Duration(seconds: 95));
      a.onBackground();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sent().map((e) => e['name']), ['app_open', 'app_background']);
      expect((sent().last['props'] as Map)['dur'], 95);
      a.appOpen();
      expect(a.queue.map((e) => e['name']), ['app_open']);
    });

    test('signedIn(): ön plandayken henüz gitmemiş app_open gönderilir (oturum sonradan açıldı)', () async {
      final lateA = Analytics(wireErrorLog: false);
      final s = makeSession(backend, signedIn: false);
      lateA.attach(s);
      lateA.appOpen(); // oturum yok: kuyruğa alınmaz
      expect(lateA.queue, isEmpty);
      s.state = SessionState.signedIn;
      lateA.signedIn();
      expect(lateA.queue.map((e) => e['name']), ['app_open']);
      lateA.signedIn();
      expect(lateA.queue, hasLength(1));
    });

    test('discard: kuyruk + ekran izleyicisi sıfırlanır', () {
      a.screens.setRoute('x');
      a.track('e');
      a.discard();
      expect(a.queue, isEmpty);
      expect(a.screens.current, isNull);
    });
  });

  group('eylem çağrıları ve ayar', () {
    setUp(() async {
      mockSecureStorage();
      ConnectivityService.instance.reset();
      Analytics.instance.discard();
      await Analytics.instance.setEnabled(true);
    });

    tearDown(() => Analytics.instance.discard());

    testWidgets('haber detayı news_open (başlık/içerik yok)', (tester) async {
      final b = FakeBackend()
        ..on('/bookmarks/news/ids', {'ids': []})
        ..on('/bookmarks/news/1', {});
      final s = makeSession(b);
      Analytics.instance.attach(s);
      await tester.pumpWidget(buildApp(NewsDetailPage(session: s, item: newsItem(1, title: 'Gizli başlık metni'))));
      await tester.pump(const Duration(milliseconds: 200));
      expect(Analytics.instance.queue.map((e) => e['name']), contains('news_open'));
      expect(Analytics.instance.queue.first['props'], {'kind': 'news'});
      expect(Analytics.instance.queue.toString(), isNot(contains('Gizli')));
    });

    test('API katmanı eylemleri: poll_vote, post_create, user_follow (kimlik/içerik yok)', () async {
      final b = FakeBackend()
        ..on('/polls/5/vote', {'id': 5, 'title': 'x', 'type': 'SINGLE', 'scope': 'GLOBAL', 'options': []})
        ..on('/posts', {'id': 9})
        ..on('/users/7/follow', {'following': true, 'followerCount': 3});
      final s = makeSession(b);
      Analytics.instance.attach(s);
      try {
        await PollApi(s).vote(5, PollSelection(PollType.single, initial: [1]));
      } catch (_) {}
      try {
        await PostApi(s).create(text: 'Gizli gonderi metni', mediaId: 3);
      } catch (_) {}
      await SocialApi(s).follow(7);
      final q = Analytics.instance.queue;
      expect(q.map((e) => e['name']), containsAll(['poll_vote', 'post_create', 'user_follow']));
      expect(q.toString(), isNot(contains('Gizli')));
      expect(q.every((e) => !e.containsKey('props')), isTrue, reason: 'kimlik/içerik özelliği yok');
    });

    testWidgets('duyuru türü announcement_open üretir', (tester) async {
      final b = FakeBackend()..on('/bookmarks/news/ids', {'ids': []});
      final s = makeSession(b);
      Analytics.instance.attach(s);
      await tester.pumpWidget(buildApp(NewsDetailPage(session: s, item: newsItem(2, type: 'DUYURU'))));
      await tester.pump(const Duration(milliseconds: 200));
      expect(Analytics.instance.queue.map((e) => e['name']), contains('announcement_open'));
    });

    testWidgets('Ayarlar > Gizlilik: "Kullanım istatistikleri" anahtarı varsayılan açık, açıklama görünür, kapatınca olay alınmaz',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final b = FakeBackend();
      final s = makeSession(b);
      Analytics.instance.attach(s);
      await tester.pumpWidget(buildApp(SettingsPage(session: s, themeController: ThemeController())));
      await tester.pump(const Duration(milliseconds: 100));
      final sw = find.byKey(const ValueKey('usageStatsSwitch'));
      await tester.scrollUntilVisible(sw, 200, scrollable: find.byType(Scrollable).first);
      expect(sw, findsOneWidget);
      expect(find.text('Kullanım istatistikleri'), findsOneWidget);
      expect(find.textContaining('kimliksiz ve toplu olarak ölçülür'), findsOneWidget);
      expect(Analytics.instance.enabled, isTrue);
      Analytics.instance.track('before_off');
      expect(Analytics.instance.queue, isNotEmpty);
      await tester.tap(sw);
      await tester.pump();
      expect(Analytics.instance.enabled, isFalse);
      expect(Analytics.instance.queue, isEmpty, reason: 'kapatınca bekleyenler silinir');
      Analytics.instance.track('after_off');
      expect(Analytics.instance.queue, isEmpty);
      await tester.tap(sw);
      await tester.pump();
      expect(Analytics.instance.enabled, isTrue);
    });
  });
}
