import 'dart:async';
import 'dart:io';

import 'package:bu_kampus/core/realtime/stomp_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// T-094 (A15-09, C4/C6): STOMP bağlantısı TOKEN_EXPIRED/UNAUTHORIZED döngüsünde ve "bağlan-hemen-kop" döngüsünde
/// geri çekilmeli; art arda 3 yetki hatasında oturum bitmiş sayılmalı. Gerçek yerel WebSocket sunucusu kullanılır
/// (widget testi değil: gerçek zaman).
class _Server {
  _Server(this._onConnect);

  final Future<void> Function(WebSocket ws, int n) _onConnect;
  late HttpServer http;
  final connectTimes = <DateTime>[];
  int get connects => connectTimes.length;

  static Future<_Server> start(Future<void> Function(WebSocket ws, int n) onConnect) async {
    final s = _Server(onConnect);
    s.http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    s.http.listen((req) async {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response
          ..statusCode = 400
          ..close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req);
      ws.listen((data) async {
        if (data is String && data.startsWith('CONNECT')) {
          s.connectTimes.add(DateTime.now());
          await s._onConnect(ws, s.connectTimes.length);
        }
      }, onError: (_) {}, onDone: () {});
    });
    return s;
  }

  String get url => 'ws://127.0.0.1:${http.port}/ws';
  Future<void> stop() => http.close(force: true);
}

StompClient _client(_Server s,
        {required void Function() onRefresh, Duration unit = const Duration(milliseconds: 40)}) =>
    StompClient(
      url: s.url,
      host: '127.0.0.1',
      accessToken: () => 'tok',
      refreshToken: () async {
        onRefresh();
        return 'tok2';
      },
      heartbeat: Duration.zero,
      backoffUnit: unit,
    );

void main() {
  test('TOKEN_EXPIRED dongusu: sinirli baglanti + refresh, 3. redde sessionExpired ve durur', () async {
    final server = await _Server.start((ws, n) async {
      ws.add('ERROR\nmessage:TOKEN_EXPIRED\n\n\x00');
    });
    var refreshes = 0;
    final c = _client(server, onRefresh: () => refreshes++);
    final fatal = Completer<StompFatal>();
    c.fatal.listen((f) {
      if (!fatal.isCompleted) fatal.complete(f);
    });
    c.connect();
    expect(await fatal.future.timeout(const Duration(seconds: 10)), StompFatal.sessionExpired);
    // Durdu: bir süre daha bekle, yeni bağlantı gelmemeli (eskiden 3 sn'de 191 bağlantı + 190 refresh).
    final at = server.connects;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(server.connects, at);
    expect(server.connects, lessThan(10));
    expect(server.connects, 3);
    expect(refreshes, lessThan(10));
    c.dispose();
    await server.stop();
  });

  test('UNAUTHORIZED: ardisik yeniden baglanmalar arasinda geri cekilme vardir (hemen degil)', () async {
    final server = await _Server.start((ws, n) async {
      ws.add('ERROR\nmessage:UNAUTHORIZED\n\n\x00');
    });
    final c = StompClient(
      url: server.url,
      host: '127.0.0.1',
      accessToken: () => 'tok',
      refreshToken: () async => 'tok2',
      heartbeat: Duration.zero,
      backoffUnit: const Duration(milliseconds: 150),
    );
    final fatal = Completer<void>();
    c.fatal.listen((_) => fatal.complete());
    c.connect();
    await fatal.future.timeout(const Duration(seconds: 10));
    expect(server.connects, 3);
    final gap = server.connectTimes[1].difference(server.connectTimes[0]);
    // Geri çekilme birimi 150 ms (+-%20): hemen yeniden bağlanma (<50 ms) olmamalı.
    expect(gap.inMilliseconds, greaterThan(100));
    c.dispose();
    await server.stop();
  });

  test('CONNECTED alip hemen kopan sunucu: _attempt sifirlanmaz, aralik buyur (C6)', () async {
    final server = await _Server.start((ws, n) async {
      ws.add('CONNECTED\nversion:1.2\nheart-beat:0,0\n\n\x00');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await ws.close();
    });
    final c = _client(server, onRefresh: () {}, unit: const Duration(milliseconds: 60));
    c.connect();
    while (server.connects < 5) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    c.dispose();
    await server.stop();
    final gaps = [
      for (var i = 1; i < server.connectTimes.length; i++)
        server.connectTimes[i].difference(server.connectTimes[i - 1]).inMilliseconds
    ];
    // 60, 120, 240, 480 ms (+-%20): son aralık ilkinin en az 2 katı olmalı. Eski kodda her CONNECTED sayacı sıfırlıyordu
    // ve aralıklar hep ~60 ms kalıyordu (bağlantı fırtınası).
    expect(gaps.last, greaterThan(gaps.first * 2), reason: 'aralıklar: $gaps');
  });

  test('kararli baglanti (stableAfter) sayaci sifirlar: uzun yasayan baglantidan sonra geri cekilme kisadir', () async {
    final server = await _Server.start((ws, n) async {
      ws.add('CONNECTED\nversion:1.2\nheart-beat:0,0\n\n\x00');
      // 1-3. bağlantılar hemen kopar (sayaç büyür); 4. bağlantı uzun yaşar (kararlı) ve sonra kopar.
      await Future<void>.delayed(Duration(milliseconds: n == 4 ? 300 : 5));
      await ws.close();
    });
    final c = StompClient(
      url: server.url,
      host: '127.0.0.1',
      accessToken: () => 'tok',
      refreshToken: () async => 'tok2',
      heartbeat: Duration.zero,
      backoffUnit: const Duration(milliseconds: 100),
      stableAfter: const Duration(milliseconds: 200),
    );
    c.connect();
    while (server.connects < 5) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    c.dispose();
    await server.stop();
    final t = server.connectTimes;
    final gap45 = t[4].difference(t[3]).inMilliseconds;
    // Sayaç sıfırlanmasaydı 4. aralık 8 birim (800 ms) olurdu: 300 ms yaşam + 800 ms ≈ 1100 ms. Sıfırlandığı için
    // ~300 ms + 100 ms geri çekilme.
    expect(gap45, lessThan(700), reason: 'aralıklar: ${[for (var i = 1; i < t.length; i++) t[i].difference(t[i - 1]).inMilliseconds]}');
  });
}
