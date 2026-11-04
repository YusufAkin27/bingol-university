import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/features/search/global_search_screen.dart';
import 'package:bu_kampus/features/search/search_fold.dart';
import 'package:bu_kampus/features/search/user_search_result_tile.dart';
import 'package:bu_kampus/widgets/profile_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(20).join('\n')}');
}

Map<String, dynamic> user(int id, String name, {String? dept, int? year, String? state, bool priv = false, String? avatar}) => {
      'id': id,
      'displayName': name,
      'department': dept,
      'classYear': year,
      'followState': state ?? 'NONE',
      'isPrivate': priv,
      'avatarUrl': avatar,
    };

Map<String, dynamic> postHit(int id, String author, {int likes = 3}) => {
      'type': 'POSTS',
      'targetId': id,
      'title': author,
      'snippet': 'merhaba',
      'imageUrl': null,
      'likeCount': likes,
    };

FakeBackend backend({List<Map<String, dynamic>>? users, List<Map<String, dynamic>>? posts, bool reels = false}) {
  final b = FakeBackend();
  b.on('/users/search*', {'items': users ?? [], 'nextCursor': null});
  b.handlers.add((req, path) {
    if (path != '/search') return null;
    final type = req.url.queryParameters['type'];
    if (type == 'POSTS') {
      return FakeResult.json({
        'groups': [
          {'type': 'POSTS', 'items': posts ?? []}
        ],
        'nextCursor': null
      });
    }
    if (type == 'REELS') {
      return reels
          ? const FakeResult.json({'groups': [], 'nextCursor': null})
          : const FakeResult.json({'code': 'VALIDATION_ERROR', 'message': 'x'}, status: 400);
    }
    return null;
  });
  return b;
}

Widget screen(FakeBackend b, {GlobalSearchTab tab = GlobalSearchTab.all}) =>
    GlobalSearchScreen(session: makeSession(b), initialTab: tab);

Future<void> type(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(const ValueKey('globalSearchField')), q);
  await tester.pump();
}

