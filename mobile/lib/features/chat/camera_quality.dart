import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';

/// Sohbet kamerasının kalite kararları tek yerde (saf, test edilebilir).
///
/// Kök neden (2026-11-05, "kamerayı sanki kullanmıyor"): denetleyici `ResolutionPreset.high` (~720p, Android'de
/// 1280x720) ile kuruluyordu; önizleme de çekilen fotoğraf da bu çözünürlükteydi. Ayrıca kamera seçimi "ilk arka
/// kamera" idi ve çevirme düğmesi tüm kameraları (geniş açı/telefoto dahil) dolaşıyordu.
class CameraQuality {
  const CameraQuality._();

  /// Fotoğraf için cihazın desteklediği en yüksek çözünürlük (CameraX: en yüksek kullanılabilir, iOS: en yüksek biçim).
  static const photoPreset = ResolutionPreset.max;

  /// Video: kare hızı ve bit hızı sabitlenir; `max` ile 4K+ çözünürlük seçilse bile dosya boyutu sınırlı kalır
  /// (sonra istemcide 720p'ye sıkıştırılır, sunucu sınırı 40 MB/60 sn).
  static const videoFps = 30;
  static const videoBitrate = 8000000;
  static const audioBitrate = 128000;

  /// Sohbet kamerası denetleyicisi: fotoğraf için en yüksek çözünürlük, video için bit hızı sınırı.
  static CameraController controllerFor(CameraDescription d, {required bool audio}) => CameraController(
        d,
        photoPreset,
        enableAudio: audio,
        fps: videoFps,
        videoBitrate: videoBitrate,
        audioBitrate: audioBitrate,
      );

  /// Açılışta kullanılacak arka kamera: ana (geniş) kamera. `lensType` bilinen platformlarda (iOS) `wide` seçilir,
  /// geniş açı (ultraWide) ve telefoto elenir; Android'de tür bilinmez (`unknown`): Camera2 kimliği en küçük olan
  /// (`0` = ana kamera geleneği), eşitlikte listedeki ilk. Arka kamera yoksa 0.
  static int mainBackIndex(List<CameraDescription> cams) {
    final backs = [for (var i = 0; i < cams.length; i++) if (cams[i].lensDirection == CameraLensDirection.back) i];
    if (backs.isEmpty) return 0;
    final wide = [for (final i in backs) if (cams[i].lensType == CameraLensType.wide) i];
    if (wide.isNotEmpty) return wide.first;
    // Ana olmayanlar elenir; hepsi elenirse (yalnız ultraWide/telefoto) yine ilki.
    final plain = [
      for (final i in backs)
        if (cams[i].lensType != CameraLensType.ultraWide && cams[i].lensType != CameraLensType.telephoto) i,
    ];
    final pool = plain.isEmpty ? backs : plain;
    return pool.reduce((a, b) => _idOf(cams[b]) < _idOf(cams[a]) ? b : a);
  }

  /// Çevirme: ön kamera <-> ana arka kamera. Ön kamera yoksa ya da arka yoksa mevcut dizin değişmez.
  static int flipTarget(List<CameraDescription> cams, int current) {
    if (cams.length < 2 || current < 0 || current >= cams.length) return current;
    if (cams[current].lensDirection == CameraLensDirection.front) {
      final back = mainBackIndex(cams);
      return cams[back].lensDirection == CameraLensDirection.back ? back : current;
    }
    final front = cams.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (front >= 0) return front;
    // Ön kamera yok (yalnız arka/harici): sıradaki kameraya geç.
    return (current + 1) % cams.length;
  }

  static int _idOf(CameraDescription c) => int.tryParse(c.name) ?? 1 << 30;

  /// Önizleme kutusu: çekilen fotoğrafın aynısını gösterir (kırpma/yakınlaştırma yok). Dikey ekranda önizleme oranı
  /// `1 / aspectRatio` (genişlik/yükseklik) olur; ekrana sığacak en büyük kutu bulunur, dar kalan yer sahne rengidir.
  static Size previewBox(Size screen, double sensorAspectRatio) {
    if (screen.isEmpty || sensorAspectRatio <= 0 || !sensorAspectRatio.isFinite) return screen;
    final pa = 1 / sensorAspectRatio; // genişlik / yükseklik (dikey)
    final w = math.min(screen.width, screen.height * pa);
    return Size(w, w / pa);
  }

  /// İki parmak yakınlaştırma: taban + ölçek, cihaz sınırlarına kırpılır.
  static double zoomFor(double base, double scale, double min, double max) =>
      (base * scale).clamp(min, math.max(min, max)).toDouble();
}
