import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/news/unit_news.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Ortak durum matrisi: her ekran x (bos, 401, 403, 429, 5xx, cevrimdisi, bozuk govde) x (320/390) x (acik-LTR, koyu-RTL)
/// x yazi olcegi 1.3. Beklenti: istisna / tasma yok, sayfa ayakta.
typedef ScreenBuilder = Widget Function(FakeBackend b);

Widget _frame(Widget page, {required bool rtl}) => Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: page,
        ),
      ),
    );

enum Scenario { empty, unauthorized, forbidden, rateLimited, serverError, offline, garbage }

void _arm(FakeBackend b, Scenario s) {
  FakeResult? err(int status, String code) => FakeResult.json({'code': code, 'message': 'x'}, status: status);
  switch (s) {
    case Scenario.empty:
      b.handlers.add((req, path) {
        if (path == '/news') return const FakeResult.json({'items': [], 'totalPages': 0});
        if (path == '/menu') return const FakeResult.json([]);
        if (path == '/notifications') return const FakeResult.json({'items': [], 'nextCursor': null, 'unreadCount': 0});
        return null;
      });
    case Scenario.unauthorized:
      b.handlers.add((req, path) => err(401, 'UNAUTHORIZED'));
    case Scenario.forbidden:
      b.handlers.add((req, path) => err(403, 'FORBIDDEN'));
    case Scenario.rateLimited:
      b.handlers.add((req, path) => err(429, 'RATE_LIMITED'));
    case Scenario.serverError:
      b.handlers.add((req, path) => err(500, 'SERVER_ERROR'));
    case Scenario.offline:
      b.offline = true;
    case Scenario.garbage:
      // Bozuk gövde: beklenen harita yerine dizi/dize/null.
      b.handlers.add((req, path) => const FakeResult.json('bozuk'));
  }
}