Future<void> wait(WidgetTester tester, [int ms = 700]) async {
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(loadTestFonts);

  group('katlama + vurgu', () {
    test('searchFold: Turkce karakter ve harf duyarsiz, uzunluk korunur', () {
      expect(searchFold('İSTANBUL Ğüşöç ı'), 'istanbul gusoc i');
      expect(searchFold('Ayşe').length, 4);
      expect(searchFold('ayse'), searchFold('AYŞE'));
    });
  });

  group('genel arama', () {
    testWidgets('baslangic: ipucu + sekmeler, istek yok; 1 karakter aramaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = backend();
      await tester.pumpWidget(buildApp(screen(b)));
      await tester.pump();
      expect(find.text('Tümü'), findsOneWidget);
      expect(find.text('Kullanıcılar'), findsOneWidget);
      expect(find.text('Gönderiler'), findsOneWidget);
      expect(find.text('Reels'), findsOneWidget);
      await type(tester, 'a');
      await wait(tester);
      expect(b.requests.where((r) => r.contains('search')), isEmpty);
      noErr(tester);
    });

    testWidgets('300 ms bekletme: hizli yazim tek istek; kullanici + gonderi bolumleri, reels yoksa sessiz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = backend(users: [user(7, 'Ayşe Demir', dept: 'Bilgisayar Mühendisliği', year: 2)], posts: [postHit(11, 'Ali Veli')]);
      await tester.pumpWidget(buildApp(screen(b)));
      await tester.pump();
      await type(tester, 'ay');
      await tester.pump(const Duration(milliseconds: 150));
      await type(tester, 'ays');
      await tester.pump(const Duration(milliseconds: 150));
      expect(b.requests.where((r) => r.contains('/users/search')), isEmpty);
      await wait(tester);
      final userReqs = b.requests.where((r) => r.contains('/users/search')).toList();
      expect(userReqs.length, 1);
      expect(userReqs.single, contains('q=ays'));
      expect(find.byKey(const ValueKey('user-search-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-post-11')), findsOneWidget);
      expect(find.textContaining('2. sınıf'), findsOneWidget);
      // @kullaniciadi uydurulmaz.
      expect(find.textContaining('@'), findsNothing);
      noErr(tester);
    });

    testWidgets('Reels sekmesi: sunucu turu bilmiyorsa "kullanilamiyor" bilgisi', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = backend();
      await tester.pumpWidget(buildApp(screen(b)));
      await tester.pump();
      await type(tester, 'ay');
      await wait(tester);
      await tester.tap(find.byKey(const ValueKey('global-search-tab-3')));
      await wait(tester, 400);
      expect(find.text('Reels araması şu an kullanılamıyor.'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('sonuc yok: bos durum', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = backend(reels: true);
      await tester.pumpWidget(buildApp(screen(b)));
      await tester.pump();
      await type(tester, 'zzzz');
      await wait(tester);
      expect(find.text('Sonuç bulunamadı.'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('Kullanicilar sekmesi sayfalar (nextCursor) ve cift kaydi eler', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = backend(reels: true);
      b.on('/users/search?q=ay&size=20', {
        'items': [for (var i = 1; i <= 12; i++) user(i, 'Ay Kisi $i')],
        'nextCursor': 20,
      });
      b.on('/users/search?q=ay&size=20&cursor=20', {
        'items': [user(12, 'Ay Kisi 12'), user(13, 'Ay Kisi 13')],
        'nextCursor': null,
      });
      await tester.pumpWidget(buildApp(screen(b, tab: GlobalSearchTab.users)));
      await tester.pump();
      await type(tester, 'ay');
      await wait(tester);
      expect(find.byKey(const ValueKey('user-search-1')), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await wait(tester, 300);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await wait(tester, 300);
      expect(b.requests.where((r) => r.contains('cursor=20')).length, 1);
      expect(find.byKey(const ValueKey('user-search-13')), findsOneWidget);
      // Tekrarlanan kimlik (12) tek satir.
      expect(find.byKey(const ValueKey('user-search-12')), findsOneWidget);
      noErr(tester);
    });

    testWidgets('hata: Yeniden dene yeniden ister', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = backend();
      b.fail('/users/search*', status: 500);
      await tester.pumpWidget(buildApp(screen(b, tab: GlobalSearchTab.users)));
      await tester.pump();
      await type(tester, 'ay');
      await wait(tester, 1200);
      expect(find.text('Yeniden dene'), findsOneWidget);
      b.on('/users/search*', {
        'items': [user(5, 'Ay Kisi')],
        'nextCursor': null
      });
      await tester.tap(find.text('Yeniden dene'));
      await wait(tester, 1200);
      expect(find.byKey(const ValueKey('user-search-5')), findsOneWidget);
      noErr(tester);
    });

    testWidgets('satira dokunma profili acar; avatara uzun basma blur onizleme (fotograf varsa)', (tester) async {
      useScreen(tester, const Size(390, 844));
      ProfilePhotoViewer.providerOverride = (_, __, ___) => MemoryImage(fakePng);
      addTearDown(() => ProfilePhotoViewer.providerOverride = null);
      final b = backend(users: [user(7, 'Ayşe Demir', avatar: '/files/avatars/7.jpg'), user(8, 'Ayhan Kaya')]);
      await tester.pumpWidget(buildApp(screen(b, tab: GlobalSearchTab.users)));
      await tester.pump();
      await type(tester, 'ay');
      await wait(tester);
      await tester.longPress(find.byKey(const ValueKey('user-search-avatar-7')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('profilePhotoViewerBlur')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profilePhotoViewerClose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('profilePhotoViewerBlur')), findsNothing);
      // Uzun basma profili ACMAZ (onizleme kazanir).
      expect(find.byType(UserProfilePage), findsNothing);
      // Fotografi olmayan avatar: onizleme acilmaz; dokunus satira (profil) duser.
      await tester.longPress(find.byKey(const ValueKey('user-search-avatar-8')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('profilePhotoViewerBlur')), findsNothing);
      expect(find.byType(UserProfilePage), findsOneWidget);
      noErr(tester);
    });

    testWidgets('arama gecmisi: gonderimde kaydolur, bos alanda listelenir, silinebilir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = backend(reels: true);
      await tester.pumpWidget(buildApp(screen(b)));
      await tester.pump();
      await type(tester, 'ayse');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await wait(tester);
      await tester.tap(find.byKey(const ValueKey('globalSearchClear')));
      await wait(tester, 400);
      expect(find.text('Son aramalar'), findsOneWidget);
      expect(find.text('ayse'), findsOneWidget);
      await tester.tap(find.byTooltip('Aramayı sil').first);
      await wait(tester, 400);
      expect(find.text('ayse'), findsNothing);
      noErr(tester);
    });

    testWidgets('kendi satirinda takip dugmesi yok; baskasinda var', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = backend(users: [user(1, 'Ayşe Yılmaz'), user(2, 'Ayhan Kaya')], reels: true);
      await tester.pumpWidget(buildApp(screen(b, tab: GlobalSearchTab.users)));
      await tester.pump();
      await type(tester, 'ay');
      await wait(tester);
      expect(find.byKey(const ValueKey('followButton')), findsOneWidget);
      noErr(tester);
    });

    for (final size in [const Size(320, 640), const Size(390, 844)]) {
      for (final dark in [false, true]) {
        testWidgets('tasma yok ${size.width.toInt()} dp x1.3 ${dark ? 'koyu' : 'acik'} + RTL', (tester) async {
          useScreen(tester, size);
          final b = backend(
            users: [user(7, 'عائشة يلماز ' * 4, dept: 'Bilgisayar Mühendisliği ' * 3, year: 2, priv: true), user(8, 'Çok Uzun Bir İsim Soyisim ' * 3, state: 'FOLLOWING')],
            posts: [postHit(11, 'Çok uzun yazar adı ' * 4, likes: 12345), postHit(12, 'B')],
            reels: true,
          );
          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)),
            child: buildApp(
              Directionality(textDirection: TextDirection.rtl, child: screen(b)),
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
          ));
          await tester.pump();
          await type(tester, 'ay');
          await wait(tester);
          expect(find.byType(UserSearchResultTile), findsWidgets);
          noErr(tester);
          await tester.tap(find.byKey(const ValueKey('global-search-tab-2')));
          await wait(tester, 400);
          noErr(tester);
        });
      }
    }
  });
}
