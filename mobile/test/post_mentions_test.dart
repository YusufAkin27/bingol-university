import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart' show ApiError;
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/mention_picker_sheet.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_rich_text.dart';
import 'package:bu_kampus/features/posts/social_models.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

class _Up extends PostMediaUploader {
  _Up(super.session);
  @override
  Future<PostMedia> upload(Uint8List bytes) async => PostMedia.fromJson(samplePostMedia(id: 4242));
}

const _ali = SocialUser(id: 3, displayName: 'Ali Veli', department: 'Bilgisayar Mühendisliği');
const _ayse = SocialUser(id: 4, displayName: 'Ayşe Kaya');
const _can = SocialUser(id: 5, displayName: 'Can Yıldız');

List<SocialUser> _people([int n = 3]) => [
      _ali,
      _ayse,
      _can,
      for (var i = 6; i < 6 + n - 3; i++) SocialUser(id: i, displayName: 'Kisi $i'),
    ];

/// Sayfali sahte takip listesi (imleç = sonraki başlangıç dizini).
FollowingFetcher _fetcher(List<SocialUser> all, {int page = 20, List<String?>? log}) => (cursor) async {
      log?.add(cursor);
      final start = int.tryParse(cursor ?? '0') ?? 0;
      final end = math.min(start + page, all.length);
      return PostPage<SocialUser>(items: all.sublist(start, end), nextCursor: end < all.length ? '$end' : null);
    };

