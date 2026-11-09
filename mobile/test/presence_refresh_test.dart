import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Çevrimiçi/çevrimdışı durumu: karşı taraf durum değiştirince başlık, yoklama turundan bağımsız saatle güncellenir.

FakeBackend _be(bool online) => FakeBackend()
  ..on('/conversations/1/messages?size=30', {
    'items': [
      {'id': 5, 'conversationId': 1, 'senderId': 11, 'text': 'Merhaba', 'createdAt': DateTime.now().toUtc().toIso8601String()},
    ],
    'nextCursor': null,
  })
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': online})
  ..on('/messages/reactions', {'emojis': <String>[]});

void main() {
  setUpAll(loadTestFonts);

  testWidgets('karşı taraf çevrimdışı olunca başlık presenceInterval içinde güncellenir', (tester) async {
    final be = _be(true);
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(
        ChatDetailPage(
          session: makeSession(be),
          connectRealtime: false,
          conversation: const {
            'id': 1,
            'type': 'DIRECT',
            'title': 'Ali Veli',
            'peer': {'id': 11, 'displayName': 'Ali Veli'},
          },
        ),
        size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('çevrimiçi'), findsOneWidget);

    be.on('/users/11/presence', {'online': false});
    await tester.pump(kChatPresenceInterval + const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('çevrimiçi'), findsNothing, reason: 'durum 15 sn içinde (yoklama turunu beklemeden) yenilenmeli');

    be.on('/users/11/presence', {'online': true});
    await tester.pump(kChatPresenceInterval + const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('çevrimiçi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
