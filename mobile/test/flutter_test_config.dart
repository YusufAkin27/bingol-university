import 'dart:async';

import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// Her test dosyasından önce çalışır: yerel önbellekler her testte TEMİZ ve yalnız bellek/pasif olur
/// (diske/eklentiye dokunmaz, testler arasında mesaj kaydı sızmaz). Diskli davranış kendi testlerinde
/// geçici dizinle ayrıca sınanır (m1_message_cache_test.dart).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    MessageCache.instance = MessageCache.memoryOnly();
    ImageDiskCache.instance = ImageDiskCache.disabled();
  });
  await testMain();
}
