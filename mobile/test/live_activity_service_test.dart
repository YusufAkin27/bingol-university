import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/live/live_activity_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

LiveSpec spec({DateTime? start, DateTime? end, LiveKind kind = LiveKind.event}) => LiveSpec(
      kind: kind,
      refId: 7,
      title: 'Seminer',
      startsAt: start ?? DateTime.utc(2026, 11, 7, 12),
      endsAt: end ?? DateTime.utc(2026, 11, 7, 14),
      detail: 'Salon A',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 7, 10);

  group('LiveSpec evre hesabi', () {
    test('baslamadan once: baslangica sayar', () {
      final s = spec();
      expect(s.phaseAt(now), LivePhase.upcoming);
      expect(s.targetAt(now), s.startsAt);
    });
    test('surerken: bitise sayar', () {
      final s = spec();
      final n = DateTime.utc(2026, 11, 7, 13);
      expect(s.phaseAt(n), LivePhase.live);
      expect(s.targetAt(n), s.endsAt);
    });
    test('bitmis ya da gecersiz aralik: canli etkinlik baslatilmaz', () {
      expect(spec().phaseAt(DateTime.utc(2026, 11, 7, 15)), isNull);
      expect(spec(end: DateTime.utc(2026, 11, 7, 11)).phaseAt(now), isNull); // bitis < baslangic
    });
    test('kisa kritik metin en cok 7 karakter', () {
      expect(spec().shortCritical(now), '2h');
      expect(spec().shortCritical(DateTime.utc(2026, 11, 7, 11, 30)), '30m');
    });
  });

  group('Android yolu (kanal)', () {
    final calls = <MethodCall>[];
    setUp(() {
      calls.clear();
      LiveActivityService.debugIsIos = false;
      LiveActivityService.debugIsAndroid = true;
      LiveActivityService.clock = () => now;
      LiveActivityService.resetForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('bu_kampus/live_updates'), (c) async {
        calls.add(c);
        return c.method == 'isSupported' || c.method == 'start' ? true : null;
      });
    });
    tearDown(() {
      LiveActivityService.debugIsIos = null;
      LiveActivityService.debugIsAndroid = null;
      LiveActivityService.clock = DateTime.now;
    });

    test('baslat: dogru yuk, sunucuya kayit YOK (Android jetonsuz)', () async {
      final svc = LiveActivityService.of(ApiClient());
      const labels = LiveLabels(startsIn: 'Basliyor', endsIn: 'Bitiyor', channelName: 'Canli');
      expect(await svc.supported(), isTrue);
      expect(await svc.start(spec(), labels), LiveStartResult.started);
      final start = calls.firstWhere((c) => c.method == 'start');
      final a = start.arguments as Map;
      expect(a['kind'], 'EVENT');
      expect(a['refId'], 7);
      expect(a['text'], 'Basliyor - Salon A');
      expect((a['shortText'] as String).length <= 7, isTrue);
      expect(a['targetMs'], spec().startsAt.millisecondsSinceEpoch);
    });

    test('bitmis surec reddedilir, native cagrilmaz', () async {
      final svc = LiveActivityService.of(ApiClient());
      const labels = LiveLabels(startsIn: 'a', endsIn: 'b', channelName: 'c');
      final r = await svc.start(spec(end: DateTime.utc(2026, 11, 7, 9), start: DateTime.utc(2026, 11, 7, 8)), labels);
      expect(r, LiveStartResult.rejected);
      expect(calls.where((c) => c.method == 'start'), isEmpty);
    });

    test('destek yoksa (eksik eklenti) unsupported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('bu_kampus/live_updates'), null);
      final svc = LiveActivityService.of(ApiClient());
      expect(await svc.supported(), isFalse);
      const labels = LiveLabels(startsIn: 'a', endsIn: 'b', channelName: 'c');
      expect(await svc.start(spec(), labels), LiveStartResult.unsupported);
    });

    test('durdur ve cikis temizligi native end/endAll cagirir', () async {
      final svc = LiveActivityService.of(ApiClient());
      await svc.stop(LiveKind.event, 7);
      await LiveActivityService.clearUserData();
      expect(calls.map((c) => c.method), containsAll(['end', 'endAll']));
    });
  });

  group('iOS yolu (kanal)', () {
    setUp(() {
      LiveActivityService.debugIsIos = true;
      LiveActivityService.debugIsAndroid = false;
      LiveActivityService.clock = () => now;
      LiveActivityService.resetForTest();
    });
    tearDown(() {
      LiveActivityService.debugIsIos = null;
      LiveActivityService.debugIsAndroid = null;
      LiveActivityService.clock = DateTime.now;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('bu_kampus/live_activity'), null);
    });

    test('kullanici Canli Etkinlikleri kapattiysa disabledByUser', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('bu_kampus/live_activity'), (c) async {
        if (c.method == 'start') throw PlatformException(code: 'disabled');
        return null;
      });
      final svc = LiveActivityService.of(ApiClient());
      const labels = LiveLabels(startsIn: 'a', endsIn: 'b', channelName: 'c');
      expect(await svc.start(spec(), labels), LiveStartResult.disabledByUser);
    });
  });
}
