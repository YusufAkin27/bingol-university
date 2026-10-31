import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_gate.dart' show appVersion;
import 'secure_store.dart';

/// Cihaz engeli için istemci kimliği. Ham değer yalnızca istek başlığında gider; sunucu HMAC'leyip saklar.
/// Kimlik, ilk açılışta üretilen rastgele UUID'dir ve güvenli depoda (Keychain/Keystore) durur:
/// donanım kimliği (IMEI, ANDROID_ID) okunmaz, kullanıcı takibi için kullanılmaz.
class DeviceIdentity {
  DeviceIdentity._();

  static final DeviceIdentity instance = DeviceIdentity._();

  static const _key = 'device_id';

  String? _id;

  /// Testlerde kimliği doğrudan atamak için.
  @visibleForTesting
  void debugSet(String? id) {
    _id = id;
    if (id == null) _loading = null; // yeniden okunabilsin
  }

  /// Hazır mı? (Hazır değilken başlıklar boş gider; istekler engellenmez.)
  String? get id => _id;

  Future<void>? _loading;

  /// Kimlik okuması bitti mi? Okuma hiç başlatılmadıysa (testler) beklenecek bir şey yoktur: true.
  bool get isReady => _id != null || _loading == null;

  /// Başlatılmış okumanın bitişi; ApiClient ilk istekten önce bunu bekler (kimliksiz istek atılmasın).
  Future<void> get ready => _loading ?? Future<void>.value();

  /// Uygulama açılışında bir kez çağrılır; hata fırlatmaz. Eşzamanlı çağrılar aynı okumayı paylaşır.
  Future<void> load({FlutterSecureStorage storage = kDeviceSecureStorage}) {
    if (_id != null) return Future<void>.value();
    return _loading ??= _load(storage);
  }

  Future<void> _load(FlutterSecureStorage storage) async {
    try {
      var v = await storage.read(key: _key);
      if (v == null || v.length < 16) {
        v = generateUuid();
        await storage.write(key: _key, value: v);
      }
      _id = v;
    } catch (_) {
      // Depo kullanılamıyorsa bu oturum için bellek içi kimlik (kalıcı değil).
      _id ??= generateUuid();
    }
  }

  static String get platform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'other';
    }
  }

  /// HTTP istek başlıkları.
  Map<String, String> get httpHeaders => {
        if (_id != null) 'X-Device-Id': _id!,
        'X-Device-Platform': platform,
        'X-App-Version': appVersion,
      };

  /// STOMP CONNECT başlıkları.
  Map<String, String> get stompHeaders => {
        if (_id != null) 'device-id': _id!,
        'device-platform': platform,
        'app-version': appVersion,
      };
}

/// RFC 4122 v4 UUID (güvenli rastgele).
String generateUuid([Random? rng]) {
  final r = rng ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-'
      '${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}
