// W1-G: oturum açılışı (anında kabuk), çıkışta silme dayanıklılığı, belirteç yazma sırası, cihaz kimliği beklemesi,
// dil eşitleme (yalnız değişince). Güvenli depo bu dosyada KENDİ sahte kanalıyla (gecikme/hata enjekte edilebilir) taklit edilir.
import 'dart:async';
import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/device_identity.dart';
import 'package:bu_kampus/core/language_sync.dart';
import 'package:bu_kampus/core/pending_verification.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _Vault {
  final data = <String, String>{};
  Duration writeDelay = Duration.zero;
  Duration readDelay = Duration.zero;

  /// Bu anahtarlar için delete çağrısı hata verir (Keychain/Keystore geçici hatası).
  final failDelete = <String>{};
  int deleteCalls = 0;

  void install() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          if (readDelay > Duration.zero) await Future<void>.delayed(readDelay);
          return data[key];
        case 'write':
          if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
          data[key!] = args['value'] as String;
          return null;
        case 'delete':
          deleteCalls++;
          if (failDelete.contains(key)) throw PlatformException(code: 'KEYSTORE', message: 'gecici');
          data.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.of(data);
        case 'deleteAll':
          data.clear();
          return null;
        case 'containsKey':
          return data.containsKey(key);
      }
      return null;
    });
  }
}

