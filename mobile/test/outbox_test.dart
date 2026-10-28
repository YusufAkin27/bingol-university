import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  var nowMs = DateTime(2026, 10, 28, 12).millisecondsSinceEpoch;
  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(nowMs);

  setUp(() => nowMs = DateTime(2026, 10, 28, 12).millisecondsSinceEpoch);

  Outbox make({MemoryOutboxStore? store, OutboxSender? sender, int maxItems = 100}) =>
      Outbox(store: store ?? MemoryOutboxStore(), sender: sender, now: clock, autoSchedule: false, maxItems: maxItems);

  void due() => nowMs += const Duration(minutes: 10).inMilliseconds;

  test('metin mesaji ag hatasinda kuyruga alinir, kalici depoya yazilir, yeniden yuklenir', () async {
    final store = MemoryOutboxStore();
    final api = ApiClient(
        client: MockClient((r) async => throw http.ClientException('yok')),
        retryDelay: Duration.zero,
        connectivity: ConnectivityService());
    final ob = make(store: store);
    api.outbox = ob;
    await expectLater(
        api.post('/conversations/7/messages', {'text': 'merhaba', 'clientId': 'c-1'}), throwsA(isA<ApiError>()));
    expect(ob.pendingCount, 1);
    await Future<void>.delayed(Duration.zero);
    expect(store.value, contains('merhaba'));

    final ob2 = make(store: store); // uygulama yeniden acildi
    await ob2.load();
    expect(ob2.items.single.clientId, 'c-1');
    expect(ob2.items.single.conversationId, 7);
  });

  test('medya (attachmentIds) ve baska POSTlar kuyruga alinmaz; ayni clientId tekrar eklenmez', () {
    final ob = make();
    expect(ob.captureRequest('/conversations/7/messages', {'text': 'x', 'clientId': 'a', 'attachmentIds': [1]}), isFalse);
    expect(ob.captureRequest('/posts', {'text': 'x', 'clientId': 'a'}), isFalse);
    expect(ob.captureRequest('/conversations/7/messages', {'text': '  ', 'clientId': 'a'}), isFalse);
    expect(ob.captureRequest('/conversations/7/messages', {'text': 'x', 'clientId': 'a'}), isTrue);
    expect(ob.captureRequest('/conversations/7/messages', {'text': 'x', 'clientId': 'a'}), isFalse);
    expect(ob.items.length, 1);
  });

  test('gonderim sirayla yapilir; ag hatasinda durur ve geri cekilir; sonra tamamlanir', () async {
    final sent = <String>[];
    var online = false;
    final ob = make(sender: (i) async {
      if (!online) throw ApiError(0, 'NETWORK', '');
      sent.add(i.text);
      return {'id': 1};
    });
    ob.enqueue(conversationId: 1, clientId: 'a', text: 'bir');
    ob.enqueue(conversationId: 1, clientId: 'b', text: 'iki');
    due();
    await ob.drain();
    expect(sent, isEmpty);
    expect(ob.items.first.attempts, 1);
    expect(ob.items.last.attempts, 0); // sira korunur: ikinci denenmedi
    expect(ob.pendingCount, 2);

    online = true;
    await ob.drain(); // geri cekilme suresi dolmadi
    expect(sent, isEmpty);
    due();
    await ob.drain();
    expect(sent, ['bir', 'iki']);
    expect(ob.items, isEmpty);
  });

  test('geri cekilme artar ve 5 dk ile sinirlanir', () {
    expect(Outbox.backoff(1), const Duration(seconds: 2));
    expect(Outbox.backoff(3), const Duration(seconds: 15));
    expect(Outbox.backoff(5), const Duration(minutes: 5));
    expect(Outbox.backoff(40), const Duration(minutes: 5));
  });

  test('4xx dogrulama hatasi kalici: failed olur, yeniden denenmez; elle retry calisir', () async {
    var calls = 0;
    var ok = false;
    final ob = make(sender: (i) async {
      calls++;
      if (!ok) throw ApiError(422, 'MESSAGE_TOO_LONG', '');
      return {'id': 9};
    });
    ob.enqueue(conversationId: 1, clientId: 'a', text: 'x');
    due();
    await ob.drain();
    expect(ob.items.single.status, OutboxStatus.failed);
    expect(ob.items.single.errorCode, 'MESSAGE_TOO_LONG');
    due();
    await ob.drain();
    expect(calls, 1);
    ok = true;
    await ob.retry('a');
    expect(ob.items, isEmpty);
    expect(calls, 2);
  });

  test('engelli kullanici hatasi sessizce kuyruktan cikar', () async {
    final ob = make(sender: (i) async => throw ApiError(403, 'USER_BLOCKED', ''));
    ob.enqueue(conversationId: 1, clientId: 'a', text: 'x');
    due();
    await ob.drain();
    expect(ob.items, isEmpty);
  });

  test('5xx en fazla 8 kez denenir, sonra failed', () async {
    final ob = make(sender: (i) async => throw ApiError(503, 'DOWN', ''));
    ob.enqueue(conversationId: 1, clientId: 'a', text: 'x');
    for (var i = 0; i < 8; i++) {
      due();
      await ob.drain();
    }
    expect(ob.items.single.status, OutboxStatus.failed);
    expect(ob.items.single.serverFails, 8);
  });

  test('tavan: en cok 100 oge; asinca en eski atilir', () {
    final ob = make(maxItems: 100);
    for (var i = 0; i < 105; i++) {
      ob.enqueue(conversationId: 1, clientId: 'c$i', text: 't$i');
    }
    expect(ob.items.length, 100);
    expect(ob.contains('c0'), isFalse);
    expect(ob.contains('c104'), isTrue);
  });

  test('2000 karakterden uzun metin alinmaz', () {
    final ob = make();
    expect(ob.enqueue(conversationId: 1, clientId: 'a', text: 'x' * 2001), isFalse);
  });

  test('7 gunden eski ogeler yuklemede atilir', () async {
    final store = MemoryOutboxStore();
    final a = make(store: store);
    a.enqueue(conversationId: 1, clientId: 'eski', text: 'x');
    await Future<void>.delayed(Duration.zero);
    nowMs += const Duration(days: 8).inMilliseconds;
    final b = make(store: store);
    await b.load();
    expect(b.items, isEmpty);
  });

  test('oturum kapanisi (setTokens null) kuyrugu ve depoyu temizler', () async {
    final store = MemoryOutboxStore();
    final api = ApiClient(
        client: MockClient((r) async => http.Response('{}', 200)), connectivity: ConnectivityService())
      ..tokens = Tokens('A', 'R');
    final ob = make(store: store);
    api.outbox = ob;
    ob.enqueue(conversationId: 1, clientId: 'a', text: 'gizli');
    await Future<void>.delayed(Duration.zero);
    expect(store.value, isNotNull);
    await api.setTokens(null);
    await Future<void>.delayed(Duration.zero);
    expect(ob.items, isEmpty);
    expect(store.value, isNull);
  });

  test('baglanti geri gelince (reconnects) kuyruk bosalir; sunucuya clientId ile gider', () async {
    final bodies = <Map>[];
    var down = true;
    final cs = ConnectivityService();
    final api = ApiClient(
        client: MockClient((r) async {
          if (down) throw http.ClientException('yok');
          if (r.method == 'POST') bodies.add(jsonDecode(r.body) as Map);
          return http.Response('{"id":5}', 201, headers: {'content-type': 'application/json'});
        }),
        retryDelay: Duration.zero,
        connectivity: cs)
      ..tokens = Tokens('A', 'R');
    final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false);
    api.outbox = ob;
    ob.attach(api, cs);
    await expectLater(
        api.post('/conversations/3/messages', {'text': 'selam', 'clientId': 'z-1', 'replyToMessageId': 4}),
        throwsA(isA<ApiError>()));
    expect(cs.online, isFalse);
    expect(ob.pendingCount, 1);
    down = false;
    // gercek akis: baska bir istek basarili olur -> reportSuccess -> reconnects -> drain
    await api.get('/news');
    for (var i = 0; i < 10 && ob.pendingCount > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ob.pendingCount, 0);
    expect(bodies.last['clientId'], 'z-1');
    expect(bodies.last['text'], 'selam');
    expect(bodies.last['replyToMessageId'], 4);
  });
}
