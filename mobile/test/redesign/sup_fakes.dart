import 'dart:async';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/features/support/support_attachments.dart';

import 'p10_images.dart';

/// Destek ek testleri için sahte yükleyici: kimlik 100'den artar; [gate] verilirse yükleme onu bekler;
/// [failNext] true iken ilk yükleme 500 ile düşer.
class FakeUploader implements SupportAttachmentUploader {
  int next = 100;
  bool failNext = false;
  Completer<void>? gate;
  final List<String> log = [];

  Future<void> _wait() async {
    if (gate != null) await gate!.future;
    if (failNext) {
      failNext = false;
      throw ApiError(500, 'SERVER_ERROR', '');
    }
  }

  @override
  Future<SupportAttachment> uploadImage(PreparedImage image) async {
    await _wait();
    log.add('img ${image.bytes.length}');
    final id = next++;
    return SupportAttachment(id: id, kind: 'IMAGE', url: '/api/support/attachments/$id', thumbUrl: '/api/support/attachments/$id/thumb');
  }

  @override
  Future<SupportAttachment> uploadVideo(PreparedVideo video, void Function(double progress) onProgress) async {
    onProgress(.4);
    await _wait();
    onProgress(1);
    log.add('vid ${video.sizeBytes}');
    final id = next++;
    return SupportAttachment(id: id, kind: 'VIDEO', url: '/api/support/attachments/$id', durationMs: video.durationMs);
  }
}

/// Sahte video sıkıştırıcı: süre/boyut verilir, sıkıştırma yapmaz, poster üretir.
class FakeCompressor implements VideoCompressor {
  FakeCompressor({this.durationMs = 20000, this.sizeBytes = 3 * 1024 * 1024, this.poster0});
  final int durationMs;
  final int sizeBytes;
  final Uint8List? poster0;

  @override
  Future<VideoInfo?> info(String path) async => VideoInfo(path: path, sizeBytes: sizeBytes, durationMs: durationMs, width: 640, height: 360);
  @override
  Future<VideoInfo?> compress(String path, void Function(double progress) onProgress) async => null;
  @override
  Future<Uint8List?> poster(String path, {int positionMs = 0}) async => poster0 ?? p10Photo(3);
  @override
  Future<void> cancel() async {}
}
