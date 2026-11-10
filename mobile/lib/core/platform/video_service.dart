import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart' as vc;
import 'package:video_player/video_player.dart';

import '../api.dart';
import '../session.dart';
import 'video_frame.dart';
import 'media_compression.dart';
import 'image_service.dart';

/// Seçilmiş (henüz işlenmemiş) video dosyası.
class PickedVideo {
  const PickedVideo(this.path);
  final String path;
}

/// Bir video dosyasının özeti.
class VideoInfo {
  const VideoInfo(
      {required this.path, required this.sizeBytes, required this.durationMs, this.width, this.height, this.bytes});
  final String path;
  final int sizeBytes;
  final int durationMs;
  final int? width;
  final int? height;

  /// Bellek içi içerik (testler); üretimde null, dosya yolundan okunur.
  final Uint8List? bytes;
}

/// Yüklemeye hazır video: sıkıştırılmış dosya + önizleme (poster) karesi.
class PreparedVideo {
  PreparedVideo({
    this.path,
    this.bytes,
    required this.sizeBytes,
    required this.durationMs,
    this.width,
    this.height,
    this.poster,
    this.compression,
  }) : assert(path != null || bytes != null);

  /// Disk yolu (üretimde); testlerde yerine [bytes] verilebilir.
  final String? path;
  final Uint8List? bytes;
  final int sizeBytes;
  final int durationMs;
  final int? width;
  final int? height;

  /// JPEG önizleme karesi (alınamazsa null).
  final Uint8List? poster;
  final CompressionStats? compression;

  String get fileName => 'video.mp4';

  /// Aynı video, farklı kapak (poster) karesiyle.
  PreparedVideo withPoster(Uint8List? poster) => PreparedVideo(
        path: path,
        bytes: bytes,
        sizeBytes: sizeBytes,
        durationMs: durationMs,
        width: width,
        height: height,
        poster: poster,
        compression: compression,
      );
}

class VideoException implements Exception {
  VideoException(this.code);

  /// TOO_LONG | TOO_LARGE | UNSUPPORTED | CANCELLED | FAILED
  final String code;
  @override
  String toString() => 'VideoException($code)';
}

/// Kullanıcı vazgeçince sıkıştırmayı durdurmak için.
class VideoCancel {
  bool _cancelled = false;
  Future<void> Function()? _onCancel;
  bool get cancelled => _cancelled;

  Future<void> cancel() async {
    _cancelled = true;
    await _onCancel?.call();
  }
}

/// Sıkıştırma/ön izleme katmanı. Üretimde [PlatformVideoCompressor]; testlerde sahtesi verilir.
abstract class VideoCompressor {
  /// Bilgi okunamazsa null.
  Future<VideoInfo?> info(String path);

  /// En fazla 1080p sıkıştırır; başarısızlıkta/iptalde null.
  Future<VideoInfo?> compress(String path, void Function(double progress) onProgress);

  /// İlk anlamlı kare (JPEG); alınamazsa null.
  Future<Uint8List?> poster(String path, {int positionMs = 0});

  Future<void> cancel();
}

/// `video_compress` ile Android'de Transcoder (1080p üst sınırlı).
/// Diğer platformlarda sıkıştırma null döner; çağıran özgün dosyayı kullanır.
class PlatformVideoCompressor implements VideoCompressor {
  // video_compress yalniz Android'de derlenir (iOS'ta CocoaPods gerekir, xcross desteklemez).
  bool get _supported => Platform.isAndroid;

  /// iOS: sikistirma/poster yok; sure ve boyut video_player (SwiftPM destekli) ile okunur.
  Future<VideoInfo?> _infoViaPlayer(String path) async {
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.file(File(path));
      await c.initialize();
      final size = c.value.size;
      return VideoInfo(
        path: path,
        sizeBytes: await File(path).length(),
        durationMs: c.value.duration.inMilliseconds,
        width: size.width > 0 ? size.width.round() : null,
        height: size.height > 0 ? size.height.round() : null,
      );
    } catch (_) {
      return null;
    } finally {
      try {
        await c?.dispose();
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
    }
  }

  VideoInfo? _fromMedia(vc.MediaInfo i, String fallbackPath) {
    final p = i.path ?? fallbackPath;
    var w = i.width;
    var h = i.height;
    final o = i.orientation;
    if (w != null && h != null && (o == 90 || o == 270)) {
      final t = w;
      w = h;
      h = t;
    }
    return VideoInfo(
      path: p,
      sizeBytes: i.filesize ?? 0,
      durationMs: (i.duration ?? 0).round(),
      width: w,
      height: h,
    );
  }

