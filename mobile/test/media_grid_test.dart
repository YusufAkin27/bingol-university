import 'dart:typed_data';

import 'package:bu_kampus/features/chat/chat_media_viewer.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _att(int i, {bool video = false}) => {
      'id': i,
      'url': '/files/m$i.jpg',
      'thumbUrl': '/files/t$i.jpg',
      'width': 800,
      'height': 600,
      if (video) 'kind': 'VIDEO',
      if (video) 'durationMs': 12000,
      if (video) 'mimeType': 'video/mp4',
    };

Widget _bubble(Map<String, dynamic> m, Size size,
    {void Function(List<Map<String, dynamic>>, int)? onGallery}) {
  return buildApp(
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: MessageBubble(
          message: m,
          mine: true,
          senderName: null,
          replyName: null,
          seen: false,
          authHeaders: const {},
          onMenu: () {},
          onRetry: () {},
          onOpenImage: (_) {},
          onOpenGallery: onGallery,
          onReact: (_) {},
        ),
      ),
    ),
    size: size,
  );
}

void main() {
  for (final n in [2, 3, 4, 6, 10]) {
    for (final size in kPhoneSizes) {
      testWidgets('sunucu ızgarası $n öğe ${size.width.toInt()} dp taşma yok', (tester) async {
        useScreen(tester, size);
        final m = {
          'id': 1,
          'senderId': 1,
          'text': '',
          'createdAt': '2026-01-01T10:00:00Z',
          'status': 'SENT',
          'attachments': [for (var i = 0; i < n; i++) _att(i + 1, video: i == 1)],
        };
        await tester.pumpWidget(_bubble(m, size));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final box = tester.getRect(find.byType(MessageBubble));
        expect(box.right, lessThanOrEqualTo(size.width));
      });

      testWidgets('yerel ızgara $n öğe ${size.width.toInt()} dp taşma yok', (tester) async {
        useScreen(tester, size);
        final m = {
          'clientId': 'c',
          'senderId': 1,
          'text': '',
          '_state': 'pending',
          '_localItems': [
            for (var i = 0; i < n; i++)
              {'bytes': Uint8List(0), 'video': i == 1, 'durationMs': 1000}
          ],
        };
        await tester.pumpWidget(_bubble(m, size));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('uploadProgress')), findsOneWidget);
      });
    }
  }

  testWidgets('7+ öğede son hücrede +N; hücre dokunuşu galeriye indeks verir', (tester) async {
    useScreen(tester, kPhoneMedium);
    int? tapped;
    int? total;
    final m = {
      'id': 1,
      'senderId': 1,
      'text': '',
      'createdAt': '2026-01-01T10:00:00Z',
      'status': 'SENT',
      'attachments': [for (var i = 0; i < 10; i++) _att(i + 1)],
    };
    await tester.pumpWidget(_bubble(m, kPhoneMedium, onGallery: (a, i) {
      tapped = i;
      total = a.length;
    }));
    await tester.pump();
    expect(find.text('+5'), findsOneWidget);
    await tester.tap(find.text('+5'));
    expect(tapped, 5);
    expect(total, 10);
  });

  testWidgets('ChatMediaViewer verilen başlangıç indeksinden açılır', (tester) async {
    useScreen(tester, kPhoneMedium);
    final items = [
      for (var i = 0; i < 5; i++) ChatMediaItem(url: '/files/m$i.jpg', thumbUrl: '/files/t$i.jpg')
    ];
    await tester.pumpWidget(buildApp(
        ChatMediaViewer(items: items, headers: const {}, initialIndex: 3),
        size: kPhoneMedium));
    await tester.pump();
    expect(find.textContaining('4 / 5'), findsOneWidget);
  });
}
