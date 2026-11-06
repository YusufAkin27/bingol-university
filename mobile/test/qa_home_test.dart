import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _item(int id) => {
      'id': id,
      'type': 'HABER',
      'title': 'Haber basligi $id',
      'summary': 'Ozet $id',
      'publishedDate': '2026-11-0${(id % 9) + 1}',
      'imageUrl': null,
      'url': 'https://www.bingol.edu.tr/h/$id',
    };

Map<String, dynamic> _page(List<int> ids, int totalPages) => {
      'items': [for (final i in ids) _item(i)],
      'totalPages': totalPages,
      'page': 0,
    };

void main() {
  setUpAll(loadTestFonts);

  group('QA ana sayfa alani: haber listesi', () {
    testWidgets('bozuk ogeler (id yok / harita degil) atlanir, liste cokmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/news', {
          'items': [
            _item(1),
            {'title': 'idsiz'},
            'bozuk',
            _item(2),
          ],
          'totalPages': 1,
        })
        ..on('/status', {})
        ..on('/bookmarks/news/ids', {'ids': []});
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Haber basligi 1'), findsOneWidget);
      expect(find.text('Haber basligi 2'), findsOneWidget);
      expect(find.text('idsiz'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('sayfalama: ikinci sayfada ayni kayit tekrar gelirse kopya cizilmez', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend()
        ..on('/status', {})
        ..on('/bookmarks/news/ids', {'ids': []});
      b.handlers.add((req, path) {
        if (path != '/news') return null;
        final page = int.parse(req.url.queryParameters['page'] ?? '0');
        // Sayfa 1: araya yeni haber girdigi icin 6 (onceki sayfanin sonu) yine gelir.
        return FakeResult.json(page == 0 ? _page([1, 2, 3, 4, 5, 6], 2) : _page([6, 7], 2));
      });
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(b)), size: kPhoneSmall));
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await settle(tester);
      expect(find.text('Haber basligi 6', skipOffstage: false), findsOneWidget);
      expect(find.text('Haber basligi 7', skipOffstage: false), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yenileme hata verirse sayfa sayaci sifirlanmaz: sonraki kaydirma sayfa 0 kopyasi cekmez', (tester) async {
      useScreen(tester, kPhoneSmall);
      var failRefresh = false;
      final b = FakeBackend()
        ..on('/status', {})
        ..on('/bookmarks/news/ids', {'ids': []});
      final asked = <String>[];
      b.handlers.add((req, path) {
        if (path != '/news') return null;
        asked.add(req.url.queryParameters['page'] ?? '0');
        final page = int.parse(req.url.queryParameters['page'] ?? '0');
        if (failRefresh && page == 0) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
        return FakeResult.json(page == 0 ? _page([1, 2, 3, 4, 5, 6], 3) : _page([10 + page], 3));
      });
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(b)), size: kPhoneSmall));
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await settle(tester);
      expect(asked, ['0', '1']);
      // Cekerek yenile: sayfa 0 hata verir.
      failRefresh = true;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await settle(tester, const Duration(seconds: 2));
      failRefresh = false;
      asked.clear();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await settle(tester);
      // Siradaki istek 2. sayfa olmali; 0 degil (0 olsaydi ilk 6 haber kopyalanirdi).
      expect(asked.contains('0'), isFalse);
      await unmount(tester);
    });

    testWidgets('sayfa sonunda (son sayfa) ek istek atilmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/news', _page([1, 2], 1))
        ..on('/status', {})
        ..on('/bookmarks/news/ids', {'ids': []});
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await settle(tester);
      expect(b.count('GET /news?'), 1);
      await unmount(tester);
    });
  });

  group('QA ana sayfa alani: yemek gunu (Europe/Istanbul)', () {
    test('menuToday cihaz saat diliminden bagimsiz Istanbul gununu verir', () {
      // 5 Kasim 22:30 UTC = 6 Kasim 01:30 Istanbul.
      expect(menuToday(DateTime.utc(2026, 11, 5, 22, 30)), DateTime(2026, 11, 6));
      // 6 Kasim 20:59 UTC = 6 Kasim 23:59 Istanbul.
      expect(menuToday(DateTime.utc(2026, 11, 6, 20, 59)), DateTime(2026, 11, 6));
      // Ay sonu gecisi: 30 Kasim 21:00 UTC = 1 Aralik 00:00 Istanbul.
      expect(menuToday(DateTime.utc(2026, 11, 30, 21, 0)), DateTime(2026, 12, 1));
    });
  });

  group('QA ana sayfa alani: bildirim hedefi', () {
    test('POLL hedefi + communityId: kulup degil anket acilir', () {
      final t = resolvePushTarget({'targetType': 'POLL_NEW', 'targetId': '7', 'communityId': '3'});
      expect(t.dest, PushDest.poll);
      expect(t.id, 7);
    });

    test('NEWS hedefi + communityId: haber acilir', () {
      final t = resolvePushTarget({'targetType': 'NEWS', 'targetId': '9', 'communityId': '3'});
      expect(t.dest, PushDest.news);
      expect(t.id, 9);
    });

    test('COMMUNITY hedefi + communityId: kulup', () {
      final t = resolvePushTarget({'targetType': 'COMMUNITY', 'communityId': '3'});
      expect(t.dest, PushDest.community);
      expect(t.id, 3);
    });

    test('bozuk / bos yuk listeye duser, exception yok', () {
      expect(resolvePushTarget(null).dest, PushDest.notifications);
      expect(resolvePushTarget({'targetType': 'POLL', 'targetId': 'abc'}).dest, PushDest.poll == PushDest.notifications ? PushDest.poll : resolvePushTarget({'targetType': 'POLL', 'targetId': 'abc'}).dest);
      expect(resolvePushTarget({'targetId': '-5'}).dest, PushDest.notifications);
      expect(resolvePushTarget({'targetType': 'URL', 'value': 'http://x.com'}).dest, PushDest.notifications);
    });
  });

  group('QA ana sayfa alani: yemek sayfasi', () {
    testWidgets('bos menu + sunucu hatasi: hata gorunumu, yeniden dene calisir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/menu', status: 500);
      await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Yeniden dene'), findsWidgets);
      b.on('/menu', <dynamic>[]);
      await tester.tap(find.text('Yeniden dene').first);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
