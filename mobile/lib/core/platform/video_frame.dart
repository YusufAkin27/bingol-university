import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_compress/video_compress.dart' as vc;

/// Bir videodan tek kare (JPEG) çıkarır: yerel dosyadan (gönderirken) ya da yetkili ağ adresinden (gösterirken,
/// sunucuda kapak/poster yoksa). Hata sızdırmaz; alınamazsa null.
abstract class VideoFrameSource {
  /// [path] (yerel dosya) ya da [url] (+ [headers]) verilir. [positionMs] istenen an (videodan uzunsa baştan),
  /// [maxEdge] uzun kenar üst sınırı (px).
  Future<Uint8List?> frame({
    String? path,
    String? url,
    Map<String, String>? headers,
    int positionMs = 500,
    int maxEdge = 720,
  });
}

/// Platform uygulaması.
/// - iOS: yerel kanal `bu_kampus/video_frame` (`BuNativeBridge.swift` `BuVideoFrames`, AVAssetImageGenerator).
/// - Android: yerel dosya `video_compress` (getByteThumbnail), ağ adresi `video_compress` kanalındaki
///   `getByteFrameUrl` (MediaMetadataRetriever; `packages/video_compress_android` eki).
/// - Diğer platformlar (masaüstü, test): null.
class PlatformVideoFrames implements VideoFrameSource {
  PlatformVideoFrames({MethodChannel? channel, bool? ios, bool? android})
      : _ch = channel ?? const MethodChannel('bu_kampus/video_frame'),
        _ios = ios ?? (!kIsWeb && Platform.isIOS),
        _android = android ?? (!kIsWeb && Platform.isAndroid);

  /// Uygulama genelinde paylaşılan örnek; testler değiştirir.
  static VideoFrameSource instance = PlatformVideoFrames();

  final MethodChannel _ch;
  final bool _ios;
  final bool _android;

  /// Yerel taraf bu sürede yanıt vermezse vazgeçilir (ağ akışı takılabilir).
  static const timeout = Duration(seconds: 25);

  @override
  Future<Uint8List?> frame({
    String? path,
    String? url,
    Map<String, String>? headers,
    int positionMs = 500,
    int maxEdge = 720,
  }) async {
    if ((path == null || path.isEmpty) && (url == null || url.isEmpty)) return null;
    try {
      if (_ios) {
        final r = await _ch
            .invokeMethod<Object?>('frame', {
              if (path != null && path.isNotEmpty) 'path': path else 'url': url,
              if (path == null || path.isEmpty) 'headers': headers ?? const <String, String>{},
              'positionMs': positionMs,
              'maxEdge': maxEdge,
              'quality': 0.8,
            })
            .timeout(timeout);
        return _bytes(r);
      }
      if (_android) {
        if (path != null && path.isNotEmpty) {
          return _bytes(await vc.VideoCompress.getByteThumbnail(path, quality: 80, position: positionMs).timeout(timeout));
        }
        final r = await const MethodChannel('video_compress').invokeMethod<Object?>('getByteFrameUrl', {
          'url': url,
          'headers': headers ?? const <String, String>{},
          'positionMs': positionMs,
          'maxEdge': maxEdge,
          'quality': 80,
        }).timeout(timeout);
        return _bytes(r);
      }
    } on MissingPluginException {
      // yerel taraf yok
    } on PlatformException {
      // kare alınamadı
    } on TimeoutException {
      // yanıt gelmedi
    } catch (_) {
      // hata asla çağırana sızmaz
    }
    return null;
  }

  static Uint8List? _bytes(Object? r) {
    if (r is Uint8List && r.isNotEmpty) return r;
    if (r is List<int> && r.isNotEmpty) return Uint8List.fromList(r);
    return null;
  }
}
