import 'package:bu_kampus/features/forum/data/forum_compose_rules.dart';
import 'package:bu_kampus/features/forum/data/forum_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

void main() {
  group('isBlankText', () {
    test('bosluk ve gorunmez karakter bos sayilir', () {
      expect(isBlankText(''), isTrue);
      expect(isBlankText('   \n\t'), isTrue);
      expect(isBlankText('​  ﻿'), isTrue);
      expect(isBlankText(' a '), isFalse);
    });
  });

  group('PollDraft', () {
    test('en az 2 dolu secenek gerekir', () {
      expect(const PollDraft(options: ['a', '']).isValid, isFalse);
      expect(const PollDraft(options: ['a', '  ']).isValid, isFalse);
      expect(const PollDraft(options: ['a', 'b']).isValid, isTrue);
    });

    test('en cok 6 secenek, secenek basina 80 karakter', () {
      expect(PollDraft(options: List.generate(6, (i) => 'x$i')).isValid, isTrue);
      expect(PollDraft(options: List.generate(7, (i) => 'x$i')).isValid, isFalse);
      expect(PollDraft(options: ['a', 'b' * 81]).isValid, isFalse);
      expect(PollDraft(options: ['a', 'b' * 80]).isValid, isTrue);
    });

    test('bitis 1..30 gun; 0 ve 31 gecersiz', () {
      expect(const PollDraft(options: ['a', 'b'], endsInDays: 30).isValid, isTrue);
      expect(const PollDraft(options: ['a', 'b'], endsInDays: 31).isValid, isFalse);
      expect(const PollDraft(options: ['a', 'b'], endsInDays: 0).isValid, isFalse);
    });

    test('endsAt: gelecekte ve 30 gunu asmaz', () {
      final now = DateTime.utc(2026, 11, 5, 12);
      const p = PollDraft(options: ['a', 'b'], endsInDays: 30);
      final e = p.endsAt(now)!;
      expect(e.isAfter(now), isTrue);
      expect(e.difference(now) < const Duration(days: 30), isTrue);
      expect(const PollDraft(options: ['a', 'b'], endsInDays: 3).endsAt(now), DateTime.utc(2026, 11, 8, 12));
      expect(const PollDraft(options: ['a', 'b']).endsAt(now), isNull);
    });

    test('toRequest: bos soru gonderilmez, bos secenekler atilir', () {
      final r = const PollDraft(question: '  ', options: [' a ', '', 'b'], allowChangeVote: true)
          .toRequest(DateTime.utc(2026, 11, 5));
      expect(r.containsKey('question'), isFalse);
      expect(r['options'], ['a', 'b']);
      expect(r['allowChangeVote'], isTrue);
      expect(r.containsKey('endsAt'), isFalse);
    });

    test('json gidis-donus ve bozuk veriye dayanikli', () {
      const p = PollDraft(question: 'q', options: ['a', 'b', 'c'], endsInDays: 7, allowChangeVote: true);
      final back = PollDraft.fromJson(p.toJson());
      expect(back.question, 'q');
      expect(back.options, ['a', 'b', 'c']);
      expect(back.endsInDays, 7);
      expect(back.allowChangeVote, isTrue);
      final bad = PollDraft.fromJson({'o': <String>[], 'd': 99});
      expect(bad.options.length, 2);
      expect(bad.endsInDays, isNull);
    });
  });

  group('validateCompose', () {
    ComposeIssue v({String t = 'Baslik', String b = 'Aciklama', int? c = 1, PollDraft? p, int busy = 0, int failed = 0}) =>
        validateCompose(title: t, body: b, categoryId: c, poll: p, imagesBusy: busy, imagesFailed: failed);

    test('sirayla ilk eksik alan', () {
      expect(v(), ComposeIssue.none);
      expect(v(t: '  '), ComposeIssue.title);
      expect(v(t: 'a' * 151), ComposeIssue.title);
      expect(v(b: '\n \n'), ComposeIssue.body);
      expect(v(b: 'a' * 10001), ComposeIssue.body);
      expect(v(c: null), ComposeIssue.category);
      expect(v(p: const PollDraft(options: ['a', ''])), ComposeIssue.poll);
      expect(v(busy: 1), ComposeIssue.imagesPending);
      expect(v(failed: 1, busy: 1), ComposeIssue.imageFailed);
    });

    test('sinirda gecerli', () {
      expect(v(t: 'a' * 150, b: 'b' * 10000), ComposeIssue.none);
    });
  });

  group('ForumDraftStore', () {
    setUpAll(mockSecureStorage);

    test('kaydet / yukle / sil, kullanici basina ayri', () async {
      final s = ForumDraftStore();
      const d = ForumDraft(
        title: 'T',
        body: 'B',
        categoryId: 3,
        anonymous: true,
        images: [DraftImage(id: 9, url: '/u', thumbUrl: '/t', width: 10, height: 20)],
        poll: PollDraft(options: ['a', 'b'], endsInDays: 3),
      );
      await s.save(1, d);
      final back = (await s.load(1))!;
      expect(back.title, 'T');
      expect(back.categoryId, 3);
      expect(back.anonymous, isTrue);
      expect(back.images.single.id, 9);
      expect(back.images.single.thumbUrl, '/t');
      expect(back.poll!.endsInDays, 3);
      expect(await s.load(2), isNull);
      await s.clear(1);
      expect(await s.load(1), isNull);
    });

    test('bos taslak yazilmaz, varsa silinir', () async {
      final s = ForumDraftStore();
      await s.save(5, const ForumDraft(title: 'x'));
      expect(await s.load(5), isNotNull);
      await s.save(5, const ForumDraft(title: '  '));
      expect(await s.load(5), isNull);
    });

    test('bozuk kayit null doner', () async {
      final s = ForumDraftStore();
      await s.save(7, const ForumDraft(title: 'x'));
      expect(ForumDraft.fromJson('nope'), isNull);
    });
  });
}
