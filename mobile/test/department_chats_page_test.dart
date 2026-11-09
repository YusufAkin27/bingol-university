import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/department_chat_entry.dart';
import 'package:bu_kampus/features/chat/department_chats_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets(
      'department discovery searches Turkish names and leaves the selected chat',
      (tester) async {
    useScreen(tester, kPhoneSmall);
    final b = FakeBackend()
      ..on('/department-chat/rooms', [
        {
          'departmentName': 'Bilgisayar Mühendisliği',
          'joined': true,
          'conversationId': 91
        },
        {'departmentName': 'Hukuk', 'joined': false},
      ]);
    await tester
        .pumpWidget(buildApp(DepartmentChatsPage(session: makeSession(b))));
    await tester.pumpAndSettle();
    expect(find.text('Hukuk'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bilgisayar muhendisligi');
    await tester.pumpAndSettle();
    expect(find.text('Hukuk'), findsNothing);
    await tester.tap(find.text('Ayrıl'));
    await tester.pumpAndSettle();
    expect(b.requests,
        contains('DELETE /department-chat/membership?conversationId=91'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'department filter shows empty department chats and discovery entry',
      (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()
      ..on('/conversations', {
        'items': [
          {
            'id': 91,
            'type': 'DEPARTMENT',
            'title': 'Bilgisayar Mühendisliği',
            'memberCount': 1
          },
          {'id': 92, 'type': 'CLUB', 'title': 'Müzik Kulübü', 'memberCount': 3},
        ]
      });
    await tester.pumpWidget(
        buildApp(ChatTab(session: makeSession(b), connectRealtime: false)));
    await tester.pumpAndSettle();
    expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
    final chip = find.text('Bölümler');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
    expect(find.text('Müzik Kulübü'), findsNothing);
    expect(
        find.byKey(const ValueKey('department-chats-browse')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('join targets the requested department', () async {
    final b = FakeBackend()
      ..on('/department-chat/join', {'joined': true, 'conversationId': 91});
    final api = DepartmentChatApi(makeSession(b));
    final joined = await api.join('Bilgisayar Mühendisliği');
    expect(joined['joined'], isTrue);
    expect(b.requests.single,
        'POST /department-chat/join?department=${Uri.encodeComponent('Bilgisayar Mühendisliği')}');
  });
}
