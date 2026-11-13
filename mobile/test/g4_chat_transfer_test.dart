import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/transfers/transfer_executor.dart';
import 'package:bu_kampus/core/transfers/transfer_job.dart';
import 'package:bu_kampus/core/transfers/transfer_queue.dart';
import 'package:bu_kampus/core/transfers/transfer_store.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_transfer.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// G4 x G10: sohbet medya mesajı aktarım kuyruğuna bağlanır. Gerçek yükleme/sunucu YOK: çalıştırıcı sahtedir;
/// bu testler balon durum eşlemesini, yeniden denemeyi ve "Gönderildi yalnız sunucu mesaj kimliği dönünce"
/// kuralını doğrular. Gerçek cihazda arka plan/süreç ölümü doğrulaması YAPILMAMIŞTIR.

class _ScriptExecutor extends TransferExecutor {
  _ScriptExecutor(this.steps);
  final List<Future<String> Function(TransferJob, TransferRunContext)> steps;
  int calls = 0;
  @override
  Future<String> run(TransferJob job, TransferRunContext ctx) => steps[calls++ < steps.length ? calls - 1 : steps.length - 1](job, ctx);
}

final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

FakeBackend _be() => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': <Object>[], 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe'},
      {'userId': 11, 'displayName': 'Ali'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });
  setUp(() {
    MessageCache.instance = MessageCache.memoryOnly();
    debugResetChatSeen();
  });

  testWidgets('kuyruktaki medya: gönderiliyor -> hata -> yeniden dene -> yalnız sunucu kimliği dönünce Gönderildi', (tester) async {
    late TransferQueue q;
    late File src;
    final gate = Completer<void>();
    final exec = _ScriptExecutor([
      (j, c) async {
        c.progress(40, 100);
        await gate.future;
        throw const TransferFailure('REJECTED', retryable: false);
      },
      (j, c) async {
        c.progress(100, 100);
        c.markProcessing();
        return '77'; // sunucu mesaj kimliği
      },
    ]);
    await tester.runAsync(() async {
      src = File('${Directory.systemTemp.path}/g4_src_${DateTime.now().microsecondsSinceEpoch}.png');
      await src.writeAsBytes(_png);
      q = TransferQueue(
        store: MemoryTransferStore(),
        backoff: (_) => Duration.zero,
        emitInterval: const Duration(milliseconds: 1),
      );
      q.registerExecutor(TransferKind.chatMedia, exec);
      await q.start(1);
      await q.enqueue(TransferRequest(
        ownerUserId: 1,
        kind: TransferKind.chatMedia,
        targetKey: ChatTransfers.targetKey(1),
        sourcePath: src.path,
        mime: 'image/png',
        meta: const {'conversationId': 1, 'text': 'kuyruktan gelen aciklama'},
        jobId: 'cid-abc-12345678',
      ));
    });
    final s = makeSession(_be());
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(MaterialApp(
      theme: BuTheme.light(),
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ChatDetailPage(
        session: s,
        connectRealtime: false,
        realtime: ChatRealtime(s),
        transferQueue: q,
        conversation: const {
          'id': 1,
          'type': 'DIRECT',
          'title': 'Ali Veli',
          'peer': {'id': 11, 'displayName': 'Ali Veli'},
        },
      ),
    ));

    Future<void> pumpReal([int ms = 60]) async {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (var i = 0; i < 6; i++) {
      await pumpReal();
    }
    // Süreç yeniden açılmış gibi: kuyruktaki iş balon olarak geri geldi, "gönderiliyor" durumunda.
    expect(find.text('kuyruktan gelen aciklama'), findsOneWidget);
    expect(find.textContaining('Gönderildi'), findsNothing);
    expect(find.textContaining('Yeniden dene'), findsNothing);

    gate.complete(); // sunucu reddetti -> kalıcı hata
    for (var i = 0; i < 6; i++) {
      await pumpReal();
    }
    expect(find.textContaining('Yeniden dene'), findsOneWidget);
    expect(find.textContaining('Gönderildi'), findsNothing);

    await tester.tap(find.textContaining('Yeniden dene'));
    for (var i = 0; i < 10; i++) {
      await pumpReal();
    }
    expect(exec.calls, 2);
    expect(q.job('cid-abc-12345678')?.status, TransferStatus.published);
    expect(q.job('cid-abc-12345678')?.publishedRef, '77');
    // Sunucu mesaj kimliği döndü: artık gönderildi (karşıya ulaştı / okundu ayrı receipt olaylarıdır).
    expect(find.textContaining('Yeniden dene'), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('msg-status-line')), matching: find.textContaining('Gönderildi')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() async {
      if (await src.exists()) await src.delete();
    });
  });

  testWidgets('ChatTransfers.enqueue: kalıcı iş, meta ve idempotent kimlik; finalize clientId + attachmentIds gönderir', (tester) async {
    late TransferQueue q;
    late bool ok;
    final be = FakeBackend()..on('/conversations/1/messages', {'id': 99, 'conversationId': 1, 'senderId': 1, 'text': 'x'});
    final s = makeSession(be);
    await tester.runAsync(() async {
      q = TransferQueue(store: MemoryTransferStore(), emitInterval: const Duration(milliseconds: 1));
      await q.start(1);
      ok = await ChatTransfers.enqueue(q,
          ownerUserId: 1,
          conversationId: 1,
          clientId: 'cid-xyz-12345678',
          text: 'baslik',
          replyToMessageId: 5,
          image: PreparedImage(_png, 'image/png'));
    });
    expect(ok, isTrue);
    final j = q.job('cid-xyz-12345678')!;
    expect(j.targetKey, 'conv:1');
    expect(j.meta['conversationId'], 1);
    expect(j.meta['replyToMessageId'], 5);
    expect(j.mime, 'image/png');
    // Başka hesabın kuyruğuna alınmaz.
    late bool other;
    await tester.runAsync(() async {
      other = await ChatTransfers.enqueue(q, ownerUserId: 2, conversationId: 1, clientId: 'cid-other-1234', text: '', image: PreparedImage(_png, 'image/png'));
    });
    expect(other, isFalse);
    // Tamamlama: mesaj clientId (= iş kimliği) ve ek kimliğiyle gider; sunucu kimliği döner.
    late String ref;
    await tester.runAsync(() async {
      ref = await ChatTransfers.finalize(s, j, 321);
    });
    expect(ref, '99');
    final body = be.bodies['POST /conversations/1/messages'] as Map;
    expect(body['clientId'], 'cid-xyz-12345678');
    expect(body['attachmentIds'], [321]);
    expect(body['replyToMessageId'], 5);
    await tester.runAsync(() => q.signOut());
  });
}
