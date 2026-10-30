import 'dart:io';

import '../api.dart';
import '../platform/image_service.dart';
import '../platform/video_service.dart';
import '../session.dart';
import 'outbox.dart';

/// Kuyruktaki ekleri sohbet medya ucuna yükler (`POST /conversations/{id}/media`). Aynı yükleyiciler sohbet
/// ekranında da kullanılır; burada ekran bağımsız, dosyadan okur. Ağ yoksa [ApiError] (status 0) fırlatır.
OutboxMediaUploader outboxUploaderFor(Session session) {
  final images = MultipartUploader(session);
  final videos = VideoUploader(session);
  return (OutboxItem item, OutboxMedia media, File file, File? poster) async {
    final path = '/conversations/${item.conversationId}/media';
    final dynamic res;
    if (media.isVideo) {
      final pv = PreparedVideo(
        path: file.path,
        sizeBytes: media.size,
        durationMs: media.durationMs ?? 0,
        width: media.width,
        height: media.height,
        poster: poster == null ? null : await poster.readAsBytes(),
      );
      res = await videos.upload(path, pv);
    } else {
      res = await images.upload(path, PreparedImage(await file.readAsBytes(), media.mime));
    }
    final id = res is Map ? res['id'] : null;
    if (id is! num) throw ApiError(502, 'BAD_RESPONSE', '');
    return id.toInt();
  };
}
