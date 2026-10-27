import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/follow/follow_button.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/follow/follow_summary.dart';
import 'package:bu_kampus/features/posts/comment_composer.dart';
import 'package:bu_kampus/features/posts/hashtag_posts_page.dart';
import 'package:bu_kampus/features/posts/post_feed_view.dart';
import 'package:bu_kampus/features/posts/rich_text.dart';
import 'package:bu_kampus/features/posts/saved_posts_page.dart';
import 'package:bu_kampus/features/posts/social_models.dart';
import 'package:bu_kampus/features/posts/trending_tags_strip.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/features/stories/story_create_page.dart';
import 'package:bu_kampus/features/stories/story_tray.dart';
import 'package:bu_kampus/features/stories/story_viewer_page.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_social.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(40).join(String.fromCharCode(10))}');
}

Widget discover(FakeBackend b) =>
    DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null));

void main() {
  setUpAll(loadTestFonts);

  group('kaydetme', () {
    testWidgets('kart yer imi dokunusu iyimser gunceller ve PUT/DELETE yollar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakePosts(b, withMedia: false);
      fakeSocial(b);
      await tester.pumpWidget(buildApp(Scaffold(body: PostFeedView(session: makeSession(b)))));
      await settle(tester, const Duration(milliseconds: 500));
      final first = find.byKey(const ValueKey('saveButton')).first;
      await tester.tap(first);
      await settle(tester, const Duration(milliseconds: 300));
      expect(b.requests, contains('PUT /posts/1000/save'));
      expect(f.savedIds, {1000});
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      await tester.tap(first);
      await settle(tester, const Duration(milliseconds: 300));
      expect(b.requests, contains('DELETE /posts/1000/save'));
      expect(f.savedIds, isEmpty);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('hata olursa geri alir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      b.handlers.insert(
          0,
          (req, path) => path == '/posts/1000/save'
              ? const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'Hata'}, status: 500)
              : null);
      await tester.pumpWidget(buildApp(Scaffold(body: PostFeedView(session: makeSession(b)))));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('saveButton')).first);
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.bookmark), findsNothing);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('Kaydedilen gonderiler: liste, yer imi kalkinca satir duser, bos durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakePosts(b, withMedia: false);
      f.savedIds.add(1000);
      await tester.pumpWidget(buildApp(SavedPostsPage(session: makeSession(b))));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Gönderi 1000'), findsOneWidget);
      expect(find.text('Gönderi 999'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('saveButton')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Gönderi 1000'), findsNothing);
      expect(find.textContaining('kaydettiğin bir gönderi yok'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });
  });

  group('metin vurgulari', () {
    testWidgets('anma ve etiket vurgulu; dokununca geri cagrilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      int? mentionId;
      String? tag;
      await tester.pumpWidget(buildApp(Scaffold(
        body: RichPostText(
          'Selam @[Ali Veli](uid:21) #bahar harika',
          style: const TextStyle(fontSize: 15),
          onMention: (id, name) => mentionId = id,
          onTag: (t) => tag = t,
        ),
      )));
      final rt = tester.widget<Text>(find.byType(Text).first);
      final spans = (rt.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.map((s) => s.text), ['Selam ', '@Ali Veli', ' ', '#bahar', ' harika']);
      expect(spans[1].style?.fontWeight, FontWeight.w600);
      (spans[1].recognizer! as dynamic).onTap();
      (spans[3].recognizer! as dynamic).onTap();
      expect(mentionId, 21);
      expect(tag, 'bahar');
      noErr(tester);
    });

    testWidgets('kartta #etiket dokunusu etiket akisini acar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakePosts(b, count: 1, withMedia: false);
      fakeSocial(b)
        ..tagPosts = [samplePost(id: 77, text: 'Etiketli gönderi')]
        ..trending = [];
      f.posts.first['text'] = 'Merhaba #bahar herkese';
      await tester.pumpWidget(buildApp(Scaffold(body: PostFeedView(session: makeSession(b)))));
      await settle(tester, const Duration(milliseconds: 500));
      final text = tester.widget<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.textSpan != null && w.textSpan!.toPlainText(includeSemanticsLabels: false).contains('#bahar')));
      final span = (text.textSpan! as TextSpan).children!.cast<TextSpan>().firstWhere((s) => s.text == '#bahar');
      (span.recognizer! as dynamic).onTap();
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(HashtagPostsPage), findsOneWidget);
      expect(find.text('#bahar'), findsWidgets);
      expect(b.requests.any((r) => r.startsWith('GET /hashtags/bahar/posts')), isTrue);
      expect(find.text('Etiketli gönderi'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('etiket akisi bos durum', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakeSocial(b);
      await tester.pumpWidget(buildApp(HashtagPostsPage(session: makeSession(b), tag: 'yok')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.textContaining('etiketli gönderi yok'), findsOneWidget);
      noErr(tester);
    });
  });

  group('yazarken oneri', () {
    Widget composer(FakeBackend b, TextEditingController c) => Scaffold(
          body: Column(children: [
            const Spacer(),
            CommentComposer(controller: c, focusNode: FocusNode(), onSend: () {}, session: makeSession(b)),
          ]),
        );

    testWidgets('@ yazinca oneriler gelir, secilince @[Ad](uid:N) eklenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeSocial(b);
      final c = TextEditingController();
      await tester.pumpWidget(buildApp(composer(b, c)));
      await tester.enterText(find.byType(TextField), 'Selam @Al');
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.startsWith('GET /users/mention-suggest?q=Al')), isTrue);
      expect(find.byKey(const ValueKey('mention-21')), findsOneWidget);
      expect(find.byKey(const ValueKey('mention-23')), findsNothing); // Mehmet Demir 'Al' icermiyor
      await tester.tap(find.byKey(const ValueKey('mention-21')));
      await tester.pump();
      expect(c.text, 'Selam @[Ali Veli](uid:21) ');
      expect(find.byKey(const ValueKey('assistList')), findsNothing);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('# yazinca etiket onerisi', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakeSocial(b);
      final c = TextEditingController();
      await tester.pumpWidget(buildApp(composer(b, c)));
      await tester.enterText(find.byType(TextField), '#ba');
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('tag-bahar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tag-bahar')));
      await tester.pump();
      expect(c.text, '#bahar ');
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('tetikleyici yoksa liste gorunmez; hata sessiz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/users/mention-suggest');
      final c = TextEditingController();
      await tester.pumpWidget(buildApp(composer(b, c)));
      await tester.enterText(find.byType(TextField), 'sadece metin');
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('assistList')), findsNothing);
      await tester.enterText(find.byType(TextField), 'sadece @ab');
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('assistList')), findsNothing);
      noErr(tester);
      await unmount(tester);
    });
  });

  group('kesfet', () {
    testWidgets('trend etiket seridi gorunur ve dokunulunca akisi acar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      fakeSocial(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(TrendingTagsStrip), findsOneWidget);
      expect(find.text('#bahar'), findsOneWidget);
      await tester.tap(find.text('#bahar'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(HashtagPostsPage), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('kapsam sekmeleri: Yeni/Popüler/Takip/Bölümüm istek parametresi', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      fakeSocial(b).followingFeedEmpty = false;
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      for (final e in const [('Takip', 'following'), ('Bölümüm', 'department'), ('Popüler', 'popular')]) {
        await tester.tap(find.text(e.$1));
        await settle(tester, const Duration(milliseconds: 500));
        expect(b.requests.any((r) => r.contains('/feed') && r.contains('scope=${e.$2}')), isTrue, reason: e.$2);
      }
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('Takip sekmesi bos: aciklama + onerilen kisiler', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakePosts(b, withMedia: false);
      fakeSocial(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Takip'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Takip ettiklerinin gönderileri'), findsOneWidget);
      expect(find.text('Önerilen kişiler'), findsOneWidget);
      expect(find.text('Ali Veli'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('Bölümüm: bölüm yoksa ipucu metni', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakePosts(b, empty: true);
      fakeSocial(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Bölümüm'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Bölümünü profilinden seçersen'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('320/390/430 acik ve koyu cokmez', (tester) async {
      for (final size in kPhoneSizes) {
        for (final br in Brightness.values) {
          useScreen(tester, size);
          final b = FakeBackend();
          fakePosts(b, withMedia: false);
          final s = fakeSocial(b);
          s.tray = [s.group(1, 'Ayşe Yılmaz', mine: true, unseen: false), s.group(21, 'Ali Veli')];
          await tester.pumpWidget(buildApp(discover(b), brightness: br, size: size));
          await settle(tester, const Duration(milliseconds: 600));
          expect(find.byType(StoryTray), findsOneWidget);
          noErr(tester);
          await unmount(tester);
        }
      }
    });
  });

  group('takip', () {
    testWidgets('FollowButton iyimser; hata geri alir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = fakeSocial(b);
      final seen = <bool>[];
      await tester.pumpWidget(buildApp(Scaffold(
          body: Center(child: FollowButton(session: makeSession(b), userId: 21, followed: false, onChanged: seen.add)))));
      expect(find.text('Takip et'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('followButton')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Takipte'), findsOneWidget);
      expect(s.following, {21});
      await tester.tap(find.byKey(const ValueKey('followButton')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Takip et'), findsOneWidget);
      expect(s.following, isEmpty);
      expect(seen, [true, false]);
      b.handlers.insert(
          0,
          (req, path) => path == '/users/21/follow'
              ? const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'Hata'}, status: 500)
              : null);
      await tester.tap(find.byKey(const ValueKey('followButton')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Takip et'), findsOneWidget); // geri alindi
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('FollowSummary: sayilar, takip edince takipci artar, listeye gider', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = fakeSocial(b);
      await tester.pumpWidget(buildApp(Scaffold(body: FollowSummary(session: makeSession(b), userId: 21, name: 'Ali Veli'))));
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.widget<Text>(find.byKey(const ValueKey('followerCount'))).data, '3');
      await tester.tap(find.byKey(const ValueKey('followButton')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(tester.widget<Text>(find.byKey(const ValueKey('followerCount'))).data, '4');
      expect(s.following, {21});
      await tester.tap(find.text('Takipçi'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(FollowListPage), findsOneWidget);
      expect(find.text('Aylin Kaya'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('baskasinin profilinde takip bolumu gorunur (320 dar ekran)', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend()
        ..on('/users/21', {'id': 21, 'displayName': 'Ali Veli', 'department': 'Hemşirelik', 'email': 'a@bingol.edu.tr'});
      fakeSocial(b);
      fakePosts(b, withMedia: false);
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 21)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('followButton')), findsOneWidget);
      expect(find.text('Takipçi'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('kendi profilinde takip dugmesi yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeSocial(b);
      await tester.pumpWidget(buildApp(Scaffold(body: FollowSummary(session: makeSession(b), userId: 1))));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('followerCount')), findsOneWidget);
      expect(find.byKey(const ValueKey('followButton')), findsNothing);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('takipci listesi bos ve hata', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakeSocial(b).users.clear();
      await tester.pumpWidget(buildApp(FollowListPage(session: makeSession(b), userId: 5, followers: false)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.textContaining('kimse takip edilmiyor'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
      final b2 = FakeBackend()..fail('/users/5/followers');
      await tester.pumpWidget(buildApp(FollowListPage(session: makeSession(b2), userId: 5, followers: true)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('hikayeler', () {
    testWidgets('serit: kendi balon + gorulmemis halka; dokununca goruntuleyici acilir ve goruldu gonderilir',
        (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = fakeSocial(b);
      s.stories[21] = [s.story(1, kind: 'TEXT', bodyText: 'Merhaba kampüs', bg: '#9D174D'), s.story(2, kind: 'TEXT', bodyText: 'İkinci')];
      s.tray = [s.group(21, 'Ali Veli')];
      await tester.pumpWidget(buildApp(Scaffold(body: StoryTray(session: makeSession(b)))));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Hikâyen'), findsOneWidget);
      expect(find.text('Ali Veli'), findsOneWidget);
      await tester.tap(find.text('Ali Veli'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(StoryViewerPage), findsOneWidget);
      expect(find.text('Merhaba kampüs'), findsOneWidget);
      expect(s.viewed, [1]);
      noErr(tester);
      await tester.tap(find.byKey(const ValueKey('storyClose')));
      await settle(tester, const Duration(milliseconds: 500));
      await unmount(tester);
    });

    testWidgets('goruntuleyici: 5 sn sonra otomatik ilerler, sagdan dokun ileri, soldan geri', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = fakeSocial(b);
      s.stories[21] = [
        s.story(1, kind: 'TEXT', bodyText: 'Bir'),
        s.story(2, kind: 'TEXT', bodyText: 'Iki'),
        s.story(3, kind: 'TEXT', bodyText: 'Uc'),
      ];
      final session = makeSession(b);
      await tester.pumpWidget(buildApp(StoryViewerPage(
          session: session, groups: const [StoryGroup(userId: 21, displayName: 'Ali Veli', hasUnseen: true)])));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Bir'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 5200));
      expect(find.text('Iki'), findsOneWidget);
      // sag taraf = ileri
      await tester.tapAt(const Offset(350, 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Uc'), findsOneWidget);
      // sol uc bir = geri (ilk saniyeden once)
      await tester.tapAt(const Offset(40, 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Iki'), findsOneWidget);
      expect(s.viewed, containsAll([1, 2, 3]));
      expect(s.viewed.where((e) => e == 2).length, 1); // ayni hikaye iki kez isaretlenmez
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('basili tutunca durur, birakinca devam eder; son hikaye bitince kapanir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = fakeSocial(b);
      s.stories[21] = [s.story(1, kind: 'TEXT', bodyText: 'Tek')];
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute<void>(
                      builder: (_) => StoryViewerPage(
                          session: makeSession(b), groups: const [StoryGroup(userId: 21, displayName: 'Ali')]))),
              child: const Text('ac'),
            ),
          ),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Tek'), findsOneWidget);
      final g = await tester.startGesture(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 700)); // long press
      await tester.pump(const Duration(seconds: 8)); // duraklatildi
      expect(find.text('Tek'), findsOneWidget);
      await g.up();
      await settle(tester, const Duration(seconds: 6));
      expect(find.byType(StoryViewerPage), findsNothing); // bitti, kapandi
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('asagi kaydirinca kapanir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = fakeSocial(b);
      s.stories[21] = [s.story(1, kind: 'TEXT', bodyText: 'Tek')];
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
                c,
                MaterialPageRoute<void>(
                    builder: (_) => StoryViewerPage(
                        session: makeSession(b), groups: const [StoryGroup(userId: 21, displayName: 'Ali')]))),
            child: const Text('ac'),
          ),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.fling(find.byKey(const ValueKey('storyStage')), const Offset(0, 400), 1500);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(StoryViewerPage), findsNothing);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('kendi hikayen: izleyen sayisi, izleyenler listesi, silme', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = fakeSocial(b);
      s.stories[1] = [s.story(9, kind: 'TEXT', bodyText: 'Benim', views: 4)];
      await tester.pumpWidget(buildApp(StoryViewerPage(
          session: makeSession(b), groups: const [StoryGroup(userId: 1, displayName: 'Ayşe', mine: true)])));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('4'), findsOneWidget);
      expect(s.viewed, isEmpty); // kendi hikayeni isaretleme
      await tester.tap(find.byKey(const ValueKey('storyViewers')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.textContaining('Görüntüleyenler (4)'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // sheet kapat
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('storyDelete')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Sil'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(s.deletedStories, [9]);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('yukleme hatasi -> yeniden dene', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend()..fail('/users/21/stories');
      await tester.pumpWidget(buildApp(StoryViewerPage(
          session: makeSession(b), groups: const [StoryGroup(userId: 21, displayName: 'Ali')])));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Yeniden dene'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('serit hatasi: yalniz Hikayen balonu', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakeSocial(b).failTray = true;
      await tester.pumpWidget(buildApp(Scaffold(body: StoryTray(session: makeSession(b)))));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Hikâyen'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('olusturma: metin hikayesi arka plan + paylas', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final s = fakeSocial(b);
      await tester.pumpWidget(buildApp(StoryCreatePage(session: makeSession(b))));
      await tester.tap(find.text('Metin'));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('storyBg-2')));
      await tester.enterText(find.byKey(const ValueKey('storyBody')), 'Günaydın');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('storyShare')));
      await settle(tester, const Duration(milliseconds: 500));
      final body = b.bodies['POST /stories'] as Map;
      expect(body['kind'], 'TEXT');
      expect(body['bodyText'], 'Günaydın');
      expect(body['background'], kStoryBackgrounds[2]);
      expect(s.stories[1], hasLength(1));
      noErr(tester);
    });

    test('video 30 saniyeden uzunsa reddedilir', () {
      MediaPick pick(bool video, int ms) =>
          MediaPick(key: 'k', isVideo: video, durationMs: ms, thumb: (_) async => null);
      expect(storyMediaProblem(pick(true, 31000)), isNotNull);
      expect(storyMediaProblem(pick(true, 30000)), isNull);
      expect(storyMediaProblem(pick(false, 0)), isNull);
    });

    testWidgets('olusturma: bos metinde Paylas kapali', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakeSocial(b);
      await tester.pumpWidget(buildApp(StoryCreatePage(session: makeSession(b))));
      await tester.tap(find.text('Metin'));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('storyShare')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(b.bodies.containsKey('POST /stories'), isFalse);
      noErr(tester);
    });
  });
}

