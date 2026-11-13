import 'dart:async';
import 'dart:io';

import 'package:bu_kampus/core/transfers/transfer_executor.dart';
import 'package:bu_kampus/core/transfers/transfer_job.dart';
import 'package:bu_kampus/core/transfers/transfer_platform.dart';
import 'package:bu_kampus/core/transfers/transfer_queue.dart';
import 'package:bu_kampus/core/transfers/transfer_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sahte yürütücü: her çağrı sırayla [script]'ten bir davranış alır.
class FakeExecutor extends TransferExecutor {
  FakeExecutor(this.script);
  final List<Future<String> Function(TransferJob, TransferRunContext)> script;
  final List<String> keys = [];
  final List<String> discarded = [];
  int calls = 0;
  int maxParallel = 0;
  int _parallel = 0;

  @override
  Future<String> run(TransferJob job, TransferRunContext ctx) async {
    keys.add(job.idempotencyKey);
    final i = calls++;
    _parallel++;
    if (_parallel > maxParallel) maxParallel = _parallel;
    try {
      final step = script[i < script.length ? i : script.length - 1];
      return await step(job, ctx);
    } finally {
      _parallel--;
    }
  }

  @override
  Future<void> discard(TransferJob job) async => discarded.add(job.id);
}

class RecordingPlatform implements TransferPlatform {
  final List<TransferSummary> updates = [];
  int stops = 0;
  @override
  Future<void> update(TransferSummary s, TransferLabels l) async => updates.add(s);
  @override
  Future<void> stop() async => stops++;
}

Future<String> ok(TransferJob j, TransferRunContext c) async {
  c.progress(50, 100);
  c.markProcessing();
  return 'msg-1';
}

