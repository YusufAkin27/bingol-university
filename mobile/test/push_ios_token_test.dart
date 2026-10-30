import 'package:bu_kampus/core/push/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const d = Duration(milliseconds: 1);

  test('iOS: APNs gelene kadar bekler, sonra FCM jetonu alinir', () async {
    var apnsCalls = 0;
    final t = await fetchPushToken(
      isIOS: true,
      apns: () async => ++apnsCalls < 4 ? null : 'apns',
      fcm: () async => 'fcm-token',
      delay: d,
    );
    expect(t, 'fcm-token');
    expect(apnsCalls, 4);
  });

  test('iOS: APNs hic gelmezse bile cokmez; FCM hata verirse null', () async {
    var fcmCalls = 0;
    final t = await fetchPushToken(
      isIOS: true,
      apns: () async => null,
      fcm: () async {
        fcmCalls++;
        throw Exception('apns-token-not-set');
      },
      attempts: 3,
      delay: d,
    );
    expect(t, isNull);
    expect(fcmCalls, 3);
  });

  test('iOS: ilk FCM denemesi basarisiz, ikincisi basarili', () async {
    var n = 0;
    final t = await fetchPushToken(
      isIOS: true,
      apns: () async => 'apns',
      fcm: () async => ++n == 1 ? null : 'tok',
      delay: d,
    );
    expect(t, 'tok');
  });

  test('Android: APNs beklenmez, ilk basarida durur', () async {
    var apnsCalls = 0;
    final t = await fetchPushToken(
      isIOS: false,
      apns: () async {
        apnsCalls++;
        return null;
      },
      fcm: () async => 'a',
      delay: d,
    );
    expect(t, 'a');
    expect(apnsCalls, 0);
  });

  test('Android: gecici hatada (Play Hizmetleri/ag) 3 kez dener, sonra basarir', () async {
    var n = 0;
    final t = await fetchPushToken(
      isIOS: false,
      apns: () async => null,
      fcm: () async {
        if (++n < 3) throw Exception('SERVICE_NOT_AVAILABLE');
        return 'tok';
      },
      delay: d,
    );
    expect(t, 'tok');
    expect(n, 3);
  });
}
