import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Kullanıcı kararı (2026-11-07): "Son görülme" hiçbir kullanıcı için sohbet sayfalarında gösterilmez; "çevrimiçi" kalır.

FakeBackend _be({required Map<String, dynamic> presence}) => FakeBackend()
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
  ..on('/users/11/presence', presence)
  ..on('/messages/reactions', {'emojis': <String>[]});

Future<void> _open(WidgetTester tester, Map<String, dynamic> presence) async {
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(buildApp(
      ChatDetailPage(
        session: makeSession(_be(presence: presence)),
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
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('çevrimdışı kullanıcıda son görülme yazısı yok (bugün/dün/eski fark etmez)', (tester) async {
    for (final iso in [
      DateTime.now().toUtc().toIso8601String(),
      DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
      '2020-01-05T10:00:00Z',
    ]) {
      await _open(tester, {'online': false, 'lastSeenAt': iso});
      expect(find.textContaining('Son görülme'), findsNothing, reason: iso);
      expect(find.textContaining('son görülme'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('çevrimiçi kullanıcıda "çevrimiçi" görünür', (tester) async {
    await _open(tester, {'online': true});
    expect(find.text('çevrimiçi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
