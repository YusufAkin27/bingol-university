import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:bu_kampus/features/posts/mention_assist.dart';
import 'package:bu_kampus/features/posts/rich_text.dart';
import 'package:bu_kampus/features/posts/social_models.dart';
import 'package:bu_kampus/features/stories/story_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRichText', () {
    test('duz metin tek parca', () {
      expect(parseRichText('merhaba dunya'), [const RichSpan(RichKind.text, 'merhaba dunya')]);
      expect(parseRichText(''), isEmpty);
    });

    test('anma: @[Ad Soyad](uid:123)', () {
      final s = parseRichText('Selam @[Ali Veli](uid:123) nasilsin');
      expect(s.length, 3);
      expect(s[0].text, 'Selam ');
      expect(s[1], const RichSpan(RichKind.mention, '@Ali Veli', userId: 123));
      expect(s[2].text, ' nasilsin');
    });

    test('turkce harfli ad ve ard arda iki anma', () {
      final s = parseRichText('@[Şule Çağlar](uid:7)@[Öğr Ğ](uid:8)');
      expect(s.map((e) => e.kind), [RichKind.mention, RichKind.mention]);
      expect(s[0].userId, 7);
      expect(s[1].text, '@Öğr Ğ');
    });

    test('etiket: #bahar, turkce harf ve alt cizgi', () {
      final s = parseRichText('Bu #BaharŞenliği_2026 harika');
      expect(s[1], const RichSpan(RichKind.hashtag, '#BaharŞenliği_2026', tag: 'BaharŞenliği_2026'));
    });

    test('yalniz rakamdan olusan #123 etiket sayilmaz', () {
      final s = parseRichText('soru #123 ve #4b');
      expect(s.where((e) => e.kind == RichKind.hashtag).map((e) => e.tag), ['4b']);
      expect(richPlain('soru #123'), 'soru #123');
    });

    test('kelime ortasindaki # ve url parcasi etiket degil', () {
      expect(parseRichText('a#b').every((e) => e.kind == RichKind.text), isTrue);
      expect(parseRichText('https://x.com/a#frag').every((e) => e.kind == RichKind.text), isTrue);
      expect(parseRichText('##cift').where((e) => e.kind == RichKind.hashtag), isEmpty);
    });

    test('bozuk anma bicimi duz metin kalir', () {
      expect(parseRichText('@[Ali](uid:)').every((e) => e.kind == RichKind.text), isTrue);
      expect(parseRichText('@[Ali](id:3)').every((e) => e.kind == RichKind.text), isTrue);
      expect(parseRichText('@Ali').every((e) => e.kind == RichKind.text), isTrue);
    });

    test('anma ve etiket bir arada, satir sonu', () {
      final s = parseRichText('#kampus\n@[A B](uid:1) #bahar');
      expect(s.map((e) => e.kind), [RichKind.hashtag, RichKind.text, RichKind.mention, RichKind.text, RichKind.hashtag]);
    });

    test('richPlain anmayi @Ad yapar, mentionToken geri cevrilebilir', () {
      expect(richPlain('Selam @[Ali Veli](uid:123)!'), 'Selam @Ali Veli!');
      final tok = mentionToken(5, 'Ay[se] Yılmaz');
      final s = parseRichText(tok);
      expect(s.single.kind, RichKind.mention);
      expect(s.single.userId, 5);
    });
  });

  group('findAssistTrigger', () {
    test('@ yazinca tetiklenir', () {
      final t = findAssistTrigger('merhaba @al', 11);
      expect(t, isNotNull);
      expect(t!.char, '@');
      expect(t.query, 'al');
      expect(t.start, 8);
    });

    test('bos @ ve metin basinda', () {
      expect(findAssistTrigger('@', 1)?.query, '');
      expect(findAssistTrigger('@Ali Ve', 7)?.query, 'Ali Ve');
    });

    test('ad soyad icin bir bosluk serbest, iki bosluk degil', () {
      expect(findAssistTrigger('@Ali Veli ', 10), isNull);
      expect(findAssistTrigger('x @Ali V', 8)?.query, 'Ali V');
    });

    test('# tetikler; bosluk iceremez', () {
      expect(findAssistTrigger('yeni #bah', 9)?.query, 'bah');
      expect(findAssistTrigger('yeni #bah x', 11), isNull);
    });

    test('kelime ortasinda ve bicimli anma icinde tetiklenmez', () {
      expect(findAssistTrigger('mail@ali', 8), isNull);
      expect(findAssistTrigger('@[Ali Veli](uid:3)', 18), isNull);
      expect(findAssistTrigger('a@[Al', 5), isNull);
    });

    test('yeni satir tetikleyiciyi keser', () {
      expect(findAssistTrigger('@al\nxyz', 7), isNull);
    });

    test('imlec metnin ortasindaysa o ana kadarki kisim sorgudur', () {
      expect(findAssistTrigger('@alisonra', 4)?.query, 'ali');
    });
  });

  test('applySuggestion tetikleyici araligini degistirir ve imleci dogru koyar', () {
    final t = findAssistTrigger('selam @al sonra', 9)!;
    final r = applySuggestion('selam @al sonra', t, mentionToken(3, 'Ali Veli'));
    expect(r.text, 'selam @[Ali Veli](uid:3)  sonra');
    expect(r.text.substring(0, r.cursor), 'selam @[Ali Veli](uid:3) ');
    final h = findAssistTrigger('yeni #ba', 8)!;
    expect(applySuggestion('yeni #ba', h, '#bahar').text, 'yeni #bahar ');
  });

  group('modeller', () {
    test('StoryGroup sirasi: kendi, gorulmemis, gorulmus', () {
      final all = [
        const StoryGroup(userId: 3, displayName: 'C', hasUnseen: false),
        const StoryGroup(userId: 2, displayName: 'B', hasUnseen: true),
        const StoryGroup(userId: 1, displayName: 'Ben', mine: true),
        const StoryGroup(userId: 4, displayName: 'D', hasUnseen: true),
      ];
      expect(StoryGroup.ordered(all).map((e) => e.userId), [1, 2, 4, 3]);
    });

    test('Story.fromJson turleri ve bos alanlar', () {
      expect(Story.fromJson({'id': 1, 'kind': 'TEXT', 'bodyText': 'a', 'background': '#112233'}).kind, StoryKind.text);
      expect(Story.fromJson({'id': 2, 'kind': 'VIDEO', 'media': {'id': 5, 'kind': 'VIDEO', 'durationMs': 9000}}).media!.durationMs, 9000);
      expect(Story.fromJson(null).id, 0);
      expect(StoryGroup.fromJson({'user': {'id': 9, 'displayName': 'X'}, 'unseen': true}).hasUnseen, isTrue);
      expect(StoryGroup.fromJson({'author': {'id': 9}}, selfId: 9).mine, isTrue);
    });

    test('FollowStats ve TrendingTag', () {
      final s = FollowStats.fromJson({'followerCount': 4, 'followingCount': 2, 'followedByMe': true});
      expect(s.followers, 4);
      expect(s.following, 2);
      expect(s.copyWith(followers: 5).followers, 5);
      expect(TrendingTag.fromJson({'tag': '#bahar', 'postCount': 3}).tag, 'bahar');
      expect(FollowStats.fromJson(null).followers, 0);
    });
  });

  group('StoryPlayer', () {
    StoryPlayer make({int n = 3, VoidCallback? done}) => StoryPlayer(
        durations: List.filled(n, const Duration(seconds: 5)), onFinished: done);

    test('sure dolunca sonrakine gecer, cubuk dolulugu', () {
      final p = make();
      p.tick(const Duration(milliseconds: 2500));
      expect(p.index, 0);
      expect(p.progress, closeTo(.5, .001));
      expect(p.fillOf(0), closeTo(.5, .001));
      expect(p.fillOf(1), 0);
      p.tick(const Duration(milliseconds: 2500));
      expect(p.index, 1);
      expect(p.elapsed, Duration.zero);
      expect(p.fillOf(0), 1);
    });

    test('son hikaye bitince onFinished bir kez cagrilir', () {
      var done = 0;
      final p = make(n: 2, done: () => done++);
      p.tick(const Duration(seconds: 5));
      p.tick(const Duration(seconds: 5));
      expect(p.finished, isTrue);
      expect(done, 1);
      p.tick(const Duration(seconds: 5));
      p.next();
      expect(done, 1);
    });

    test('duraklatinca ilerlemez, surdurunce devam eder', () {
      final p = make();
      p.pause();
      p.tick(const Duration(seconds: 4));
      expect(p.elapsed, Duration.zero);
      p.resume();
      p.tick(const Duration(seconds: 1));
      expect(p.elapsed, const Duration(seconds: 1));
    });

    test('hold (medya yukleniyor) sayaci durdurur', () {
      final p = make();
      p.hold(true);
      p.tick(const Duration(seconds: 3));
      expect(p.elapsed, Duration.zero);
      expect(p.running, isFalse);
      p.hold(false);
      p.tick(const Duration(seconds: 3));
      expect(p.elapsed, const Duration(seconds: 3));
    });

    test('previous: ilk saniyeden sonra basa sarar, once onceki hikayeye doner', () {
      final p = make();
      p.next();
      p.tick(const Duration(seconds: 2));
      p.previous();
      expect(p.index, 1);
      expect(p.elapsed, Duration.zero);
      p.previous();
      expect(p.index, 0);
      p.previous(); // ilkte: yalniz basa sarar
      expect(p.index, 0);
    });

    test('video suresi sonradan bilinir', () {
      final p = StoryPlayer(durations: const [Duration(seconds: 5), Duration(seconds: 5)], index: 1);
      p.setDuration(1, const Duration(seconds: 12));
      expect(p.duration, const Duration(seconds: 12));
      p.tick(const Duration(seconds: 6));
      expect(p.progress, closeTo(.5, .001));
    });

    test('storyDuration: gorsel 5 sn, video suresi en cok 30 sn', () {
      expect(storyDuration(const Story(id: 1, kind: StoryKind.image)), kStoryImageDuration);
      expect(storyDuration(const Story(id: 1, kind: StoryKind.text)), kStoryImageDuration);
      final v = Story.fromJson({'id': 2, 'kind': 'VIDEO', 'media': {'id': 2, 'kind': 'VIDEO', 'durationMs': 12000}});
      expect(storyDuration(v), const Duration(seconds: 12));
      final long = Story.fromJson({'id': 2, 'kind': 'VIDEO', 'media': {'id': 2, 'kind': 'VIDEO', 'durationMs': 90000}});
      expect(storyDuration(long), kStoryMaxVideo);
      expect(storyDuration(const Story(id: 3, kind: StoryKind.video)), kStoryImageDuration);
      expect(storyDuration(const Story(id: 3, kind: StoryKind.video), videoOverride: const Duration(seconds: 7)), const Duration(seconds: 7));
    });

    test('firstUnseenIndex', () {
      expect(firstUnseenIndex([const Story(id: 1, kind: StoryKind.image, seen: true), const Story(id: 2, kind: StoryKind.image)]), 1);
      expect(firstUnseenIndex([const Story(id: 1, kind: StoryKind.image, seen: true)]), 0);
      expect(firstUnseenIndex(const []), 0);
    });
  });
}
