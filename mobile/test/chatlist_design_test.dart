import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _row(int id, String type, String title,
        {int unread = 0, String text = '', List<Map<String, dynamic>>? att, String? status}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title},
      'unreadCount': unread,
      'lastMessage': {
        'id': 100 + id,
        'conversationId': id,
        'senderId': 10 + id,
        'text': text,
        'attachments': att ?? const [],
        if (status != null) 'status': status,
        'createdAt': _iso(DateTime.now()),
      },
    };

FakeBackend _be() => FakeBackend()
  ..on('/conversations/unread-count', {'total': 3})
  ..on('/conversations*', {
    'items': [
      _row(1, 'DIRECT', 'Mehmet Kaya', unread: 2, text: 'Yarınki ders notlarını atar mısın?'),
      _row(2, 'DIRECT', 'Zeynep Demir', status: 'READ', att: [
        {'id': 1, 'kind': 'IMAGE', 'url': '/x.jpg'}
      ]),
      _row(3, 'DIRECT', 'Ahmet Yıldız', att: [
        {'id': 2, 'kind': 'VIDEO', 'url': '/v.mp4', 'durationMs': 24000}
      ]),
      _row(4, 'CLUB', 'Edebiyat Kulübü Çok Uzun Bir Kulüp Adı Taşma Denemesi', unread: 120, text: 'Merhaba'),
    ],
    'nextCursor': null,
  });

void main() {
  test('baş harfler', () {
    expect(ChatlistAvatar.initials('Ahmet Yıldız'), 'AY');
    expect(ChatlistAvatar.initials('burak'), 'B');
    expect(ChatlistAvatar.initials(''), '?');
  });

  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      for (final rtl in [false, true]) {
        testWidgets('sohbet listesi taşma yok ${b.name} ${size.width.toInt()} rtl=$rtl', (tester) async {
          useScreen(tester, size);
          await tester.pumpWidget(buildApp(
              Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: ChatTab(session: makeSession(_be()), connectRealtime: false)),
              brightness: b,
              size: size));
          await settle(tester, const Duration(seconds: 1));
          expect(find.text('Mehmet Kaya'), findsOneWidget);
          expect(find.text('Fotoğraf'), findsOneWidget);
          expect(find.text('Video 0:24'), findsOneWidget);
          expect(find.text('99+'), findsOneWidget);
          expect(find.byType(ChatlistAvatar), findsNWidgets(4));
          expect(tester.getSize(find.byType(ChatlistAvatar).first), const Size(52, 52));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
