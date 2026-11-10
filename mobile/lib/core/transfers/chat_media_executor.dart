import 'dart:io';

import '../api.dart' show apiBase;
import '../platform/image_service.dart';
import '../platform/video_service.dart';
import '../session.dart';
import 'transfer_executor.dart';
import 'ios_background_upload.dart';
import 'transfer_job.dart';

/// Sohbet mesajını sunucuda tamamlar (G4 yazar): yüklenen ek kimliğiyle mesajı gönderir ve SUNUCUDAN dönen mesaj
/// kimliğini verir. `clientId` ile idempotent olmalıdır (aynı iş ikinci mesaj üretmez); [job.meta] içinde
/// `clientId`, `text`, `replyTo` gibi G4'ün koyduğu alanlar bulunur.
typedef ChatMessageFinalizer = Future<String> Function(TransferJob job, int attachmentId);

/// Sohbet medya yükleyici (`POST /conversations/{cid}/media`, `Idempotency-Key` = iş anahtarı).
///
/// Aşama 1: dosya sunucuya yüklenir (video ilerlemesi gönderilen bayttan; görselde ara ilerleme yoktur).
/// Aşama 2: [finalize] mesajı gönderir. "Yayımlandı" yalnız [finalize] sunucu sonucuyla dönünce olur.
/// İş meta alanları: `conversationId` (zorunlu), `durationMs`, `width`, `height`, `posterPath`.
class ChatMediaTransferExecutor extends TransferExecutor {
  ChatMediaTransferExecutor(this.session, this.finalize, {MultipartUploader? images, VideoUploader? videos, this.background})
      : _images = images ?? MultipartUploader(session),
        _videos = videos ?? VideoUploader(session);

  final Session session;
  final ChatMessageFinalizer finalize;
  final MultipartUploader _images;
  final VideoUploader _videos;

  /// iOS arka plan yükleme (yalnız FOTOĞRAF; video ön planda kalır). null ise ön plan Dart http.
  final IosBackgroundUploader? background;

  static int? _conv(TransferJob j) => (j.meta['conversationId'] as num?)?.toInt();

  @override
  Future<String> run(TransferJob job, TransferRunContext ctx) async {
    final cid = _conv(job);
    if (cid == null) throw const TransferFailure('BAD_JOB', retryable: false);
    var aid = int.tryParse(job.serverRef ?? '');
    if (aid == null) {
      final headers = {'Idempotency-Key': job.idempotencyKey};
      final path = '/conversations/$cid/media';
      final file = File(job.localPath);
      final size = job.totalBytes ?? await file.length();
      final dynamic res;
      try {
        if (job.mime.startsWith('video/')) {
          final posterPath = job.meta['posterPath'] as String?;
          final poster = posterPath != null && File(posterPath).existsSync() ? await File(posterPath).readAsBytes() : null;
          final pv = PreparedVideo(
            path: file.path,
            sizeBytes: size,
            durationMs: (job.meta['durationMs'] as num?)?.toInt() ?? 0,
            width: (job.meta['width'] as num?)?.toInt(),
            height: (job.meta['height'] as num?)?.toInt(),
            poster: poster,
          );
          res = await _videos.upload(path, pv,
              headers: headers, onProgress: (f) => ctx.progress((f * size).round(), size));
        } else if (background != null) {
          // Sıkıştırma ön planda yapılır; hazır bayt iş dizinine yazılır, URLSession dosyadan gönderir (arka planda sürer).
          final ready = await ImageService().prepareForUpload(path, PreparedImage(await file.readAsBytes(), job.mime));
          final out = File('${file.path}.bgup');
          await out.writeAsBytes(ready.bytes, flush: true);
          final api = session.api;
          final t = api.tokens;
          try {
            res = await background!.upload(
              taskKey: job.id,
              url: '$apiBase$path',
              filePath: out.path,
              fileName: ready.fileName,
              mime: ready.mime,
              headers: {
                ...headers,
                'Accept': 'application/json',
                'Accept-Language': api.lang,
                if (t != null) 'Authorization': 'Bearer ${t.access}',
              },
              onProgress: (sent, total) => ctx.progress(sent, total),
            );
          } finally {
            try {
              await out.delete();
            } catch (_) {}
          }
          ctx.progress(size, size);
        } else {
          res = await _images.upload(path, PreparedImage(await file.readAsBytes(), job.mime), headers: headers);
          ctx.progress(size, size);
        }
      } catch (e) {
        throw TransferFailure.fromError(e);
      }
      final id = res is Map ? res['id'] : null;
      if (id is! num) throw const TransferFailure('BAD_RESPONSE');
      aid = id.toInt();
      ctx.setServerRef('$aid');
    }
    if (ctx.canceled) {
      await discard(job..serverRef = '$aid');
      throw const TransferFailure('CANCELED', retryable: false);
    }
    ctx.markProcessing(); // dosya sunucuda; mesaj sunucu tarafından yayımlanana dek "Sunucuda işleniyor"
    try {
      return await finalize(job, aid);
    } catch (e) {
      throw TransferFailure.fromError(e);
    }
  }

  /// Gönderilmemiş eki sil (`DELETE /conversations/{cid}/media/{aid}`; mesaja bağlıysa sunucu 409 verir, yutulur).
  @override
  Future<void> discard(TransferJob job) async {
    final cid = _conv(job), aid = int.tryParse(job.serverRef ?? '');
    if (cid == null || aid == null) return;
    try {
      await session.api.delete('/conversations/$cid/media/$aid');
    } catch (_) {
      // Bilerek yutulur: yetim ek sunucuda gece süpürülür.
    }
  }
}
