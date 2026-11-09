import 'dart:math';
import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/platform/media_compression.dart';
import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class _Video implements VideoCompressor {
  _Video(this.output);
  final VideoInfo output;
  @override
  Future<VideoInfo?> info(String path) async => const VideoInfo(
      path: '/original.mp4',
      sizeBytes: 20 * 1024 * 1024,
      durationMs: 10000,
      width: 1920,
      height: 1080);
  @override
  Future<VideoInfo?> compress(
          String path, void Function(double) onProgress) async =>
      output;
  @override
  Future<Uint8List?> poster(String path, {int positionMs = 0}) async => null;
  @override
  Future<void> cancel() async {}
}

void main() {
  test('savings describe byte reduction, not a guessed quality loss percentage',
      () {
    const stats = CompressionStats(
        originalBytes: 4000000, outputBytes: 1000000, codec: 'H.264');
    expect(stats.ratio, 4);
    expect(stats.savedPercent, 75);
    expect(stats.targetReached, isTrue);
    expect(stats.ssim, isNull);
  });

  test('SSIM detects color changes and reports identical RGB pixels as 1', () {
    final a = img.Image(width: 16, height: 16)
      ..clear(img.ColorRgb8(200, 20, 10));
    final b = img.Image(width: 16, height: 16)
      ..clear(img.ColorRgb8(10, 20, 200));
    expect(PhotoCompression.similarity(a, a.clone()), closeTo(1, 1e-10));
    expect(PhotoCompression.similarity(a, b), lessThan(.5));
  });

  test('small images and already compressed WebP are passed through', () async {
    final bytes = img.encodePng(img.Image(width: 32, height: 32));
    final result = await ImageService().prepare(bytes);
    expect(result.bytes, bytes);
    expect(result.compression!.ratio, 1);
    final encoded = img.encodeWebP(img.Image(width: 32, height: 32));
    expect(PhotoCompression.optimize(encoded, 'image/webp', 3000000).bytes,
        same(encoded));
  });

  test('transparent PNG keeps its alpha exactly when optimized', () {
    final source = img.Image(width: 640, height: 480, numChannels: 4);
    final random = Random(27);
    for (final p in source) {
      p.setRgba((p.x / 3).round(), (p.y / 2).round(), 120, random.nextInt(256));
    }
    final bytes = img.encodePng(source);
    expect(bytes.length, greaterThan(PhotoCompression.minBytes));
    final result = PhotoCompression.optimize(bytes, 'image/png', 3000000);
    final decoded = img.decodeImage(result.bytes)!;
    expect(decoded.width, source.width);
    expect(decoded.height, source.height);
    for (var y = 0; y < source.height; y += 17) {
      for (var x = 0; x < source.width; x += 17) {
        expect(decoded.getPixel(x, y).a, source.getPixel(x, y).a);
      }
    }
    expect(result.bytes.length, lessThanOrEqualTo(bytes.length));
    expect(result.stats.ssim, greaterThanOrEqualTo(PhotoCompression.minSsim));
  });

  test('16 bit PNG is not silently reduced to an 8 bit WebP', () {
    final source = img.Image(
        width: 256, height: 256, numChannels: 4, format: img.Format.uint16);
    final random = Random(91);
    for (final p in source) {
      p.setRgba(random.nextInt(65536), random.nextInt(65536),
          random.nextInt(65536), random.nextInt(65536));
    }
    final bytes = img.encodePng(source);
    expect(bytes.length, greaterThan(PhotoCompression.minBytes));
    expect(PhotoCompression.optimize(bytes, 'image/png', 3000000).bytes,
        same(bytes));
  });

  test('larger or truncated video output is never selected', () async {
    for (final output in [
      const VideoInfo(
          path: '/larger.mp4', sizeBytes: 25 * 1024 * 1024, durationMs: 10000),
      const VideoInfo(
          path: '/truncated.mp4', sizeBytes: 5 * 1024 * 1024, durationMs: 7000),
    ]) {
      final result = await VideoService(compressor: _Video(output))
          .prepare(const PickedVideo('/original.mp4'));
      expect(result.path, '/original.mp4');
      expect(result.compression!.ratio, 1);
      expect(result.compression!.ssim, isNull);
    }
  });

  test('video savings survive changing its poster', () async {
    final result = await VideoService(
            compressor: _Video(const VideoInfo(
                path: '/small.mp4',
                sizeBytes: 5 * 1024 * 1024,
                durationMs: 10000,
                width: 1920,
                height: 1080)))
        .prepare(const PickedVideo('/original.mp4'));
    expect(result.compression!.ratio, 4);
    expect(result.withPoster(Uint8List(0)).compression!.savedPercent, 75);
  });
}
