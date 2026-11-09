import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/platform/media_compression.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'support/fake_app.dart';

class _Images extends ImageService {
  final limits = <int?>[];
  @override
  Future<PreparedImage> prepare(Uint8List bytes,
      {bool avatar = false, int? limit}) async {
    limits.add(limit);
    final output = img.encodeWebP(img.Image(width: 16, height: 16));
    return PreparedImage(output, 'image/webp',
        compression: CompressionStats(
            originalBytes: bytes.length,
            outputBytes: output.length,
            codec: 'WebP'));
  }
}

void main() {
  test(
      'all image upload routes apply the shared policy and send the actual output MIME',
      () async {
    final routes = {
      '/users/me/avatar': ImageService.avatarLimit,
      '/conversations/7/avatar': ImageService.avatarLimit,
      '/conversations/7/media': ImageService.chatLimit,
      '/communities/9/logo': ImageService.avatarLimit,
      '/communities/9/cover': ImageService.defaultLimit,
      '/events/4/cover': ImageService.defaultLimit,
      '/posts/media': ImageService.defaultLimit,
      '/forum/media': 8 * 1024 * 1024,
    };
    final images = _Images();
    final bodies = <String>[];
    final uploader = MultipartUploader(makeSession(FakeBackend()),
        image: images, client: MockClient((r) async {
      bodies.add(String.fromCharCodes(r.bodyBytes));
      return http.Response('{"id":1}', 200);
    }));
    final raw = PreparedImage(Uint8List.fromList(kFakePng), 'image/png');
    for (final route in routes.keys) {
      await uploader.upload(route, raw,
          method: route.endsWith('/cover') ? 'PUT' : 'POST');
    }
    expect(images.limits, routes.values.toList());
    expect(bodies, hasLength(routes.length));
    for (final body in bodies) {
      expect(body, contains('filename="upload.webp"'));
      expect(body, contains('image/webp'));
    }
  });

  test(
      'already prepared images are not re-encoded at upload or retry boundaries',
      () async {
    final images = _Images();
    final ready = await images.prepare(Uint8List.fromList(kFakePng));
    final result = await images.prepareForUpload('/events/4/cover', ready);
    expect(result, same(ready));
    expect(images.limits, hasLength(1));
  });
}
