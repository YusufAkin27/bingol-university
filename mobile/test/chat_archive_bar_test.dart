import 'package:bu_kampus/core/icons/bu_icons.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:bu_kampus/l10n/app_localizations_ar.dart';
import 'package:bu_kampus/l10n/app_localizations_en.dart';
import 'package:bu_kampus/l10n/app_localizations_tr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Sohbet listesinin en üstündeki "Arşivlenenler" çubuğu: sayı sohbet başına 1, kaydırınca arşive girer, çubuk yoksa çizilmez.

String _iso() => DateTime.now().toUtc().toIso8601String();

Map<String, dynamic> _row(int id, String title, {int unread = 0}) => {
      'id': id,
      'type': 'DIRECT',
      'title': title,
      'peer': {'id': 10 + id, 'displayName': title},
      'unreadCount': unread,
      'lastMessage': {
        'id': 100 + id,
        'conversationId': id,
        'senderId': 10 + id,
        'text': 'Merhaba $title',
        'attachments': const [],
        'createdAt': _iso(),
      },
    };

/// Sunucu davranışını taklit eden durumlu yedek: PUT/DELETE arşiv durumunu değiştirir, özet ve liste ona göre döner.
class _Server {
  _Server({required this.normal, required this.archived});

  final List<Map<String, dynamic>> normal;
  final List<Map<String, dynamic>> archived;

  FakeBackend build() {
    final be = FakeBackend();
    be.handlers.add((req, path) {
      final m = req.method;
      if (m == 'GET' && path == '/conversations/unread-count') {
        final total = normal.fold<int>(0, (a, c) => a + (c['unreadCount'] as int));
        return FakeResult.json({
          'total': total,
          'mutedTotal': 0,
          'conversations': [],
          'archivedChats': archived.length,
          'archivedUnreadChats': archived.where((c) => (c['unreadCount'] as int) > 0).length,
        });
      }
      if (m == 'GET' && path == '/conversations') {
        final arch = req.url.queryParameters['archived'] == 'true';
        return FakeResult.json({'items': arch ? archived : normal, 'nextCursor': null});
      }
      final mm = RegExp(r'^/conversations/(\d+)/archive$').firstMatch(path);
      if (mm != null) {
        final id = int.parse(mm.group(1)!);
        if (m == 'PUT') {
          final i = normal.indexWhere((c) => c['id'] == id);
          if (i >= 0) archived.insert(0, normal.removeAt(i));
        } else if (m == 'DELETE') {
          final i = archived.indexWhere((c) => c['id'] == id);
          if (i >= 0) normal.insert(0, archived.removeAt(i));
        }
        return const FakeResult.json(<String, dynamic>{});
      }
      return null;
    });
    return be;
  }
}

Future<void> _pump(WidgetTester tester, FakeBackend be, {ChatRealtime Function(Session s)? rt}) async {
  useScreen(tester, kPhoneMedium);
  final s = makeSession(be);
  if (rt != null) s.realtime = rt(s);
  await tester.pumpWidget(buildApp(ChatTab(session: s, connectRealtime: false), size: kPhoneMedium));
  await settle(tester, const Duration(seconds: 1));
}

final _bar = find.byKey(const ValueKey('chat-archive-bar'));

