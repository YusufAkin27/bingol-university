import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_app.dart';

http.Response _json(int status, Object body, {Map<String, String>? headers}) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers});

/// /me 401 verir; /auth/refresh için [refresh] yanıtını döner.
ApiClient _api(Future<http.Response> Function(http.Request r) refresh, {void Function(String)? onPath}) {
  return ApiClient(
    retryDelay: Duration.zero,
    client: MockClient((r) async {
      onPath?.call(r.url.path);
      if (r.url.path.endsWith('/auth/refresh')) return refresh(r);
      if (r.headers['Authorization'] == 'Bearer A2') return _json(200, {'ok': true});
      return _json(401, {'code': 'UNAUTHORIZED'});
    }),
  )..tokens = Tokens('A1', 'R1');
}

void main() {
  group('ApiError siniflandirmasi', () {
    test('isTransient', () {
      for (final s in [0, 408, 429, 500, 502, 503, 504]) {
        expect(ApiError(s, 'X', '').isTransient, isTrue, reason: '$s');
      }
      for (final s in [400, 401, 403, 404, 409, 422]) {
        expect(ApiError(s, 'X', '').isTransient, isFalse, reason: '$s');
      }
    });

    test('isAuthRejected yalniz kesin yetki hatasi', () {
      expect(ApiError(401, 'INVALID_REFRESH_TOKEN', '').isAuthRejected, isTrue);
      expect(ApiError(401, 'HTTP_401', '').isAuthRejected, isTrue);
      expect(ApiError(403, 'INVALID_REFRESH_TOKEN', '').isAuthRejected, isTrue);
      expect(ApiError(403, 'SESSION_REVOKED', '').isAuthRejected, isTrue);
      expect(ApiError(400, 'INVALID_REFRESH_TOKEN', '').isAuthRejected, isTrue);
      expect(ApiError(403, 'ACCOUNT_SUSPENDED', '').isAuthRejected, isTrue);
      // Geçici hatalar ve ilgisiz kodlar oturumu bitirmez.
      for (final s in [0, 408, 429, 500, 502, 503, 504]) {
        expect(ApiError(s, 'X', '').isAuthRejected, isFalse, reason: '$s');
      }
      expect(ApiError(403, 'FORBIDDEN', '').isAuthRejected, isFalse);
      expect(ApiError(400, 'VALIDATION', '').isAuthRejected, isFalse);
      // Kendi yolu olan kodlar
      expect(ApiError(401, 'SESSION_REPLACED', '').isAuthRejected, isFalse);
      expect(ApiError(403, 'ACCESS_BLOCKED', '').isAuthRejected, isFalse);
    });
  });

  group('refresh gecici hatada oturumu korur', () {
    for (final st in [500, 502, 503, 504, 408]) {
      test('refresh $st: oturum korunur, belirtecler silinmez, 3 deneme', () async {
        var calls = 0;
        final api = _api((r) async {
          calls++;
          return _json(st, {'code': 'SERVER_ERROR'});
        });
        var expired = 0;
        api.onSessionExpired = () => expired++;
        await expectLater(api.get('/me'), throwsA(isA<ApiError>().having((e) => e.status, 'status', st)));
        expect(expired, 0);
        expect(api.tokens?.refresh, 'R1');
        expect(calls, 3); // ilk + 2 yeniden deneme
      });
    }

    test('refresh 429 + Retry-After: oturum korunur', () async {
      var calls = 0;
      final api = _api((r) async {
        calls++;
        return _json(429, {'code': 'RATE_LIMITED', 'message': 'x'}, headers: {'retry-after': '0'});
      });
      var expired = 0;
      api.onSessionExpired = () => expired++;
      await expectLater(api.get('/me'), throwsA(isA<ApiError>().having((e) => e.status, 'status', 429)));
      expect(expired, 0);
      expect(api.tokens, isNotNull);
      expect(calls, 3);
    });

    test('refresh once 503 sonra 200: istek sessizce basarili olur', () async {
      var calls = 0;
      final api = _api((r) async {
        calls++;
        return calls == 1 ? _json(503, {'code': 'DB_TIMEOUT'}) : _json(200, {'accessToken': 'A2', 'refreshToken': 'R2'});
      });
      var expired = 0;
      api.onSessionExpired = () => expired++;
      expect(await api.get('/me'), {'ok': true});
      expect(expired, 0);
      expect(api.tokens?.access, 'A2');
      expect(calls, 2);
    });

    test('kesin ret (401 / 403 INVALID_REFRESH_TOKEN) oturumu bitirir, yeniden denenmez', () async {
      for (final r in [(401, 'INVALID_REFRESH_TOKEN'), (403, 'INVALID_REFRESH_TOKEN'), (403, 'SESSION_REVOKED')]) {
        var calls = 0;
        final api = _api((q) async {
          calls++;
          return _json(r.$1, {'code': r.$2});
        });
        var expired = 0;
        api.onSessionExpired = () => expired++;
        await expectLater(api.get('/me'), throwsA(isA<ApiError>()));
        expect(expired, 1, reason: '$r');
        expect(calls, 1, reason: '$r');
      }
    });
  });

  group('Session acilisi (/auth/me)', () {
    Future<Session> restore(FakeBackend b) async {
      final s = makeSession(b, signedIn: false)..meRetryDelays = const [Duration(milliseconds: 20)];
      const st = FlutterSecureStorage();
      await st.write(key: 'access', value: 'old');
      await st.write(key: 'refresh', value: 'oldr');
      await s.restore();
      return s;
    }

    for (final st in [500, 502, 503, 504, 429, 408]) {
      test('/auth/me $st: oturum korunur, signedIn, belirtecler yerinde', () async {
        final b = FakeBackend()..fail('/auth/me', status: st, code: 'SERVER_ERROR');
        final s = await restore(b);
        expect(s.state, SessionState.signedIn);
        expect(s.api.tokens?.refresh, 'oldr');
        expect(b.count('/auth/logout'), 0);
        await s.signOut(remote: false); // sonraki testlere sizmasin
      });
    }

    test('/auth/me gecici hatadan sonra yeniden denenir ve kullanici bilgisi dolar', () async {
      final b = FakeBackend()..fail('/auth/me', status: 503, code: 'SERVER_ERROR');
      final s = await restore(b);
      expect(s.state, SessionState.signedIn);
      expect(s.userId, isNull);
      b.on('/auth/me', {'id': 7, 'displayName': 'Ali Veli', 'email': 'ali@bingol.edu.tr'});
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(s.userId, 7);
      expect(s.displayName, 'Ali Veli');
      expect(s.state, SessionState.signedIn);
      await s.signOut(remote: false);
    });

    test('/auth/me 401 + refresh 401: oturum kapanir', () async {
      final b = FakeBackend()
        ..fail('/auth/me', status: 401, code: 'TOKEN_EXPIRED')
        ..fail('/auth/refresh', status: 401, code: 'INVALID_REFRESH_TOKEN');
      final s = await restore(b);
      expect(s.state, SessionState.signedOut);
      expect(s.api.tokens, isNull);
    });


    test('/auth/me 401 + refresh 503: oturum korunur', () async {
      final b = FakeBackend()
        ..fail('/auth/me', status: 401, code: 'TOKEN_EXPIRED')
        ..fail('/auth/refresh', status: 503, code: 'DB_TIMEOUT');
      final s = await restore(b);
      expect(s.state, SessionState.signedIn);
      expect(s.api.tokens?.refresh, 'oldr');
      await s.signOut(remote: false);
    });
  });
}
