import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart' show Session;
import 'package:bu_kampus/core/transfers/transfer_job.dart';
import 'package:bu_kampus/core/transfers/transfer_queue.dart';
import 'package:bu_kampus/core/transfers/transfer_store.dart';
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/pending_posts_strip.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/post_draft_store.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

class _Up extends PostMediaUploader {
  _Up(super.session);
  @override
  Future<PostMedia> upload(Uint8List bytes) async => PostMedia.fromJson(samplePostMedia(id: 4242));
}

/// Dogrudan yol (kuyruk yok): paylasim hata verir.
class _FailApi extends PostApi {
  _FailApi(super.session);
  @override
  Future<Post> create(
          {String? text,
          int? mediaId,
          List<int>? mediaIds,
          List<int> mentionUserIds = const [],
          bool hideLikeCount = false,
          bool commentsDisabled = false,
          String? idempotencyKey}) async =>
      throw ApiError(422, 'CONTENT_PROFANITY', '');
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

/// Gercek dosya G/C ile ilerleyen isler icin: gercek zamanda bekler, her turda sahte saati de oynatir.
Future<void> until(WidgetTester tester, bool Function() cond, {int ms = 5000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('zaman asimi');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 15));
  }
}

Future<void> realPump(WidgetTester tester, [int ms = 200]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() {
    loadTestFonts();
    mockSecureStorage();
  });

  late Directory tmp;
  late TransferQueue q;
  late PostDraftStore drafts;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('g2compose');
    // Executor KAYITLI DEGIL: isler sirada kalir (arka plan yurutmesi bu testlerin konusu degil).
    q = TransferQueue(store: MemoryTransferStore(dir: tmp), emitInterval: const Duration(milliseconds: 1));
    await q.start(1);
    drafts = PostDraftStore();
    await PostDraftStore.clearAll();
  });

  tearDown(() async {
    await q.dispose();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget host(FakeBackend b, Widget Function(Session) page, void Function(Object?) onResult) {
    final s = makeSession(b);
    return buildApp(Builder(
      builder: (c) => Center(
        child: TextButton(
          key: const ValueKey('open'),
          onPressed: () async => onResult(await Navigator.of(c).push<Object?>(MaterialPageRoute<Object?>(builder: (_) => page(s)))),
          child: const Text('ac'),
        ),
      ),
    ));
  }

  Future<void> pickPhotoFlow(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('composeGallery')));
    await settle(tester, const Duration(milliseconds: 900));
    await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
    await settle(tester, const Duration(milliseconds: 300));
  }

  Widget composer(Session s, {String? restore, PostApi? api}) => ComposePostPage(
        session: s,
        uploader: _Up(s),
        api: api,
        transferQueue: q,
        drafts: drafts,
        restoreJobId: restore,
        cropPhoto: (c, b, spec) async => CropOutcome.cropped(b),
        pickPhoto: (_) async => Uint8List.fromList(kFakePng),
      );

  testWidgets('Paylas: kuyruga alinir, sayfa PostQueued ile kapanir, "Paylasildi" DENMEZ, taslak silinir', (tester) async {
    useScreen(tester, const Size(390, 844));
    Object? result;
    await tester.pumpWidget(host(FakeBackend(), (s) => composer(s), (r) => result = r));
    await tester.tap(find.byKey(const ValueKey('open')));
    await settle(tester, const Duration(milliseconds: 500));
    await pickPhotoFlow(tester);
    await tester.enterText(find.byKey(const ValueKey('composeText')), 'Kuyruktaki metin');
    await tester.pump(const Duration(milliseconds: 900)); // taslak yazilir
    expect((await tester.runAsync(() => drafts.load(1)))?.text, 'Kuyruktaki metin');
    await tester.tap(find.byKey(const ValueKey('composeShare')));
    await until(tester, () => result != null);
    await settle(tester, const Duration(milliseconds: 600));
    expect(result, isA<PostQueued>());
    final jobs = q.jobsFor(targetKey: kPostTransferTarget);
    expect(jobs, hasLength(1));
    expect(jobs.single.status, isNot(TransferStatus.published));
    final pay = await tester.runAsync(() => PostPayload.read(PostPayload.dirOf(jobs.single)));
    expect(pay!.text, 'Kuyruktaki metin');
    expect(pay.photos, hasLength(1));
    expect(find.text('Paylaşıldı'), findsNothing);
    expect(await tester.runAsync(() => drafts.load(1)), isNull, reason: 'kuyruga alinan paylasimin taslagi silinir');
    noErr(tester);
  });

  testWidgets('taslak: hesap bazli, geri yuklenir; baska hesapta gorunmez; "At" silinir', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.runAsync(() => drafts.save(1, const PostDraft(text: 'yarim kalan @Can Yildiz', mentions: [(id: 5, name: 'Can Yildiz')])));
    expect(await tester.runAsync(() => drafts.load(2)), isNull, reason: 'baska hesabin taslagi yok');
    await tester.pumpWidget(host(FakeBackend(), (s) => composer(s), (_) {}));
    await tester.tap(find.byKey(const ValueKey('open')));
    await settle(tester, const Duration(milliseconds: 600));
    String txt() => tester.widget<TextField>(find.byKey(const ValueKey('composeText'))).controller!.text;
    await until(tester, () => txt().isNotEmpty);
    expect(txt(), 'yarim kalan @Can Yildiz');
    expect(find.byKey(const ValueKey('composeTagChip-5')), findsOneWidget);
    // Cikis/hesap degisimi temizleyicisi tum taslaklari siler.
    await tester.runAsync(PostDraftStore.clearAll);
    expect(await tester.runAsync(() => drafts.load(1)), isNull);
    noErr(tester);
  });

  testWidgets('geri jesti: dolu form onay ister; "At" taslagi siler', (tester) async {
    useScreen(tester, const Size(390, 844));
    await tester.pumpWidget(host(FakeBackend(), (s) => composer(s), (_) {}));
    await tester.tap(find.byKey(const ValueKey('open')));
    await settle(tester, const Duration(milliseconds: 600));
    await tester.enterText(find.byKey(const ValueKey('composeText')), 'silinecek');
    await tester.pump(const Duration(milliseconds: 900));
    expect((await tester.runAsync(() => drafts.load(1)))?.text, 'silinecek');
    await tester.tap(find.byKey(const ValueKey('composeClose')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('composeText')), findsOneWidget, reason: 'onay sorulur, hemen kapanmaz');
    noErr(tester);
  });

  testWidgets('hata gorunur yerde: kucuk ekranda uygunsuz ifade karti ekrana kaydirilir', (tester) async {
    useScreen(tester, const Size(390, 520));
    final b = FakeBackend();
    await tester.pumpWidget(buildApp(ComposePostPage(
      session: makeSession(b),
      uploader: _Up(makeSession(b)),
      api: _FailApi(makeSession(b)),
      cropPhoto: (c, bt, spec) async => CropOutcome.cropped(bt),
      pickPhoto: (_) async => Uint8List.fromList(kFakePng),
    )));
    await settle(tester, const Duration(milliseconds: 300));
    await pickPhotoFlow(tester);
    await tester.tap(find.byKey(const ValueKey('composeShare')));
    await settle(tester, const Duration(milliseconds: 1500));
    final err = find.byKey(const ValueKey('composeError'));
    expect(err, findsOneWidget);
    final r = tester.getRect(err);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(520), reason: 'hata katlanmanin altinda kalmamali');
    noErr(tester);
  });

  Future<TransferJob> pending(WidgetTester tester, {String text = 'metin'}) async => (await tester.runAsync(() => enqueuePostTransfer(
        q,
        ownerUserId: 1,
        text: text,
        photos: [(bytes: Uint8List.fromList(kFakePng), aspect: 0.8)],
      )))!;

  testWidgets('duzenle: basarisiz paylasim forma geri yuklenir; yeniden kuyruga alinca eski kayit kalkar', (tester) async {
    useScreen(tester, const Size(390, 844));
    final old = await pending(tester, text: 'reddedilen metin');
    old
      ..status = TransferStatus.failed
      ..lastRetryable = false
      ..lastErrorCode = 'CONTENT_PROFANITY';
    Object? result;
    await tester.pumpWidget(host(FakeBackend(), (s) => composer(s, restore: old.id), (r) => result = r));
    await tester.tap(find.byKey(const ValueKey('open')));
    await settle(tester, const Duration(milliseconds: 800));
    String txt() => tester.widget<TextField>(find.byKey(const ValueKey('composeText'))).controller!.text;
    await until(tester, () => txt().isNotEmpty);
    await settle(tester, const Duration(milliseconds: 400));
    expect(txt(), 'reddedilen metin');
    expect(find.byKey(const ValueKey('composePreview')), findsOneWidget, reason: 'dosya da geri geldi');
    await tester.enterText(find.byKey(const ValueKey('composeText')), 'duzeltilmis metin');
    await tester.tap(find.byKey(const ValueKey('composeShare')));
    await until(tester, () => result != null);
    expect(result, isA<PostQueued>());
    expect(q.job(old.id), isNull, reason: 'eski kayit kaldirildi');
    final now = q.jobsFor(targetKey: kPostTransferTarget);
    expect(now, hasLength(1));
    expect((await tester.runAsync(() => PostPayload.read(PostPayload.dirOf(now.single))))!.text, 'duzeltilmis metin');
    noErr(tester);
  });

  group('bekleyen paylasim satiri', () {
    Future<void> mount(WidgetTester tester, FakeBackend b, {void Function(Post)? onPublished}) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: PendingPostsStrip(session: makeSession(b), queue: q, onPublished: onPublished)))));
      await tester.pump(const Duration(milliseconds: 100)); // yayin akisina abone olunsun
    }

    testWidgets('sirada / yukleniyor yuzde / baglanti bekleniyor / paylasiliyor durumlari; iptal onayli', (tester) async {
      final j = await pending(tester);
      await mount(tester, FakeBackend());
      expect(find.text('Paylaşım sırada'), findsOneWidget);
      j
        ..status = TransferStatus.active
        ..totalBytes = 100
        ..doneBytes = 50;
      q.nudge();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Paylaşım yükleniyor 50%'), findsOneWidget);
      j.status = TransferStatus.waitingNetwork;
      q.nudge();
      await tester.pump();
      // nudge() beklemeyi kuyruga cevirir; metin "sirada" ya da "baglanti bekleniyor" olabilir: yayimlandi DEMEZ
      expect(find.text('Paylaşıldı'), findsNothing);
      j.status = TransferStatus.processing;
      q.nudge();
      await tester.pump();
      expect(find.text('Paylaşılıyor'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pendingCancel')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Paylaşım silinsin mi?'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('basarisiz: neden gorunur; kalici reddedilirse Yeniden dene yok, Duzenle + Sil var; gecicide Yeniden dene var', (tester) async {
      final j = await pending(tester);
      j
        ..status = TransferStatus.failed
        ..lastRetryable = false
        ..lastErrorCode = 'CONTENT_PROFANITY';
      await mount(tester, FakeBackend());
      expect(find.text('Paylaşılamadı'), findsOneWidget);
      expect(find.byKey(const ValueKey('pendingError')), findsOneWidget);
      expect(find.byKey(const ValueKey('pendingRetry')), findsNothing);
      expect(find.byKey(const ValueKey('pendingEdit')), findsOneWidget);
      expect(find.byKey(const ValueKey('pendingRemove')), findsOneWidget);
      j
        ..lastRetryable = true
        ..lastErrorCode = 'NETWORK';
      q.nudge();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('pendingRetry')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pendingRetry')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(j.status, TransferStatus.queued, reason: 'yeniden dene kuyruga alir; dosya ve metin duruyor');
      noErr(tester);
    });

    testWidgets('yayimlandi: yalniz sunucu sonucu gelince "Paylasildi" + gonderi callback; sonra kayit kalkar', (tester) async {
      final b = FakeBackend();
      final fp = fakePosts(b);
      final pid = fp.posts.first['id'] as int;
      final j = await pending(tester);
      Post? got;
      await mount(tester, b, onPublished: (p) => got = p);
      expect(find.text('Paylaşıldı'), findsNothing);
      j
        ..status = TransferStatus.published
        ..publishedRef = '$pid';
      q.nudge();
      await settle(tester, const Duration(milliseconds: 800));
      await until(tester, () => got != null);

      expect(got?.id, pid);
      expect(find.text('Paylaşıldı'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // kayit 4 sn sonra kaldirilir
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 3));
      noErr(tester);
    });
  });
}
