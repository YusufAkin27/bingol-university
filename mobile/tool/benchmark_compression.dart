import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/platform/media_compression.dart';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.length != 2)
    throw ArgumentError('input photo PNG, output directory');
  final source = img.decodePng(File(args[0]).readAsBytesSync())!;
  final out = Directory(args[1])..createSync(recursive: true);
  final fixtures = <String, (Uint8List, String)>{
    'photo-png': (img.encodePng(source), 'image/png'),
    'photo-jpeg95': (img.encodeJpg(source, quality: 95), 'image/jpeg'),
    'photo-jpeg70': (img.encodeJpg(source, quality: 70), 'image/jpeg'),
  };
  final results = <Map<String, Object?>>[];
  for (final e in fixtures.entries) {
    final timer = Stopwatch()..start();
    final result =
        PhotoCompression.optimize(e.value.$1, e.value.$2, 4 * 1024 * 1024);
    timer.stop();
    final extension = result.mime == 'image/webp'
        ? 'webp'
        : result.mime == 'image/png'
            ? 'png'
            : 'jpg';
    File('${out.path}/${e.key}.$extension').writeAsBytesSync(result.bytes);
    results.add({
      'fixture': e.key,
      ...result.stats.toJson(),
      'elapsedMs': timer.elapsedMilliseconds
    });
  }
  File('${out.path}/photo-results.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  print(const JsonEncoder.withIndent('  ').convert(results));
}
