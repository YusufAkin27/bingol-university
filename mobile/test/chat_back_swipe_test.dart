import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// iOS: sohbet sayfasında soldan sağa (kenardan) kaydırınca sohbet listesine dönülür; arama/ek menüsü açıkken önce onlar kapanır.

FakeBackend _be() => FakeBackend()
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
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

Widget _host(FakeBackend be) => Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(
                    builder: (_) => ChatDetailPage(
                          session: makeSession(be),
                          connectRealtime: false,
                          conversation: const {
                            'id': 1,
                            'type': 'DIRECT',
                            'title': 'Ali Veli',
                            'peer': {'id': 11, 'displayName': 'Ali Veli'},
                          },
                        ))),
            child: const Text('Sohbet listesi'),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadTestFonts);

  testWidgets('iOS: soldan sağa kenar kaydırması sohbet sayfasını kapatır', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(_host(_be()), size: kPhoneMedium));
    await tester.tap(find.byKey(const ValueKey('open')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byType(ChatDetailPage), findsOneWidget);
    // Kenardan (x≈3) sağa sürükle.
    final g = await tester.startGesture(const Offset(3, 300));
    await g.moveBy(const Offset(120, 0));
    await tester.pump();
    await g.moveBy(const Offset(200, 0));
    await tester.pump();
    await g.up();
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byType(ChatDetailPage), findsNothing, reason: 'kaydırma sohbet listesine dönmeli');
    expect(find.text('Sohbet listesi'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
