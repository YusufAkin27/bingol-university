import 'dart:io';

import 'package:bu_kampus/core/error_log.dart';
import 'package:bu_kampus/core/swallow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('swallow hata turunu gunluge yazar, fırlatmaz, mesaj tutmaz', () {
    final log = ErrorLog(quiet: true);
    swallow('widget.put', StateError('gizli@mail.com jeton'), log: log);
    expect(log.entries, hasLength(1));
    expect(log.entries.single.source, 'swallow:widget.put');
    expect(log.entries.single.type, 'StateError');
    expect(log.entries.single.toJson().toString().contains('gizli'), isFalse);
  });

  test('swallow etiketi guvenli karakterlere indirilir', () {
    final log = ErrorLog(quiet: true);
    swallow('a b/ç', Exception('x'), log: log);
    expect(log.entries.single.source, 'swallow:ab');
  });

  test('sohbet gorselleri persistentNetworkImage kullanir', () {
    for (final f in ['lib/features/chat/chat_info_media.dart', 'lib/features/chat/chat_media_parts.dart']) {
      final s = File(f).readAsStringSync();
      expect(s.contains('Image.network('), isFalse, reason: f);
      expect(s.contains('persistentNetworkImage('), isTrue, reason: f);
    }
  });

  test('bildirim listesi tembel (ListView.builder)', () {
    final s = File('lib/features/notifications/notifications_page.dart').readAsStringSync();
    expect(s.contains('ListView.builder('), isTrue);
    expect(s.contains('children: children,'), isFalse);
  });
}
