import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/forum/forum_routes.dart';
import 'package:bu_kampus/features/share/share_button.dart';
import 'package:bu_kampus/features/share/share_card.dart';
import 'package:bu_kampus/features/share/share_links.dart';
import 'package:bu_kampus/features/share/share_models.dart';
import 'package:bu_kampus/features/share/share_open.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_extras.dart';
import '../support/forum_d_harness.dart';

void main() {
  group('baglanti cozumleme', () {
    test('https/http/ozel sema: /s/f/{id} konu, /s/fc/{id} yorum', () {
      expect(parseShareLink('https://bukampus.com.tr/s/f/12'), const ShareTarget(ShareType.forumTopic, 12));
      expect(parseShareLink('https://www.bukampus.com.tr/s/fc/9/'), const ShareTarget(ShareType.forumComment, 9));
      expect(parseShareLink('bukampus://s/f/5'), const ShareTarget(ShareType.forumTopic, 5));
      expect(parseShareLink('bukampus:///s/fc/7'), const ShareTarget(ShareType.forumComment, 7));
      expect(parseShareLink(Uri.parse('https://bukampus.com.tr/s/f/3?utm=x#a')), const ShareTarget(ShareType.forumTopic, 3));
    });

    test('bozuk bagliklar null: bilinmeyen kod, sifir/negatif/dev kimlik, baska alan adi', () {
      expect(parseShareLink('https://bukampus.com.tr/s/ff/5'), isNull);
      expect(parseShareLink('https://bukampus.com.tr/s/f/0'), isNull);
      expect(parseShareLink('https://bukampus.com.tr/s/f/-4'), isNull);
      expect(parseShareLink('https://bukampus.com.tr/s/f/99999999999999999'), isNull);
      expect(parseShareLink('https://example.com/s/f/5'), isNull);
      expect(parseShareLink('https://bukampus.com.tr/s/f'), isNull);
    });

    test('hedef URL ve mevcut turler bozulmadi', () {
      expect(const ShareTarget(ShareType.forumTopic, 12).url, 'https://bukampus.com.tr/s/f/12');
      expect(const ShareTarget(ShareType.forumComment, 9).url, 'https://bukampus.com.tr/s/fc/9');
      expect(const ShareTarget(ShareType.post, 12).url, 'https://bukampus.com.tr/s/p/12');
      expect(ShareType.fromApi('forum_topic'), ShareType.forumTopic);
      expect(ShareType.fromApi('FORUM_COMMENT'), ShareType.forumComment);
      expect(ShareType.fromCode('fc'), ShareType.forumComment);
      expect(ShareType.fromCode('f'), ShareType.forumTopic);
    });

    test('ShareLinks: derin baglanti bekleyen hedef olur', () {
      final l = ShareLinks.instance..reset();
      l.ingest(Uri.parse('https://bukampus.com.tr/s/f/77'));
      expect(l.take(), const ShareTarget(ShareType.forumTopic, 77));
      l.reset();
    });

    test('mesajdaki share yuku: kategori + baslik + (anonim degilse) yazar; eksik kimlik null', () {
      final i = ShareInfo.fromMessage({
        'share': {'type': 'FORUM_TOPIC', 'id': 12, 'title': 'Kantin fiyatları', 'subtitle': 'Mehmet Kaya', 'categoryName': 'Yemekhane', 'available': true},
      })!;
      expect(i.type, ShareType.forumTopic);
      expect(i.category, 'Yemekhane');
      expect(i.subtitle, 'Mehmet Kaya');
      expect(ShareInfo.fromMessage({'share': {'type': 'FORUM_COMMENT', 'id': 0}}), isNull);
      expect(ShareInfo.fromMessage({'share': {'type': 'POST', 'id': 4}})!.category, isNull);
    });
  });

  group('paylasim icerigi', () {
    final session = makeSession(FakeBackend());

    test('konu: baslik + kategori (+ yazar); anonim konuda yazar adi ASLA eklenmez', () {
      final open = TopicSummaryFixture.of(sampleForumTopic(id: 5, title: 'Kantin', categoryName: 'Yemekhane', authorName: 'Mehmet Kaya'));
      final c = shareContentForTopic(session, open);
      expect((c.type, c.id, c.title, c.source), (ShareType.forumTopic, 5, 'Kantin', 'Yemekhane · Mehmet Kaya'));
      expect(c.restricted, isFalse);
      expect(c.url, 'https://bukampus.com.tr/s/f/5');
      expect(c.externalText(), 'Kantin\nhttps://bukampus.com.tr/s/f/5');

      final anon = TopicSummaryFixture.of(sampleForumTopic(id: 6, title: 'Gizli', categoryName: 'Yurtlar', anonymous: true));
      final a = shareContentForTopic(session, anon);
      expect(a.source, 'Yurtlar');
      expect('${a.source}${a.title}'.contains('Anonim'), isFalse, reason: 'anonim etiketi de paylaşım metnine karışmaz');
    });

    test('yorum: metnin basi + konu basligi', () {
      final c = shareContentForComment(session, ForumComment(id: 9, topicId: 5, body: '   Çok  uzun ${'yorum ' * 40}'), topicTitle: 'Kantin');
      expect(c.type, ShareType.forumComment);
      expect(c.id, 9);
      expect(c.source, 'Kantin');
      expect(c.title!.runes.length, lessThanOrEqualTo(120));
      expect(c.title!.startsWith('Çok uzun yorum'), isTrue);
      expect(c.url, 'https://bukampus.com.tr/s/fc/9');
      final noBody = shareContentForComment(session, const ForumComment(id: 10, topicId: 5), topicTitle: 'Kantin');
      expect(noBody.title, 'Kantin');
    });
  });

  group('kart + acma', () {
    late FakeBackend b;
    late FakeForum f;
    late FakeForumExtras x;
    late RouteLog log;

    setUp(() {
      b = FakeBackend();
      f = fakeForum(b, count: 3);
      x = fakeForumExtras(f);
      log = RouteLog();
    });

    Future<void> mount(WidgetTester tester, Widget home, {Brightness brightness = Brightness.light, double scale = 1}) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [log],
        theme: BuTheme.light(),
        darkTheme: BuTheme.dark(),
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: w!),
        home: home,
      ));
      await settle(tester, const Duration(milliseconds: 300));
    }

    testWidgets('forum karti: ustte kategori adi, baslik, yazar; anonimde yazar satiri yok', (tester) async {
      await mount(
        tester,
        const Scaffold(
          body: Column(children: [
            ShareCard(
              info: ShareInfo(type: ShareType.forumTopic, id: 12, title: 'Kantin fiyatları', subtitle: 'Mehmet Kaya', category: 'Yemekhane'),
              mine: false,
              width: 260,
            ),
            SizedBox(height: 12),
            ShareCard(info: ShareInfo(type: ShareType.forumTopic, id: 13, title: 'Gizli konu', category: 'Yurtlar'), mine: true, width: 260),
          ]),
        ),
      );
      expect(find.text('YEMEKHANE'), findsOneWidget);
      expect(find.text('Kantin fiyatları'), findsOneWidget);
      expect(find.text('Mehmet Kaya'), findsOneWidget);
      expect(find.text('YURTLAR'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-card-source')), findsOneWidget, reason: 'yalnız yazarlı kartta alt satır var');
      expectNoException(tester);
    });

    testWidgets('kategori yoksa tur etiketi "Forum"; kullanilamayan icerik yer tutucu; koyu tema + buyuk yazi', (tester) async {
      await mount(
        tester,
        const Scaffold(
          body: Column(children: [
            ShareCard(info: ShareInfo(type: ShareType.forumComment, id: 9, title: 'Yorum metni'), mine: false, width: 220),
            ShareCard(info: ShareInfo(type: ShareType.forumTopic, id: 9, available: false), mine: false, width: 220),
          ]),
        ),
        brightness: Brightness.dark,
        scale: 1.6,
      );
      expect(find.text('FORUM YORUMU'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-card-unavailable')), findsOneWidget);
      expectNoException(tester);
    });

    testWidgets('sohbet listesi onizlemesi', (tester) async {
      late String? topic, comment;
      await mount(
        tester,
        Builder(builder: (ctx) {
          topic = sharePreviewText(ctx, {'text': 'https://bukampus.com.tr/s/f/4'});
          comment = sharePreviewText(ctx, {'share': {'type': 'FORUM_COMMENT', 'id': 4}});
          return const Scaffold();
        }),
      );
      expect(topic, 'Forum konusu paylaştı');
      expect(comment, 'Forum yorumu paylaştı');
    });

    testWidgets('openShared: konu dogrudan acilir', (tester) async {
      late BuildContext ctx;
      await mount(tester, Builder(builder: (c) {
        ctx = c;
        return const Scaffold();
      }));
      openShared(ctx, makeSession(b), const ShareTarget(ShareType.forumTopic, 500));
      await settle(tester, const Duration(milliseconds: 400));
      expect(log.count('forum_topic'), 1);
    });

    testWidgets('openShared: yorum baglantisi konuyu GET /forum/comments/{id} ile cozer', (tester) async {
      x.commentsById[55] = sampleForumCommentD(id: 55, topicId: 500);
      late BuildContext ctx;
      await mount(tester, Builder(builder: (c) {
        ctx = c;
        return const Scaffold();
      }));
      openShared(ctx, makeSession(b), const ShareTarget(ShareType.forumComment, 55));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests, contains('GET /forum/comments/55'));
      expect(log.count('forum_topic'), 1);
    });

    testWidgets('openShared: silinmis yorum -> "Icerik bulunamadi" bildirimi, cokme yok', (tester) async {
      late BuildContext ctx;
      await mount(tester, Builder(builder: (c) {
        ctx = c;
        return const Scaffold();
      }));
      openShared(ctx, makeSession(b), const ShareTarget(ShareType.forumComment, 999));
      await settle(tester, const Duration(milliseconds: 600));
      expect(log.count('forum_topic'), 0);
      expect(find.text('İçerik bulunamadı'), findsOneWidget);
      expectNoException(tester);
    });

    testWidgets('ShareLinkHost: derin baglanti (soguk/sicak) konuyu acar', (tester) async {
      final links = ShareLinks.instance..reset();
      final s = makeSession(b);
      PushRouter.session = s;
      await mount(tester, ShareLinkHost(session: s, links: links, child: const Scaffold()));
      links.ingest(Uri.parse('https://bukampus.com.tr/s/f/500'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(log.count('forum_topic'), 1);
      links.reset();
    });

    testWidgets('konu paylas: sohbete FORUM_TOPIC karti gider', (tester) async {
      b.on('/conversations?size=50', {
        'items': [
          {'id': 1, 'type': 'DIRECT', 'peer': {'id': 101, 'displayName': 'Ali Veli'}, 'blocked': false, 'closed': false},
        ],
        'nextCursor': null,
      });
      final s = makeSession(b);
      final topic = TopicSummaryFixture.of(sampleForumTopic(id: 500, title: 'Kantin', categoryName: 'Yemekhane'));
      await mount(
        tester,
        Builder(builder: (c) => Scaffold(body: TextButton(key: const ValueKey('go'), onPressed: () => openTopicShare(c, s, topic), child: const Text('paylaş')))),
      );
      await tester.tap(find.byKey(const ValueKey('go')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('share-pick-c1')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('share-send')));
      await settle(tester, const Duration(milliseconds: 800));
      final m = b.bodies['POST /conversations/1/messages'] as Map;
      expect(m['share'], {'type': 'FORUM_TOPIC', 'id': 500});
      expectNoException(tester);
    });
  });
}

/// Sozlesme JSON'undan TopicSummary uretir (testte kisa yol).
abstract final class TopicSummaryFixture {
  static TopicSummary of(Map<String, dynamic> json) => TopicSummary.fromJson(json);
}
