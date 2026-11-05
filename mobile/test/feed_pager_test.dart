import 'package:bu_kampus/features/posts/feed_pager.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Keşfet "bitmeyen" sayfalayıcı: imleç zinciri, zincir bitince yeni tohum, exhausted kesintisiz, tekilleştirme.

Map<String, dynamic> p(int id) => samplePost(id: id, text: 'G $id');

void main() {
  group('FeedPager', () {
    test('imlec zinciri sirayla; bitince imlecsiz yeni oturum; ayni gonderi ikinci kez gelmez', () async {
      final b = FakeBackend();
      final seen = <String?>[];
      b.handlers.add((req, path) {
        if (path != '/feed') return null;
        final c = req.url.queryParameters['cursor'];
        seen.add(c);
        if (c == null) {
          return seen.length == 1
              ? FakeResult.json({'items': [p(1), p(2)], 'nextCursor': 'c2'})
              : FakeResult.json({'items': [p(3), p(1)], 'nextCursor': null, 'exhausted': true}); // yeni oturum: 1 tekrar
        }
        return FakeResult.json({'items': [p(2), p(4)], 'nextCursor': null});
      });
      final pager = FeedPager(PostApi(makeSession(b)), size: 12);
      final have = <int>{};
      var c = await pager.next(have);
      expect([for (final e in c.items) e.id], [1, 2]);
      have.addAll([1, 2]);
      c = await pager.next(have);
      expect([for (final e in c.items) e.id], [4]); // c2 sayfasindan 2 elendi
      have.add(4);
      expect(pager.renew, isTrue); // zincir bitti
      c = await pager.next(have);
      expect([for (final e in c.items) e.id], [3]); // imlecsiz yeni oturum; 1 tekrari elendi
      expect(c.exhausted, isTrue);
      expect(seen, [null, 'c2', null]);
      expect(pager.ended, isFalse);
    });

    test('yalniz tekrardan olusan sayfalar: en cok 3 denemeden sonra ended (sonsuz dongu yok)', () async {
      final b = FakeBackend();
      var calls = 0;
      b.handlers.add((req, path) {
        if (path != '/feed') return null;
        calls++;
        return FakeResult.json({'items': [p(1), p(2)], 'nextCursor': null, 'exhausted': true});
      });
      final pager = FeedPager(PostApi(makeSession(b)));
      final first = await pager.next(const {});
      expect(first.items.length, 2);
      final more = await pager.next({1, 2});
      expect(more.items, isEmpty);
      expect(pager.ended, isTrue);
      expect(calls, 1 + 3);
      pager.reset();
      expect(pager.ended, isFalse);
    });

    test('bos imlecsiz sayfa: hemen ended', () async {
      final b = FakeBackend();
      b.on('/feed*', {'items': <Object>[], 'nextCursor': null});
      final pager = FeedPager(PostApi(makeSession(b)));
      final c = await pager.next(const {});
      expect(c.items, isEmpty);
      expect(pager.ended, isTrue);
    });

    test('POST_CURSOR_INVALID: imlecsiz surdurur, hata sizmaz', () async {
      final b = FakeBackend();
      b.handlers.add((req, path) {
        if (path != '/feed') return null;
        return req.url.queryParameters['cursor'] == null
            ? FakeResult.json({'items': [p(5)], 'nextCursor': null})
            : const FakeResult.json({'code': 'POST_CURSOR_INVALID', 'message': 'x'}, status: 400);
      });
      final pager = FeedPager(PostApi(makeSession(b)), cursor: 'bad', renew: false);
      final c = await pager.next(const {});
      expect([for (final e in c.items) e.id], [5]);
    });

    test('sunucu hatasi cagirana yansir (kullanici Yeniden dene gorur)', () async {
      final b = FakeBackend();
      b.fail('/feed*');
      final pager = FeedPager(PostApi(makeSession(b)));
      await expectLater(pager.next(const {}), throwsA(anything));
    });
  });
}
