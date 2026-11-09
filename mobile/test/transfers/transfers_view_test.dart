import 'dart:async';
import 'dart:io';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/transfers/transfer_executor.dart';
import 'package:bu_kampus/core/transfers/transfer_job.dart';
import 'package:bu_kampus/core/transfers/transfer_queue.dart';
import 'package:bu_kampus/core/transfers/transfer_store.dart';
import 'package:bu_kampus/core/transfers/transfers_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Hang extends TransferExecutor {
  final done = Completer<String>();
  @override
  Future<String> run(TransferJob job, TransferRunContext ctx) {
    ctx.progress(25, 100);
    return done.future;
  }
}

void main() {
  testWidgets('Aktarimlar: yukleniyor + yuzde, iptal; yayimlanmadan Yayimlandi yazmaz', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('bu_tv_');
    final src = File('${tmp.path}/a.jpg')..writeAsBytesSync(List.filled(100, 1));
    final ex = _Hang();
    late TransferQueue q;
    // Kuyruk (Future zincirleri) gercek zaman diliminde kurulur: testWidgets sahte zamaninda mikro gorevler akmaz.
    await tester.runAsync(() async {
      q = TransferQueue(
          store: MemoryTransferStore(dir: Directory('${tmp.path}/f')..createSync()),
          emitInterval: const Duration(milliseconds: 1));
      q.registerExecutor(TransferKind.chatMedia, ex);
      await q.start(1);
      await q.enqueue(TransferRequest(
          ownerUserId: 1, kind: TransferKind.chatMedia, targetKey: 'conv:1', sourcePath: src.path, totalBytes: 100));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpWidget(MaterialApp(
      theme: BuTheme.light(),
      home: Scaffold(body: TransfersList(queue: q)),
    ));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('Yükleniyor'), findsOneWidget);
    expect(find.textContaining('25%'), findsOneWidget);
    expect(find.text('Yayımlandı'), findsNothing);
    expect(find.text('İptal'), findsOneWidget);
    await tester.runAsync(() async {
      ex.done.complete('m1');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Yayımlandı'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(q.dispose);
  });
}
