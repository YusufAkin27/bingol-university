import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/core/transfers/transfer_job.dart';
import 'package:bu_kampus/core/transfers/transfer_queue.dart';
import 'package:bu_kampus/core/transfers/transfer_store.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_transfer.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

class _Up extends PostMediaUploader {
  _Up(super.session);
  final List<Map<String, String>?> calls = [];
  int failOnCall = -1;

  @override
  Future<PostMedia> uploadWith(Uint8List bytes, {Map<String, String>? headers}) async {
    calls.add(headers);
    if (calls.length == failOnCall) throw ApiError(0, 'NETWORK', '');
    return PostMedia.fromJson(samplePostMedia(id: 100 + calls.length));
  }
}

class _Vid extends VideoUploader {
  _Vid(super.session);
  final List<Map<String, String>?> calls = [];

  @override
  Future<dynamic> upload(String path, PreparedVideo video,
      {void Function(double progress)? onProgress, Map<String, String>? headers, bool audio = false}) async {
    calls.add(headers);
    onProgress?.call(1);
    return {'media': samplePostMedia(id: 900, video: true)};
  }
}

class _Api extends PostApi {
  _Api(super.session);
  final List<Map<String, Object?>> created = [];
  Object? error;
  Completer<void>? gate;

  @override
  Future<Post> create(
      {String? text,
      int? mediaId,
      List<int>? mediaIds,
      List<int> mentionUserIds = const [],
      bool hideLikeCount = false,
      bool commentsDisabled = false,
      String? idempotencyKey}) async {
    created.add({'text': text, 'ids': mediaIds, 'mentions': mentionUserIds, 'key': idempotencyKey, 'hide': hideLikeCount});
    await gate?.future;
    final e = error;
    if (e != null) {
      error = null;
      throw e;
    }
    return Post.fromJson(samplePost(id: 777));
  }
}

