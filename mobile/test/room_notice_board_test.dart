import 'package:bu_kampus/features/chat/room_notice_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _n(int id, {bool seen = false, bool pinned = true, int? count}) => {
      'id': id,
      'title': 'Baslik $id',
      'body': 'Metin $id',
      'pinned': pinned,
      'seenByMe': seen,
      'seenCount': count,
    };

void main() {
  testWidgets('sabit duyuru yoksa ve yonetici degilse serit gizli', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()..on('/conversations/5/notices/pinned', {'items': [], 'canManage': false, 'total': 0});
    await tester.pumpWidget(buildApp(RoomNoticeStrip(session: makeSession(b), conversationId: 5), size: kPhoneMedium));
    await settle(tester);
    expect(find.byKey(const ValueKey('roomNoticeStrip')), findsNothing);
  });

  testWidgets('sabit duyuru sertte gorunur ve gorulmemisse bir kez gordu bildirilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()
      ..on('/conversations/5/notices/pinned', {
        'items': [_n(7)],
        'canManage': false,
        'total': 1,
      })
      ..on('/conversations/5/notices/7/seen', null, status: 204);
    await tester.pumpWidget(buildApp(RoomNoticeStrip(session: makeSession(b), conversationId: 5), size: kPhoneMedium));
    await settle(tester);
    expect(find.text('Baslik 7'), findsOneWidget);
    expect(b.requests.where((r) => r.contains('/notices/7/seen')).length, 1);
  });

  testWidgets('yonetici sabit duyuru olmasa da panoya girebilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()..on('/conversations/5/notices/pinned', {'items': [], 'canManage': true, 'total': 0});
    await tester.pumpWidget(buildApp(RoomNoticeStrip(session: makeSession(b), conversationId: 5), size: kPhoneMedium));
    await settle(tester);
    expect(find.byKey(const ValueKey('roomNoticeStrip')), findsOneWidget);
  });

  testWidgets('pano sayfalama: build sirasinda setState yok, hata sonrasi otomatik tekrar dongusu yok', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = FakeBackend()
      ..handlers.add((req, path) {
        if (path != '/conversations/5/notices') return null;
        final cursor = req.url.queryParameters['cursor'];
        if (cursor == null) {
          return FakeResult.json({'items': [for (var i = 1; i <= 3; i++) _n(i)], 'nextCursor': 3});
        }
        return FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
      });
    await tester.pumpWidget(buildApp(
        RoomNoticeBoardPage(session: makeSession(b), conversationId: 5, canManage: false),
        size: kPhoneMedium));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    final n = b.requests.where((r) => r.contains('cursor=3')).length;
    expect(n, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(b.requests.where((r) => r.contains('cursor=3')).length, 1);
  });
}
