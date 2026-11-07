import 'dart:convert';
import 'dart:typed_data';

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/platform/image_service.dart' show ImageSource;
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/comments/comment_sheet.dart';
import 'package:bu_kampus/features/posts/comments/comments_api.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/like_button.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_comments.dart';

/// Gönderi ayarları: beğeni sayısını gizle, yorumları kapat, sahibi yorum silme.
Map<String, dynamic> _post({
  int id = 91,
  bool mine = false,
  bool hide = false,
  bool off = false,
  int? likes = 4,
  int comments = 2,
}) =>
    {
      ...samplePost(id: id, text: 'Not', media: [samplePostMedia(id: id * 10)], likeCount: likes ?? 0, commentCount: comments, mine: mine, authorId: mine ? 1 : 12),
      'likeCount': likes,
      'hideLikeCount': hide,
      'commentsDisabled': off,
    };

Widget _app(Widget home, {String lang = 'tr', double scale = 1}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: home,
    );

class _FakeUploader extends PostMediaUploader {
  _FakeUploader(super.session);

  @override
  Future<PostMedia> upload(Uint8List bytes) async => PostMedia.fromJson(samplePostMedia(id: 4242));
}

void main() {
  setUpAll(loadTestFonts);

  group('model', () {
    test('alanlar okunur; sayi gizliligi yalniz baskasi icin gecerli; likeCount null guvenli', () {
      final p = Post.fromJson(_post(hide: true, off: true, likes: null));
      expect(p.hideLikeCount, isTrue);
      expect(p.commentsDisabled, isTrue);
      expect(p.likeCount, 0);
      expect(p.likeCountHiddenFor(7), isTrue);
      final mine = Post.fromJson(_post(hide: true, mine: true));
      expect(mine.likeCountHiddenFor(7), isFalse);
      expect(Post.fromJson(_post()).likeCountHiddenFor(7), isFalse);
      expect(Post.fromJson(const {}).hideLikeCount, isFalse);
      expect(LikeResult.fromJson(const {'liked': true}).likeCount, isNull);
    });
  });

  group('beğeni sayisi', () {
    Future<FakeBackend> pump(WidgetTester tester, Map<String, dynamic> json) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      b.handlers.add((req, path) {
        if (path == '/posts/91/like') return FakeResult.json({'liked': req.method == 'PUT'});
        return null;
      });
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Scaffold(body: Center(child: LikeButton(session: s, post: Post.fromJson(json))))));
      await settle(tester, const Duration(milliseconds: 300));
      return b;
    }

    testWidgets('baskasinin gizli gonderisi: sayi yok, kalp calisir, cokme yok', (tester) async {
      final b = await pump(tester, _post(hide: true, likes: null));
      expect(find.byKey(const ValueKey('like-count')), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.byKey(const ValueKey('like-hidden-hint')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests, contains('PUT /posts/91/like'));
      expect(find.byKey(const ValueKey('like-count')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kendi gizli gonderim: sayiyi gorurum + ipucu simgesi', (tester) async {
      await pump(tester, _post(hide: true, mine: true, likes: 12));
      expect(find.text('12'), findsOneWidget);
      expect(find.byKey(const ValueKey('like-hidden-hint')), findsOneWidget);
    });

    testWidgets('gizli degilse sayi normal gorunur', (tester) async {
      await pump(tester, _post(likes: 4));
      expect(find.text('4'), findsOneWidget);
      expect(find.byKey(const ValueKey('like-hidden-hint')), findsNothing);
    });
  });

  group('yorumlar kapali', () {
    testWidgets('detay: onizlemede yazma satiri yerine bilgi; sayac kalir; sheet yazma cubugu yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.add(commentView(1, postId: 91, body: 'Eski yorum'));
      final p = _post(off: true, comments: 1);
      b.on('/posts/91', p);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 91, initial: Post.fromJson(p))));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('commentsDisabledRow')), findsOneWidget);
      expect(find.byKey(const ValueKey('commentsAddRow')), findsNothing);
      expect(find.text('Bu gönderide yorumlar kapalı'), findsOneWidget);
      expect(find.text('Eski yorum'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('post-comments-91')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('commentsDisabledBar')), findsOneWidget);
      expect(find.byKey(const ValueKey('commentInput')), findsNothing);
      expect(find.byKey(const ValueKey('commentReply-1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('403 COMMENTS_DISABLED: bilgi satirina gecer + hata metni', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.failAdd = const FakeResult.json({'code': 'COMMENTS_DISABLED', 'message': 'x'}, status: 403);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Builder(
          builder: (c) => TextButton(
              onPressed: () => showCommentSheet(c, session: s, postId: 91, api: HttpCommentsApi(s)), child: const Text('ac')))));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.enterText(find.byKey(const ValueKey('commentInput')), 'Merhaba');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('commentSend')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('commentsDisabledBar')), findsOneWidget);
      expect(find.byKey(const ValueKey('commentNotice')), findsOneWidget);
      expect(find.text('Bu gönderide yorumlar kapalı'), findsWidgets);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('gonderi sahibi baskasinin yorumunu onayla siler', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.add({...commentView(3, postId: 91, body: 'Baskasinin yorumu'), 'canDelete': true});
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Builder(
          builder: (c) => TextButton(
              onPressed: () => showCommentSheet(c, session: s, postId: 91, commentCount: 1, api: HttpCommentsApi(s)),
              child: const Text('ac')))));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('commentMenu-3')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('commentMenuDelete')));
      await settle(tester, const Duration(milliseconds: 500));
      // Onay iletisimi; iptalde silinmez.
      expect(find.byKey(const ValueKey('commentDeleteDialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentDeleteCancel')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(f.deletes, isEmpty);
      await tester.tap(find.byKey(const ValueKey('commentMenu-3')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('commentMenuDelete')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('commentDeleteConfirm')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(f.deletes, [3]);
      expect(find.text('Baskasinin yorumu'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('sahip menusu', () {
    Future<(FakeBackend, List<Post>)> pumpCard(WidgetTester tester, {bool fail = false}) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final bodies = <Map>[];
      b.handlers.add((req, path) {
        if (path == '/posts/91/settings' && req.method == 'PATCH') {
          bodies.add(jsonDecode(req.body) as Map);
          if (fail) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
          final m = bodies.last;
          return FakeResult.json(_post(mine: true, hide: m['hideLikeCount'] == true, off: m['commentsDisabled'] == true));
        }
        return null;
      });
      final changed = <Post>[];
      Post cur = Post.fromJson(_post(mine: true));
      await tester.pumpWidget(buildApp(StatefulBuilder(
        builder: (c, set) => Scaffold(
          body: SingleChildScrollView(
            child: PostCard(
              session: makeSession(b),
              post: cur,
              onChanged: (p) {
                changed.add(p);
                set(() => cur = p);
              },
              onDeleted: (_) {},
            ),
          ),
        ),
      )));
      await settle(tester, const Duration(milliseconds: 400));
      b.bodies['_list'] = bodies;
      return (b, changed);
    }

    testWidgets('yorumlari kapat: iyimser guncelleme + PATCH govdesi', (tester) async {
      final (b, changed) = await pumpCard(tester);
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Beğeni sayısını gizle'), findsOneWidget);
      expect(find.text('Yorumları kapat'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('post-act-toggleComments')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.requests, contains('PATCH /posts/91/settings'));
      expect((b.bodies['_list'] as List).single, {'commentsDisabled': true});
      expect(changed.first.commentsDisabled, isTrue);
      expect(changed.last.commentsDisabled, isTrue);
      expect(find.text('Yorumlar kapatıldı'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('beğeni sayisini gizle', (tester) async {
      final (_, changed) = await pumpCard(tester);
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('post-act-toggleLikes')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(changed.last.hideLikeCount, isTrue);
      expect(find.byKey(const ValueKey('like-hidden-hint')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('hata: eski duruma doner + hata toast', (tester) async {
      final (_, changed) = await pumpCard(tester, fail: true);
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('post-act-toggleComments')));
      await settle(tester, const Duration(milliseconds: 900));
      expect(changed.first.commentsDisabled, isTrue); // iyimser
      expect(changed.last.commentsDisabled, isFalse); // geri alindi
      expect(find.text('Ayar değiştirilemedi. Tekrar dene.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('paylasim ekrani', () {
    Future<(FakeBackend, FakePosts)> open(WidgetTester tester, {String lang = 'tr', Size size = const Size(390, 844), double scale = 1}) async {
      useScreen(tester, size);
      final b = FakeBackend();
      final fp = fakePosts(b);
      final s = makeSession(b);
      await tester.pumpWidget(_app(
          ComposePostPage(
            session: s,
            uploader: _FakeUploader(s),
            cropPhoto: (c, b, spec) async => CropOutcome.cropped(b),
            pickPhoto: (ImageSource src) async => Uint8List.fromList(kFakePng),
          ),
          lang: lang,
          scale: scale));
      await settle(tester, const Duration(milliseconds: 300));
      return (b, fp);
    }

    testWidgets('gelismis ayarlar: anahtarlar varsayilan kapali, isteğe yansir', (tester) async {
      final (b, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeCamera')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('composeAdvancedToggle')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const ValueKey('composeHideLikes')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('composeAdvancedToggle')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.widget<Switch>(find.byKey(const ValueKey('composeHideLikes'))).value, isFalse);
      expect(tester.widget<Switch>(find.byKey(const ValueKey('composeCommentsOff'))).value, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('composeCommentsOff')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composeHideLikes')));
      await tester.tap(find.byKey(const ValueKey('composeCommentsOff')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 800));
      final body = b.bodies['POST /posts'] as Map;
      expect(body['hideLikeCount'], isTrue);
      expect(body['commentsDisabled'], isTrue);
      expect(body['mediaIds'], [4242]);
    });

    testWidgets('varsayilan: alanlar gonderilmez', (tester) async {
      final (b, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeCamera')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 800));
      final body = b.bodies['POST /posts'] as Map;
      expect(body.containsKey('hideLikeCount'), isFalse);
      expect(body.containsKey('commentsDisabled'), isFalse);
    });

    for (final lang in ['tr', 'ar']) {
      testWidgets('tasma yok: $lang 320dp x1.3', (tester) async {
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
        addTearDown(() => LocaleController.current = null);
        await open(tester, lang: lang, size: const Size(320, 640), scale: 1.3);
        await tester.tap(find.byKey(const ValueKey('composeCamera')));
        await settle(tester, const Duration(milliseconds: 300));
        await tester.scrollUntilVisible(find.byKey(const ValueKey('composeAdvancedToggle')), 200,
          scrollable: find.byType(Scrollable).first);
        await tester.tap(find.byKey(const ValueKey('composeAdvancedToggle')));
        await settle(tester, const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('composeAdvancedBody')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tasma yok: yorum kapali bilgi satiri $lang 320dp x1.3', (tester) async {
        useScreen(tester, const Size(320, 640));
        final b = FakeBackend();
        CommentsFake(b);
        final s = makeSession(b);
        await tester.pumpWidget(_app(
            Builder(
                builder: (c) => TextButton(
                    onPressed: () => showCommentSheet(c, session: s, postId: 91, api: HttpCommentsApi(s), commentsDisabled: true),
                    child: const Text('ac'))),
            lang: lang,
            scale: 1.3));
        await tester.tap(find.text('ac'));
        await settle(tester, const Duration(milliseconds: 700));
        expect(find.byKey(const ValueKey('commentsDisabledBar')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