void main() {
  testWidgets('arşiv hiç yoksa çubuk çizilmez, sağ üstte arşiv ikonu da yok', (tester) async {
    final srv = _Server(normal: [_row(1, 'Ali Veli', unread: 2)], archived: []);
    await _pump(tester, srv.build());
    expect(_bar, findsNothing);
    expect(find.text('Arşivlenenler'), findsNothing);
    expect(find.byIcon(BuIcons.archive), findsNothing);
    expect(find.text('Ali Veli'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çubuk: okunmamış SOHBET sayısı (sohbet başına 1; 100 okunmamış da 1)', (tester) async {
    final srv = _Server(
      normal: [_row(1, 'Ali Veli')],
      archived: [_row(2, 'Arşiv Bir', unread: 100), _row(3, 'Arşiv İki', unread: 3), _row(4, 'Arşiv Üç')],
    );
    await _pump(tester, srv.build());
    expect(_bar, findsOneWidget);
    expect(find.text('Arşivlenenler'), findsOneWidget);
    expect(find.text('2 bildirim'), findsOneWidget); // 3 arşivli sohbetin 2'sinde okunmamış var
    expect(find.text('103 bildirim'), findsNothing);
    // Çubuk listenin en üstünde: ilk sohbet satırının üstünde.
    expect(tester.getTopLeft(_bar).dy, lessThan(tester.getTopLeft(find.text('Ali Veli')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('arşivli sohbetlerde okunmamış yoksa çubuk var ama sayı yok', (tester) async {
    final srv = _Server(normal: [_row(1, 'Ali Veli')], archived: [_row(2, 'Arşiv Bir')]);
    await _pump(tester, srv.build());
    expect(_bar, findsOneWidget);
    expect(find.text('Arşivlenenler'), findsOneWidget);
    expect(find.textContaining('bildirim'), findsNothing);
  });

  testWidgets('sağa/sola kaydırınca sohbet listeden çıkar, arşiv çubuğu belirir ve sayı güncellenir', (tester) async {
    final srv = _Server(normal: [_row(1, 'Ali Veli', unread: 5), _row(2, 'Veli Can')], archived: []);
    final be = srv.build();
    await _pump(tester, be);
    expect(_bar, findsNothing);

    await tester.drag(find.text('Ali Veli'), const Offset(-500, 0));
    await settle(tester, const Duration(seconds: 1));

    expect(find.text('Ali Veli'), findsNothing); // listeden çıktı
    expect(find.text('Veli Can'), findsOneWidget);
    expect(be.count('PUT /conversations/1/archive'), 1);
    expect(be.bodies['PUT /conversations/1/archive'], {'keepArchived': true});
    expect(_bar, findsOneWidget);
    expect(find.text('1 bildirim'), findsOneWidget); // okunmamışı olan 1 sohbet arşive girdi
    expect(tester.takeException(), isNull);

    // Okunmamışı olmayan ikinci sohbet de arşive girer: çubuktaki sayı değişmez (okunmamış sohbet sayısı).
    await tester.drag(find.text('Veli Can'), const Offset(-500, 0));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Veli Can'), findsNothing);
    expect(find.text('1 bildirim'), findsOneWidget);
    expect(find.text('Arşivlenenler'), findsOneWidget);
  });

  testWidgets('arşivleme başarısız olursa satır geri gelir ve çubuk sayısı geri alınır', (tester) async {
    final srv = _Server(normal: [_row(1, 'Ali Veli', unread: 2)], archived: []);
    final be = srv.build();
    be.handlers.insert(0, (req, path) => req.method == 'PUT' && path == '/conversations/1/archive'
        ? const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500)
        : null);
    await _pump(tester, be);
    await tester.drag(find.text('Ali Veli'), const Offset(-500, 0));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Ali Veli'), findsOneWidget);
    expect(_bar, findsNothing);
  });

  testWidgets('çubuğa dokununca arşiv listesi açılır; orada kaydırınca arşivden çıkar ve çubuk sayısı düşer', (tester) async {
    final srv = _Server(normal: [_row(1, 'Ali Veli')], archived: [_row(2, 'Arşiv Bir', unread: 4), _row(3, 'Arşiv İki')]);
    final be = srv.build();
    await _pump(tester, be);
    expect(find.text('1 bildirim'), findsOneWidget);

    await tester.tap(_bar);
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Arşiv'), findsNothing); // sayfa başlığı görünmez (sadeleştirme); içerik aşağıda doğrulanır
    expect(find.text('Arşiv Bir'), findsOneWidget);
    expect(find.text('Arşiv İki'), findsOneWidget);
    expect(find.text('Ali Veli'), findsNothing);

    await tester.drag(find.text('Arşiv Bir'), const Offset(-500, 0));
    await settle(tester, const Duration(seconds: 1));
    expect(be.count('DELETE /conversations/2/archive'), 1);
    expect(find.text('Arşiv Bir'), findsNothing);

    // Geri dön: sohbet normal listede, çubukta yalnız kalan arşivli sohbet var ve bildirim sayısı yok.
    await tester.tap(find.byIcon(BuIcons.arrowLeft).first);
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Arşiv Bir'), findsOneWidget);
    expect(find.text('Arşivlenenler'), findsOneWidget);
    expect(find.textContaining('bildirim'), findsNothing);
  });

  testWidgets('canlı mesaj: arşivli sohbete yeni mesaj gelince çubuk sayısı sunucudan güncellenir', (tester) async {
    final srv = _Server(normal: [_row(1, 'Ali Veli')], archived: [_row(2, 'Arşiv Bir'), _row(3, 'Arşiv İki', unread: 1)]);
    final be = srv.build();
    late ChatRealtime rt;
    await _pump(tester, be, rt: (s) => rt = ChatRealtime(s));
    expect(find.text('1 bildirim'), findsOneWidget);

    // Sunucu: arşivli 2 numaralı sohbette artık okunmamış var (bildirim gitmez, sayaç artar).
    srv.archived.firstWhere((c) => c['id'] == 2)['unreadCount'] = 7;
    rt.debugEmitMessage({
      'id': 500,
      'conversationId': 2,
      'senderId': 12,
      'text': 'yeni',
      'attachments': const [],
      'createdAt': _iso(),
    });
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('2 bildirim'), findsOneWidget);

    // Aynı sohbete ikinci mesaj: sohbet başına 1 olduğundan sayı artmaz.
    srv.archived.firstWhere((c) => c['id'] == 2)['unreadCount'] = 8;
    rt.debugEmitMessage({
      'id': 501,
      'conversationId': 2,
      'senderId': 12,
      'text': 'yeni 2',
      'attachments': const [],
      'createdAt': _iso(),
    });
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('2 bildirim'), findsOneWidget);
    expect(find.text('Ali Veli'), findsOneWidget);
  });

  testWidgets('arama yazılınca çubuk gizlenir (arşiv süzülmez)', (tester) async {
    final srv = _Server(normal: [_row(1, 'Ali Veli')], archived: [_row(2, 'Arşiv Bir', unread: 1)]);
    await _pump(tester, srv.build());
    expect(_bar, findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ali');
    await settle(tester, const Duration(milliseconds: 500));
    expect(_bar, findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await settle(tester, const Duration(milliseconds: 500));
    expect(_bar, findsOneWidget);
  });

  group('üç dil', () {
    test('başlık ve "N bildirim" metinleri tr/en/ar', () {
      final tr = AppLocalizationsTr();
      final en = AppLocalizationsEn();
      final ar = AppLocalizationsAr();
      expect(tr.chatArchiveBarTitle, 'Arşivlenenler');
      expect(tr.chatArchiveBarCount(3), '3 bildirim');
      expect(tr.chatArchiveBarCount(5), '5 bildirim');
      expect(en.chatArchiveBarTitle, 'Archived');
      expect(en.chatArchiveBarCount(1), '1 notification');
      expect(en.chatArchiveBarCount(3), '3 notifications');
      expect(ar.chatArchiveBarTitle, isNotEmpty);
      for (final n in [1, 2, 3, 11, 100]) {
        expect(ar.chatArchiveBarCount(n), isNotEmpty);
        expect(ar.chatArchiveBarSemantics(n), contains(ar.chatArchiveBarTitle));
      }
      expect(tr.chatArchiveBarSemantics(2), contains('2 bildirim'));
    });

    testWidgets('çubuk bileşeni: 0 arşivli = hiçbir şey, RTL taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(buildApp(
          Directionality(
              textDirection: TextDirection.rtl,
              child: Column(children: [
                ChatArchiveBar(archivedChats: 0, unreadChats: 0, onTap: () {}),
                ChatArchiveBar(archivedChats: 4, unreadChats: 120, onTap: () {}),
              ])),
          size: kPhoneSmall));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('chat-archive-bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
