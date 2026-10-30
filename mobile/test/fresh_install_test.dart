import 'dart:io';

import 'package:bu_kampus/core/platform/fresh_install.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bu_fresh_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('iOS ilk acilis: oturum anahtarlari silinir, device_id korunur; ikinci acilista dokunmaz', () async {
    final deleted = <String>[];
    final first = await FreshInstallGuard.run(isIOS: true, supportDir: () async => tmp, deleteKey: (k) async => deleted.add(k));
    expect(first, isTrue);
    expect(deleted, ['access', 'refresh']);
    expect(deleted.contains('device_id'), isFalse);

    deleted.clear();
    final second = await FreshInstallGuard.run(isIOS: true, supportDir: () async => tmp, deleteKey: (k) async => deleted.add(k));
    expect(second, isFalse);
    expect(deleted, isEmpty);
  });

  test('Android/diger platformda hicbir sey yapmaz', () async {
    final deleted = <String>[];
    final r = await FreshInstallGuard.run(isIOS: false, supportDir: () async => tmp, deleteKey: (k) async => deleted.add(k));
    expect(r, isFalse);
    expect(deleted, isEmpty);
    expect(await tmp.list().isEmpty, isTrue);
  });

  test('isaret yazilamazsa silmez ve hata sizdirmaz', () async {
    final deleted = <String>[];
    final blocked = File('${tmp.path}${Platform.pathSeparator}notadir')..writeAsStringSync('x');
    final r = await FreshInstallGuard.run(
      isIOS: true,
      supportDir: () async => Directory(blocked.path), // dosya, dizin degil -> olusturma/yazma hata verir
      deleteKey: (k) async => deleted.add(k),
    );
    expect(r, isFalse);
    expect(deleted, isEmpty);
  });

  test('tek anahtar silinemese de digeri denenir', () async {
    final deleted = <String>[];
    final r = await FreshInstallGuard.run(
      isIOS: true,
      supportDir: () async => tmp,
      deleteKey: (k) async {
        if (k == 'access') throw StateError('x');
        deleted.add(k);
      },
    );
    expect(r, isTrue);
    expect(deleted, ['refresh']);
  });
}
