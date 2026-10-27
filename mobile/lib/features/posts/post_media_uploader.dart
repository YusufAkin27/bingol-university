import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../core/api.dart';
import '../../core/platform/image_service.dart';
import '../../core/platform/video_service.dart';
import '../../core/session.dart';
import '../chat/media_pick.dart';
import 'post_models.dart';

/// Gönderi medyası yüklemesi başarısız (kullanıcıya gösterilecek kısa Türkçe [message] ile).
class PostUploadException implements Exception {
  PostUploadException(this.message, {this.cancelled = false, this.retryable = true});
  final String message;
  final bool cancelled;
  final bool retryable;
  @override
  String toString() => 'PostUploadException($message)';
}

/// Sunucu/ağ/hazırlık hatalarını kısa Türkçe mesaja çevirir (yükleme ve gönderi oluşturma ortak).
String postErrorText(Object e) {
  if (e is PostUploadException) return e.message;
  if (e is VideoException) return _videoText(e.code);
  if (e is ImageException) {
    return switch (e.code) {
      'TOO_LARGE' => 'Görsel çok büyük.',
      'UNSUPPORTED_TYPE' => 'Bu görsel biçimi desteklenmiyor.',
      _ => 'Görsel okunamadı.',
    };
  }
  if (e is ApiError) {
    if (e.isNetwork) return 'Bağlantı yok, tekrar dene.';
    switch (e.code) {
      case 'VIDEO_TOO_LARGE':
        return 'Video çok büyük (en fazla 40 MB).';
      case 'VIDEO_TOO_LONG':
        return 'Video en fazla 60 saniye olabilir.';
      case 'VIDEO_INVALID':
        return 'Video biçimi desteklenmiyor.';
      case 'MEDIA_BLOCKED':
        return 'Bu içerik paylaşılamaz.';
      case 'POST_MEDIA_INVALID':
        return 'Medya geçersiz, yeniden yükle.';
      case 'CONTENT_PROFANITY':
        return 'Bu alanda uygunsuz ifade kullanılamaz. Lütfen metni düzenleyin.';
    }
    if (e.status == 429) return 'Çok hızlı paylaşım yapıyorsun, biraz bekle.';
    if (e.status == 413) return 'Dosya çok büyük.';
    if (e.message.isNotEmpty) return e.message;
  }
  return 'Bir sorun oluştu, tekrar dene.';
}

String _videoText(String code) => switch (code) {
      'TOO_LONG' => 'Video en fazla 60 saniye olabilir.',
      'TOO_LARGE' => 'Video çok büyük (en fazla 40 MB).',
      'UNSUPPORTED' => 'Bu cihazda video hazırlanamıyor.',
      'CANCELLED' => 'İptal edildi.',
      _ => 'Video hazırlanamadı.',
    };

/// İptal işareti; video sıkıştırmasını da durdurur.
class PostUploadCancel {
  final VideoCancel video = VideoCancel();
  bool get cancelled => video.cancelled;
  Future<void> cancel() => video.cancel();
}

/// `POST /posts/media` (multipart `file`, video için `poster`). Görsel: en uzun kenar 1600, kalite 85;
/// video: [VideoService] (60 sn / 40 MB doğrulama, Android'de sıkıştırma).
class PostMediaUploader {
  PostMediaUploader(this.session, {http.Client? client, VideoService? video, ImageService? image})
      : _image = image ?? ImageService(),
        _video = video ?? VideoService(),
        _imageUp = MultipartUploader(session, client: client),
        _videoUp = VideoUploader(session, client: client);

  final Session session;
  final ImageService _image;
  final VideoService _video;
  final MultipartUploader _imageUp;
  final VideoUploader _videoUp;

  static const path = '/posts/media';
  static const maxEdge = 1600;

  /// [onProgress] 0..1 (hazırlık + gönderim). Hata: [PostUploadException] (mesaj hazır) ya da [ApiError].
  Future<PostMedia> upload(MediaPick item, {void Function(double)? onProgress, PostUploadCancel? cancel}) async {
    try {
      onProgress?.call(0);
      final dynamic json = item.isVideo ? await _uploadVideo(item, onProgress, cancel) : await _uploadImage(item, onProgress);
      if (json is! Map) throw PostUploadException('Sunucudan beklenmeyen yanıt.');
      onProgress?.call(1);
      return PostMedia.fromJson(Map<String, dynamic>.from(json));
    } on PostUploadException {
      rethrow;
    } on ApiError catch (e) {
      throw PostUploadException(postErrorText(e), retryable: !_permanent(e));
    } on VideoException catch (e) {
      throw PostUploadException(_videoText(e.code),
          cancelled: e.code == 'CANCELLED', retryable: e.code != 'TOO_LONG' && e.code != 'TOO_LARGE');
    } on ImageException catch (e) {
      throw PostUploadException(postErrorText(e), retryable: false);
    } catch (_) {
      throw PostUploadException('Medya hazırlanamadı.');
    }
  }

  static bool _permanent(ApiError e) =>
      const {'VIDEO_TOO_LARGE', 'VIDEO_TOO_LONG', 'VIDEO_INVALID', 'MEDIA_BLOCKED'}.contains(e.code);

  Future<dynamic> _uploadImage(MediaPick item, void Function(double)? onProgress) async {
    final bytes = await item.imageBytes?.call();
    if (bytes == null || bytes.isEmpty) throw ImageException('EMPTY');
    final resized = await _fit(bytes);
    onProgress?.call(.3);
    final prepared = await _image.prepare(resized);
    onProgress?.call(.5);
    return _imageUp.upload(path, prepared);
  }

  /// Büyükse yeniden boyutlandırır (yalnız 600 KB üzeri baytlar çözülür; küçükler olduğu gibi gider).
  Future<Uint8List> _fit(Uint8List bytes) async {
    if (bytes.length < 600 * 1024) return bytes;
    try {
      final out = await Isolate.run(() {
        final src = img.decodeImage(bytes);
        if (src == null) return null;
        if (src.width <= maxEdge && src.height <= maxEdge) return null;
        final scaled = src.width >= src.height
            ? img.copyResize(src, width: maxEdge)
            : img.copyResize(src, height: maxEdge);
        return Uint8List.fromList(img.encodeJpg(scaled, quality: 85));
      });
      return out ?? bytes;
    } catch (_) {
      return bytes;
    }
  }

  Future<dynamic> _uploadVideo(MediaPick item, void Function(double)? onProgress, PostUploadCancel? cancel) async {
    final p = await item.videoPath?.call();
    if (p == null || p.isEmpty) throw VideoException('FAILED');
    final prepared = await _video.prepare(PickedVideo(p),
        cancel: cancel?.video, onProgress: (v) => onProgress?.call(.4 * v));
    if (cancel?.cancelled == true) throw VideoException('CANCELLED');
    onProgress?.call(.4);
    return _videoUp.upload(path, prepared, onProgress: (v) => onProgress?.call(.4 + .6 * v));
  }
}
