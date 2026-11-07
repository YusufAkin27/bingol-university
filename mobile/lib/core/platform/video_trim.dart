import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'video_service.dart' show VideoException;

/// Videodan bir zaman aralığını yeni bir dosyaya keser (yeniden kodlamadan).
///
/// Üretimde [PlatformVideoTrimService] (yerel kanal `bu_kampus/video_trim`); testlerde sahtesi verilir
/// (`VideoTrimService.instance`). Hata [VideoException] olarak fırlar: `UNSUPPORTED` (platform desteklemiyor),
/// `FAILED` (kesme başarısız).
abstract class VideoTrimService {
  /// Uygulama genelinde paylaşılan örnek; testler değiştirir.
  static VideoTrimService instance = PlatformVideoTrimService();

  /// Bu cihazda yerel kesme var mı (Android/iOS).
  bool get supported;

  /// [path] videosundan `[startMs, endMs]` aralığını keser ve yeni dosyanın yolunu döndürür. Kesim en yakın anahtar kareye
  /// oturur, bu yüzden süre birkaç yüz ms oynayabilir; [maxMs] > 0 ise çıktı bu süreyi aşmaz.
  Future<String> trim({required String path, required int startMs, required int endMs, int maxMs = 0});

  /// Kesimle üretilmiş geçici dosyayı siler (sessiz).
  Future<void> discard(String path);
}

class PlatformVideoTrimService implements VideoTrimService {
  PlatformVideoTrimService({MethodChannel? channel, bool? supported})
      : _ch = channel ?? const MethodChannel('bu_kampus/video_trim'),
        _supported = supported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  final MethodChannel _ch;
  final bool _supported;

  /// Kesme bu sürede bitmezse vazgeçilir (anahtar kareye kopyalama saniyeler sürer).
  static const timeout = Duration(minutes: 2);

  @override
  bool get supported => _supported;

  @override
  Future<String> trim({required String path, required int startMs, required int endMs, int maxMs = 0}) async {
    if (!_supported) throw VideoException('UNSUPPORTED');
    if (path.isEmpty || startMs < 0 || endMs <= startMs) throw VideoException('FAILED');
    try {
      final r = await _ch
          .invokeMethod<String>('trim', {'path': path, 'startMs': startMs, 'endMs': endMs, 'maxMs': maxMs})
          .timeout(timeout);
      if (r == null || r.isEmpty) throw VideoException('FAILED');
      return r;
    } on VideoException {
      rethrow;
    } on MissingPluginException {
      throw VideoException('UNSUPPORTED');
    } on PlatformException {
      throw VideoException('FAILED');
    } on TimeoutException {
      throw VideoException('FAILED');
    }
  }

  @override
  Future<void> discard(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Bilerek yutulur: en iyi çaba, akışı ve kullanıcı verisini etkilemez.
    }
  }
}
