import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../nav.dart';
import '../permissions/ensure_permission.dart';
import '../session.dart';

export 'package:image_picker/image_picker.dart' show ImageSource, XFile;

/// Yüklemeye hazır görsel: doğrulanmış tür + sınır altı boyut.
class PreparedImage {
  PreparedImage(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime; // image/jpeg | image/png | image/webp

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

  static const maxWidth = 1600.0;
  static const quality = 85;
  static const avatarLimit = 2 * 1024 * 1024;
  static const defaultLimit = 3 * 1024 * 1024;

  /// Galeriden/kameradan seçer (1600 px, kalite 85). İptalde null.
  /// Kamera kaynağında önce izin garanti edilir (manifestte CAMERA bildirili olduğundan Android
  /// kamera niyeti izinsiz çökerdi); galeri seçici kendi sistem seçicisini kullanır, çift istem olmaz.
  Future<XFile?> pick(ImageSource source) async {
    if (source == ImageSource.camera) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        if (!await ensurePermission(ctx, AppPermission.camera)) return null;
      }
    }
    return _picker.pickImage(source: source, maxWidth: maxWidth, imageQuality: quality, requestFullMetadata: false);
  }

  /// Seç + doğrula + gerekirse yeniden sıkıştır. İptalde null; geçersizse [ImageException].
  Future<PreparedImage?> pickPrepared(ImageSource source, {bool avatar = false}) async {
    final f = await pick(source);
    if (f == null) return null;
    return prepare(await f.readAsBytes(), avatar: avatar);
  }

  /// Tür (sihirli baytlar) ve boyut doğrulaması; sınırı aşarsa JPEG'e küçülterek sıkıştırır.
  Future<PreparedImage> prepare(Uint8List bytes, {bool avatar = false}) async {
    if (bytes.isEmpty) throw ImageException('EMPTY');
    final mime = sniffMime(bytes);
    if (mime == null) throw ImageException('UNSUPPORTED_TYPE');
    final limit = avatar ? avatarLimit : defaultLimit;
    if (bytes.length <= limit) return PreparedImage(bytes, mime);
    final out = await Isolate.run(() => _shrink(bytes, limit));
    if (out == null) throw ImageException('TOO_LARGE');
    return PreparedImage(out, 'image/jpeg');
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

  static Uint8List? _shrink(Uint8List bytes, int limit) {
    final src = img.decodeImage(bytes);
    if (src == null) return null;
    for (final w in [1600, 1280, 1024, 800, 640]) {
      for (final q in [85, 75, 65, 55]) {
        final scaled = src.width > w ? img.copyResize(src, width: w) : src;
        final out = Uint8List.fromList(img.encodeJpg(scaled, quality: q));
        if (out.length <= limit) return out;
      }
    }
    return null;
  }
}

/// `multipart/form-data` yükleme (alan adı `file`); ApiClient'a dokunmaz.
class MultipartUploader {
  MultipartUploader(this.session, {http.Client? client}) : _http = client ?? http.Client();

  final Session session;
  final http.Client _http;

  static const _timeout = Duration(seconds: 60);

  /// Örn. `upload('/users/me/avatar', img)`; yol `/api` önekisizdir. Sonuç JSON (çoğu uçta `avatarUrl`/`url`).
  /// [method] varsayılan POST; kapak gibi uçlar PUT ister.
  Future<dynamic> upload(String path, PreparedImage image, {String method = 'POST'}) =>
      _send(path, image, false, method);

  Future<dynamic> _send(String path, PreparedImage image, bool retried, String method) async {
    final api = session.api;
    final req = http.MultipartRequest(method, Uri.parse('$apiBase$path'));
    req.headers['Accept-Language'] = api.lang;
    req.headers['Accept'] = 'application/json';
    final t = api.tokens;
    if (t != null) req.headers['Authorization'] = 'Bearer ${t.access}';
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
        if (!e.isNetwork) api.onSessionExpired?.call();
        rethrow;
      }
      return _send(path, image, true, method);
    }

    final text = utf8.decode(res.bodyBytes);
    dynamic json;
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    if (json is Map && json['code'] is String) {
      throw ApiError(res.statusCode, json['code'] as String, (json['message'] as String?) ?? '');
    }
    throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '');
  }
}
