import 'dart:async';
import 'dart:io';

import '../../core/platform/image_service.dart';
import '../../core/platform/video_service.dart';
import '../../core/session.dart';
import '../../core/transfers/chat_media_executor.dart';
import '../../core/transfers/ios_background_upload.dart';
import '../../core/transfers/transfer_hub.dart';
import '../../core/transfers/transfer_job.dart';
import '../../core/transfers/transfer_queue.dart';

/// Sohbet medya mesajlarını G10 kalıcı aktarım kuyruğuna bağlar (G4).
///
/// Tek ek (1 fotoğraf VEYA 1 video) taşıyan mesaj bu yoldan gider: dosya yüklenir, ardından mesaj
/// `attachmentIds + clientId` ile tamamlanır. Aktarıldı (bayt) != mesaj gönderildi (sunucu mesaj kimliği döndü) !=
/// karşıya ulaştı (`receipt`) != okundu (`receipt`) ayrı olaylardır; bu dosya yalnız ilk ikisini üretir.
/// Sayfa kapansa/uygulama yeniden açılsa da iş kuyrukta sürer; iş kimliği = mesajın `clientId`'si.
class ChatTransfers {
  ChatTransfers._();

  static final _published = StreamController<Map<String, dynamic>>.broadcast();

  /// Sunucunun yayımladığı mesaj (tamamlama yanıtı): açık sohbet balonu bununla değiştirir.
  static Stream<Map<String, dynamic>> get published => _published.stream;

  static String targetKey(int conversationId) => 'conv:$conversationId';

  /// Mesajı tamamlar (idempotent: `clientId` aynı kalır) ve SUNUCU mesaj kimliğini döndürür.
  static Future<String> finalize(Session session, TransferJob job, int attachmentId) async {
    final cid = (job.meta['conversationId'] as num?)?.toInt();
    if (cid == null) throw const FormatException('conversationId yok');
    final reply = (job.meta['replyToMessageId'] as num?)?.toInt();
    final res = await session.api.post('/conversations/$cid/messages', {
      'text': (job.meta['text'] as String?) ?? '',
      'clientId': job.id,
      if (reply != null) 'replyToMessageId': reply,
      'attachmentIds': [attachmentId],
      if (job.meta['viewOnce'] == true) 'viewOnce': true,
    });
    if (res is! Map || res['id'] is! num) throw const FormatException('mesaj kimliği dönmedi');
    if (!_published.isClosed) _published.add(Map<String, dynamic>.from(res));
    return '${(res['id'] as num).toInt()}';
  }

  /// Sesli mesajı kuyruğa alır (kayıt dosyası iş dizinine TAŞINIR/kopyalanır). Başarısızsa false.
  static Future<bool> enqueueVoice(
    TransferQueue queue, {
    required int ownerUserId,
    required int conversationId,
    required String clientId,
    required String path,
    required int durationMs,
    int? replyToMessageId,
  }) async {
    if (queue.owner != ownerUserId) return false;
    try {
      final filesRoot = await queue.store.filesDir();
      final jobDir = Directory('${filesRoot.path}${Platform.pathSeparator}$clientId');
      await jobDir.create(recursive: true);
      final dest = File('${jobDir.path}${Platform.pathSeparator}voice.m4a');
      await File(path).copy(dest.path);
      await queue.enqueue(TransferRequest(
        ownerUserId: ownerUserId,
        kind: TransferKind.chatMedia,
        targetKey: targetKey(conversationId),
        sourcePath: dest.path,
        mime: 'audio/mp4',
        meta: <String, Object?>{
          'conversationId': conversationId,
          'text': '',
          if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
          'durationMs': durationMs,
        },
        jobId: clientId,
      ));
      try {
        await File(path).delete();
      } catch (_) {
        // Geçici kayıt; sistem temizler.
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _registered = false;

  /// Çalıştırıcıyı kaydeder (idempotent). Kuyruk başlamadan önce (açılışta) çağrılmalı: süreç ölümünden kurtarılan
  /// işler çalıştırıcı olmadan bekler.
  static void register() {
    if (_registered) return;
    _registered = true;
    TransferHub.instance.addExecutor(
      TransferKind.chatMedia,
      (session) => ChatMediaTransferExecutor(session, (job, aid) => finalize(session, job, aid),
          background: IosBackgroundUploader.shared),
    );
  }

  static String _ext(String mime) => switch (mime) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/gif' => 'gif',
        'video/quicktime' => 'mov',
        'video/webm' => 'webm',
        'video/mp4' => 'mp4',
        _ => 'jpg',
      };

  /// Tek eki kuyruğa alır. Başarısızsa false (çağıran eski yola düşer); dosya sistemi/kuyruk hatası yutulur.
  static Future<bool> enqueue(
    TransferQueue queue, {
    required int ownerUserId,
    required int conversationId,
    required String clientId,
    required String text,
    int? replyToMessageId,
    bool viewOnce = false,
    PreparedImage? image,
    PreparedVideo? video,
  }) async {
    if (queue.owner != ownerUserId || (image == null) == (video == null)) return false;
    File? tmp;
    try {
      final filesRoot = await queue.store.filesDir();
      final jobDir = Directory('${filesRoot.path}${Platform.pathSeparator}$clientId');
      await jobDir.create(recursive: true);
      final String srcPath;
      final String mime;
      final meta = <String, Object?>{
        'conversationId': conversationId,
        'text': text,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        if (viewOnce) 'viewOnce': true,
      };
      if (image != null) {
        mime = image.mime;
        tmp = File('${Directory.systemTemp.path}${Platform.pathSeparator}g4_$clientId.${_ext(mime)}');
        await tmp.writeAsBytes(image.bytes, flush: true);
        srcPath = tmp.path;
      } else {
        final v = video!;
        mime = 'video/mp4';
        if (v.path != null) {
          srcPath = v.path!;
        } else {
          tmp = File('${Directory.systemTemp.path}${Platform.pathSeparator}g4_$clientId.mp4');
          await tmp.writeAsBytes(v.bytes!, flush: true);
          srcPath = tmp.path;
        }
        meta['durationMs'] = v.durationMs;
        if (v.width != null) meta['width'] = v.width;
        if (v.height != null) meta['height'] = v.height;
        final poster = v.poster;
        if (poster != null) {
          // Kuyruk işi bitince/iptalde iş dizinini siler: poster de onunla gider.
          final pf = File('${jobDir.path}${Platform.pathSeparator}poster.jpg');
          await pf.writeAsBytes(poster, flush: true);
          meta['posterPath'] = pf.path;
        }
      }
      await queue.enqueue(TransferRequest(
        ownerUserId: ownerUserId,
        kind: TransferKind.chatMedia,
        targetKey: targetKey(conversationId),
        sourcePath: srcPath,
        mime: mime,
        meta: meta,
        jobId: clientId,
      ));
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {
        // Geçici dosya; sistem temizler.
      }
    }
  }
}
