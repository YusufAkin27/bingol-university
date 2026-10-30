import 'package:bu_kampus/core/push/icon_badge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ch = MethodChannel('bu_kampus/badge');
  late List<int> sent;

  setUp(() {
    sent = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (call) async {
      expect(call.method, 'set');
      sent.add((call.arguments as Map)['count'] as int);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null);
  });

  test('iOS: ilk deger hemen, sonra yalniz degisimler gonderilir; cikista sifirlanir', () async {
    final src = ValueNotifier<int>(2);
    final b = IconBadge(channel: ch, isIOS: true);
    b.attach(src);
    await Future<void>.delayed(Duration.zero);
    expect(sent, [2]);

    src.value = 2; // ayni deger: bildirim yok
    src.value = 5;
    src.value = 0;
    await Future<void>.delayed(Duration.zero);
    expect(sent, [2, 5, 0]);

    src.value = 3;
    await Future<void>.delayed(Duration.zero);
    b.detach();
    await Future<void>.delayed(Duration.zero);
    expect(sent, [2, 5, 0, 3, 0]);

    src.value = 9; // ayrildiktan sonra dinlenmez
    await Future<void>.delayed(Duration.zero);
    expect(sent.last, 0);
  });

  test('Android/diger platformda kanal cagrilmaz', () async {
    final src = ValueNotifier<int>(4);
    final b = IconBadge(channel: ch, isIOS: false);
    b.attach(src);
    src.value = 7;
    b.detach();
    await Future<void>.delayed(Duration.zero);
    expect(sent, isEmpty);
  });

  test('negatif sayi 0 olur; kanal yoksa (MissingPlugin) hata sizmaz', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null);
    final b = IconBadge(channel: ch, isIOS: true);
    await b.set(-3); // MissingPluginException yutulur
    await b.set(1);
  });
}
