import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_home_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/forum_placeholder_page.dart';
import 'package:bu_kampus/features/home/home_layout.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_forum.dart';

/// Forum giriş noktaları (MB-A): Keşfet'te "Kampüs Forum" şeridi, Ana Sayfa'da "Kampüste konuşulanlar" kartı.
/// Alt çubuğa 6. sekme EKLENMEZ (bkz. floating_nav_test).

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(20).join('\n')}');
}

void main() {
  setUpAll(loadTestFonts);

  Widget discover(FakeBackend b) => DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null));
  Widget home(FakeBackend b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}));

  group('Kesfet giris seridi', () {
    testWidgets('serit gorunur, dokununca forum ana sayfasi acilir; koyu modda tasma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = FakeBackend();
      fakePosts(b);
      fakeForum(b, count: 5);
      await tester.pumpWidget(buildApp(discover(b), brightness: Brightness.dark));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('forum-entry-strip')), findsOneWidget);
      expect(find.text('Kampüs Forum'), findsOneWidget); // içerik başlığı (şerit)
      noErr(tester);
      await tester.tap(find.byKey(const ValueKey('forum-entry-strip')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(ForumHomePage), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });
  });

  group('Ana Sayfa kampuste konusulanlar', () {
    testWidgets('en cok yorumlanan 3 konu gelir; baslik/Tumu ve satir forum rotalarini acar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      final f = fakeForum(b, count: 9);
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(f.topicQueries.any((q) => q.contains('sort=MOST_COMMENTED') && q.contains('size=3')), isTrue);
      final card = find.byKey(const ValueKey('homeForumTalked'));
      await tester.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Kampüste konuşulanlar'), findsOneWidget);
      final rows = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('home-forum-topic-'));
      expect(rows, findsNWidgets(3));
      await tester.tap(rows.first);
      await settle(tester);
      expect(find.byType(ForumPlaceholderPage), findsOneWidget); // konu detayı
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('forum bos ya da ulasilamaz: bolum tamamen gizlenir (hata karti yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeForum(b, count: 0);
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('homeForumTalked')), findsNothing);
      expect(find.text('Kampüste konuşulanlar'), findsNothing);
      noErr(tester);
      await unmount(tester);

      final b2 = FakeBackend();
      fakeForum(b2, count: 4).failTopics = true;
      await tester.pumpWidget(buildApp(home(b2)));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('homeForumTalked')), findsNothing);
      noErr(tester);
      await unmount(tester);
    });

    test('yerlesim: forum bolumu varsayilan olarak Onerilen kisilerin ardinda ve gorunur', () {
      const d = HomeLayout.defaults;
      expect(d.order.indexOf(HomeSection.forum), d.order.indexOf(HomeSection.suggestions) + 1);
      expect(d.isVisible(HomeSection.forum), isTrue);
      // Eski kayıtlı düzene sonradan eklenir (Önerilenlerin ardına, yoksa sona).
      final old = HomeLayout.fromJson({
        'u': 1,
        'order': ['menu', 'suggestions', 'quickAccess', 'featuredNews', 'todayClasses', 'upcomingEvents', 'announcements'],
        'hidden': <String>[],
        'sOn': ['news'],
      }, 1);
      expect(old.order.indexOf(HomeSection.forum), old.order.indexOf(HomeSection.suggestions) + 1);
    });
  });
}
