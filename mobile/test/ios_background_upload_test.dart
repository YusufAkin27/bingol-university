import 'package:bu_kampus/core/api.dart' show ApiError;
import 'package:bu_kampus/core/transfers/ios_background_upload.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const name = 'bu_kampus/transfers';
  const ch = MethodChannel(name);
  final calls = <MethodCall>[];

  Future<void> emit(String method, Map<String, dynamic> args) async {
    final data = const StandardMethodCodec().encodeMethodCall(MethodCall(method, args));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(name, data, (_) {});
  }

  void mock({Map<String, dynamic>? take, List<String> pending = const []}) {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) async {
      calls.add(c);
      if (c.method == 'bgTake') return take;
      if (c.method == 'bgPending') return pending;
      return null;
    });
  }

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null));

  Future<dynamic> start(IosBackgroundUploader u, {void Function(int, int)? p}) => u.upload(
      taskKey: 'j1', url: 'https://x/api/m', filePath: '/f', fileName: 'a.jpg', mime: 'image/jpeg',
      headers: {'Idempotency-Key': 'k'}, onProgress: p);

  test('basarili yukleme: baslatir, ilerleme ve sonuc', () async {
    mock();
    final u = IosBackgroundUploader(channel: ch);
    int? sent;
    final f = start(u, p: (s, t) => sent = s);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls.where((c) => c.method == 'bgUpload').length, 1);
    await emit('bgProgress', {'taskKey': 'j1', 'sent': 5, 'total': 10});
    await emit('bgDone', {'taskKey': 'j1', 'status': 201, 'body': '{"id":7}'});
    expect(await f, {'id': 7});
    expect(sent, 5);
  });

  test('onceden biten sonuc yeniden baglanir, yeniden baslatmaz', () async {
    mock(take: {'status': 200, 'body': '{"id":3}'});
    final r = await start(IosBackgroundUploader(channel: ch));
    expect(r, {'id': 3});
    expect(calls.any((c) => c.method == 'bgUpload'), isFalse);
  });

  test('suren gorev varsa ikinci kez baslatilmaz', () async {
    mock(pending: ['j1']);
    final u = IosBackgroundUploader(channel: ch);
    final f = start(u);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls.any((c) => c.method == 'bgUpload'), isFalse);
    await emit('bgDone', {'taskKey': 'j1', 'status': 200, 'body': '{}'});
    await f;
  });

  test('401 ApiError, status 0 ag hatasi', () async {
    mock(take: {'status': 401, 'body': '{"code":"UNAUTHORIZED","message":"x"}'});
    await expectLater(start(IosBackgroundUploader(channel: ch)),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)));
    mock(take: {'status': 0, 'body': '', 'error': 'offline'});
    await expectLater(start(IosBackgroundUploader(channel: ch)),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 0)));
  });
}