  @override
  Future<VideoInfo?> info(String path) async {
    if (Platform.isIOS) return _infoViaPlayer(path);
    if (!_supported) return null;
    try {
      return _fromMedia(await vc.VideoCompress.getMediaInfo(path), path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<VideoInfo?> compress(String path, void Function(double progress) onProgress) async {
    if (!_supported) return null;
    final sub = vc.VideoCompress.compressProgress$.subscribe((p) => onProgress((p / 100).clamp(0.0, 1.0)));
    try {
      final r = await vc.VideoCompress.compressVideo(
        path,
        quality: vc.VideoQuality.Res1920x1080Quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );
      if (r == null || r.isCancel == true) return null;
      return _fromMedia(r, path);
    } catch (_) {
      return null;
    } finally {
      sub.unsubscribe();
    }
  }

  @override
  Future<Uint8List?> poster(String path, {int positionMs = 0}) async {
    // iOS: yerel AVAssetImageGenerator köprüsü (video_compress iOS'ta derlenmez).
    if (Platform.isIOS) return PlatformVideoFrames.instance.frame(path: path, positionMs: positionMs);
    if (!_supported) return null;
    try {
      return await vc.VideoCompress.getByteThumbnail(path, quality: 80, position: positionMs);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await vc.VideoCompress.cancelCompression();
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }
}

/// Video seç + doğrula + sıkıştır + poster al.
///
/// Sınırlar sunucuyla aynıdır: en çok [maxDurationMs] ve [maxBytes]. Küçük/uygun çözünürlüklü videolar
/// yeniden kodlanmaz (gereksiz kalite kaybı olmasın); sıkıştırma başarısız olursa özgün dosya boyutu
/// uygunsa o gönderilir.
class VideoService {
  VideoService({
    ImagePicker? picker,
    VideoCompressor? compressor,
    Future<PickedVideo?> Function(ImageSource source)? pick,
    this.limitBytes = maxBytes,
    this.limitMs = maxDurationMs,
  })  : _picker = picker,
        _compressor = compressor ?? PlatformVideoCompressor(),
        _pick = pick;

  ImagePicker? _picker;
  final VideoCompressor _compressor;
  final Future<PickedVideo?> Function(ImageSource source)? _pick;

  static const maxDurationMs = 60 * 1000;
  static const maxBytes = 40 * 1024 * 1024;

  /// Gönderi videosu üst sınırı (Keşfet): sunucuyla aynı 50 MB. Sohbet [maxBytes] ile kalır.
  static const postMaxBytes = 50 * 1024 * 1024;

  /// Bu örneğin kabul ettiği en büyük dosya boyutu.
  final int limitBytes;

  /// Bu örneğin kabul ettiği en uzun süre (ms). Gönderi videosunda `PostVideoLimits.maxDurationMs`.
  final int limitMs;

  /// Dosyanın süre/boyut/çözünürlük özeti; okunamazsa null (kırpma ekranı süreyi buradan alır).
  Future<VideoInfo?> info(String path) => _compressor.info(path);

  /// Bu boyutun altındaki ve en çok 1280 px'lik videolar olduğu gibi gönderilir.
  static const skipCompressBytes = 6 * 1024 * 1024;

  /// Videonun [positionMs] anındaki kare (JPEG); alınamazsa null (kare çıkarma desteklenmeyen platformda kapak seçimi gösterilmez).
  Future<Uint8List?> frameAt(String path, int positionMs) => _compressor.poster(path, positionMs: positionMs);

  /// Galeriden ya da kameradan seçer (kamera en çok 60 sn kaydeder). İptalde null.
  Future<PickedVideo?> pick(ImageSource source) async {
    final custom = _pick;
    if (custom != null) return custom(source);
    final f = await (_picker ??= ImagePicker()).pickVideo(
      source: source,
      maxDuration: Duration(milliseconds: limitMs),
    );
    return f == null ? null : PickedVideo(f.path);
  }

  /// Doğrular ve sıkıştırır. [VideoException] fırlatır; iptalde `CANCELLED`.
  Future<PreparedVideo> prepare(PickedVideo picked, {void Function(double)? onProgress, VideoCancel? cancel}) async {
    cancel?._onCancel = _compressor.cancel;
    void check() {
      if (cancel?.cancelled == true) throw VideoException('CANCELLED');
    }

    check();
    final orig = await _compressor.info(picked.path);
    var origSize = orig?.sizeBytes ?? 0;
    if (origSize <= 0) {
      try {
        origSize = await File(picked.path).length();
      } catch (_) {
        // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
      }
    }
    if (orig != null && orig.durationMs > limitMs + 500) throw VideoException('TOO_LONG');
    check();

    var best = VideoInfo(
      path: picked.path,
      sizeBytes: origSize,
      durationMs: orig?.durationMs ?? 0,
      width: orig?.width,
      height: orig?.height,
    );

    final small = origSize > 0 &&
        origSize <= skipCompressBytes &&
        math.max(orig?.width ?? 0, orig?.height ?? 0) <= 1280 &&
        (orig?.width ?? 0) > 0;
    if (!small) {
      final c = await _compressor.compress(picked.path, (p) => onProgress?.call(p));
      check();
      if (c != null && c.sizeBytes > 0 && (origSize <= 0 || c.sizeBytes < origSize) &&
          (orig == null || orig.durationMs <= 0 || c.durationMs <= 0 || (c.durationMs - orig.durationMs).abs() <= 500)) {
        best = VideoInfo(
          path: c.path,
          sizeBytes: c.sizeBytes,
          durationMs: c.durationMs > 0 ? c.durationMs : best.durationMs,
          width: c.width ?? best.width,
          height: c.height ?? best.height,
          bytes: c.bytes,
        );
      }
    }
    onProgress?.call(1);
    if (best.sizeBytes > limitBytes) throw VideoException('TOO_LARGE');
    if (best.durationMs > limitMs + 500) throw VideoException('TOO_LONG');

    final at = best.durationMs > 1500 ? 500 : 0;
    final poster = await _compressor.poster(best.path, positionMs: at);
    check();
    return PreparedVideo(
      path: best.path,
      bytes: best.bytes,
      sizeBytes: best.sizeBytes,
      durationMs: best.durationMs,
      width: best.width,
      height: best.height,
      poster: poster,
      compression: CompressionStats(originalBytes: origSize, outputBytes: best.sizeBytes,
        originalWidth: orig?.width, originalHeight: orig?.height, width: best.width, height: best.height,
        codec: best.path == picked.path ? 'original' : 'H.264/AAC'),
    );
  }
}

/// Video yüklemesi: `file` (video/mp4) + isteğe bağlı `poster`; gönderilen bayt sayısına göre ilerleme bildirir.
class VideoUploader {
  VideoUploader(this.session, {http.Client? client}) : _http = client ?? http.Client();

  final Session session;
  final http.Client _http;

  static const _timeout = Duration(minutes: 5);

  /// [headers]: ek başlıklar (aktarım kuyruğu `Idempotency-Key` verir: yeniden denemede ikinci ek oluşmaz).
  Future<dynamic> upload(String path, PreparedVideo video,
          {void Function(double progress)? onProgress, Map<String, String>? headers, bool audio = false}) =>
      _send(path, video, onProgress, false, headers, audio);

  Future<http.MultipartRequest> _build(String path, PreparedVideo video, void Function(double)? onProgress,
      Map<String, String>? headers, bool audio) async {
    final api = session.api;
    final req = _ProgressRequest('POST', Uri.parse('$apiBase$path'), (sent, total) {
      if (total > 0) onProgress?.call((sent / total).clamp(0.0, 1.0));
    });
    req.headers['Accept-Language'] = api.lang;
    req.headers['Accept'] = 'application/json';
    final t = api.tokens;
    if (t != null) req.headers['Authorization'] = 'Bearer ${t.access}';
    if (headers != null) req.headers.addAll(headers);
    // Sesli mesaj (m4a/AAC) de MP4 kabıdır: aynı yükleyici, yalnız tür ve dosya adı farklı.
    final ct = MediaType(audio ? 'audio' : 'video', 'mp4');
    final fileName = audio ? 'voice.m4a' : video.fileName;
    final bytes = video.bytes;
    if (bytes != null) {
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName, contentType: ct));
    } else {
      final f = File(video.path!);
      req.files.add(http.MultipartFile('file', http.ByteStream(f.openRead()), await f.length(),
          filename: fileName, contentType: ct));
    }
    final poster = video.poster;
    if (poster != null && poster.isNotEmpty) {
      final ready = await ImageService().prepare(poster);
      req.files.add(http.MultipartFile.fromBytes('poster', ready.bytes,
          filename: 'poster.${ready.fileName.split('.').last}', contentType: MediaType.parse(ready.mime)));
    }
    return req;
  }

  Future<dynamic> _send(String path, PreparedVideo video, void Function(double)? onProgress, bool retried,
      Map<String, String>? headers, bool audio) async {
    final api = session.api;
    final t = api.tokens;
    final req = await _build(path, video, onProgress, headers, audio);
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
      return _send(path, video, onProgress, true, headers, audio);
    }
    // Geçersiz UTF-8 FormatException sızdırmasın (bkz. MultipartUploader).
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

class _ProgressRequest extends http.MultipartRequest {
  _ProgressRequest(super.method, super.url, this.onSent);

  final void Function(int sent, int total) onSent;

  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    final stream = super.finalize().transform<List<int>>(StreamTransformer.fromHandlers(handleData: (chunk, sink) {
      sent += chunk.length;
      onSent(sent, total);
      sink.add(chunk);
    }));
    return http.ByteStream(stream);
  }
}
