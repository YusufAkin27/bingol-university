import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Görsel disk önbelleği tutarlılığı: avatarlar ve normal sohbet görselleri diske yazan sağlayıcıyı kullanır;
/// tek gösterimlik / kaldırılmış ekler asla; yetkili başlıklar korunur.
void main() {
  setUpAll(loadTestFonts);

  /// Ağaçtaki tüm `Image` widget'larının en içteki (ResizeImage soyulmuş) sağlayıcıları.
  List<ImageProvider> providers(WidgetTester tester) => [
        for (final img in tester.widgetList<Image>(find.byType(Image)))
          if (img.image is ResizeImage) (img.image as ResizeImage).imageProvider else img.image
      ];

  group('persistentNetworkImage', () {
    test('persist true: DiskNetworkImage, başlıklar ve çözümleme genişliği korunur', () {
      final p = persistentNetworkImage('https://x/a.jpg', headers: const {'Authorization': 'Bearer t'}, cacheWidth: 200);
      expect(p, isA<ResizeImage>());
      final inner = (p as ResizeImage).imageProvider;
      expect(inner, isA<DiskNetworkImage>());
      expect((inner as DiskNetworkImage).headers, {'Authorization': 'Bearer t'});
      expect(p.width, 200);
    });

    test('persist false: diske dokunmayan NetworkImage (başlıklar korunur)', () {
      final p = persistentNetworkImage('https://x/a.jpg', headers: const {'Authorization': 'Bearer t'}, cacheWidth: 200, persist: false);
      final inner = (p as ResizeImage).imageProvider;
      expect(inner, isA<NetworkImage>());
      expect(inner, isNot(isA<DiskNetworkImage>()));
      expect((inner as NetworkImage).headers, {'Authorization': 'Bearer t'});
    });

    test('cacheWidth yoksa sarmalanmaz', () {
      expect(persistentNetworkImage('https://x/a.jpg'), isA<DiskNetworkImage>());
    });
  });

  group('Avatarlar', () {
    testWidgets('BuAvatar: fotoğraf URL ise DiskNetworkImage', (tester) async {
      await tester.pumpWidget(buildApp(const Scaffold(body: BuAvatar(name: 'Ayşe', url: '/files/avatars/a.jpg')), size: kPhoneMedium));
      await tester.pump();
      expect(providers(tester).whereType<DiskNetworkImage>().length, 1);
      await unmount(tester);
    });

    testWidgets('BuAvatar: URL yoksa ağ görseli yok (varsayılan avatar)', (tester) async {
      await tester.pumpWidget(buildApp(const Scaffold(body: BuAvatar(name: 'Ayşe')), size: kPhoneMedium));
      await tester.pump();
      expect(providers(tester).whereType<DiskNetworkImage>(), isEmpty);
      await unmount(tester);
    });

    testWidgets('ChatlistAvatar: yetkili /api adresinde başlık DiskNetworkImage ile korunur', (tester) async {
      ChatlistAvatar.authProvider = () => {'Authorization': 'Bearer abc'};
      addTearDown(() => ChatlistAvatar.authProvider = null);
      await tester.pumpWidget(buildApp(const Scaffold(body: ChatlistAvatar(name: 'Kulüp', url: '/api/communities/3/avatar', group: true)), size: kPhoneMedium));
      await tester.pump();
      final disk = providers(tester).whereType<DiskNetworkImage>().toList();
      expect(disk.length, 1);
      expect(disk.single.headers, {'Authorization': 'Bearer abc'});
      await unmount(tester);
    });
  });

  group('Sohbet görsel balonu', () {
    Widget bubble(Map<String, dynamic> m) => buildApp(
          Scaffold(
            body: MessageBubble(
              message: m,
              mine: true,
              senderName: null,
              replyName: null,
              seen: false,
              authHeaders: const {'Authorization': 'Bearer abc'},
              onMenu: () {},
              onRetry: () {},
              onOpenImage: (_) {},
              onReact: (_) {},
            ),
          ),
          size: kPhoneMedium,
        );

    Map<String, dynamic> msg(List<Map<String, dynamic>> atts) =>
        {'id': 1, 'senderId': 1, 'text': '', 'createdAt': '2026-01-01T10:00:00Z', 'status': 'SENT', 'attachments': atts};

    testWidgets('normal ek: DiskNetworkImage, yetkili başlık korunur', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(bubble(msg([
        {'id': 7, 'url': '/api/conversations/1/media/7', 'thumbUrl': '/api/conversations/1/media/7/thumb', 'width': 800, 'height': 600},
      ])));
      await tester.pump();
      final disk = providers(tester).whereType<DiskNetworkImage>().toList();
      expect(disk.length, 1);
      expect(disk.single.url, endsWith('/api/conversations/1/media/7/thumb'));
      expect(disk.single.headers, {'Authorization': 'Bearer abc'});
      await unmount(tester);
    });

    testWidgets('tek gösterimlik ek: hiçbir görsel sağlayıcı kurulmaz, diske yazılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(bubble(msg([
        {'id': 8, 'kind': 'IMAGE', 'viewOnce': true, 'viewed': false, 'url': '/api/conversations/1/media/8', 'thumbUrl': '/api/conversations/1/media/8/thumb'},
      ])));
      await tester.pump();
      expect(providers(tester).whereType<DiskNetworkImage>(), isEmpty);
      expect(find.byType(Image), findsNothing);
      await unmount(tester);
    });

    testWidgets('kaldırılmış ek: görsel çizilmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(bubble(msg([
        {'id': 9, 'removed': true, 'url': '/api/conversations/1/media/9', 'thumbUrl': '/api/conversations/1/media/9/thumb'},
      ])));
      await tester.pump();
      expect(providers(tester).whereType<DiskNetworkImage>(), isEmpty);
      await unmount(tester);
    });
  });
}
