import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Sohbet listesi: kaydırma = yan yana "Arşivle" + "Daha fazla" (kendiliğinden eylem yok);
/// uzun basma = salt okunur önizleme (okundu işaretlenmez).

String _iso() => DateTime.now().toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, String text, {int sender = 11}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'attachments': const [],
      'createdAt': _iso(),
    };

FakeBackend _backend() {
  final be = FakeBackend();
  be.handlers.add((req, path) {
    if (req.method == 'GET' && path == '/conversations/unread-count') {
      return const FakeResult.json({'total': 3, 'mutedTotal': 0, 'conversations': [], 'archivedChats': 0, 'archivedUnreadChats': 0});
    }
    if (req.method == 'GET' && path == '/conversations') {
      return FakeResult.json({
        'items': [
          {
            'id': 1,
            'type': 'DIRECT',
            'title': 'Ali Veli',
            'peer': {'id': 11, 'displayName': 'Ali Veli'},
            'unreadCount': 3,
            'lastMessage': _msg(103, 'Son mesaj burada'),
          }
        ],
        'nextCursor': null,
      });
    }
    if (req.method == 'GET' && path == '/conversations/1/messages') {
      return FakeResult.json({
        'items': [_msg(103, 'Son mesaj burada'), _msg(102, 'Ikinci mesaj', sender: 1), _msg(101, 'Ilk mesaj')],
        'nextCursor': null,
      });
    }
    return null;
  });
  return be;
}

Future<void> _pump(WidgetTester tester, FakeBackend be) async {
  useScreen(tester, kPhoneMedium);
  final Session s = makeSession(be);
  s.realtime = ChatRealtime(s);
  await tester.pumpWidget(buildApp(ChatTab(session: s, connectRealtime: false), size: kPhoneMedium));
  await settle(tester, const Duration(seconds: 1));
}

void main() {
  testWidgets('tam kaydırma eylem çalıştırmaz; Arşivle + Daha fazla yan yana açılır', (tester) async {
    final be = _backend();
    await _pump(tester, be);
    await tester.drag(find.text('Ali Veli'), const Offset(-600, 0));
    await settle(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('swipe-archive')), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe-more')), findsOneWidget);
    expect(find.text('Arşivle'), findsOneWidget);
    expect(find.text('Daha fazla'), findsOneWidget);
    expect(be.count('PUT /conversations/1/archive'), 0);
    expect(be.count('DELETE /conversations/1'), 0);
    expect(find.text('Ali Veli'), findsOneWidget);
    final a = tester.getCenter(find.byKey(const ValueKey('swipe-archive')));
    final m = tester.getCenter(find.byKey(const ValueKey('swipe-more')));
    expect((a.dy - m.dy).abs(), lessThan(1)); // yan yana
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daha fazla: Sessize al / Arşivle / Sil menüsü açılır', (tester) async {
    final be = _backend();
    await _pump(tester, be);
    await tester.drag(find.text('Ali Veli'), const Offset(-600, 0));
    await settle(tester, const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('swipe-more')));
    await settle(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('act-mute')), findsOneWidget);
    expect(find.byKey(const ValueKey('act-archive')), findsOneWidget);
    expect(find.byKey(const ValueKey('act-delete')), findsOneWidget);
    expect(be.count('DELETE /conversations/1'), 0);
  });

  testWidgets('uzun basma: önizleme mesajları gösterir, okundu/teslim ucu çağrılmaz', (tester) async {
    final be = _backend();
    await _pump(tester, be);
    final before = be.requests.length; // liste kendi teslim bildirimini zaten gonderdi (onizlemeden bagimsiz)
    await tester.longPress(find.text('Ali Veli'));
    await settle(tester, const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('conversation-peek')), findsOneWidget);
    expect(find.text('Ilk mesaj'), findsOneWidget);
    expect(find.text('Ikinci mesaj'), findsOneWidget);
    expect(be.count('GET /conversations/1/messages'), 1);
    expect(be.count('/read'), 0);
    // Onizleme boyunca yalniz mesaj listesi GET'i atilir: POST/PUT/DELETE yok.
    expect(be.requests.skip(before).where((r) => !r.startsWith('GET ')), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
