import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../core/api.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../l10n/app_localizations.dart';
import 'post_models.dart';

AppLocalizations _trL10n() => lookupAppLocalizations(const Locale('tr'));

/// Sunucu/ağ/hazırlık hatalarını kısa mesaja çevirir (yükleme ve gönderi oluşturma ortak).
/// [l] verilmezse Türkçe kullanılır.
String postErrorText(Object e, [AppLocalizations? l]) {
  final t = l ?? _trL10n();
  if (e is ImageException) {
    return switch (e.code) {
      'TOO_LARGE' => t.postComposeErrImageTooLarge,
      'UNSUPPORTED_TYPE' => t.postComposeErrImageUnsupported,
      _ => t.postComposeErrImageUnreadable,
    };
  }
  if (e is ApiError) {
    if (e.isNetwork) return t.postComposeErrNetwork;
    switch (e.code) {
      case 'MEDIA_BLOCKED':
        return t.postComposeErrBlocked;
      case 'POST_MEDIA_INVALID':
        return t.postComposeErrMediaInvalid;
      case 'CONTENT_PROFANITY':
        return t.postComposeErrProfanity;
    }
    if (e.status == 429) return t.postComposeErrRate;
    if (e.status == 413) return t.postComposeErrFileTooLarge;
    if (e.message.isNotEmpty) return e.message;
  }
  return t.postComposeErrGeneric;
}

/// `POST /posts/media` (multipart `file`): tek fotoğraf. En uzun kenar 1600, kalite 85.
class PostMediaUploader {
  PostMediaUploader(this.session, {http.Client? client, ImageService? image})
      : _image = image ?? ImageService(),
        _up = MultipartUploader(session, client: client);

  final Session session;
  final ImageService _image;
  final MultipartUploader _up;

  static const path = '/posts/media';
  static const maxEdge = 1600;

  /// Hata: [ImageException] ya da [ApiError]; [postErrorText] ile çevrilir.
  Future<PostMedia> upload(Uint8List bytes) async {
    if (bytes.isEmpty) throw ImageException('EMPTY');
    final resized = await _fit(bytes);
    final prepared = await _image.prepare(resized);
    final json = await _up.upload(path, prepared);
    if (json is! Map) throw ApiError(500, 'BAD_RESPONSE', '');
    return PostMedia.fromJson(Map<String, dynamic>.from(json));
  }

  /// Büyükse yeniden boyutlandırır (yalnız 600 KB üzeri baytlar çözülür).
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
}
