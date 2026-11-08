import 'package:bu_kampus/features/chat/department_chat_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  setUpAll(loadTestFonts);

  Future<FakeBackend> pump(WidgetTester tester, Map<String, dynamic> state) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()..on('/department-chat', state);
    await tester.pumpWidget(buildApp(
      Scaffold(body: DepartmentChatEntry(session: makeSession(b))),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    return b;
  }

  testWidgets('bölüm var, üye değil: katıl satırı görünür', (tester) async {
    await pump(tester, {
      'available': true,
      'departmentName': 'Bilgisayar Mühendisliği',
      'closed': false,
      'joined': false,
      'memberCount': 3,
      'conversationId': null,
    });
    expect(find.byKey(const ValueKey('department-chat-entry')), findsOneWidget);
    expect(find.textContaining('Bilgisayar Mühendisliği'), findsOneWidget);
  });

  testWidgets('bölüm yok: satır çizilmez', (tester) async {
    await pump(tester, {'available': false, 'closed': false, 'joined': false, 'memberCount': 0});
    expect(find.byKey(const ValueKey('department-chat-entry')), findsNothing);
  });

  testWidgets('zaten üye: satır çizilmez', (tester) async {
    await pump(tester, {
      'available': true,
      'departmentName': 'Bilgisayar Mühendisliği',
      'closed': false,
      'joined': true,
      'memberCount': 3,
      'conversationId': 9,
    });
    expect(find.byKey(const ValueKey('department-chat-entry')), findsNothing);
  });

  testWidgets('oda kapalı: satır çizilmez', (tester) async {
    await pump(tester, {
      'available': true,
      'departmentName': 'Bilgisayar Mühendisliği',
      'closed': true,
      'joined': false,
      'memberCount': 0,
    });
    expect(find.byKey(const ValueKey('department-chat-entry')), findsNothing);
  });
}
