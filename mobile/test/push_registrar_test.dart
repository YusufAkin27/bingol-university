import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/push/push_registrar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ms = Duration(milliseconds: 5);
  Future<void> settle([int n = 6]) => Future<void>.delayed(ms * n);

  test('basarili kayit: registered + lastOkAt; ayni jeton tekrar cagrilmaz', () async {
    var now = DateTime(2026, 1, 1, 8);
    final sent = <String>[];
    final r = PushRegistrar(send: (t) async => sent.add(t), now: () => now, refreshAfter: const Duration(hours: 6));
    expect(r.needsRefresh, isTrue);
    expect(await r.register('tok-1'), isTrue);
    expect(r.state, PushRegState.registered);
    expect(r.lastOkAt, now);
    expect(r.needsRefresh, isFalse);

    await r.register('tok-1'); // taze: sunucu hiz siniri icin atlanir
    expect(sent, ['tok-1']);

    now = now.add(const Duration(hours: 7)); // eskidi: lastSeenAt tazelenmeli
    expect(r.needsRefresh, isTrue);
    await r.register('tok-1');
    expect(sent, ['tok-1', 'tok-1']);

    await r.register('tok-2'); // jeton degisti: hemen gonderilir
    expect(sent.last, 'tok-2');
    await r.register('tok-2', force: true);
    expect(sent.length, 4);
    r.dispose();
  });

  test('ag hatasi: yeniden dener ve basarinca registered olur', () async {
    var calls = 0;
    final r = PushRegistrar(
      send: (t) async {
        if (++calls < 3) throw ApiError(0, 'NETWORK', 'ag yok');
      },
      retryDelays: [ms, ms, ms],
    );
    expect(await r.register('t'), isFalse);
    expect(r.state, PushRegState.retrying);
    await settle(20);
    expect(calls, 3);
    expect(r.state, PushRegState.registered);
    r.dispose();
  });

  test('5xx ve 429 gecici sayilir; 400 kalici: yeniden denenmez', () async {
    var calls = 0;
    final transient = PushRegistrar(
      send: (t) async {
        calls++;
        throw ApiError(503, 'X', 'x');
      },
      retryDelays: [ms],
    );
    await transient.register('t');
    expect(transient.state, PushRegState.retrying);
    await settle(10);
    expect(calls, 2);
    expect(transient.state, PushRegState.failed); // hak bitti
    transient.dispose();

    var calls2 = 0;
    final permanent = PushRegistrar(
      send: (t) async {
        calls2++;
        throw ApiError(400, 'VALIDATION', 'gecersiz');
      },
      retryDelays: [ms, ms],
    );
    await permanent.register('t');
    await settle(10);
    expect(calls2, 1);
    expect(permanent.state, PushRegState.failed);
    permanent.dispose();
  });

  test('basarisizken sonraki register (on plana donus) yeniden dener; reset bekleyen denemeyi iptal eder', () async {
    var fail = true;
    var calls = 0;
    final r = PushRegistrar(
      send: (t) async {
        calls++;
        if (fail) throw ApiError(0, 'NETWORK', 'ag yok');
      },
      retryDelays: const [],
    );
    await r.register('t');
    expect(r.state, PushRegState.failed);
    expect(r.needsRefresh, isTrue);
    fail = false;
    expect(await r.register('t'), isTrue); // needsRefresh true -> atlanmaz
    expect(r.registered, isTrue);
    expect(calls, 2);

    final p = PushRegistrar(
      send: (t) async {
        calls++;
        throw ApiError(0, 'NETWORK', 'ag yok');
      },
      retryDelays: [ms],
    );
    await p.register('x');
    final before = calls;
    p.reset(); // cikis: zamanlayici iptal
    await settle(10);
    expect(calls, before);
    expect(p.state, PushRegState.idle);
    expect(p.token, isNull);
    r.dispose();
    p.dispose();
  });

  test('bos jeton kaydedilmez', () async {
    var calls = 0;
    final r = PushRegistrar(send: (t) async => calls++);
    expect(await r.register(''), isFalse);
    expect(calls, 0);
    r.dispose();
  });
}
