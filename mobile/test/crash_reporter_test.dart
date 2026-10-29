import 'dart:io';

import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/crash/crash_reporter.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _path = 'POST /app/crash-reports';

StackTrace _stack(int line) => StackTrace.fromString(
    '#0      Foo.bar (package:bu_kampus/features/x/x_page.dart:$line:5)\n'
    '#1      _baz (package:bu_kampus/core/api.dart:77:3)\n'
    '<asynchronous suspension>');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend backend;
  late CrashReporter rep;
  late Directory dir;

  setUp(() async {
    mockSecureStorage();
    ConnectivityService.instance.reset();
    backend = FakeBackend();
    dir = await Directory.systemTemp.createTemp('crash_q');
    rep = CrashReporter(active: true, osVersion: 'Android 14');
    await rep.init(dir: dir);
    rep.attach(makeSession(backend).api);
  });

  tearDown(() async {
    ConnectivityService.instance.reset();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  group('maskeleme', () {
    test('e-posta, jeton, sorgu dizesi, ev dizini ve uzun sayılar temizlenir; dosya yolu kalır', () {
      final out = CrashReporter.scrubStack(
          '#0 login (package:bu_kampus/features/auth/login_page.dart:42:7)\n'
          'Hata ali.veli@bingol.edu.tr https://api.x.com/a?token=abc123&e=a@b.com\n'
          'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.imza_degeri\n'
          'C:\\Users\\Toprak\\dev\\app.dart /Users/ayse/x.dart /data/user/0/edu.bingol/files\n'
          'ogrenci 226051015 tel 5321234567 uuid 123e4567-e89b-12d3-a456-426614174000\n'
          'anahtar a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8');
      for (final s in ['ali.veli', 'a@b.com', 'abc123', 'Toprak', 'ayse', '226051015', '5321234567', '123e4567', 'eyJhbGci', 'a1b2c3d4e5f6']) {
        expect(out, isNot(contains(s)), reason: s);
      }
      expect(out, contains('package:bu_kampus/features/auth/login_page.dart:42:7'));
      expect(out, contains('[eposta]'));
      expect(out, contains('?[gizli]'));
    });

    test('yığın izi satır ve karakter sınırlıdır', () {
      final big = List.generate(300, (i) => '#$i frame$i (package:x/y.dart:1:1)').join('\n');
      final out = CrashReporter.scrubStack(big);
      expect(out.split('\n').length, lessThanOrEqualTo(CrashReporter.maxStackLines));
      expect(out.length, lessThanOrEqualTo(CrashReporter.maxStackChars));
    });

    test('imza satır numarasından bağımsız, tür ve karelerden etkilenir', () {
      String sig(String t, int line) => CrashReporter.signature(t, CrashReporter.scrubStack(_stack(line).toString()));
      expect(sig('StateError', 10), sig('StateError', 99));
      expect(sig('StateError', 10), isNot(sig('TypeError', 10)));
    });

    test('tür adı güvenli karakterlere indirilir', () {
      expect(CrashReporter.sanitizeType(StateError('ali@x.com')), 'StateError');
      expect(CrashReporter.sanitizeType(const [1]), isNotEmpty);
    });
  });

  group('yakalama ve gönderme', () {
    test('etkin değilken (debug/test) hiçbir şey kaydedilmez', () {
      final off = CrashReporter(active: false);
      expect(off.capture(StateError('x'), _stack(1)), isFalse);
      expect(off.pending, 0);
    });

    test('rapor yalnız izin verilen alanları taşır; mesaj ve kimlik yok; anonim gider', () async {
      expect(rep.capture(StateError('ali@bingol.edu.tr gizli'), _stack(10), source: 'platform'), isTrue);
      await rep.flush();
      final body = backend.bodies[_path] as Map;
      expect(body.keys.toSet(), containsAll({'appVersion', 'platform', 'errorType', 'stackTrace', 'fatal', 'occurredAt'}));
      expect(body.keys, isNot(contains('message')));
      expect(body.keys, isNot(contains('userId')));
      expect(body['errorType'], 'StateError');
      expect(body['fatal'], isTrue);
      expect(body['osVersion'], 'Android 14');
      expect(body.toString(), isNot(contains('ali@bingol')));
      expect(rep.pending, 0);
    });

    test('aynı hata oturumda yalnız bir kez gönderilir', () async {
      expect(rep.capture(StateError('a'), _stack(10)), isTrue);
      expect(rep.capture(StateError('b'), _stack(11)), isFalse); // aynı tür + aynı kareler
      expect(rep.capture(ArgumentError('c'), _stack(10)), isTrue); // farklı tür
      await rep.flush();
      expect(backend.count(_path), 2);
    });

    test('çevrimdışıyken yerelde biriktirir, diske yazar; bağlantı gelince gönderir', () async {
      backend.offline = true;
      expect(rep.capture(StateError('a'), _stack(10)), isTrue);
      await rep.flush();
      expect(rep.pending, 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(File('${dir.path}${Platform.pathSeparator}crash_queue.json').existsSync(), isTrue);

      // Uygulama yeniden açılır: kuyruk diskten yüklenir
      final rep2 = CrashReporter(active: true);
      await rep2.init(dir: dir);
      expect(rep2.pending, 1);
      backend.offline = false;
      ConnectivityService.instance.reset();
      rep2.attach(makeSession(backend).api);
      await rep2.flush();
      expect(rep2.pending, 0);
      expect(backend.count(_path), greaterThanOrEqualTo(1));
      expect(File('${dir.path}${Platform.pathSeparator}crash_queue.json').existsSync(), isFalse);
    });

    test('kuyruk en çok 20 kayıt tutar (en eskisi atılır)', () async {
      backend.offline = true;
      ConnectivityService.instance.reportFailure(); // flush çevrimdışı görüp denemesin
      for (var i = 0; i < 30; i++) {
        rep.capture(StateError('e'), StackTrace.fromString('#0 f$i (package:x/f$i.dart:1:1)'));
      }
      expect(rep.pending, CrashReporter.maxQueue);
      expect(rep.queue.first['stackTrace'], contains('f10'));
    });

    test('kalıcı 4xx raporu atar, 429 kuyruğu korur', () async {
      backend.fail('/app/crash-reports', status: 400, code: 'VALIDATION_ERROR');
      rep.capture(StateError('a'), _stack(10));
      await rep.flush();
      expect(rep.pending, 0);

      backend.fail('/app/crash-reports', status: 429, code: 'RATE_LIMITED');
      rep.capture(ArgumentError('b'), _stack(10));
      await rep.flush();
      expect(rep.pending, 1);
    });

    test('ayar kapalıyken kaydedilmez/gönderilmez; kapatınca bekleyenler silinir', () async {
      backend.offline = true;
      rep.capture(StateError('a'), _stack(10));
      await rep.flush();
      expect(rep.pending, 1);
      await rep.setEnabled(false);
      expect(rep.pending, 0);
      expect(rep.capture(ArgumentError('b'), _stack(20)), isFalse);
      backend.offline = false;
      ConnectivityService.instance.reset();
      await rep.flush();
      expect(backend.count(_path), 1); // yalnız çevrimdışı deneme; sonrası hiç gönderilmedi

      // Ayar kalıcıdır: yeni örnek kapalı başlar
      final rep3 = CrashReporter(active: true);
      await rep3.init(dir: dir);
      expect(rep3.enabled, isFalse);
      await rep.setEnabled(true);
    });
  });

  group('ayarlar ekranı', () {
    testWidgets('anahtar varsayılan açık, açıklama metni görünür, kapatınca ayar kapanır', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await CrashReporter.instance.setEnabled(true);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(SettingsPage(session: makeSession(b), themeController: ThemeController())));
      await tester.pump(const Duration(milliseconds: 100));
      final sw = find.byKey(const ValueKey('crashReportsSwitch'));
      await tester.scrollUntilVisible(sw, 200, scrollable: find.byType(Scrollable).first);
      expect(sw, findsOneWidget);
      expect(find.byKey(const ValueKey('crashReportsDesc')), findsOneWidget);
      expect(find.textContaining('anonim bir hata raporu'), findsOneWidget);
      expect(CrashReporter.instance.enabled, isTrue);
      await tester.tap(sw);
      await tester.pump();
      expect(CrashReporter.instance.enabled, isFalse);
      await tester.tap(sw);
      await tester.pump();
      expect(CrashReporter.instance.enabled, isTrue);
    });
  });
}
