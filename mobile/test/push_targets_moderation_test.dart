import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moderasyon ANNOUNCEMENT (kulüp duyurusu kimliği) haber detayına gitmez', () {
    final t = resolvePushTarget({'targetType': 'ANNOUNCEMENT', 'targetId': '7', 'moderation': '1'});
    expect(t.dest, PushDest.notifications);
  });

  test('moderasyon dışı ANNOUNCEMENT ve haber kimliği eskisi gibi çözülür', () {
    expect(resolvePushTarget({'targetType': 'ANNOUNCEMENT', 'targetId': '7'}).dest, PushDest.news);
    expect(resolvePushTarget({'newsId': '9', 'moderation': '1'}).dest, PushDest.news);
  });

  test('moderasyon POST hedefi gönderiyi açar', () {
    final t = resolvePushTarget({'targetType': 'POST', 'targetId': '5', 'moderation': '1'});
    expect(t, const PushTarget(PushDest.post, id: 5));
  });
}
