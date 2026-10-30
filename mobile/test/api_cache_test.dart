import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jr(int status, Object body, {Map<String, String> h = const {}}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8', ...h});

ApiClient make(MockClient c) => ApiClient(client: c, retryDelay: Duration.zero);

void main() {
  test('ETag saklanir, If-None-Match gonderilir, 304te onbellek doner', () async {
    final seen = <String?>[];
    final api = make(MockClient((r) async {
      seen.add(r.headers['If-None-Match']);
      if (r.headers['If-None-Match'] == '"v1"') return http.Response('', 304);
      return jr(200, {'a': 1}, h: {'etag': '"v1"'});
    }));
    expect(await api.get('/news'), {'a': 1});
    expect(await api.get('/news', force: true), {'a': 1}); // cekip yenile: taze suresi yok sayilir
    expect(seen, [null, '"v1"']);
  });

  test('cikista (setTokens null) onbellek temizlenir', () async {
    final seen = <String?>[];
    final api = make(MockClient((r) async {
      seen.add(r.headers['If-None-Match']);
      return jr(200, {'a': 1}, h: {'etag': '"v1"'});
    }))
      ..tokens = Tokens('A', 'R');
    await api.get('/me/x');
    await api.setTokens(null);
    await api.get('/me/x');
    expect(seen, [null, null]);
  });

  test('onbellek 100 girisle sinirli (LRU)', () async {
    var calls = <String?>[];
    final api = make(MockClient((r) async {
      calls.add(r.headers['If-None-Match']);
      return jr(200, {'p': r.url.path}, h: {'etag': '"e"'});
    }));
    for (var i = 0; i < 101; i++) {
      await api.get('/n$i');
    }
    calls = [];
    await api.get('/n0'); // atilmis olmali
    expect(calls, [null]);
    calls = [];
    await api.get('/n100');
    expect(calls, ['"e"']);
  });

  test('429 Retry-After okunur', () async {
    final api = make(MockClient((r) async =>
        jr(429, {'code': 'RATE_LIMITED', 'message': 'x'}, h: {'retry-after': '17'})));
    await expectLater(api.post('/x', {}, false),
        throwsA(isA<ApiError>().having((e) => e.retryAfter, 'retryAfter', 17)));
  });

  test('GET 503te bir kez yeniden dener', () async {
    var n = 0;
    final api = make(MockClient((r) async => ++n == 1 ? jr(503, {}) : jr(200, {'ok': true})));
    expect(await api.get('/a'), {'ok': true});
    expect(n, 2);
  });

  test('GET agda iki kez dener sonra NETWORK', () async {
    var n = 0;
    final api = make(MockClient((r) async {
      n++;
      throw http.ClientException('off');
    }));
    await expectLater(api.get('/a'), throwsA(isA<ApiError>().having((e) => e.isNetwork, 'net', true)));
    expect(n, 2);
  });

  test('POST yeniden denenmez', () async {
    var n = 0;
    final api = make(MockClient((r) async {
      n++;
      return jr(503, {});
    }));
    await expectLater(api.post('/a', {}), throwsA(isA<ApiError>()));
    expect(n, 1);
  });
}
