// A15 denetimi: baglanti (ConnectivityService yanlis pozitifleri). STOMP yeniden baglanma firtinasi (C4-C7) W1-H'nindir
// (core/realtime/stomp_client.dart); kaynak testler denetim klasorundeki a15_conn_test.dart icindedir (C4-C7).
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('S5 ConnectivityService', () {
    test('C1 502/503/504 ve captive-portal 200 "baglanti var" sayilir; kesinti->gelis reconnects tetikler ve kuyruk drain eder', () async {
      var mode = 'down';
      final conn = ConnectivityService();
      final api = ApiClient(
          client: MockClient((r) async {
            if (mode == 'down') throw http.ClientException('x');
            if (mode == 'gw') return http.Response('<html>Bad Gateway</html>', 502);
            if (mode == 'ok') return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
            return http.Response('<html>login</html>', 200, headers: {'content-type': 'text/html'});
          }),
          retryDelay: Duration.zero,
          connectivity: conn);
      try {
        await api.get('/menu/today');
      } catch (_) {}
      expect(conn.online, isFalse);
      mode = 'gw';
      try {
        await api.get('/menu/today');
      } catch (_) {}
      // ignore: avoid_print
      print('C1 502 sonrasi online=${conn.online} reconnects=${conn.reconnects.value}');
      expect(conn.online, isFalse, reason: 'gateway hatasi ("bagli ama internet yok") cevrimici sayilmamali');
      expect(conn.reconnects.value, 0, reason: '502 "baglanti geri geldi" olayi uretmemeli (kuyruk deneme firtinasi)');
      mode = 'portal';
      try {
        await api.get('/menu/today');
      } catch (_) {}
      expect(conn.online, isFalse, reason: 'captive portal 200 HTML cevrimici sayilmamali');
      expect(conn.reconnects.value, 0);
      mode = 'ok';
      await api.get('/menu/today');
      expect(conn.online, isTrue, reason: 'gercek JSON yanit baglantiyi geri getirir');
      expect(conn.reconnects.value, 1);
    });

    test('C2 5xx kesintisi: baglanti "geri geldi" olayi her 502/200-HTML ile kuyruk deneme firtinasi (reconnect) uretir', () async {
      final conn = ConnectivityService();
      var online = false;
      final api = ApiClient(
          client: MockClient((r) async {
            if (!online) throw http.ClientException('x');
            return http.Response('', 502);
          }),
          retryDelay: Duration.zero,
          connectivity: conn);
      var attempts = 0;
      final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false, sender: (i) async {
        attempts++;
        throw ApiError(502, 'HTTP_502', '');
      });
      ob.attach(api, conn);
      for (var k = 0; k < 6; k++) {
        online = false;
        try {
          await api.get('/menu/today');
        } catch (_) {}
        online = true;
        try {
          await api.get('/menu/today');
        } catch (_) {}
        ob.enqueue(conversationId: 1, clientId: 'c$k', text: 't');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      // ignore: avoid_print
      print('C2 reconnects=${conn.reconnects.value} gonderim denemesi=$attempts');
      expect(conn.reconnects.value, 0, reason: '502 yanitlari "baglanti geldi" sayilmaz: bos gonderim denemesi firtinasi yok');
      expect(attempts, 0);
      ob.dispose();
    });

    test('C3 reportStale / reportSuccess durum makinesi', () {
      final c = ConnectivityService();
      c.reportFailure();
      c.reportStale(DateTime(2026, 1, 1));
      c.reportStale(DateTime(2026, 2, 1)); // daha yeni: en eski korunur
      expect(c.lastStaleAt, DateTime(2026, 1, 1));
      c.reportSuccess();
      expect(c.online, isTrue);
      expect(c.lastStaleAt, isNull);
      expect(c.reconnects.value, 1);
    });
  });
}