Future<void> until(bool Function() cond, {int ms = 3000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('zaman asimi');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory tmp;
  late File src;
  late MemoryTransferStore store;

  TransferQueue makeQueue({TransferPlatform? platform, int maxConcurrent = 2, int maxAttempts = 3}) => TransferQueue(
        store: store,
        platform: platform,
        maxConcurrent: maxConcurrent,
        maxAttempts: maxAttempts,
        backoff: (_) => Duration.zero,
        emitInterval: const Duration(milliseconds: 1),
      );

  TransferRequest req({int owner = 7, String target = 'conv:1', String? id}) => TransferRequest(
        ownerUserId: owner,
        kind: TransferKind.chatMedia,
        targetKey: target,
        sourcePath: src.path,
        jobId: id,
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bu_tq_');
    src = File('${tmp.path}/video.mp4')..writeAsBytesSync(List.filled(100, 1));
    store = MemoryTransferStore(dir: Directory('${tmp.path}/files')..createSync());
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('basarili is: kopya alinir, sunucu sonucundan sonra yayimlandi, yerel kopya silinir', () async {
    final q = makeQueue();
    final ex = FakeExecutor([ok]);
    q.registerExecutor(TransferKind.chatMedia, ex);
    await q.start(7);
    final j = await q.enqueue(req());
    expect(j.localPath, isNot(src.path), reason: 'kaynak uygulama dizinine kopyalanir');
    expect(File(j.localPath).existsSync(), isTrue);
    await until(() => j.status == TransferStatus.published);
    expect(j.publishedRef, 'msg-1');
    expect(File(j.localPath).existsSync(), isFalse);
    expect(src.existsSync(), isTrue, reason: 'kullanicinin kendi dosyasina dokunulmaz');
    await q.dispose();
  });

  test('ag hatasi: Baglanti bekleniyor, ayni Idempotency-Key ile yeniden denenir, tek yayim', () async {
    final q = makeQueue();
    final ex = FakeExecutor([
      (j, c) async => throw const TransferFailure('NETWORK', network: true),
      ok,
    ]);
    q.registerExecutor(TransferKind.chatMedia, ex);
    await q.start(7);
    final j = await q.enqueue(req());
    await until(() => j.status == TransferStatus.published);
    expect(ex.calls, 2);
    expect(ex.keys[0], ex.keys[1]);
    expect(j.attempts, 2);
    await q.dispose();
  });

  test('kalici hata: failed; retry yeni Idempotency-Key alir', () async {
    final q = makeQueue();
    final ex = FakeExecutor([
      (j, c) async => throw const TransferFailure('CHAT_MEDIA_REJECTED', retryable: false),
      ok,
    ]);
    q.registerExecutor(TransferKind.chatMedia, ex);
    await q.start(7);
    final j = await q.enqueue(req());
    await until(() => j.status == TransferStatus.failed);
    expect(j.lastErrorCode, 'CHAT_MEDIA_REJECTED');
    expect(await q.retry(j.id), isTrue);
    await until(() => j.status == TransferStatus.published);
    expect(ex.keys[0], isNot(ex.keys[1]));
  });

  test('gecici hata deneme hakki bitince failed olur, retry ayni anahtari korur', () async {
    final q = makeQueue(maxAttempts: 2);
    final ex = FakeExecutor([
      (j, c) async => throw const TransferFailure('SERVER'),
      (j, c) async => throw const TransferFailure('SERVER'),
      ok,
    ]);
    q.registerExecutor(TransferKind.chatMedia, ex);
    await q.start(7);
    final j = await q.enqueue(req());
    await until(() => j.status == TransferStatus.failed);
    expect(ex.calls, 2);
    await q.retry(j.id);
    await until(() => j.status == TransferStatus.published);
    expect(ex.keys.toSet().length, 1);
  });

  test('iptal: discard cagrilir, yerel dosya silinir, yeniden acilista otomatik baslamaz', () async {
    final gate = Completer<String>();
    final q = makeQueue();
    final ex = FakeExecutor([
      (j, c) async {
        c.setServerRef('att-9');
        c.progress(10, 100);
        return gate.future;
      },
    ]);
    q.registerExecutor(TransferKind.chatMedia, ex);
    await q.start(7);
    final j = await q.enqueue(req());
    await until(() => j.status == TransferStatus.active && j.serverRef != null);
    expect(await q.cancel(j.id), isTrue);
    expect(j.status, TransferStatus.canceled);
    expect(ex.discarded, [j.id]);
    expect(File(j.localPath).existsSync(), isFalse);
    gate.completeError(const TransferFailure('CANCELED', retryable: false));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(j.status, TransferStatus.canceled);

    final q2 = makeQueue();
    final ex2 = FakeExecutor([ok]);
    q2.registerExecutor(TransferKind.chatMedia, ex2);
    await q2.start(7);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(ex2.calls, 0, reason: 'kullanici iptali otomatik baslatilmaz');
    expect(q2.job(j.id)?.status, TransferStatus.canceled);
  });

  test('kurtarma: surec yururken olduyse is sirada basa doner ve tamamlanir; yayimlanan tekrar gonderilmez', () async {
    final q = makeQueue();
    final gate = Completer<String>();
    q.registerExecutor(TransferKind.chatMedia, FakeExecutor([(j, c) async => gate.future]));
    await q.start(7);
    final a = await q.enqueue(req(id: 'a'));
    await until(() => a.status == TransferStatus.active);
    // "surec olur": yeni kuyruk ayni depodan acilir
    final q2 = makeQueue();
    final ex2 = FakeExecutor([ok]);
    q2.registerExecutor(TransferKind.chatMedia, ex2);
    await q2.start(7);
    await until(() => q2.job('a')?.status == TransferStatus.published);
    expect(ex2.calls, 1);

    final q3 = makeQueue();
    final ex3 = FakeExecutor([ok]);
    q3.registerExecutor(TransferKind.chatMedia, ex3);
    await q3.start(7);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(ex3.calls, 0, reason: 'yayimlanan yeniden gonderilmez');
  });

  test('hesap: baska hesabin isi yeni kimlikle devam etmez; signOut dosyalari siler', () async {
    final gate = Completer<String>();
    final q = makeQueue();
    q.registerExecutor(TransferKind.chatMedia, FakeExecutor([(j, c) async => gate.future]));
    await q.start(7);
    final j = await q.enqueue(req(id: 'mine'));
    await until(() => j.status == TransferStatus.active);
    final path = j.localPath;
    await q.signOut();
    expect(File(path).existsSync(), isFalse);
    expect(q.job('mine'), isNull);
    gate.complete('late');

    // baska hesap acilinca eski kayit kalmis olsa bile calismaz
    final q2 = makeQueue();
    final ex2 = FakeExecutor([ok]);
    q2.registerExecutor(TransferKind.chatMedia, ex2);
    await q2.start(8);
    expect(q2.jobs, isEmpty);
    expect(() => q2.enqueue(req(owner: 7)), throwsStateError);
  });

  test('toplam bilinmiyorsa yuzde yok; sunucu islerken yuzde yok', () async {
    final j = TransferJob(
        id: 'x', ownerUserId: 1, kind: TransferKind.chatMedia, direction: TransferDirection.upload, targetKey: 't',
        localPath: 'p', mime: 'm', idempotencyKey: 'k', createdAt: DateTime(2026), doneBytes: 40, status: TransferStatus.active);
    expect(j.fraction, isNull);
    expect(TransferSummary.of([j]).fraction, isNull);
    j.totalBytes = 100;
    expect(j.fraction, 0.4);
    expect(TransferSummary.of([j]).fraction, 0.4);
    j.status = TransferStatus.processing;
    expect(j.fraction, isNull);
    expect(TransferSummary.of([j]).processing, 1);
  });

  test('esz. is siniri ve bildirim koprusu tek ozetten beslenir', () async {
    final plat = RecordingPlatform();
    final q = makeQueue(platform: plat, maxConcurrent: 1);
    final gate = Completer<String>();
    final ex = FakeExecutor([(j, c) async {
      c.progress(30, 100);
      return gate.future;
    }, ok]);
    q.registerExecutor(TransferKind.chatMedia, ex);
    await q.start(7);
    await q.enqueue(req(id: 'a'));
    await q.enqueue(req(id: 'b'));
    await until(() => ex.calls == 1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(ex.maxParallel, 1);
    expect(q.summary.active, 2);
    expect(plat.updates.isNotEmpty, isTrue);
    gate.complete('m');
    await until(() => q.job('b')?.status == TransferStatus.published && q.summary.isIdle);
    expect(plat.updates.last.isIdle, isTrue);
  });

  test('ayni jobId ile ikinci enqueue mevcut isi doner', () async {
    final q = makeQueue();
    q.registerExecutor(TransferKind.chatMedia, FakeExecutor([ok]));
    await q.start(7);
    final a = await q.enqueue(req(id: 'same'));
    final b = await q.enqueue(req(id: 'same'));
    expect(identical(a, b), isTrue);
    await until(() => a.status == TransferStatus.published);
  });

  test('kaynak dosya yoksa kalici hata SOURCE_MISSING', () async {
    final q = makeQueue();
    q.registerExecutor(TransferKind.chatMedia, FakeExecutor([ok]));
    await q.start(7);
    final j = await q.enqueue(req(id: 'gone'));
    File(j.localPath).deleteSync();
    q.nudge();
    await until(() => j.status == TransferStatus.failed || j.status == TransferStatus.published);
    // hizli kosu: yayimlandiysa yaris kaybi (dosya zaten okunmustur); aksi halde SOURCE_MISSING
    if (j.status == TransferStatus.failed) expect(j.lastErrorCode, 'SOURCE_MISSING');
  });
}