Future<void> until(bool Function() cond, {int ms = 15000}) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('zaman asimi');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory tmp;
  late TransferQueue q;
  late _Up up;
  late _Vid vid;
  late _Api api;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('g2post');
    final s = makeSession(FakeBackend());
    up = _Up(s);
    vid = _Vid(s);
    api = _Api(s);
    q = TransferQueue(
      store: MemoryTransferStore(dir: tmp),
      maxAttempts: 3,
      backoff: (_) => Duration.zero,
      emitInterval: const Duration(milliseconds: 1),
    );
    q.registerExecutor(TransferKind.postMedia, PostTransferExecutor(s, photos: up, videos: vid, api: api));
    await q.start(1);
  });

  tearDown(() async {
    await q.dispose();
    try {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // kuyruk son dosya temizligini bu sirada bitirmis olabilir (yaris); geri kalan bir sey yok
    }
  });

  Future<TransferJob> enq({int photos = 2, String text = 'Merhaba', PreparedVideo? video}) => enqueuePostTransfer(
        q,
        ownerUserId: 1,
        text: text,
        mentions: const [PostMentionRef(5, 'Can Yildiz')],
        hideLikes: true,
        photos: video != null ? const [] : [for (var i = 0; i < photos; i++) (bytes: Uint8List.fromList(kFakePng), aspect: 0.8)],
        video: video,
      );

  test('foto: her yukleme ve gonderi isteginde is anahtari; yayimlandi yalniz sunucu sonucuyla', () async {
    api.gate = Completer<void>();
    final job = await enq();
    await until(() => q.job(job.id)!.status == TransferStatus.processing);
    expect(q.job(job.id)!.status, isNot(TransferStatus.published), reason: 'create yaniti gelmeden yayimlandi denmez');
    expect(api.created, hasLength(1));
    api.gate!.complete();
    await until(() => q.job(job.id)!.status == TransferStatus.published);
    final key = q.job(job.id)!.idempotencyKey;
    expect(up.calls.map((h) => h!['Idempotency-Key']), ['$key-m0', '$key-m1']);
    expect(api.created.single['key'], key);
    expect(api.created.single['ids'], [101, 102]);
    expect(api.created.single['text'], 'Merhaba');
    expect(api.created.single['mentions'], [5]);
    expect(api.created.single['hide'], true);
    expect(q.job(job.id)!.publishedRef, '777');
    // `published` durumu dosya silinmeden ONCE yazilir (iptal yarisi icin); silme hemen ardindan biter -> bekle.
    await until(() => !Directory(PostPayload.dirOf(q.job(job.id)!).path).existsSync());
    expect(Directory(PostPayload.dirOf(q.job(job.id)!).path).existsSync(), isFalse, reason: 'bitince yerel kopya silinir');
  });

  test('ag koparsa kalan fotograf yeniden denenir; yuklenen tekrar yuklenmez, anahtar ayni', () async {
    up.failOnCall = 2; // ikinci foto ilk denemede dusuyor
    final job = await enq();
    await until(() => q.job(job.id)!.status == TransferStatus.published);
    final key = q.job(job.id)!.idempotencyKey;
    expect(up.calls.map((h) => h!['Idempotency-Key']), ['$key-m0', '$key-m1', '$key-m1']);
    expect(api.created, hasLength(1));
    expect(api.created.single['ids'], [101, 103]);
  });

  test('uygunsuz ifade: kalici hata, metin ve dosyalar KORUNUR; anlasilir neden; duzenleme icin icerik okunur', () async {
    api.error = ApiError(422, 'CONTENT_PROFANITY', '');
    final job = await enq(text: 'duzeltilecek metin');
    await until(() => q.job(job.id)!.status == TransferStatus.failed);
    final j = q.job(job.id)!;
    expect(j.lastRetryable, isFalse);
    final pay = await PostPayload.read(PostPayload.dirOf(j));
    expect(pay.text, 'duzeltilecek metin');
    expect(pay.photos, hasLength(2));
    for (final p in pay.photos) {
      expect(File('${PostPayload.dirOf(j).path}${Platform.pathSeparator}${p.file}').existsSync(), isTrue);
    }
    expect(postFailureText(j, lookupAppLocalizations(const Locale('tr'))), lookupAppLocalizations(const Locale('tr')).postComposeErrProfanity);
    // Yeniden dene: kalici reddedildigi icin YENI anahtar, yuklemeler bastan.
    final oldKey = j.idempotencyKey;
    expect(await q.retry(job.id), isTrue);
    await until(() => q.job(job.id)!.status == TransferStatus.published);
    expect(q.job(job.id)!.idempotencyKey, isNot(oldKey));
  });

  test('POST_MEDIA_INVALID: yuklenen medya atilir, yeniden yuklenir ve tamamlanir', () async {
    api.error = ApiError(422, 'POST_MEDIA_INVALID', '');
    final job = await enq(photos: 1);
    await until(() => q.job(job.id)!.status == TransferStatus.published);
    expect(up.calls, hasLength(2));
    expect(api.created, hasLength(2));
  });

  test('429: gecici hata, otomatik yeniden denenir (is kaybolmaz)', () async {
    api.error = ApiError(429, 'RATE_LIMITED', '', retryAfter: 1);
    final job = await enq(photos: 1);
    await until(() => q.job(job.id)!.status == TransferStatus.published);
    expect(api.created, hasLength(2));
    expect(api.created.map((c) => c['key']).toSet(), hasLength(1), reason: 'ayni anahtar');
  });

  test('video: tek yukleme (-m0 anahtari) + poster, gonderi mediaIds=[video]', () async {
    final src = File('${tmp.path}${Platform.pathSeparator}src.mp4')..writeAsBytesSync(List.filled(4096, 7));
    final job = await enq(
        video: PreparedVideo(path: src.path, sizeBytes: 4096, durationMs: 5000, poster: Uint8List.fromList(kFakePng)));
    await until(() => q.job(job.id)!.status == TransferStatus.published);
    expect(vid.calls.single!['Idempotency-Key'], '${q.job(job.id)!.idempotencyKey}-m0');
    expect(api.created.single['ids'], [900]);
    expect(src.existsSync(), isTrue, reason: 'kullanicinin/onbellegin dosyasina dokunulmaz (kopya silinir)');
  });

  test('hesap cikisi: bekleyen paylasim ve dosyalari silinir, baska hesaba sizmaz', () async {
    api.gate = Completer<void>(); // create bekler
    final job = await enq();
    await until(() => q.job(job.id)!.status == TransferStatus.processing);
    final dir = PostPayload.dirOf(q.job(job.id)!);
    await q.signOut();
    api.gate!.complete();
    expect(q.jobsFor(), isEmpty);
    expect(dir.existsSync(), isFalse);
  });

  test('postFailureText: ag / hiz siniri / dosya yok kodlari anlasilir metne gider', () {
    final l = lookupAppLocalizations(const Locale('tr'));
    TransferJob mk(String code, {bool retry = true}) => TransferJob(
        id: 'x', ownerUserId: 1, kind: TransferKind.postMedia, direction: TransferDirection.upload, targetKey: kPostTransferTarget,
        localPath: 'a', mime: 'image/jpeg', idempotencyKey: 'k', createdAt: DateTime(2026))
      ..lastErrorCode = code
      ..lastRetryable = retry;
    expect(postFailureText(mk('NETWORK'), l), l.postComposeErrNetwork);
    expect(postFailureText(mk('RATE_LIMITED'), l), l.postComposeErrRate);
    expect(postFailureText(mk('FILES_MISSING', retry: false), l), l.g2PostErrFiles);
    expect(postFailureText(mk('IMG_TOO_LARGE', retry: false), l), l.postComposeErrImageTooLarge);
  });
}
