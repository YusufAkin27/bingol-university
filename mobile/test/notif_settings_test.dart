import 'package:bu_kampus/core/platform/notif_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ChannelNotifSettings.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'hidePreview':
          return true;
        case 'notificationsEnabled':
          return false;
        default:
          return true;
      }
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ChannelNotifSettings.channel, null);
  });

  group('ChannelNotifSettings (Android)', () {
    final svc = ChannelNotifSettings(android: true);

    test('kanal ayarı doğru kanalı ister', () async {
      expect(await svc.openChannelSettings('chat'), isTrue);
      expect(calls.single.method, 'openChannelSettings');
      expect(calls.single.arguments, {'channelId': 'chat'});
    });

    test('uygulama bildirim ayarı + önizleme gizleme + izin okuma', () async {
      expect(await svc.openAppNotificationSettings(), isTrue);
      expect(await svc.setHidePreview(true), isTrue);
      expect(calls.last.arguments, {'hide': true});
      expect(await svc.hidePreview(), isTrue);
      expect(await svc.notificationsEnabled(), isFalse);
    });
  });

  group('Android dışı / native yok', () {
    test('iOS/test: hepsi sessizce false (izin: true), kanala çağrı gitmez', () async {
      final svc = ChannelNotifSettings(android: false);
      expect(await svc.openChannelSettings('chat'), isFalse);
      expect(await svc.setHidePreview(true), isFalse);
      expect(await svc.notificationsEnabled(), isTrue);
      expect(calls, isEmpty);
    });

    test('MissingPluginException yutulur', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ChannelNotifSettings.channel, null);
      final svc = ChannelNotifSettings(android: true);
      expect(await svc.openAppNotificationSettings(), isFalse);
      expect(await svc.notificationsEnabled(), isTrue);
    });

    test('PlatformException yutulur', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          ChannelNotifSettings.channel, (call) async => throw PlatformException(code: 'X'));
      expect(await ChannelNotifSettings(android: true).openChannelSettings('chat'), isFalse);
    });
  });

  test('FakeNotifSettings kayıt tutar', () async {
    final fake = FakeNotifSettings();
    await fake.openChannelSettings('social');
    await fake.openAppNotificationSettings();
    await fake.setHidePreview(true);
    expect(fake.openedChannels, ['social']);
    expect(fake.appSettingsOpened, 1);
    expect(await fake.hidePreview(), isTrue);
    expect(await FakeNotifSettings(canOpen: false).openChannelSettings('chat'), isFalse);
  });
}
