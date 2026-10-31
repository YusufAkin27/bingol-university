import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Sohbet detay yeni görünümü (P4 / P4d): balonlar, ızgara, video, tek gösterimlik durumları.

Map<String, dynamic> _msg(int id, int sender, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': DateTime.now().subtract(Duration(minutes: 600 - id)).toUtc().toIso8601String(),
      ...?extra,
    };

Map<String, dynamic> _img(int id) =>
    {'id': id, 'kind': 'IMAGE', 'url': '/a$id', 'thumbUrl': '/a$id', 'width': 800, 'height': 600};

Map<String, dynamic> _video(int id) => {
      'id': id,
      'kind': 'VIDEO',
      'url': '/api/conversations/1/media/$id',
      'thumbUrl': '/api/conversations/1/media/$id/poster',
      'durationMs': 24000,
      'width': 1280,
      'height': 720,
    };

FakeBackend _backend() => FakeBackend()
  ..on('/conversations/1/messages?size=30', {
    'items': [
      _msg(12, 1, '', extra: {'status': 'SENT', 'attachments': [_video(90)]}),
      _msg(11, 11, '', extra: {'attachments': [_img(1), _img(2), _img(3), _img(4), _img(5), _img(6), _img(7)]}),
      _msg(10, 11, '', extra: {'attachments': [_img(8), _img(9), _img(10), _img(11)]}),
      _msg(9, 1, 'Kafede çalışıyorum', extra: {'status': 'READ', 'attachments': [_img(20)]}),
      _msg(8, 11, '', extra: {'attachments': [_video(91)]}),
      _msg(7, 1, '', extra: {
        'status': 'SENT',
        'attachments': [
          {'id': 80, 'viewOnce': true, 'viewed': false, 'url': null}
        ]
      }),
      _msg(6, 11, '', extra: {
        'attachments': [
          {'id': 81, 'viewOnce': true, 'viewed': true, 'url': null}
        ]
      }),
      _msg(5, 11, '', extra: {
        'attachments': [
          {'id': 82, 'viewOnce': true, 'viewed': false, 'url': '/api/conversations/1/media/82'}
        ]
      }),
      _msg(4, 11, 'Merhaba, nasılsın?'),
      _msg(3, 1, 'İyiyim, sen?', extra: {'status': 'DELIVERED'}),
    ],
    'nextCursor': null,
  })
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Mehmet Kaya'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': ['👍']});

Future<void> _pump(WidgetTester tester, Size size, Brightness b, {bool rtl = false}) async {
  // Uzun ekran: liste tembel kurulduğundan tüm mesajlar görünür olsun.
  size = Size(size.width, 3200);
  useScreen(tester, size);
  final page = ChatDetailPage(
    session: makeSession(_backend()),
    connectRealtime: false,
    conversation: const {
      'id': 1,
      'type': 'DIRECT',
      'title': 'Mehmet Kaya',
      'peer': {'id': 11, 'displayName': 'Mehmet Kaya'},
    },
  );
  await tester.pumpWidget(buildApp(
      rtl ? Directionality(textDirection: TextDirection.rtl, child: page) : page,
      brightness: b,
      size: size));
  await settle(tester, const Duration(milliseconds: 600));
}

void main() {
  setUpAll(loadTestFonts);

  for (final size in [kPhoneSmall, kPhoneMedium]) {
    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('${size.width.toInt()} dp ${b.name}${rtl ? ' rtl' : ''}: yeni balonlar, tasma yok', (tester) async {
          await _pump(tester, size, b, rtl: rtl);
          // Üst çubukta çevrimiçi noktası; gelen mesajlarda 28 px avatar (birebir sohbette de).
          expect(find.byKey(const ValueKey('onlineDot')), findsOneWidget);
          expect(find.byKey(const ValueKey('sender-avatar-6')), findsOneWidget);
          // Tek gösterimlik: kilitli kart, açıldı hapı, gönderildi hapı.
          expect(find.text('Görüntüle'), findsOneWidget);
          expect(find.text('Fotoğraf · Açmak için dokun'), findsOneWidget);
          expect(find.text('Fotoğraf · Açıldı'), findsOneWidget);
          expect(find.text('Fotoğraf · Gönderildi'), findsOneWidget);
          // Açıklamalı fotoğraf ve +N ızgarası.
          expect(find.text('Kafede çalışıyorum'), findsOneWidget);
          expect(find.byType(MessageBubble), findsWidgets);
          final e = tester.takeException();
          if (e != null) fail('$e');
          await unmount(tester);
        });
      }
    }
  }

  testWidgets('giden balon marka kırmızısı, gelen kenarlıklı yüzey', (tester) async {
    await _pump(tester, kPhoneMedium, Brightness.light);
    Color? colorOf(String text) {
      final box = find
          .ancestor(of: find.text(text), matching: find.byType(Container))
          .evaluate()
          .map((e) => (e.widget as Container).decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null);
      return box.color;
    }

    expect(colorOf('İyiyim, sen?'), BuTokens.light.pr); // giden balon = marka eylem kırmızısı (RENK-1: #C0392B)
    expect(colorOf('Merhaba, nasılsın?'), const Color(0xFFFFFFFF));
    await unmount(tester);
  });
}
