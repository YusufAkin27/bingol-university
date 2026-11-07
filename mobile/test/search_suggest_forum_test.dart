import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/user_data.dart';
import 'package:bu_kampus/features/search/recent_searches.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _forumHit(int i) => {
      'type': 'FORUM_TOPIC',
      'targetId': i,
      'title': 'Yurt sorunları $i',
      'snippet': 'Kantin ve yurt hakkında özet',
      'category': 'Barınma',
      'likeCount': 7,
      'date': '2026-10-1$i',
    };

FakeBackend _backend({bool suggest = true}) {
  final b = FakeBackend()
    ..on('/search', {
      'groups': [
        {
          'type': 'FORUM_TOPIC',
          'items': [_forumHit(1), _forumHit(2)],
        },
        {
          'type': 'USER',
          'items': [
            {'type': 'USER', 'targetId': 99, 'title': 'Yinelenen Kisi'}
          ],
        },
      ],
      'nextCursor': null,
    })
    ..on('/users/search', {
      'items': [
        {'id': 7, 'displayName': 'Elif Yıldız', 'department': 'Bilgisayar Mühendisliği', 'classYear': 2}
      ]
    });
  if (suggest) {
    b.on('/search/suggest', {
      'q': 'kam',
      'suggestions': [
        {'type': 'NEWS', 'id': 1, 'text': 'Kampüs haberi'},
        {'type': 'COMMUNITY', 'id': 2, 'text': 'Kampüs Kulübü'},
        {'type': 'USER', 'id': 3, 'text': 'Kamil Aydın'},
      ],
    });
  }
  return b;
}

void main() {
  setUpAll(loadTestFonts);

  Future<void> type(WidgetTester tester, String q, [int ms = 400]) async {
    await tester.enterText(find.byType(TextField).first, q);
    await tester.pump(Duration(milliseconds: ms));
    await settle(tester);
  }

  group('Öneriler', () {
    testWidgets('debounce: hızlı yazımda tek öneri isteği, 2 karakterden azında istek yok', (tester) async {
      final b = _backend();
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'k');
      await tester.pump(const Duration(milliseconds: 400));
      expect(b.count('/search/suggest'), 0);
      await tester.enterText(find.byType(TextField).first, 'ka');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField).first, 'kam');
      await tester.pump(const Duration(milliseconds: 100));
      expect(b.count('/search/suggest'), 0);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(b.count('/search/suggest'), 1);
      expect(find.text('Kampüs haberi'), findsOneWidget);
      expect(find.text('Kamil Aydın'), findsOneWidget);
      // Öneri listesindeyken arama henüz çalışmamıştır.
      expect(b.count('GET /search?'), 0);
    });

    testWidgets('öneriye dokununca arama çalışır ve forum satırı yazarsız çizilir', (tester) async {
      final b = _backend();
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await type(tester, 'kam');
      await tester.tap(find.text('Kampüs Kulübü'));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(b.count('GET /search?'), 1);
      expect(find.text('Yurt sorunları 1'), findsOneWidget);
      expect(find.text('Barınma'), findsWidgets);
      expect(find.text('7'), findsWidgets);
      expect(find.text('Elif Yıldız'), findsOneWidget);
      // /search içindeki USER grubu yinelenmez (kişiler /users/search'ten).
      expect(find.text('Yinelenen Kisi'), findsNothing);
      // Forum satırında yazar alanı yoktur.
      expect(find.textContaining('yazar', findRichText: true), findsNothing);
    });

    testWidgets('öneri ucu hata verirse doğrudan arar', (tester) async {
      final b = _backend(suggest: false)..fail('/search/suggest');
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await type(tester, 'yurt');
      expect(b.count('GET /search?'), 1);
      expect(find.text('Yurt sorunları 1'), findsOneWidget);
    });

    testWidgets('Forum sekmesi limit<=19 ile type=FORUM_TOPIC ister', (tester) async {
      final b = _backend(suggest: false);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await type(tester, 'yurt');
      await tester.ensureVisible(find.text('Forum').first);
      await tester.tap(find.text('Forum').first);
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      final r = b.requests.where((e) => e.contains('type=FORUM_TOPIC')).toList();
      expect(r, isNotEmpty);
      expect(r.first, contains('limit=19'));
    });

    testWidgets('boş sonuç ve hata durumları', (tester) async {
      final b = FakeBackend()
        ..on('/search', {'groups': []})
        ..on('/users/search', {'items': []});
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await type(tester, 'zzzz');
      expect(find.text('Sonuç bulunamadı.'), findsOneWidget);
      final e = _backend(suggest: false)..fail('/search');
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(e)), size: kPhoneMedium));
      await settle(tester);
      await type(tester, 'yurt');
      expect(find.text('Yeniden dene'), findsWidgets);
    });
  });

  group('Son aramalar', () {
    testWidgets('kaydedilir, tek tek silinir, Temizle hepsini siler; sunucuya gönderilmez', (tester) async {
      await RecentSearches.clear();
      final b = _backend(suggest: false);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      await type(tester, 'yurt');
      expect(await RecentSearches.load(), ['yurt']);
      expect(b.requests.where((r) => r.contains('recent')), isEmpty);

      await const FlutterSecureStorage().write(key: RecentSearches.key, value: jsonEncode(['a1', 'b2', 'c3']));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      expect(find.text('b2'), findsOneWidget);
      await tester.tap(find.byTooltip('Aramayı sil').first, warnIfMissed: false);
      await settle(tester);
      expect((await RecentSearches.load()).length, lessThan(3));
      await tester.tap(find.text('Temizle'));
      await settle(tester);
      expect(await RecentSearches.load(), isEmpty);
    });

    test('en çok 10 tutulur ve çıkış temizleyicisine kayıtlıdır', () async {
      await RecentSearches.save([for (var i = 0; i < 15; i++) 'q$i']);
      expect((await RecentSearches.load()).length, 10);
      final api = ApiClient();
      registerUserDataCleaners(api);
      expect(api.onUserDataCleared.contains(RecentSearches.clear), isTrue);
      await RecentSearches.clear();
      expect(await RecentSearches.load(), isEmpty);
    });
  });

  group('Taşma 320 dp', () {
    for (final rtl in [false, true]) {
      testWidgets('öneri + forum sonuçları taşmaz${rtl ? ' (ar/rtl)' : ''}', (tester) async {
        final b = _backend();
        await tester.pumpWidget(buildApp(
            Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: SearchPage(session: makeSession(b))),
            size: kPhoneSmall));
        await settle(tester);
        await type(tester, 'kam');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Kampüs haberi'));
        await tester.pump(const Duration(milliseconds: 100));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
