import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../nav.dart';
import '../permissions/ensure_permission.dart';
import '../session.dart';
import 'media_compression.dart';

export 'package:image_picker/image_picker.dart' show ImageSource, XFile;

/// Yüklemeye hazır görsel: doğrulanmış tür + sınır altı boyut.
class PreparedImage {
  PreparedImage(this.bytes, this.mime, {this.compression});
  final Uint8List bytes;
  final String mime; // image/jpeg | image/png | image/webp
  final CompressionStats? compression;

  String get fileName => 'upload.${mime == 'image/png' ? 'png' : mime == 'image/webp' ? 'webp' : 'jpg'}';
}

class ImageException implements Exception {
  ImageException(this.code);

  /// UNSUPPORTED_TYPE | TOO_LARGE | EMPTY
  final String code;
  @override
  String toString() => 'ImageException($code)';
}

class ImageService {
  ImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Seçici üst sınırı: UZUN kenar 2048 px, JPEG kalitesi 88. Eskiden yalnız genişlik 1600 / kalite 85 idi
  /// (dikey fotoğrafta uzun kenar sınırsız, yatayda gereksiz düşük); sunucu sohbet görselini kendisi küçültür,
  /// istemci kaliteyi gereksiz düşürmemeli.
  static const maxEdge = 2048.0;
  static const quality = 88;
  static const avatarLimit = 2 * 1024 * 1024;
  static const defaultLimit = 3 * 1024 * 1024;

  /// Sohbet görseli ham yükleme sınırı (sunucu `app.media.chat.max-upload-bytes` 5 MB; pay bırakılır).
  static const chatLimit = 4 * 1024 * 1024;

  /// Tum multipart girisleri bu kapidan gecer; once hazirlanmissa tekrar kodlanmaz.
  Future<PreparedImage> prepareForUpload(String path, PreparedImage image) {
    final avatar = path.endsWith('/avatar') || path.endsWith('/logo');
    final limit = avatar ? avatarLimit
        : path == '/forum/media' ? 8 * 1024 * 1024
        : path.startsWith('/conversations/') && path.endsWith('/media') ? chatLimit
        : defaultLimit;
    if (image.compression != null && image.bytes.length <= limit) return Future.value(image);
    return prepare(image.bytes, avatar: avatar, limit: limit);
  }

