import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Byte savings are exact. SSIM is a sampled RGB similarity score, not a percentage of visual loss.
class CompressionStats {
  const CompressionStats(
      {required this.originalBytes,
      required this.outputBytes,
      this.originalWidth,
      this.originalHeight,
      this.width,
      this.height,
      this.ssim,
      this.quality,
      required this.codec});
  final int originalBytes, outputBytes;
  final int? originalWidth, originalHeight, width, height, quality;
  final double? ssim;
  final String codec;
  double get ratio => outputBytes > 0 ? originalBytes / outputBytes : 1;
  double get savedPercent =>
      originalBytes > 0 ? 100 * (1 - outputBytes / originalBytes) : 0;
  bool get targetReached => ratio >= 3;
  Map<String, Object?> toJson() => {
        'originalBytes': originalBytes,
        'outputBytes': outputBytes,
        'ratio': ratio,
        'savedPercent': savedPercent,
        'originalWidth': originalWidth,
        'originalHeight': originalHeight,
        'width': width,
        'height': height,
        'sampledRgbSsim': ssim,
        'encoderQuality': quality,
        'codec': codec,
      };
}

class CompressedPhoto {
  const CompressedPhoto(this.bytes, this.mime, this.stats);
  final Uint8List bytes;
  final String mime;
  final CompressionStats stats;
}

/// Uses the existing MIT-licensed `image` package. Never lowers quality merely to claim a 4x saving.
abstract final class PhotoCompression {
  static const minSsim = .98;
  static const minBytes = 128 * 1024;
  static const maxPixels = 5 * 1024 * 1024;

  static CompressedPhoto optimize(Uint8List bytes, String mime, int limit) {
    CompressedPhoto original() => CompressedPhoto(
        bytes,
        mime,
        CompressionStats(
            originalBytes: bytes.length,
            outputBytes: bytes.length,
            codec: 'original',
            ssim: 1));
    if (bytes.length < minBytes || mime == 'image/webp') return original();
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null ||
        info.width * info.height > maxPixels ||
        info.numFrames > 1) {
      return original();
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) return original();
    final source = img.bakeOrientation(decoded);
    // Do not silently discard a wide-gamut ICC profile without a color-space conversion.
    if (source.iccProfile != null || source.bitsPerChannel != 8) {
      return original();
    }
    // EXIF orientation has been baked into pixels; no GPS/EXIF/XMP is copied to the output.
    source.exif = img.ExifData();
    source.iccProfile = null;
    final alpha =
        source.hasAlpha && source.any((p) => p.a != p.maxChannelValue);
    final reference = _sample(source);
    Uint8List best = bytes;
    double bestSsim = 1;
    int? quality;
    for (final q in alpha ? [100] : [88, 84, 80]) {
      final candidate =
          img.encodeWebP(source, lossless: alpha, quality: q, method: 4);
      if (candidate.length >= best.length || candidate.length > limit) continue;
      if (bytes.length <= limit && candidate.length > bytes.length * .85) {
        continue;
      }
      final reconstructed = img.decodeWebP(candidate);
      if (reconstructed == null) continue;
      final score = similarity(reference, _sample(reconstructed));
      if (score < minSsim) continue;
      best = candidate;
      bestSsim = score;
      quality = q;
      if (bytes.length / best.length >= 4) break;
    }
    final changed = !identical(best, bytes);
    return CompressedPhoto(
        best,
        changed ? 'image/webp' : mime,
        CompressionStats(
            originalBytes: bytes.length,
            outputBytes: best.length,
            originalWidth: source.width,
            originalHeight: source.height,
            width: source.width,
            height: source.height,
            ssim: bestSsim,
            quality: quality,
            codec: changed
                ? alpha
                    ? 'WebP lossless'
                    : 'WebP'
                : 'original'));
  }

  static img.Image _sample(img.Image source) {
    if (math.max(source.width, source.height) <= 512) return source;
    return source.width >= source.height
        ? img.copyResize(source,
            width: 512, interpolation: img.Interpolation.average)
        : img.copyResize(source,
            height: 512, interpolation: img.Interpolation.average);
  }

  /// Mean 8x8-window SSIM over RGB channels at matching dimensions. Alpha is preserved losslessly.
  static double similarity(img.Image a, img.Image b) {
    if (a.width != b.width || a.height != b.height) return 0;
    const c1 = 6.5025, c2 = 58.5225;
    double total = 0;
    int windows = 0;
    for (var y = 0; y < a.height; y += 8) {
      for (var x = 0; x < a.width; x += 8) {
        for (var channel = 0; channel < 3; channel++) {
          double sa = 0, sb = 0, saa = 0, sbb = 0, sab = 0;
          int n = 0;
          for (var yy = y; yy < math.min(y + 8, a.height); yy++) {
            for (var xx = x; xx < math.min(x + 8, a.width); xx++) {
              final pa = a.getPixel(xx, yy), pb = b.getPixel(xx, yy);
              final va =
                  pa.getChannelNormalized(img.Channel.values[channel]) * 255;
              final vb =
                  pb.getChannelNormalized(img.Channel.values[channel]) * 255;
              sa += va;
              sb += vb;
              saa += va * va;
              sbb += vb * vb;
              sab += va * vb;
              n++;
            }
          }
          final ma = sa / n, mb = sb / n;
          final va = math.max(0, saa / n - ma * ma),
              vb = math.max(0, sbb / n - mb * mb);
          final covariance = sab / n - ma * mb;
          total += ((2 * ma * mb + c1) * (2 * covariance + c2)) /
              ((ma * ma + mb * mb + c1) * (va + vb + c2));
          windows++;
        }
      }
    }
    return windows == 0 ? 1 : (total / windows).clamp(0.0, 1.0);
  }
}
