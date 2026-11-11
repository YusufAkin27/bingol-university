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
    final all = [
      {
        'departmentName': 'Bilgisayar Mühendisliği',
        'joined': true,
        'conversationId': 91
      },
      {'departmentName': 'Hukuk', 'joined': false},
    ];
    final b = FakeBackend()
      ..handlers.add((req, path) {
        if (path != '/department-chat/rooms') return null;
        final q = req.url.queryParameters['q'];
        // Arama SUNUCUDA yapılır: istemci süzmez, yalnız sunucunun döndüğünü çizer.
        return FakeResult.json(q == null
            ? all
            : [all.first]);
      });
    await tester
        .pumpWidget(buildApp(DepartmentChatsPage(session: makeSession(b))));
    await tester.pumpAndSettle();
    expect(find.text('Hukuk'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bilgisayar muhendisligi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
        b.requests,
        contains(
            'GET /department-chat/rooms?size=30&q=bilgisayar+muhendisligi'));
    expect(find.text('Hukuk'), findsNothing);
    await tester.tap(find.text('Ayrıl'));
    await tester.pumpAndSettle();
    expect(b.requests,
        contains('DELETE /department-chat/membership?conversationId=91'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('department list pages by last departmentName and stops on short page',
      (tester) async {
    useScreen(tester, kPhoneSmall);
    final names = [for (var i = 0; i < 40; i++) 'Bölüm ${i.toString().padLeft(2, '0')}'];
    final b = FakeBackend()
      ..handlers.add((req, path) {
        if (path != '/department-chat/rooms') return null;
        final after = req.url.queryParameters['after'] ?? '';
        final page = names.where((n) => n.compareTo(after) > 0).take(30);
        return FakeResult.json([
          for (final n in page) {'departmentName': n, 'joined': false}
        ]);
      });
    await tester
        .pumpWidget(buildApp(DepartmentChatsPage(session: makeSession(b))));
    await tester.pumpAndSettle();
    expect(b.requests.where((r) => r.contains('/department-chat/rooms')).length, 1);
    expect(find.text('Bölüm 39'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(
        b.requests,
        contains(
            'GET /department-chat/rooms?size=30&after=${Uri.encodeQueryComponent('Bölüm 29')}'));
    expect(find.text('Bölüm 39'), findsOneWidget);
    // 10 < 30 döndü: liste bitti, başka sayfa istenmez.
    expect(b.requests.where((r) => r.contains('/department-chat/rooms')).length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older search response does not overwrite the newer one',
      (tester) async {
    useScreen(tester, kPhoneSmall);
    final b = FakeBackend(delay: const Duration(milliseconds: 50))
      ..handlers.add((req, path) {
        if (path != '/department-chat/rooms') return null;
        final q = req.url.queryParameters['q'] ?? '';
        return FakeResult.json([
          {'departmentName': q.isEmpty ? 'Tümü' : 'Sonuç $q', 'joined': false}
        ]);
      });
    await tester
        .pumpWidget(buildApp(DepartmentChatsPage(session: makeSession(b))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('Sonuç ab'), findsOneWidget);
    expect(find.text('Sonuç a'), findsNothing);
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

  testWidgets('sayfalamayi bilmeyen sunucu ayni listeyi dondururse sonsuz yukleme dongusu olmaz',
      (tester) async {
    useScreen(tester, kPhoneSmall);
    final all = [for (var i = 0; i < 35; i++) {'departmentName': 'Bölüm ${i.toString().padLeft(2, '0')}', 'joined': false}];
    final b = FakeBackend()
      ..handlers.add((req, path) => path == '/department-chat/rooms' ? FakeResult.json(all) : null);
    await tester.pumpWidget(buildApp(DepartmentChatsPage(session: makeSession(b))));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -8000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 8000));
      await tester.pumpAndSettle();
    }
    // İlk sayfa + en çok bir "devam" isteği; sonra yeni satır gelmediği için durur.
    expect(b.requests.where((r) => r.contains('/department-chat/rooms')).length, lessThanOrEqualTo(2));
  });
}