String _jwt(int sub) {
  String b(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b({'alg': 'none'})}.${b({'sub': '$sub', 'exp': DateTime.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000})}.sig';
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', 'etag': '"e"'});

Session _session(http.Client c) {
  final api = ApiClient(client: c, retryDelay: Duration.zero, connectivity: ConnectivityService());
  return Session(api)..pending = PendingVerificationStore.memory();
}

void main() {
  late _Vault vault;
  setUp(() {
    vault = _Vault()..install();
    DeviceIdentity.instance.debugSet('test-device-0123456789');
  });

  group('restore: kabuk /auth/me beklemeden açılır', () {
    test('belirteç varken state HEMEN signedIn; /auth/me asılı kalsa da splash beklemez', () async {
      vault.data['access'] = _jwt(7);
      vault.data['refresh'] = 'r1';
      final gate = Completer<void>();
      final s = _session(MockClient((r) async {
        if (r.url.path.endsWith('/auth/me')) {
          await gate.future; // kötü ağ: yanıt çok geç gelir
          return _json({'id': 7, 'displayName': 'Ayşe', 'email': 'a@bingol.edu.tr'});
        }
        return _json({});
      }));
      await s.restore().timeout(const Duration(seconds: 2));
      expect(s.state, SessionState.signedIn);
      expect(s.userId, 7, reason: 'kimlik JWT sub talebinden');
      expect(s.displayName, isNull);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(s.displayName, 'Ayşe', reason: '/auth/me arka planda tamamlanır');
    });

    test('arka plandaki /auth/me KESİN 401 + refresh reddi alırsa oturum kapanır', () async {
      vault.data['access'] = _jwt(7);
      vault.data['refresh'] = 'r1';
      final s = _session(MockClient((r) async {
        if (r.url.path.endsWith('/auth/refresh')) return _json({'code': 'INVALID_REFRESH_TOKEN', 'message': 'x'}, 401);
        return _json({'code': 'UNAUTHORIZED', 'message': 'x'}, 401);
      }));
      await s.restore();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(s.state, SessionState.signedOut);
      expect(vault.data.containsKey('access'), isFalse);
    });

    test('ağ yokken /auth/me başarısız: oturum KORUNUR (çevrimdışı açılış)', () async {
      vault.data['access'] = _jwt(7);
      vault.data['refresh'] = 'r1';
      final s = _session(MockClient((r) async => throw http.ClientException('offline')));
      s.meRetryDelays = const [Duration(days: 1)];
      await s.restore();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(s.state, SessionState.signedIn);
      expect(s.api.tokens, isNotNull);
    });

    test('belirteç yoksa signedOut', () async {
      final s = _session(MockClient((r) async => _json({})));
      await s.restore();
      expect(s.state, SessionState.signedOut);
    });
  });

  group('çıkışta belirteç silme dayanıklılığı', () {
    test('silme hatası: kısa yeniden deneme + signed_out işareti; sonraki açılış otomatik giriş YAPMAZ', () async {
      vault.data['access'] = _jwt(7);
      vault.data['refresh'] = 'r1';
      final s = _session(MockClient((r) async => _json({'id': 7})));
      await s.restore();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      vault.failDelete.addAll(['access', 'refresh']);
      vault.deleteCalls = 0;
      await s.signOut(remote: false);
      expect(s.state, SessionState.signedOut);
      expect(vault.deleteCalls, greaterThanOrEqualTo(3), reason: 'silme birkaç kez denenmeli');
      expect(vault.data['signed_out'], '1', reason: 'silinemediyse çıkış işareti bırakılır');
      expect(vault.data.containsKey('access'), isTrue, reason: 'senaryo: belirteç diskte kaldı');

      // Uygulama yeniden açılır: depo hâlâ silmeyi reddediyor -> yine de oturumsuz başlamalı.
      final s2 = _session(MockClient((r) async => _json({'id': 7})));
      await s2.restore();
      expect(s2.state, SessionState.signedOut);
      expect(s2.api.tokens, isNull);

      // Depo düzelince bir sonraki açılış belirteçleri siler ve işareti kaldırır.
      vault.failDelete.clear();
      final s3 = _session(MockClient((r) async => _json({'id': 7})));
      await s3.restore();
      expect(s3.state, SessionState.signedOut);
      expect(vault.data.containsKey('access'), isFalse);
      expect(vault.data.containsKey('signed_out'), isFalse);
    });

    test('yeni giriş eski çıkış işaretini siler', () async {
      vault.data['signed_out'] = '1';
      final s = _session(MockClient((r) async {
        if (r.url.path.endsWith('/auth/login')) return _json({'accessToken': _jwt(3), 'refreshToken': 'rr'});
        return _json({'id': 3, 'displayName': 'X', 'email': 'x@bingol.edu.tr'});
      }));
      await s.restore(); // işaret var -> oturumsuz; depodaki işaret silme başarısız olmadığı için temizlenir
      expect(s.state, SessionState.signedOut);
      expect(vault.data.containsKey('signed_out'), isFalse);
      await s.login('x@bingol.edu.tr', 'Parola1!');
      expect(s.state, SessionState.signedIn);
      expect(vault.data['refresh'], 'rr');
    });

    test('belirteç yazma/silme TEK SIRA: yavaş yazma, ardından gelen çıkış silmesini ezmez', () async {
      vault.writeDelay = const Duration(milliseconds: 80);
      final s = _session(MockClient((r) async => _json({})));
      unawaited(s.api.setTokens(Tokens(_jwt(1), 'rA'))); // giriş: yavaş yazma başlar
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await s.api.setTokens(null); // çıkış: silme yazmadan SONRA çalışmalı
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(vault.data.containsKey('access'), isFalse);
      expect(vault.data.containsKey('refresh'), isFalse, reason: 'çıkış yapılmış oturum diske geri yazılmamalı');
    });
  });

  group('oturum nesli: yenileme çıkışla yarışır', () {
    test('refresh uçuştayken setTokens(null): tokens null kalır, onTokensChanged(yeni) ÇAĞRILMAZ', () async {
      final gate = Completer<void>();
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/refresh')) {
            await gate.future;
            return _json({'accessToken': _jwt(1), 'refreshToken': 'r2'});
          }
          return _json({});
        }),
        retryDelay: Duration.zero,
        connectivity: ConnectivityService(),
      );
      final changes = <Tokens?>[];
      api.onTokensChanged = (t) async => changes.add(t);
      api.tokens = Tokens(_jwt(1), 'r1');
      final rf = api.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await api.setTokens(null);
      gate.complete();
      await expectLater(rf, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
      expect(api.tokens, isNull);
      expect(changes, [null], reason: 'yalnız çıkış bildirimi; yenilenmiş çift asla');
    });

    test('yenileme sürerken YENİ hesaba giriş: eski yenileme yeni oturumun belirteçlerinin üstüne yazmaz', () async {
      final gate = Completer<void>();
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/auth/refresh')) {
            await gate.future;
            return _json({'accessToken': _jwt(1), 'refreshToken': 'ESKI'});
          }
          return _json({});
        }),
        retryDelay: Duration.zero,
        connectivity: ConnectivityService(),
      );
      api.tokens = Tokens(_jwt(1), 'rA');
      final rf = api.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await api.setTokens(null);
      await api.setTokens(Tokens(_jwt(2), 'rB'));
      gate.complete();
      await expectLater(rf, throwsA(isA<ApiError>()));
      expect(api.tokens!.refresh, 'rB');
    });
  });

  group('cihaz kimliği', () {
    test('kimlik okunurken (yavaş depo) HİÇBİR istek atılmaz; başlık kimlik taşır', () async {
      DeviceIdentity.instance.debugSet(null); // yeniden okunabilsin
      vault.readDelay = const Duration(milliseconds: 150);
      vault.data['device_id'] = 'abcdefabcdefabcdefabcdef';
      final seen = <String?>[];
      final t0 = DateTime.now();
      DateTime? firstRequestAt;
      final api = ApiClient(
        client: MockClient((r) async {
          firstRequestAt ??= DateTime.now();
          seen.add(r.headers['X-Device-Id']);
          return _json({'ok': true});
        }),
        retryDelay: Duration.zero,
        connectivity: ConnectivityService(),
      );
      unawaited(DeviceIdentity.instance.load());
      await api.get('/app/info');
      expect(seen, ['abcdefabcdefabcdefabcdef']);
      expect(firstRequestAt!.difference(t0).inMilliseconds, greaterThanOrEqualTo(140), reason: 'istek kimlik okunmadan atılmamalı');
    });
  });

  group('dil eşitleme: yalnız değişince', () {
    test('aynı kullanıcı+dil ikinci açılışta PATCH atmaz; dil değişince atar; hata yazmaz', () async {
      var patches = 0;
      var fail = false;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            patches++;
            if (fail) return _json({'code': 'X', 'message': ''}, 500);
          }
          return _json({});
        }),
        retryDelay: Duration.zero,
        connectivity: ConnectivityService(),
      );
      expect(await LanguageSync.sync(api, 5, 'tr'), isTrue);
      expect(await LanguageSync.sync(api, 5, 'tr'), isFalse);
      expect(patches, 1);
      expect(await LanguageSync.sync(api, 5, 'en'), isTrue, reason: 'dil değişti');
      expect(patches, 2);
      expect(await LanguageSync.sync(api, 6, 'en'), isTrue, reason: 'başka kullanıcı');
      fail = true;
      expect(await LanguageSync.sync(api, 6, 'ar'), isFalse);
      expect(await const FlutterSecureStorage().read(key: LanguageSync.key), '6|en', reason: 'başarısız PATCH kayda yazılmaz');
      fail = false;
      expect(await LanguageSync.sync(api, 6, 'ar'), isTrue, reason: 'bir sonraki açılışta yeniden denenir');
      await LanguageSync.clear();
      expect(await const FlutterSecureStorage().read(key: LanguageSync.key), isNull);
    });
  });
}
