import 'package:bu_kampus/features/chat/all_departments_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// Sohbet listesi "Bölüm" süzgeci + mesajsız bölüm odasının listede görünmesi + katılınca listenin eşitlenmesi.

String _iso() => DateTime.now().toUtc().toIso8601String();

final _direct = {
  'id': 1,
  'type': 'DIRECT',
  'title': 'Ali Veli',
  'peer': {'id': 11, 'displayName': 'Ali Veli'},
  'unreadCount': 0,
  'lastMessage': {
    'id': 101,
    'conversationId': 1,
    'senderId': 11,
    'text': 'Merhaba Ali',
    'attachments': const [],
    'createdAt': _iso(),
  },
};

// Yeni katılınan, henüz mesajı olmayan bölüm odası: lastMessage yok.
final _emptyDept = {'id': 2, 'type': 'DEPARTMENT', 'title': 'Matematik', 'unreadCount': 0};

FakeBackend _server({required List<Map<String, dynamic>> items, List<Map<String, dynamic>> mine = const []}) {
  final be = FakeBackend();
  be.on('/conversations', {'items': items, 'nextCursor': null});
  be.on('/conversations/unread-count', {'total': 0, 'mutedTotal': 0, 'conversations': [], 'archivedChats': 0});
  be.on('/chat/departments/mine', {'items': mine, 'own': null});
  return be;
}

Future<void> _pump(WidgetTester tester, FakeBackend be) async {
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(buildApp(ChatTab(session: makeSession(be), connectRealtime: false), size: kPhoneMedium));
  await settle(tester, const Duration(seconds: 1));
}

Finder _chip(String t) => find.descendant(of: find.byKey(const ValueKey('chat-segment')), matching: find.text(t));

void main() {
  setUpAll(loadTestFonts);

  testWidgets('Bölüm çipi son sırada; mesajsız bölüm odası Tümü listesinde "Henüz mesaj yok" ile görünür', (tester) async {
    await _pump(tester, _server(items: [_direct, _emptyDept]));
    expect(_chip('Bölüm'), findsOneWidget);
    expect(tester.getTopLeft(_chip('Etkinlikler')).dx, lessThan(tester.getTopLeft(_chip('Bölüm')).dx));
    expect(find.text('Ali Veli'), findsOneWidget);
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Henüz mesaj yok. İlk mesajı sen yaz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bölüm süzgeci yalnız DEPARTMENT sohbetlerini gösterir', (tester) async {
    await _pump(tester, _server(items: [_direct, _emptyDept]));
    await tester.tap(_chip('Bölüm'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Ali Veli'), findsNothing);
    expect(find.text('Matematik'), findsOneWidget);
    await tester.tap(_chip('Kişiler'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Matematik'), findsNothing);
    expect(find.text('Ali Veli'), findsOneWidget);
  });

  testWidgets('Bölüm süzgeci boş: bilgi + Tüm bölümler düğmesi', (tester) async {
    await _pump(tester, _server(items: [_direct]));
    await tester.tap(_chip('Bölüm'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Henüz bölüm kanalına katılmadın'), findsOneWidget);
    expect(find.text('Tüm bölümler'), findsOneWidget);
  });

  testWidgets('Tüm bölümler ekranında katılınca sohbet listesi sinyali artar', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()
      ..on('/chat/departments?page=0&size=200', {
        'items': [
          {
            'key': 'matematik',
            'name': 'Matematik',
            'nameEn': 'Mathematics',
            'nameAr': 'Math AR',
            'faculty': 'Fen-Edebiyat Fakültesi',
            'own': false,
            'joined': false,
            'closed': false,
            'memberCount': 3,
            'conversationId': null,
          }
        ],
        'page': 0,
        'size': 200,
        'total': 1,
        'ownKey': null,
      })
      ..on('/chat/departments/matematik/join', {'key': 'matematik', 'joined': true, 'conversationId': 50});
    final s = makeSession(be);
    var bumps = 0;
    s.badges.conversationsDirty.addListener(() => bumps++);
    await tester.pumpWidget(p00App(AllDepartmentsPage(session: s), scaffold: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Katıl'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(be.count('POST /chat/departments/matematik/join'), 1);
    expect(bumps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
