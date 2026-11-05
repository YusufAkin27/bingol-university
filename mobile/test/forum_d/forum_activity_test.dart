import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_activity_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_saved_page.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/forum_profile_section.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/features/profile/profile_menu_page.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_extras.dart';
import '../support/forum_d_harness.dart';

void main() {
  late FakeBackend b;
  late FakeForum f;
  late FakeForumExtras x;

  setUp(() {
    b = FakeBackend();
    f = fakeForum(b, count: 30);
    x = fakeForumExtras(f);
  });

  Future<void> open(WidgetTester tester, Widget page, {RouteLog? log, Brightness brightness = Brightness.light, double scale = 1, Size size = kPhoneMedium}) async {
    useScreen(tester, size);
    await tester.pumpWidget(forumDApp(page, log: log, brightness: brightness, textScale: scale));
    await settle(tester, const Duration(milliseconds: 400));
  }

  // Kaydirilan cip satirinda ekran disindaki cipe once gorunur kilinip dokunulur.
  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.descendant(of: find.byKey(const ValueKey('forum-activity-tabs')), matching: find.text(label));
    await tester.ensureVisible(chip);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(chip);
  }

  group('kaydedilenler', () {
    testWidgets('konu + yorum kayitlari listelenir; konuya dokununca acilir', (tester) async {
      f.saved.addAll([500, 499]);
      x.commentsById[9001] = sampleForumCommentD(id: 9001, topicId: 498, body: 'Kaydettigim yorum');
      x.savedComments.add(9001);
      final log = RouteLog();
      await open(tester, ForumSavedPage(session: makeSession(b)), log: log);
      expect(find.byKey(const ValueKey('forum-topic-500')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-topic-499')), findsOneWidget);
      expect(find.text('Kaydettigim yorum'), findsOneWidget);
      await tester.tap(find.text('Konu başlığı 500'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(log.count('forum_topic'), 1);
    });

    testWidgets('kartta kaydi kaldir: satir iyimser kalkar, DELETE gider; hata olursa geri gelir', (tester) async {
      f.saved.addAll([500, 499]);
      await open(tester, ForumSavedPage(session: makeSession(b)));
      await tester.tap(find.byKey(const ValueKey('forum-save-500')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Konu başlığı 500'), findsNothing);
      expect(b.requests, contains('DELETE /forum/topics/500/bookmark'));

      f.failWrites = true;
      await tester.tap(find.byKey(const ValueKey('forum-save-499')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Konu başlığı 499'), findsOneWidget, reason: 'hata: kayıt satırı geri gelmeli');
      expect(find.text('Kaydetme işlemi yapılamadı'), findsWidgets);
    });

    testWidgets('yorum kaydini kaldirir', (tester) async {
      x.commentsById[9001] = sampleForumCommentD(id: 9001, topicId: 498, body: 'Kaydettigim yorum');
      x.savedComments.add(9001);
      await open(tester, ForumSavedPage(session: makeSession(b)));
      await tester.tap(find.byKey(const ValueKey('forum-saved-remove-COMMENT-9001')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.requests, contains('DELETE /forum/comments/9001/bookmark'));
      expect(find.text('Kaydettigim yorum'), findsNothing);
      expect(find.byKey(const ValueKey('forum-saved-empty')), findsOneWidget);
    });

    testWidgets('bos durum, hata + yeniden dene, sayfalama', (tester) async {
      await open(tester, ForumSavedPage(session: makeSession(b)));
      expect(find.byKey(const ValueKey('forum-saved-empty')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      x.failSaved = true;
      await open(tester, ForumSavedPage(session: makeSession(b)));
      expect(find.byType(BuErrorState), findsOneWidget);
      x.failSaved = false;
      f.saved.addAll([for (var i = 0; i < 20; i++) 500 - i]);
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(BuErrorState), findsNothing);
      expect(b.count('GET /forum/me/saved'), 3); // bos aciliş + hatali aciliş + yeniden dene
      for (var i = 0; i < 4 && b.requests.where((r) => r.contains('cursor=p2')).isEmpty; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
        await settle(tester, const Duration(milliseconds: 400));
      }
      expect(b.requests.any((r) => r.contains('/forum/me/saved') && r.contains('cursor=p2')), isTrue);
    });
  });

  group('faaliyetim', () {
    setUp(() {
      x.myTopics.addAll([
        sampleForumTopic(id: 601, title: 'Acik konum', mine: true),
        sampleForumTopic(id: 602, title: 'Anonim konum', mine: true, anonymous: true),
      ]);
      x.myComments.add(sampleForumCommentD(id: 701, topicId: 600, body: 'Yorumum burada', mine: true));
      x.following.add(sampleForumTopic(id: 603, title: 'Takip ettigim konu'));
    });

    testWidgets('dort sekme: konularim (anonim rozeti), yorumlarim, kaydedilenler, takip ettiklerim; sekmeler tembel yuklenir', (tester) async {
      f.saved.add(500);
      final log = RouteLog();
      await open(tester, ForumActivityPage(session: makeSession(b)), log: log);
      expect(find.byKey(const ValueKey('forum-activity-tabs')), findsOneWidget);
      expect(find.text('Acik konum'), findsOneWidget);
      // Anonim konum: yalnız bende "Anonim" rozeti, kimlik/avatar sızmaz (yazar adı sunucudaki "Anonim #N").
      expect(find.byKey(const ValueKey('forum-anon-badge')), findsOneWidget);
      expect(b.count('GET /forum/me/comments'), 0);

      await tapChip(tester, 'Yorumlarım');
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.count('GET /forum/me/comments'), 1);
      expect(find.text('Yorumum burada'), findsOneWidget);
      await tester.tap(find.text('Yorumum burada'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(log.count('forum_topic'), 1);
      await tester.pageBack();
      await settle(tester, const Duration(milliseconds: 400));

      await tapChip(tester, 'Kaydedilenler');
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Konu başlığı 500'), findsOneWidget);

      await tapChip(tester, 'Takip ettiklerim');
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Takip ettigim konu'), findsOneWidget);
      expectNoException(tester);
    });

    testWidgets('initialTab ilgili sekmeyi dogrudan acar; bos durumlar', (tester) async {
      x.following.clear();
      await open(tester, ForumActivityPage(session: makeSession(b), initialTab: 3));
      expect(find.byKey(const ValueKey('forum-activity-following-empty')), findsOneWidget);
      expect(b.count('GET /forum/me/topics'), 0, reason: 'diger sekmeler yüklenmemeli');
      await tapChip(tester, 'Açtığım konular');
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Acik konum'), findsOneWidget);
    });

    testWidgets('bos konular/yorumlar', (tester) async {
      x.myTopics.clear();
      x.myComments.clear();
      await open(tester, ForumActivityPage(session: makeSession(b)));
      expect(find.byKey(const ValueKey('forum-activity-topics-empty')), findsOneWidget);
      await tapChip(tester, 'Yorumlarım');
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('forum-activity-comments-empty')), findsOneWidget);
    });

    testWidgets('koyu tema + 1.3x yazi: tasma yok (TopicCard 320 dp/1.3x yazida kendi tasmasi var: author_line.dart:125)', (tester) async {
      await open(tester, ForumActivityPage(session: makeSession(b)), brightness: Brightness.dark, scale: 1.3, size: kPhoneMedium);
      expectNoException(tester);
      await tapChip(tester, 'Yorumlarım');
      await settle(tester, const Duration(milliseconds: 400));
      expectNoException(tester);
    });
  });

  group('baskasinin profili', () {
    testWidgets('Forum bolumu: yalniz acik sayilar; satira dokununca herkese acik faaliyet acilir', (tester) async {
      x.summaries[12] = {'topicCount': 3, 'commentCount': 0};
      x.userTopics[12] = [sampleForumTopic(id: 650, title: 'Mehmetin acik konusu')];
      final log = RouteLog();
      await open(tester, Scaffold(body: ForumProfileSection(session: makeSession(b), userId: 12, name: 'Mehmet')), log: log);
      expect(find.byKey(const ValueKey('forum-profile-section')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-profile-topics')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-profile-comments')), findsNothing, reason: 'sayısı 0 olan satır çizilmez');
      await tester.tap(find.byKey(const ValueKey('forum-profile-topics')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(log.count('forum_user_activity'), 1);
      expect(find.text('Mehmetin acik konusu'), findsOneWidget);
      expect(b.requests, contains('GET /forum/users/12/topics?size=15'));
    });

    testWidgets('sayilar 0 ya da ozet alinamazsa bolum hic cizilmez', (tester) async {
      x.summaries[12] = {'topicCount': 0, 'commentCount': 0};
      await open(tester, Scaffold(body: ForumProfileSection(session: makeSession(b), userId: 12)));
      expect(find.byKey(const ValueKey('forum-profile-section')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, Scaffold(body: ForumProfileSection(session: makeSession(b), userId: 99))); // 404
      expect(find.byKey(const ValueKey('forum-profile-section')), findsNothing);
      expectNoException(tester);
    });

    testWidgets('UserProfilePage: acik profilde bolum var; gizli (kilitli) profilde ozet bile istenmez', (tester) async {
      x.summaries[2] = {'topicCount': 2, 'commentCount': 5};
      final base = {'id': 2, 'displayName': 'Mert Kaya', 'department': 'Bilgisayar Mühendisliği', 'followerCount': 12, 'followingCount': 7, 'followsMe': false};
      b.on('/users/2', base);
      useScreen(tester, const Size(390, 1800));
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: const Size(390, 1800)));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('forum-profile-topics')), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-profile-comments')), findsOneWidget);
      await unmount(tester);

      final b2 = FakeBackend();
      final f2 = fakeForum(b2, count: 3);
      final x2 = fakeForumExtras(f2);
      x2.summaries[2] = {'topicCount': 2, 'commentCount': 5};
      b2.on('/users/2', {...base, 'isPrivate': true, 'locked': true, 'followState': 'NONE', 'followerCount': null, 'followingCount': null});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b2), userId: 2), size: const Size(390, 1800)));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('forum-profile-section')), findsNothing);
      expect(b2.requests.where((r) => r.contains('/forum/')), isEmpty, reason: 'gizli hesapta forum uçları çağrılmaz');
      await unmount(tester);
    });
  });

  group('giris noktalari', () {
    testWidgets('profil menusu: Forum satirlari ilgili sekmeyi acar', (tester) async {
      b.on('/me/summary', {'communities': 1, 'events': 1, 'bookmarks': 1});
      b.on('/users/me/follow-requests/count', {'count': 0});
      x.myComments.add(sampleForumCommentD(id: 701, topicId: 600, body: 'Yorumum burada', mine: true));
      final log = RouteLog();
      useScreen(tester, const Size(390, 1400));
      await tester.pumpWidget(forumDApp(ProfileMenuPage(session: makeSession(b), themeController: ThemeController()), log: log));
      await settle(tester, const Duration(milliseconds: 500));
      for (final k in ['menu-forum-topics', 'menu-forum-comments', 'menu-forum-saved', 'menu-forum-following']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      await tester.ensureVisible(find.byKey(const ValueKey('menu-forum-comments')));
      await tester.tap(find.byKey(const ValueKey('menu-forum-comments')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(log.count('forum_activity'), 1);
      expect(b.count('GET /forum/me/comments'), 1);
      expect(b.count('GET /forum/me/topics'), 0);
      expect(find.text('Yorumum burada'), findsOneWidget);
    });

    testWidgets('bildirim ayarlari: Forum satiri tercih sayfasini acar', (tester) async {
      b.handlers.add((req, path) => path == '/notifications/preferences'
          ? const FakeResult.json({'news': true, 'announcements': true, 'events': true, 'messages': true, 'communities': true})
          : null);
      final log = RouteLog();
      useScreen(tester, const Size(390, 1800));
      await tester.pumpWidget(forumDApp(NotificationPrefsPage(session: makeSession(b)), log: log));
      await settle(tester, const Duration(milliseconds: 500));
      final row = find.byKey(const ValueKey('prefs-forum-row'));
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester, const Duration(milliseconds: 500));
      expect(log.count('forum_prefs'), 1);
      expect(b.count('GET /forum/notification-prefs'), 1);
    });
  });
}
