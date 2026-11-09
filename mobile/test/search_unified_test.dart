import 'package:bu_kampus/features/search/search_fold.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _hit(String type, int id, String title) => {'type': type, 'targetId': id, 'title': title, 'snippet': 'ozet'};

FakeBackend _backend({int posts = 1}) {
  final b = FakeBackend();
  b.on('/users/search*', {'items': [], 'nextCursor': null});
  b.on('/search/suggest*', {'suggestions': []});
  b.handlers.add((req, path) {
    if (path != '/search') return null;
    final type = req.url.queryParameters['type'];
    if (type == 'POSTS') {
      return FakeResult.json({
        'groups': [
          {'type': 'POSTS', 'items': [for (var i = 0; i < posts; i++) _hit('POSTS', 100 + i, 'Gonderi yazari $i')]}
        ],
        'nextCursor': null
      });
    }
    return FakeResult.json({
      'groups': [
        {'type': 'COMMUNITY', 'items': [_hit('COMMUNITY', 3, 'Kampus Kulubu')]},
        {'type': 'POSTS', 'items': [_hit('POSTS', 100, 'Gonderi yazari 0')]},
        {'type': 'FORUM_TOPIC', 'items': [_hit('FORUM_TOPIC', 7, 'Forum konusu')]},
      ],
      'nextCursor': null
    });
  });
  return b;
}

void main() {
  setUpAll(loadTestFonts);

  test('searchFold: Turkce karakter ve harf duyarsiz, uzunluk korunur', () {
    expect(searchFold('İSTANBUL Ğüşöç ı'), 'istanbul gusoc i');
    expect(searchFold('ayse'), searchFold('AYŞE'));
  });

  group('tek arama deneyimi', () {
    testWidgets('Kesfet girisi: Gonderi cipi secili baslar, ilk istek POSTS turunde', (t) async {
      useScreen(t, kPhoneMedium);
      final b = _backend();
      await t.pumpWidget(buildApp(SearchPage(session: makeSession(b), initialTab: SearchTab.post, initialQuery: 'kamp'), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 800));
      expect(b.requests.any((r) => r.contains('/search') && r.contains('type=POSTS')), isTrue);
      expect(find.byKey(const ValueKey('search-hit-POSTS-100')), findsWidgets);
      await unmount(t);
    });

    testWidgets('Tumu sekmesi tum turleri verir: kulup, gonderi, forum ayni sorguda', (t) async {
      useScreen(t, kPhoneMedium);
      final b = _backend();
      await t.pumpWidget(buildApp(SearchPage(session: makeSession(b), initialQuery: 'kamp'), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.text('Kampus Kulubu'), findsWidgets);
      expect(find.byKey(const ValueKey('search-hit-POSTS-100')), findsWidgets);
      expect(find.text('Forum konusu'), findsWidgets);
      await unmount(t);
    });
  });
}
