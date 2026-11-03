import 'package:bu_kampus/core/push/push_banner.dart';
import 'package:bu_kampus/core/push/notification_push_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_app.dart';

void main() {
  testWidgets('three in-app strips coexist, merge by conversation and close independently', (tester) async {
    useScreen(tester, kPhoneMedium);
    final center = PushBannerCenter(duration: const Duration(minutes: 1));
    await tester.pumpWidget(buildApp(const Scaffold(body: Text('Campus'))));
    await settle(tester);
    final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
    void show(String key, String title, Map<String, dynamic> data) => center.show(
      BannerItem(key: key, title: title, body: 'Bildirim önizlemesi', data: data), onTap: (_) {}, overlay: overlay);
    show('chat', 'Ayşe Yılmaz', {'type':'MESSAGE','conversationId':'1'});
    show('event', 'Yapay Zekâ Atölyesi', {'type':'EVENT','eventId':'1'});
    show('news', 'Akademik takvim güncellendi', {'type':'ANNOUNCEMENT','newsId':'1'});
    await settle(tester);
    expect(find.byType(NotificationPushCard), findsNWidgets(3));
    show('chat', 'Ayşe Yılmaz', {'type':'MESSAGE','conversationId':'1'});
    await settle(tester);
    expect(center.items.value.length, 3);
    expect(center.current.value?.count, 2);
    center.dismiss('news'); await settle(tester);
    expect(find.text('Akademik takvim güncellendi'), findsNothing);
    expect(find.byType(NotificationPushCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    center.hide(); await unmount(tester);
  });
}
