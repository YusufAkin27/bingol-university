import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bu_kampus/core/api.dart';

http.Response json(int status, Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('Accept-Language ve Bearer başlıkları gönderilir', () async {
    late http.BaseRequest seen;
    final api = ApiClient(client: MockClient((r) async {
      seen = r;
      return json(200, {'ok': true});
    }))
      ..lang = 'en'
      ..tokens = Tokens('A1', 'R1');
    final res = await api.get('/ping');
    expect(res, {'ok': true});
    expect(seen.headers['Accept-Language'], 'en');
    expect(seen.headers['Authorization'], 'Bearer A1');
    expect(seen.url.path, '/api/ping');
  });

  test('401 durumunda eşzamanlı iki çağrı tek refresh yapar', () async {
    var refreshCalls = 0;
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return json(200, {'accessToken': 'A2', 'refreshToken': 'R2'});
      }
      if (r.headers['Authorization'] == 'Bearer A2') return json(200, {'path': r.url.path});
      return json(401, {});
    }))
      ..tokens = Tokens('A1', 'R1');
    var saved = 0;
    api.onTokensChanged = (_) async => saved++;

    final res = await Future.wait([api.get('/a'), api.get('/b')]);
    expect(refreshCalls, 1);
    expect(res[0], {'path': '/api/a'});
    expect(res[1], {'path': '/api/b'});
    expect(api.tokens!.access, 'A2');
    expect(api.tokens!.refresh, 'R2');
    expect(saved, 1);
  });

  test('refresh de 401 verirse onSessionExpired çağrılır', () async {
    final api = ApiClient(client: MockClient((r) async => json(401, {})))..tokens = Tokens('A1', 'R1');
    var expired = 0;
    api.onSessionExpired = () => expired++;
    await expectLater(api.get('/me'), throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)));
    expect(expired, 1);
  });

  test('ağ hatasında oturum silinmez', () async {
    final api = ApiClient(client: MockClient((r) async => throw http.ClientException('offline')))
      ..tokens = Tokens('A1', 'R1');
    var expired = 0;
    api.onSessionExpired = () => expired++;
    await expectLater(api.get('/me'), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'isNetwork', true)));
    expect(expired, 0);
    expect(api.tokens, isNotNull);
  });

  test('refresh sırasında ağ hatası oturumu bitirmez', () async {
    final api = ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('/auth/refresh')) throw http.ClientException('offline');
      return json(401, {});
    }))
      ..tokens = Tokens('A1', 'R1');
    var expired = 0;
    api.onSessionExpired = () => expired++;
    await expectLater(api.get('/me'), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'isNetwork', true)));
    expect(expired, 0);
    expect(api.tokens!.refresh, 'R1');
  });

  test('ApiError code ve message çözümlenir', () async {
    final api = ApiClient(client: MockClient((r) async => json(409, {'code': 'EMAIL_TAKEN', 'message': 'Kayıtlı'})));
    await expectLater(
        api.post('/auth/register', {'a': 1}, false),
        throwsA(isA<ApiError>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'EMAIL_TAKEN')
            .having((e) => e.message, 'message', 'Kayıtlı')));
  });

  test('gövdesiz hata HTTP_<durum> koduna düşer', () async {
    final api = ApiClient(client: MockClient((r) async => http.Response('<html>', 502)));
    await expectLater(api.get('/x'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'HTTP_502')));
  });
}
