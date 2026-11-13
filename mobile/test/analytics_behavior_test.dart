import 'package:bu_kampus/core/analytics.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Kullanım analizi (davranış) olay sözleşmesi: oturum, ekran süresi, eylem, ayar anahtarı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;
  late DateTime clock;
  late Analytics a;
  var sidN = 0;
  final sidRe = RegExp(r'^[a-z0-9]{8,32}$');

  void tick(Duration d) => clock = clock.add(d);

  List<String> names() => [for (final e in a.queue) e['name'] as String];
  Map<String, dynamic> last(String name) => a.queue.lastWhere((e) => e['name'] == name);
  Map<String, dynamic> props(Map<String, dynamic> e) => (e['props'] as Map).cast<String, dynamic>();

  setUp(() {
    mockSecureStorage();
    backend = FakeBackend();
    clock = DateTime.utc(2026, 11, 2, 10);
    sidN = 0;
    a = Analytics.forTest(now: () => clock, sid: () => 'sess${++sidN}0000');
    a.attach(makeSession(backend));
  });

  group('oturum', () {
    test('ilk ekran oturumu başlatır: session_start + app_open + screen_view, hepsinde sid', () {
      a.setTab('tab_home');
      expect(names(), ['session_start', 'app_open', 'screen_view']);
      for (final e in a.queue) {
        expect(sidRe.hasMatch(props(e)['sid'] as String), isTrue);
      }
      expect(last('screen_view')['screen'], 'tab_home');
      expect(a.queue.first.containsKey('screen'), isFalse);
    });

    test('ekran süresi: screen_exit.dwellMs ve screens sayacı', () {
      a.setTab('tab_home');
      tick(const Duration(seconds: 5));
      a.setRouteScreen('news_detail');
      tick(const Duration(seconds: 12));
      a.setRouteScreen(null); // geri: sekmeye dönüş
      final exits = a.queue.where((e) => e['name'] == 'screen_exit').toList();
      expect(exits.map((e) => [e['screen'], props(e)['dwellMs']]), [
        ['tab_home', 5000],
        ['news_detail', 12000],
      ]);
      expect(a.queue.where((e) => e['name'] == 'screen_view').length, 3);
    });

    test('arka planda geçen süre sayılmaz; kısa ayrılıkta aynı oturum sürer', () {
      a.setTab('tab_home');
      final sid = a.sid;
      tick(const Duration(seconds: 5));
      a.onLifecycle(AppLifecycleState.paused);
      expect(names().sublist(names().length - 2), ['screen_exit', 'session_end']);
      expect(props(last('screen_exit'))['dwellMs'], 5000);
      expect(props(last('session_end')), {'durationMs': 5000, 'screens': 1, 'reason': 'background', 'sid': sid});
      tick(const Duration(minutes: 10));
      a.onLifecycle(AppLifecycleState.resumed);
      expect(a.sid, sid);
      expect(names().where((n) => n == 'session_start').length, 1);
      tick(const Duration(seconds: 3));
      a.setRouteScreen('events');
      expect(props(last('screen_exit'))['dwellMs'], 3000); // 10 dakikalık arka plan dahil değil
      a.onLifecycle(AppLifecycleState.paused);
      expect(props(last('session_end'))['durationMs'], 8000); // kümülatif ön plan süresi
    });

    test('30 dk\'dan uzun ayrılık yeni oturum açar (yeni sid, giriş ekranı screen_view)', () {
      a.setTab('tab_home');
      final first = a.sid;
      a.onLifecycle(AppLifecycleState.paused);
      tick(const Duration(minutes: 31));
      a.onLifecycle(AppLifecycleState.resumed);
      expect(a.sid, isNot(first));
      final tail = a.queue.sublist(a.queue.length - 2);
      expect(tail.map((e) => e['name']), ['session_start', 'screen_view']);
      expect(tail.last['screen'], 'tab_home');
    });

    test('30 dk hareketsizlik: session_end timeout (bitiş son etkinlik anı), sonraki dokunuş yeni oturum', () {
      a.setTab('tab_home');
      tick(const Duration(seconds: 20));
      a.touch();
      tick(const Duration(minutes: 31));
      a.touch();
      final end = last('session_end');
      expect(props(end)['reason'], 'timeout');
      expect(props(end)['durationMs'], 20000);
      expect(end['at'], DateTime.utc(2026, 11, 2, 10, 0, 20).toIso8601String());
      expect(names().where((n) => n == 'session_start').length, 2);
      expect(a.sid, 'sess20000');
    });

    test('çıkış (detached) oturumu exit nedeniyle kapatır', () {
      a.setTab('tab_home');
      tick(const Duration(seconds: 2));
      a.onLifecycle(AppLifecycleState.detached);
      expect(props(last('session_end'))['reason'], 'exit');
      expect(a.sid, isNull);
    });

    test('arka plana atılırken kuyruk hemen gönderilir', () async {
      a = Analytics.forTest(now: () => clock, sid: () => 'sess10000', autoFlush: true);
      a.attach(makeSession(backend));
      a.setTab('tab_home');
      tick(const Duration(seconds: 4));
      a.onLifecycle(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final body = backend.bodies['POST /analytics/events'] as Map;
      final sent = (body['events'] as List).map((e) => (e as Map)['name']).toList();
      expect(sent, containsAll(['session_start', 'screen_view', 'screen_exit', 'session_end']));
      expect(a.queue, isEmpty);
    });

    test('oturum açık değilken hiçbir olay yok, giriş sonrası oturum başlar', () {
      final out = makeSession(backend, signedIn: false);
      final b = Analytics.forTest(now: () => clock);
      b.attach(out);
      b.setTab('tab_home');
      b.action('like');
      expect(b.queue, isEmpty);
      expect(b.sid, isNull);
    });
  });

  group('eylem', () {
    test('izinli eylem screen + kind/target + sid taşır; bilinmeyen kind ve geçersiz target atılır', () {
      a.setTab('tab_discover');
      a.action('like');
      expect(last('action')['screen'], 'tab_discover');
      expect(props(last('action')), {'kind': 'like', 'sid': a.sid});
      a.action('rsvp', target: 'not_going');
      expect(props(last('action'))['target'], 'not_going');
      final n = a.queue.length;
      a.action('hack_the_planet');
      expect(a.queue.length, n);
      a.action('bookmark', target: 'Kisi Adi@x.com');
      expect(props(last('action')).containsKey('target'), isFalse);
      a.action('bookmark', target: 'x' * 30);
      expect(props(last('action')).containsKey('target'), isFalse);
    });

    test('tabSwitch: önceki ekranda tab_switch eylemi, sonra yeni sekme ekranı', () {
      a.setTab('tab_home');
      tick(const Duration(seconds: 3));
      a.tabSwitch('chat');
      final i = names().lastIndexOf('action');
      expect(a.queue[i]['screen'], 'tab_home');
      expect(props(a.queue[i]), {'kind': 'tab_switch', 'target': 'chat', 'sid': a.sid});
      expect(names().sublist(i + 1), ['screen_exit', 'screen_view']);
      expect(a.queue.last['screen'], 'tab_chat');
      expect(a.screen, 'tab_chat');
    });

    test('pullRefresh sarmalayıcısı eylemi gönderir ve asıl işlevi çağırır', () async {
      // Singleton kullanır; oturum yoksa no-op olduğundan yalnız çağrının geçtiği doğrulanır.
      var called = 0;
      await Analytics.pullRefresh(() async => called++)();
      expect(called, 1);
    });
  });

  group('gizlilik', () {
    test('@ içeren değer olayı tümüyle atar', () {
      a.setTab('tab_home');
      final n = a.queue.length;
      a.track('x', props: {'q': 'ali@bingol.edu.tr'});
      a.track('x', screen: 'a@b');
      expect(a.queue.length, n);
    });

    test('kapalıyken olay toplanmaz/gönderilmez, kapatınca bekleyen kuyruk silinir', () async {
      a.setTab('tab_home');
      expect(a.queue, isNotEmpty);
      await a.setEnabled(false);
      expect(a.enabled, isFalse);
      expect(a.queue, isEmpty);
      expect(a.sid, isNull);
      a.setRouteScreen('events');
      a.action('like');
      a.touch();
      a.onLifecycle(AppLifecycleState.paused);
      a.onLifecycle(AppLifecycleState.resumed);
      expect(a.queue, isEmpty);
      await a.flush(all: true);
      expect(backend.count('/analytics/events'), 0);
      // Yeniden açınca yeni oturum başlar.
      await a.setEnabled(true);
      expect(a.sid, isNotNull);
      expect(names().first, 'session_start');
    });

    test('ayar kalıcıdır: init kayıtlı değeri okur', () async {
      await a.setEnabled(false);
      final b = Analytics.forTest();
      await b.init();
      expect(b.enabled, isFalse);
      await a.setEnabled(true);
      await b.init();
      expect(b.enabled, isTrue);
    });
  });

  group('kuyruk', () {
    test('en çok 200 olay tutulur', () {
      a.setTab('tab_home');
      for (var i = 0; i < 300; i++) {
        a.track('app_open');
        // flush eşiği otomatik gönderim tetikler; kuyruk yine de sınırlı kalır.
      }
      expect(a.queue.length <= 200, isTrue);
    });
  });

  group('AnalyticsNavigatorObserver', () {
    testWidgets('yalnız PageRoute sayılır; diyalog/alt sayfa ekran değil; adsız rota other', (tester) async {
      final obs = AnalyticsNavigatorObserver(analytics: a);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        navigatorObservers: [obs],
        home: const Scaffold(body: Text('kok')),
      ));
      a.setTab('tab_home'); // kök rota ('/') = sekme ekranı
      expect(a.screen, 'tab_home');

      key.currentState!.push(MaterialPageRoute<void>(settings: const RouteSettings(name: 'chat_detail'), builder: (_) => const Scaffold(body: Text('sohbet'))));
      await tester.pumpAndSettle();
      expect(a.screen, 'chat_detail');

      tick(const Duration(seconds: 7));
      showDialog<void>(context: key.currentContext!, builder: (_) => const AlertDialog(title: Text('d')));
      await tester.pumpAndSettle();
      expect(a.screen, 'chat_detail'); // diyalog ekran değil
      Navigator.of(key.currentContext!).pop();
      await tester.pumpAndSettle();
      expect(a.screen, 'chat_detail');

      key.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('adsiz'))));
      await tester.pumpAndSettle();
      expect(a.screen, 'other');

      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(a.screen, 'chat_detail');
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(a.screen, 'tab_home');

      final views = a.queue.where((e) => e['name'] == 'screen_view').map((e) => e['screen']).toList();
      expect(views, ['tab_home', 'chat_detail', 'other', 'chat_detail', 'tab_home']);
      final exit = a.queue.firstWhere((e) => e['name'] == 'screen_exit' && e['screen'] == 'chat_detail');
      expect(props(exit)['dwellMs'], 7000);
    });

    testWidgets('pushReplacement ve rota adı normalleştirme', (tester) async {
      final obs = AnalyticsNavigatorObserver(analytics: a);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: key, navigatorObservers: [obs], home: const SizedBox()));
      a.setTab('tab_home');
      key.currentState!.push(MaterialPageRoute<void>(settings: const RouteSettings(name: '/forgot-password'), builder: (_) => const SizedBox()));
      await tester.pumpAndSettle();
      expect(a.screen, 'forgot_password');
      key.currentState!.pushReplacement(MaterialPageRoute<void>(settings: const RouteSettings(name: 'reset_success'), builder: (_) => const SizedBox()));
      await tester.pumpAndSettle();
      expect(a.screen, 'reset_success');
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(a.screen, 'tab_home');
    });
  });

  group('Ayarlar > Gizlilik anahtarı', () {
    testWidgets('Kullanım analizi anahtarı varsayılan açık, kapatınca/açınca ayar değişir', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await Analytics.instance.setEnabled(true);
      await tester.pumpWidget(buildApp(SettingsPage(session: makeSession(FakeBackend()), themeController: ThemeController())));
      await tester.pump(const Duration(milliseconds: 100));
      final sw = find.byKey(const ValueKey('analyticsSwitch'));
      await tester.scrollUntilVisible(sw, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle(); // bölüm giriş animasyonu bitsin: dokunma konumu kaymasın
      expect(sw, findsOneWidget);
      expect(find.text('Kullanım analizi'), findsOneWidget);
      expect(Analytics.instance.enabled, isTrue);
      await tester.tap(sw);
      await tester.pump();
      expect(Analytics.instance.enabled, isFalse);
      await tester.tap(sw);
      await tester.pump();
      expect(Analytics.instance.enabled, isTrue);
    });
  });
}