  /// Galeriden/kameradan seçer (uzun kenar 2048 px, kalite 88). İptalde null.
  /// Kamera kaynağında önce izin garanti edilir (manifestte CAMERA bildirili olduğundan Android
  /// kamera niyeti izinsiz çökerdi); galeri seçici kendi sistem seçicisini kullanır, çift istem olmaz.
  Future<XFile?> pick(ImageSource source) async {
    if (source == ImageSource.camera) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        // direct: 'Fotoğraf çek' dokunuşu zaten niyeti söylüyor; yalnız sistem istemi (çift pencere yok).
        if (!await ensurePermission(ctx, AppPermission.camera, direct: true)) return null;
      }
    }
    return _picker.pickImage(
        source: source, maxWidth: maxEdge, maxHeight: maxEdge, imageQuality: quality, requestFullMetadata: false);
  }

  /// Seç + doğrula + gerekirse yeniden sıkıştır. İptalde null; geçersizse [ImageException].
  Future<PreparedImage?> pickPrepared(ImageSource source, {bool avatar = false}) async {
    final f = await pick(source);
    if (f == null) return null;
    return prepare(await f.readAsBytes(), avatar: avatar);
  }

  /// Tür ve boyut doğrulaması + kalite kontrollü WebP; sert sınır aşılırsa JPEG boyutlandırma.
  /// [limit] verilirse varsayılan sınırın yerine geçer (sohbet: [chatLimit]).
  Future<PreparedImage> prepare(Uint8List bytes, {bool avatar = false, int? limit}) async {
    if (bytes.isEmpty) throw ImageException('EMPTY');
    final mime = sniffMime(bytes);
    if (mime == null) throw ImageException('UNSUPPORTED_TYPE');
    limit ??= avatar ? avatarLimit : defaultLimit;
    final lim = limit;
    if (bytes.length <= lim && (bytes.length < PhotoCompression.minBytes || mime == 'image/webp')) {
      return PreparedImage(bytes, mime, compression: CompressionStats(
        originalBytes: bytes.length, outputBytes: bytes.length, codec: 'original', ssim: 1));
    }
    try {
      final optimized = await Isolate.run(() => PhotoCompression.optimize(bytes, mime, lim));
      if (optimized.bytes.length <= lim) {
        return PreparedImage(optimized.bytes, optimized.mime, compression: optimized.stats);
      }
    } catch (_) {
      // Codec failure must not prevent uploading an otherwise supported original.
    }
    if (bytes.length <= lim) return PreparedImage(bytes, mime);
    final out = await Isolate.run(() => shrink(bytes, lim));
    if (out == null) throw ImageException('TOO_LARGE');
    return PreparedImage(out, 'image/jpeg', compression: CompressionStats(
      originalBytes: bytes.length, outputBytes: out.length, codec: 'JPEG resized'));
  }

  /// Dosya imzasından tür; uzantıya/istemci bildirimine güvenilmez.
  static String? sniffMime(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
    if (b.length >= 12 &&
        ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  /// Uzun kenar basamakları (px) ve JPEG kaliteleri: önce boyutu koruyup kaliteyi düşürmeden en yüksek çiftten başlar.
  /// EXIF yönü piksellere işlenir (aksi halde yeniden kodlanan fotoğraf yan çıkar); konum EXIF'i yeniden
  /// kodlamayla zaten atılır.
  static const shrinkEdges = [2048, 1600, 1280, 1024, 800, 640];
  static const shrinkQualities = [88, 80, 70, 60];

  @visibleForTesting
  static Uint8List? shrink(Uint8List bytes, int limit) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final src = img.bakeOrientation(decoded);
    for (final e in shrinkEdges) {
      final long = src.width >= src.height;
      final big = (long ? src.width : src.height) > e;
      final scaled = !big ? src : (long ? img.copyResize(src, width: e) : img.copyResize(src, height: e));
      for (final q in shrinkQualities) {
        final out = Uint8List.fromList(img.encodeJpg(scaled, quality: q));
        if (out.length <= limit) return out;
      }
    }
    return null;
  }
}

/// `multipart/form-data` yükleme (alan adı `file`); ApiClient'a dokunmaz.
class MultipartUploader {
  MultipartUploader(this.session, {http.Client? client, ImageService? image})
      : _http = client ?? http.Client(), _image = image ?? ImageService();

  final Session session;
  final http.Client _http;
  final ImageService _image;

  static const _timeout = Duration(seconds: 60);

  /// Örn. `upload('/users/me/avatar', img)`; yol `/api` önekisizdir. Sonuç JSON (çoğu uçta `avatarUrl`/`url`).
  /// [method] varsayılan POST; kapak gibi uçlar PUT ister.
  /// [headers]: ek başlıklar (örn. aktarım kuyruğunun `Idempotency-Key`'i).
  Future<dynamic> upload(String path, PreparedImage image, {String method = 'POST', Map<String, String>? headers}) async {
    final ready = await _image.prepareForUpload(path, image);
    return _send(path, ready, false, method, headers);
  }

  Future<dynamic> _send(String path, PreparedImage image, bool retried, String method, [Map<String, String>? headers]) async {
    final api = session.api;
    final req = http.MultipartRequest(method, Uri.parse('$apiBase$path'));
    req.headers['Accept-Language'] = api.lang;
    req.headers['Accept'] = 'application/json';
    final t = api.tokens;
    if (t != null) req.headers['Authorization'] = 'Bearer ${t.access}';
    if (headers != null) req.headers.addAll(headers);
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      image.bytes,
      filename: image.fileName,
      contentType: MediaType.parse(image.mime),
    ));

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } catch (_) {
      throw ApiError(0, 'NETWORK', '');
    }

    if (res.statusCode == 401 && t != null && !retried) {
      try {
        await api.refresh();
      } on ApiError catch (e) {
        api.handleRefreshFailure(e);
        rethrow;
      }
      return _send(path, image, true, method, headers);
    }

    // Geçersiz UTF-8 (proxy/portal gövdesi) FormatException sızdırmasın: ApiError akışı bozulmaz (ApiClient ile aynı kural).
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    dynamic json;
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    if (json is Map && json['code'] is String) {
      throw ApiError(res.statusCode, json['code'] as String, json['message'] is String ? json['message'] as String : '');
    }
    throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '');
  }
}