void main() {
  setUpAll(loadTestFonts);

  final screens = <String, ScreenBuilder>{
    'Haberler': (b) => NewsListPage(session: makeSession(b)),
    'Duyurular': (b) => NewsListPage(session: makeSession(b), initialType: 'DUYURU'),
    'Yemek': (b) => MenuPage(session: makeSession(b)),
    'Bildirimler': (b) => NotificationsPage(session: makeSession(b)),
    'Arama': (b) => SearchPage(session: makeSession(b)),
    'Anketler': (b) => PollListPage(session: makeSession(b)),
  };

  for (final e in screens.entries) {
    for (final s in Scenario.values) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        for (final alt in [false, true]) {
          testWidgets('${e.key} / ${s.name} / ${size.width.toInt()} dp / ${alt ? 'koyu RTL' : 'acik LTR'} / x1.3', (tester) async {
            useScreen(tester, size);
            final b = FakeBackend();
            _arm(b, s);
            await tester.pumpWidget(buildApp(_frame(e.value(b), rtl: alt),
                brightness: alt ? Brightness.dark : Brightness.light, size: size));
            await settle(tester);
            final ex = tester.takeException();
            if (ex != null) fail('${e.key}/${s.name}: $ex');
            expect(find.byType(Scaffold), findsWidgets);
            await unmount(tester);
          });
        }
      }
    }
  }

  group('Birim haberleri (Bolumum)', () {
    Map<String, dynamic> u(int id, {String? title}) => {
          'id': id,
          'title': title ?? 'Vize programi $id',
          'summary': 'ozet',
          'publishedDate': '2026-10-28',
          'sourceName': 'Muhendislik Fakultesi',
          'unitName': 'Bilgisayar Muhendisligi',
          'url': 'https://mmf.bingol.edu.tr/d/$id',
          'attachments': [
            {'name': 'program.pdf', 'url': 'https://mmf.bingol.edu.tr/media/1/program.pdf', 'type': 'PDF'},
            {'name': 'kotu.pdf', 'url': 'http://x.invalid/kotu.pdf', 'type': 'PDF'},
          ],
        };

    test('parseUnitNews: bozuk ogeler elenir, liste olmayan bos', () {
      expect(parseUnitNews(null), isEmpty);
      expect(parseUnitNews('x'), isEmpty);
      expect(parseUnitNews({'a': 1}), isEmpty);
      expect(parseUnitNews([u(1), {'title': 'idsiz'}, 'x', {'id': 2, 'title': '  '}, u(3)]).map((e) => e['id']), [1, 3]);
    });

    for (final scenario in ['bos dizi', '401', '500', 'cevrimdisi', 'bozuk govde']) {
      testWidgets('$scenario: serit HICBIR sey cizmez (baslik, bos durum, yer tutucu yok)', (tester) async {
        useScreen(tester, kPhoneMedium);
        final b = FakeBackend();
        switch (scenario) {
          case 'bos dizi':
            b.on('/news/unit', <dynamic>[]);
          case '401':
            b.fail('/news/unit', status: 401, code: 'UNAUTHORIZED');
          case '500':
            b.fail('/news/unit', status: 500);
          case 'cevrimdisi':
            b.network('/news/unit');
          default:
            b.on('/news/unit', 'bozuk');
        }
        await tester.pumpWidget(buildApp(Scaffold(body: UnitNewsStrip(session: makeSession(b))), size: kPhoneMedium));
        await settle(tester);
        expect(find.byType(Text), findsNothing);
        expect(tester.getSize(find.byType(UnitNewsStrip)).height, 0);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('veri varsa baslik + kartlar; dokununca detay; yalniz https ek gosterilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/news/unit', [u(1), u(2, title: 'Ikinci duyuru')])
        ..on('/news/unit/1', {...u(1), 'body': 'Birinci paragraf.\n\nIkinci paragraf.'});
      await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: UnitNewsStrip(session: makeSession(b)))), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Bölümüm'), findsOneWidget);
      expect(find.text('Vize programi 1'), findsOneWidget);
      expect(find.text('Ikinci duyuru'), findsOneWidget);
      await tester.tap(find.text('Vize programi 1'));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Birinci paragraf.'), findsOneWidget);
      expect(find.text('program.pdf'), findsOneWidget);
      expect(find.text('kotu.pdf'), findsNothing); // http eki elenir
      await unmount(tester);
    });

    testWidgets('detay 404: hata gorunumu + yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/news/unit', [u(1)])
        ..fail('/news/unit/1', status: 404, code: 'UNIT_NEWS_NOT_FOUND');
      await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: UnitNewsStrip(session: makeSession(b)))), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.text('Vize programi 1'));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Yeniden dene'), findsWidgets);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('Duyuru sekmesinde serit var, Haber sekmesinde yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/news/unit', [u(1)])
        ..on('/news', {'items': [], 'totalPages': 0})
        ..on('/status', {})
        ..on('/bookmarks/news/ids', {'ids': []});
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(b), initialType: 'DUYURU'), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Vize programi 1'), findsOneWidget);
      await unmount(tester);
      final b2 = FakeBackend()
        ..on('/news/unit', [u(1)])
        ..on('/news', {'items': [], 'totalPages': 0})
        ..on('/status', {})
        ..on('/bookmarks/news/ids', {'ids': []});
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(b2)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Vize programi 1'), findsNothing);
      expect(b2.count('/news/unit'), 0);
      await unmount(tester);
    });
  });

  group('Bildirimler: zaman ve okunmamis filtresi', () {
    Map<String, dynamic> n(int id, DateTime at, {bool read = false}) => {
          'id': id,
          'type': 'NEWS',
          'title': 'Bildirim $id',
          'body': 'govde',
          'read': read,
          'createdAt': at.toUtc().toIso8601String(),
          'data': {'targetType': 'NEWS', 'targetId': '1'},
        };

    testWidgets('okunmamis filtresi + Tumunu okundu yap: satirlar listeden duser, bos mesaj gelir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final now = DateTime.now();
      final b = FakeBackend()
        ..on('/notifications', {
          'items': [n(1, now), n(2, now.subtract(const Duration(minutes: 5)))],
          'nextCursor': null,
          'unreadCount': 2,
        });
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Bildirim 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('notif-seg-unread')));
      await settle(tester);
      expect(find.text('Bildirim 1'), findsOneWidget);
      await tester.tap(find.text('Tümünü okundu yap'));
      await settle(tester);
      expect(b.bodies['POST /notifications/read'], {'all': true, 'scope': 'INFORMATION'});
      expect(find.text('Bildirim 1'), findsNothing);
      expect(find.text('Bildirim 2'), findsNothing);
      await unmount(tester);
    });

    testWidgets('zaman gruplari Istanbul gunune gore: simdi = Bugun, 40 gun once = Daha eski', (tester) async {
      useScreen(tester, kPhoneMedium);
      final now = DateTime.now();
      final b = FakeBackend()
        ..on('/notifications', {
          'items': [n(1, now, read: true), n(2, now.subtract(const Duration(days: 40)), read: true)],
          'nextCursor': null,
          'unreadCount': 0,
        });
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('BUGÜN'), findsOneWidget);
      expect(find.text('DAHA ESKİ'), findsOneWidget);
      await unmount(tester);
    });
  });
}