void main() {
  mentionTapTests();
  setUpAll(loadTestFonts);

  group('model ve metin parcalama', () {
    test('Post.mentions: alan yoksa/bozuksa bos, gecerli ogeler okunur', () {
      expect(Post.fromJson(samplePost()).mentions, isEmpty);
      final bad = samplePost()..['mentions'] = 'x';
      expect(Post.fromJson(bad).mentions, isEmpty);
      final p = samplePost()
        ..['mentions'] = [
          {'userId': 3, 'displayName': 'Ali Veli'},
          {'userId': 0, 'displayName': 'Gecersiz'},
          {'userId': 9},
          'x',
          null,
        ];
      final m = Post.fromJson(p).mentions;
      expect(m.map((e) => e.userId), [3]);
      expect(m.single.displayName, 'Ali Veli');
      // copyWith etiketleri korur
      expect(Post.fromJson(p).copyWith(likeCount: 9).mentions, hasLength(1));
    });

    test('splitMentions: yalniz listedeki adlar, en uzun ad once, harf devaminda eslesmez', () {
      const ali = PostMention(userId: 3, displayName: 'Ali');
      const aliCan = PostMention(userId: 4, displayName: 'Ali Can');
      final parts = splitMentions('Merhaba @Ali Can ve @Ali, @Alim degil @Zeynep', [ali, aliCan]);
      expect(parts.map((p) => p.text).join(), 'Merhaba @Ali Can ve @Ali, @Alim degil @Zeynep');
      final ms = parts.where((p) => p.mention != null).toList();
      expect(ms.map((p) => p.text), ['@Ali Can', '@Ali']);
      expect(ms.map((p) => p.mention!.userId), [4, 3]);
    });

    test('splitMentions: etiket yoksa tek parca; ozel karakterli ad kacirilir', () {
      expect(splitMentions('abc', const []), hasLength(1));
      const m = PostMention(userId: 1, displayName: 'A.(B)');
      final parts = splitMentions('x @A.(B)', [m]);
      expect(parts.last.mention, m);
    });

    test('foldForSearch: buyuk/kucuk harf ve Turkce karakter farki yok', () {
      expect(foldForSearch('İsmail ŞAHİN'), foldForSearch('ismail sahin'));
      expect(foldForSearch('Ğülşen Çakır').contains('gulsen'), isTrue);
    });
  });

  group('PostRichText', () {
    testWidgets('etiket marka renginde (kalin degil) ve dokununca profil callback', (tester) async {
      final b = FakeBackend();
      final s = makeSession(b);
      PostMention? tapped;
      await tester.pumpWidget(buildApp(Scaffold(
        body: PostRichText(
          session: s,
          text: 'Selam @Ali Veli nasilsin',
          mentions: const [PostMention(userId: 3, displayName: 'Ali Veli')],
          style: const TextStyle(fontSize: 15),
          onMention: (m) => tapped = m,
        ),
      )));
      final rt = tester.widget<RichText>(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Ali Veli')));
      final spans = <TextSpan>[];
      rt.text.visitChildren((s) {
        if (s is TextSpan && s.recognizer != null) spans.add(s);
        return true;
      });
      expect(spans, hasLength(1));
      expect(spans.single.text, '@Ali Veli');
      expect(spans.single.style?.fontWeight, FontWeight.w400);
      expect(spans.single.style?.color, tester.element(find.byType(PostRichText)).bu.prText);
      (spans.single.recognizer! as TapGestureRecognizer).onTap!();
      expect(tapped?.userId, 3);
      noErr(tester);
    });

    testWidgets('etiket yoksa duz Text; maxLines/ellipsis korunur', (tester) async {
      final s = makeSession(FakeBackend());
      await tester.pumpWidget(buildApp(Scaffold(
        body: SizedBox(
          width: 100,
          child: PostRichText(session: s, text: 'uzun uzun uzun uzun uzun uzun uzun uzun', mentions: const [], style: null, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      )));
      final t = tester.widget<Text>(find.byType(Text));
      expect(t.maxLines, 1);
      expect(t.overflow, TextOverflow.ellipsis);
      noErr(tester);
    });

    testWidgets('PostCard detay: metindeki etiket tiklanabilir span olarak cizilir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final s = makeSession(FakeBackend());
      final p = samplePost(id: 5, text: 'Harika gun @Ali Veli ile')
        ..['mentions'] = [
          {'userId': 3, 'displayName': 'Ali Veli'}
        ];
      await tester.pumpWidget(buildApp(Scaffold(
        body: ListView(children: [PostCard(session: s, post: Post.fromJson(p), detail: true, onChanged: (_) {}, onDeleted: (_) {})]),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('post-text')), findsOneWidget);
      final rt = tester.widget<RichText>(find.descendant(of: find.byKey(const ValueKey('post-text')), matching: find.byType(RichText)).first);
      var recog = 0;
      rt.text.visitChildren((s) {
        if (s is TextSpan && s.recognizer != null) recog++;
        return true;
      });
      expect(recog, 1);
      noErr(tester);
    });
  });

  group('kisi secici', () {
    Future<void> openPicker(WidgetTester tester, FollowingFetcher f,
        {List<SocialUser> selected = const [], int max = 10, void Function(List<SocialUser>?)? onResult}) async {
      useScreen(tester, const Size(390, 844));
      final s = makeSession(FakeBackend());
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final r = await showMentionPicker(c, s, selected: selected, max: max, fetch: f);
                onResult?.call(r);
              },
              child: const Text('ac'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 600));
    }

    testWidgets('takip ettigim kimse yok: "Etiketlemek icin kisileri takip et" bos durumu', (tester) async {
      await openPicker(tester, _fetcher(const []));
      expect(find.byKey(const ValueKey('mentionEmpty')), findsOneWidget);
      expect(find.text('Etiketlemek için kişileri takip et'), findsOneWidget);
      expect(find.byKey(const ValueKey('mentionSearch')), findsNothing);
      noErr(tester);
    });

    testWidgets('liste, arama (Turkce duyarsiz), coklu secim ve Tamam sonucu', (tester) async {
      List<SocialUser>? result;
      await openPicker(tester, _fetcher([_ali, _ayse, _can]), onResult: (r) => result = r);
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('mentionSearch')), matching: find.byType(TextField)), 'ayse');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Ali Veli'), findsNothing);
      expect(find.text('Ayşe Kaya'), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('mentionSearch')), matching: find.byType(TextField)), 'zzz');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('mentionNoMatch')), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('mentionSearch')), matching: find.byType(TextField)), '');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('mention-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mention-5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mentionDone')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(result!.map((e) => e.id), [3, 5]);
      noErr(tester);
    });

    testWidgets('en cok max kisi: dolunca digerleri secilemez, uyari gorunur, secili olan kaldirilabilir', (tester) async {
      List<SocialUser>? result;
      await openPicker(tester, _fetcher(_people(5)), max: 2, onResult: (r) => result = r);
      await tester.tap(find.byKey(const ValueKey('mention-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mention-4')));
      await tester.pump();
      expect(find.byKey(const ValueKey('mentionMax')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mention-5'))); // dolu: etkisiz
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mention-3'))); // kaldir
      await tester.pump();
      expect(find.byKey(const ValueKey('mentionMax')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mention-5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mentionDone')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(result!.map((e) => e.id), [4, 5]);
      noErr(tester);
    });

    testWidgets('imecli sayfalama: arama sirasinda sonraki sayfalar cekilir', (tester) async {
      final log = <String?>[];
      final all = [for (var i = 1; i <= 9; i++) SocialUser(id: 100 + i, displayName: i == 9 ? 'Hedef Kisi' : 'Diger $i')];
      await openPicker(tester, _fetcher(all, page: 3, log: log));
      expect(log, [null]);
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('mentionSearch')), matching: find.byType(TextField)), 'hedef');
      await settle(tester, const Duration(milliseconds: 600));
      expect(log.length, greaterThan(1), reason: 'eslesme yok -> sonraki sayfalar sessizce cekilir');
      expect(find.text('Hedef Kisi'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('hata: yeniden dene', (tester) async {
      var n = 0;
      await openPicker(tester, (c) async {
        if (n++ == 0) throw Exception('x');
        return PostPage<SocialUser>(items: [_ali]);
      });
      expect(find.text('Ali Veli'), findsNothing);
      await tester.tap(find.descendant(of: find.byType(BuErrorState), matching: find.byType(BuButton)).first);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Ali Veli'), findsOneWidget);
      noErr(tester);
    });
  });

  group('gonderi olustur: etiket', () {
    Future<(FakeBackend, FakePosts)> open(WidgetTester tester, {List<SocialUser>? people}) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = fakePosts(b);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        pickPhoto: (_) async => Uint8List.fromList(kFakePng),
        cropPhoto: (c, bytes, spec) async => CropOutcome.cropped(bytes),
        uploader: _Up(s),
        mentionFetch: _fetcher(people ?? [_ali, _ayse, _can]),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
      await settle(tester, const Duration(milliseconds: 300));
      return (b, fp);
    }

    Future<void> pick(WidgetTester tester, List<int> ids) async {
      for (final id in ids) {
        await tester.tap(find.byKey(ValueKey('mention-$id')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('mentionDone')));
      await settle(tester, const Duration(milliseconds: 500));
    }

    String text(WidgetTester tester) => tester.widget<TextField>(find.byKey(const ValueKey('composeText'))).controller!.text;

    testWidgets('"Kisi etiketle": metne @Ad Soyad eklenir, cip gorunur, mentionUserIds gonderilir', (tester) async {
      final (b, _) = await open(tester);
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'Selam');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composeTagButton')));
      await settle(tester, const Duration(milliseconds: 600));
      await pick(tester, [3, 4]);
      expect(text(tester), 'Selam @Ali Veli @Ayşe Kaya ');
      expect(find.byKey(const ValueKey('composeTagChip-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeTagChip-4')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      final body = b.bodies['POST /posts'] as Map;
      expect(body['mentionUserIds'], [3, 4]);
      expect(body['text'], 'Selam @Ali Veli @Ayşe Kaya');
      noErr(tester);
    });

    testWidgets('metinden @Ad silinince cip ve kimlik de duser; etiketsiz govdede mentionUserIds yok', (tester) async {
      final (b, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeTagButton')));
      await settle(tester, const Duration(milliseconds: 600));
      await pick(tester, [3]);
      expect(find.byKey(const ValueKey('composeTagChip-3')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'sadece yazi');
      await tester.pump();
      expect(find.byKey(const ValueKey('composeTagChip-3')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      expect((b.bodies['POST /posts'] as Map).containsKey('mentionUserIds'), isFalse);
      noErr(tester);
    });

    testWidgets('cipin ustune dokunmak etiketi ve metindeki @Ad parcasini kaldirir', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'Merhaba');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composeTagButton')));
      await settle(tester, const Duration(milliseconds: 600));
      await pick(tester, [5]);
      expect(text(tester), 'Merhaba @Can Yıldız ');
      await tester.tap(find.byKey(const ValueKey('composeTagChip-5')));
      await tester.pump();
      expect(find.byKey(const ValueKey('composeTagChip-5')), findsNothing);
      expect(text(tester), 'Merhaba ');
      noErr(tester);
    });

    testWidgets('metinde "@" yazinca secici kendiliginden acilir; secim @ yerine gecer', (tester) async {
      final (b, _) = await open(tester);
      await tester.enterText(find.byKey(const ValueKey('composeText')), '@');
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('mentionDone')), findsOneWidget);
      await pick(tester, [4]);
      expect(text(tester), '@Ayşe Kaya ');
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      expect((b.bodies['POST /posts'] as Map)['mentionUserIds'], [4]);
      noErr(tester);
    });

    testWidgets('"@" ile acilip kimse secilmezse yazilan @ silinir', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'abc ');
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'abc @');
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('mentionDone')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(text(tester), 'abc ');
      noErr(tester);
    });

    testWidgets('e-posta benzeri "a@b" secici acmaz', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'a@');
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('mentionDone')), findsNothing);
      noErr(tester);
    });

    testWidgets('takip ettigim kimse yoksa secici bos durum gosterir', (tester) async {
      await open(tester, people: const []);
      await tester.tap(find.byKey(const ValueKey('composeTagButton')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Etiketlemek için kişileri takip et'), findsOneWidget);
      noErr(tester);
    });
  });

  group('PostApi', () {
    test('create ve update mentionUserIds gonderir; etiketsizde alan yok', () async {
      final b = FakeBackend();
      fakePosts(b);
      final api = PostApi(makeSession(b));
      await api.create(text: 'x', mediaId: 7, mentionUserIds: const [3, 4]);
      expect((b.bodies['POST /posts'] as Map)['mentionUserIds'], [3, 4]);
      await api.create(text: 'y', mediaId: 7);
      expect((b.bodies['POST /posts'] as Map).containsKey('mentionUserIds'), isFalse);
      await api.update(1000, 'z @Ali Veli', mentionUserIds: const [3]);
      expect((b.bodies['PATCH /posts/1000'] as Map)['mentionUserIds'], [3]);
      await api.update(1000, 'z');
      expect((b.bodies['PATCH /posts/1000'] as Map).containsKey('mentionUserIds'), isFalse);
    });

    test('POST_TEXT_TOO_LONG genel cevrilmis mesaja doner', () {
      final e = ApiError(422, 'POST_TEXT_TOO_LONG', '');
      expect(postErrorText(e), isNot(isEmpty));
      expect(postErrorText(e), contains('çok uzun'));
    });
  });
}


void mentionTapTests() {
  testWidgets('akis: ust GestureDetector varken etikete dokunmak profili acar, ust onTap calismaz', (tester) async {
    final s = makeSession(FakeBackend());
    PostMention? tapped;
    var parent = 0;
    await tester.pumpWidget(buildApp(Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => parent++,
          child: PostRichText(
            session: s,
            text: 'Selam @Ali Veli',
            mentions: const [PostMention(userId: 3, displayName: 'Ali Veli')],
            style: const TextStyle(fontSize: 15),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            onMention: (m) => tapped = m,
          ),
        ),
      ),
    )));
    final r = tester.getRect(find.byType(PostRichText));
    await tester.tapAt(Offset(r.right - 6, r.center.dy));
    expect(tapped?.userId, 3);
    expect(parent, 0);
  });
}
