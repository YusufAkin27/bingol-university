import 'package:bu_kampus/features/discover/discover_suggestions.dart';
import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// QA-SO: envanter C bulgularının kök neden düzeltmeleri (Ö1, S4, S10, Ö16).

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(20).join('\n')}');
}

void main() {
  setUpAll(loadTestFonts);

  group('Ö1: Ana Sayfa arama kutusu', () {
    testWidgets('süzgeç eylemi yoksa süzgeç ikonu çizilmez (eskiden aramayı açıp yanıltıyordu)', (tester) async {
      useScreen(tester, kPhoneMedium);
      var taps = 0;
      await tester.pumpWidget(buildApp(Scaffold(body: HomeSearchBox(hint: 'Ara', onTap: () => taps++))));
      expect(find.byIcon(BuIcons.slidersHorizontal), findsNothing);
      await tester.tap(find.text('Ara'));
      expect(taps, 1);
      var filters = 0;
      await tester.pumpWidget(buildApp(Scaffold(body: HomeSearchBox(hint: 'Ara', onTap: () => taps++, onFilter: () => filters++))));
      await tester.tap(find.byIcon(BuIcons.slidersHorizontal));
      expect(filters, 1);
      expect(taps, 1, reason: 'süzgeç düğmesi aramayı açmaz');
      noErr(tester);
    });
  });

  group('S4: haber kaydet durumu liste ile detay arasında tutarlı', () {
    testWidgets('API hatasında liste geri alır ve açık detay sayfası da eski duruma döner', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()
        ..on('/news', newsPage([for (var i = 1; i <= 2; i++) newsItem(i, title: 'Kampüs haberi $i')]))
        ..on('/news/1', {'id': 1, 'content': 'Gövde'})
        ..on('/bookmarks/news/ids', {'ids': []})
        ..fail('/bookmarks/news/1', status: 500, code: 'SERVER_ERROR');
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(be)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.textContaining('Kampüs haberi 1'));
      await settle(tester);
      expect(find.byType(NewsDetailPage), findsOneWidget);
      expect(find.byIcon(BuIcons.bookmark), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('news-save')));
      await settle(tester, const Duration(milliseconds: 600));
      // Sunucu reddetti: detaydaki yer imi dolu KALMAZ.
      expect(find.byIcon(BuIcons.bookmarkFilled), findsNothing);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('başarıda detay dolu yer imi gösterir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()
        ..on('/news', newsPage([newsItem(1, title: 'Kampüs haberi 1')]))
        ..on('/news/1', {'id': 1, 'content': 'Gövde'})
        ..on('/bookmarks/news/ids', {'ids': []})
        ..on('/bookmarks/news/1', {});
      await tester.pumpWidget(buildApp(NewsListPage(session: makeSession(be)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.textContaining('Kampüs haberi 1'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('news-save')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byIcon(BuIcons.bookmarkFilled), findsWidgets);
      expect(be.count('PUT /bookmarks/news/1'), 1);
      noErr(tester);
      await unmount(tester);
    });
  });

  group('S10: kulüp anket listesi', () {
    testWidgets('liste boşken genel listeye giden "Tümünü gör" eylemi yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/polls*', {'items': [], 'nextCursor': null});
      await tester.pumpWidget(buildApp(PollListPage(session: makeSession(b), communityId: 5), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Tümünü gör'), findsNothing);
      noErr(tester);
      await unmount(tester);
    });
  });

  group('Ö16: Keşfet öneri kartı', () {
    testWidgets('avatar/ad dokunulabilir: profil açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/users/me/follow-suggestions*', {
          'items': [
            {'id': 7, 'displayName': 'Selin Kaya', 'department': 'Bilgisayar Müh.', 'followState': 'NONE', 'isPrivate': false}
          ]
        })
        ..on('/users/7', {'id': 7, 'displayName': 'Selin Kaya', 'followState': 'NONE'});
      await tester.pumpWidget(buildApp(Scaffold(body: SizedBox(height: 260, child: DiscoverSuggestions(session: makeSession(b))))));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('discover-suggestion-7')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover-suggestion-7')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(UserProfilePage), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });
  });
}
