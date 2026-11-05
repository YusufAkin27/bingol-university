import '../../core/platform/video_service.dart';

/// Gönderi/Reels videosu sınırları (TEK YER). Sunucunun kesin süre/boyut değeri backend ajanından gelince burası
/// güncellenir; kırpma ekranı, hazırlama (`VideoService`) ve uyarı metinleri buradan okur.
abstract final class PostVideoLimits {
  /// En uzun süre (ms). Daha uzun video paylaşılamaz; kırpma ekranı zorunlu açılır.
  static const maxDurationMs = 60 * 1000;

  /// En büyük dosya boyutu (bayt): sıkıştırma sonrası gönderilen dosya.
  static const maxBytes = VideoService.postMaxBytes;

  /// Kırpılan aralığın en az süresi (ms).
  static const minTrimMs = 1000;

  /// Süre ölçümü toleransı (ms): sınırı bu kadar aşan video hâlâ "sığıyor" sayılır.
  static const toleranceMs = 500;

  /// Videonun kırpılması ZORUNLU mu (sınırdan uzun)?
  static bool needsTrim(int durationMs) => durationMs > maxDurationMs + toleranceMs;
}
