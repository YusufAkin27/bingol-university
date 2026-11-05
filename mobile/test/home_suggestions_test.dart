import 'dart:convert';

import 'package:bu_kampus/features/follow/follow_suggestions.dart';
import 'package:bu_kampus/features/follow/suggestion_pager.dart';
import 'package:bu_kampus/features/home/home_layout.dart';
import 'package:bu_kampus/features/home/home_suggestions.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// SG-MB: Ana Sayfa "Önerilen kişiler" yatay sayfalı şerit + "Tümünü gör" dikey sayfa + ortak sayfalayıcı.
const _path = '/users/me/follow-suggestions';

/// [n] sıra numarası; kimlik n + 100 (oturum kullanıcısı 1 ve kendini eleme kuralıyla çakışmasın).
Map<String, dynamic> _person(int n, {String? reason, Object? grade, String followState = 'NONE'}) => {
      'id': n + 100,
      'displayName': 'Kişi $n',
      'department': 'Bilgisayar Mühendisliği',
      'followState': followState,
      'isPrivate': false,
      if (reason != null) 'reason': reason,
      if (grade != null) 'classYear': grade,
    };

/// Sunucu `page`/`size` bilir: toplam [total] kişi; ilk sayfa 0.
FakeBackend _paged({int total = 25, bool supportsPage = true, String? reasonFor, Set<int>? failPages}) {
  final b = FakeBackend();
  b.handlers.add((req, path) {
    if (path != _path || req.method != 'GET') return null;
    final size = int.tryParse(req.url.queryParameters['size'] ?? '') ?? 10;
    final page = supportsPage ? (int.tryParse(req.url.queryParameters['page'] ?? '') ?? 0) : 0;
    if (failPages != null && failPages.contains(page)) {
      return const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500);
    }
    final from = page * size;
    final to = (from + size).clamp(0, total);
    return FakeResult.json([
      for (var i = from; i < to; i++) _person(i + 1, reason: i == 0 ? reasonFor : null, grade: i == 0 ? 3 : null),
    ]);
  });
  return b;
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(20).join('\n')}');
}

Widget _strip(FakeBackend b, {VoidCallback? onUnavailable, Object? token}) => Scaffold(
      body: SingleChildScrollView(
        child: HomeSuggestions(session: makeSession(b), onUnavailable: onUnavailable, refreshToken: token),
      ),
    );

void main() {
  setUpAll(loadTestFonts);

  group('SuggestionPager', () {
    test('sayfalar birleşir, tekrar eden kimlikler elenir, size den az gelen sayfa sondur', () async {
      final b = _paged(total: 25);
      final p = SuggestionPager(makeSession(b), pageSize: 10);
      await p.reload();
      expect(p.items.length, 10);
      expect(p.hasMore, isTrue);
      await p.loadMore();
      await p.loadMore();
      expect(p.items.map((e) => e.user.id).toList(), [for (var i = 1; i <= 25; i++) i + 100]);
      expect(p.hasMore, isFalse, reason: '5 kayıt < size: son sayfa');
      final before = b.count(_path);
      await p.loadMore();
      expect(b.count(_path), before, reason: 'son sayfadan sonra istek yok');
      expect(b.requests.where((r) => r.contains('page=1')).length, 1);
      p.dispose();
    });

    test('sunucu page yi bilmiyorsa aynı liste döner: tekilleştirilir, sonsuz döngü olmaz', () async {
      final b = _paged(total: 30, supportsPage: false);
      final p = SuggestionPager(makeSession(b), pageSize: 10);
      await p.reload();
      expect(p.items.length, 10);
      await p.loadMore();
      expect(p.items.length, 10, reason: 'tekrarlar elendi');
      expect(p.hasMore, isFalse, reason: 'yeni kayıt getirmeyen sayfa son sayfa sayılır');
      final n = b.count(_path);
      await p.loadMore();
      await p.loadMore();
      expect(b.count(_path), n);
      p.dispose();
    });

    test('ilk sayfa hatası error, sonraki sayfa hatası moreError olur ve yeniden denenir', () async {
      final fail = <int>{0};
      final b = _paged(total: 25, failPages: fail);
      final p = SuggestionPager(makeSession(b), pageSize: 10);
      await p.reload();
      expect(p.error, isNotNull);
      expect(p.items, isEmpty);
      fail.clear();
      await p.reload();
      expect(p.error, isNull);
      expect(p.items.length, 10);
      fail.add(1);
      await p.loadMore();
      expect(p.moreError, isNotNull);
      expect(p.items.length, 10, reason: 'liste yerinde kalır');
      fail.clear();
      await p.loadMore();
      expect(p.moreError, isNull);
      expect(p.items.length, 20);
      p.dispose();
    });

    test('kendini ve geçersiz kimliği eler', () async {
      final b = FakeBackend()
        ..on(_path, [
          {..._person(1), 'id': 1}, // oturum kullanıcısı (kimlik 1)
          {..._person(2), 'id': 0},
          _person(3),
        ]);
      final p = SuggestionPager(makeSession(b), pageSize: 10);
      await p.reload();
      expect(p.items.map((e) => e.user.id), [103]);
      p.dispose();
    });
  });

  group('Ana Sayfa şeridi', () {
    testWidgets('kartlar: ad, bölüm · sınıf, neden satırı, Takip et; başlık ve Tümünü gör', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 4, reasonFor: '3 ortak arkadaş');
      await tester.pumpWidget(buildApp(_strip(b), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Önerilen kişiler'), findsOneWidget);
      expect(find.byKey(const ValueKey('homeSuggestionsAll')), findsOneWidget);
      expect(find.text('Kişi 1'), findsOneWidget);
      expect(find.textContaining('3. Sınıf'), findsOneWidget);
      expect(find.text('3 ortak arkadaş'), findsOneWidget);
      expect(find.text('Takip Et'), findsWidgets);
      expect(b.requests.where((r) => r.contains('page=0') && r.contains('size=10')).length, 1);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('Takip et: kart Takipte olur, POST gider; hata olursa geri alır ve bildirim çıkar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 3)
        ..on('/users/101/follow', {'following': true, 'followerCount': 5, 'followState': 'FOLLOWING'})
        ..fail('/users/102/follow', status: 500);
      await tester.pumpWidget(buildApp(_strip(b), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('home-suggestion-follow-101')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('POST /users/101/follow'), 1);
      expect(find.descendant(of: find.byKey(const ValueKey('home-suggestion-follow-101')), matching: find.text('Takiptesin')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-suggestion-follow-102')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('POST /users/102/follow'), 1);
      expect(find.descendant(of: find.byKey(const ValueKey('home-suggestion-follow-102')), matching: find.text('Takip Et')), findsOneWidget,
          reason: 'hata: önceki duruma döner');
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('karta dokununca kullanıcı profili açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 3)..on('/users/102', {'id': 102, 'displayName': 'Kişi 2', 'followState': 'NONE'});
      await tester.pumpWidget(buildApp(_strip(b), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.text('Kişi 2'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(UserProfilePage), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('Tümünü gör: tam sayfa açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 3);
      await tester.pumpWidget(buildApp(_strip(b), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('homeSuggestionsAll')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(FollowSuggestionsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('suggestion-row-101')), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('sağa kaydırınca sıradaki sayfa yüklenir (page=1); tekrar yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 25);
      await tester.pumpWidget(buildApp(_strip(b), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.count('page=1'), 0);
      final strip = find.byKey(const ValueKey('homeSuggestionsStrip'));
      await tester.drag(strip, const Offset(-3000, 0));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.count('page=1'), 1);
      await tester.drag(strip, const Offset(-6000, 0));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.count('page=2'), 1);
      await tester.drag(strip, const Offset(-9000, 0));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.count('page=3'), 0, reason: '25 kişi 3 sayfada biter');
      expect(find.text('Kişi 25'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('veri yok: bölüm görünmez ve onUnavailable çağrılır (boş kart yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      var gone = 0;
      final b = FakeBackend()..on(_path, <Object>[]);
      await tester.pumpWidget(buildApp(_strip(b, onUnavailable: () => gone++), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(gone, 1);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('hata: onUnavailable çağrılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      var gone = 0;
      final b = FakeBackend()..fail(_path);
      await tester.pumpWidget(buildApp(_strip(b, onUnavailable: () => gone++), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(gone, 1);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('yüklenirken iskelet; başlık görünür, kişi yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 3)..delay = const Duration(seconds: 2);
      await tester.pumpWidget(buildApp(_strip(b), size: kPhoneMedium));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Önerilen kişiler'), findsOneWidget);
      expect(find.text('Kişi 1'), findsNothing);
      await settle(tester, const Duration(seconds: 3));
      expect(find.text('Kişi 1'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    for (final dark in [false, true]) {
      for (final rtl in [false, true]) {
        testWidgets('320 dp x1.3 ${dark ? 'koyu' : 'açık'} ${rtl ? 'rtl' : 'ltr'}: taşma yok, dokunma >= 44', (tester) async {
          useScreen(tester, kPhoneSmall);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final b = FakeBackend()
            ..on(_path, [
              for (var i = 1; i <= 4; i++)
                {
                  ..._person(i, reason: 'Aynı bölümden çok uzun bir ortak neden metni burada', grade: 2),
                  'displayName': 'Çok uzun bir kullanıcı adı soyadı $i',
                  'department': 'Bilgisayar ve Yazılım Mühendisliği Bölümü',
                }
            ]);
          await tester.pumpWidget(Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: buildApp(_strip(b), brightness: dark ? Brightness.dark : Brightness.light, size: kPhoneSmall),
          ));
          await settle(tester, const Duration(milliseconds: 800));
          noErr(tester);
          final btn = tester.getSize(find.byKey(const ValueKey('home-suggestion-follow-101')));
          expect(btn.height, greaterThanOrEqualTo(44));
          expect(tester.getSize(find.byKey(const ValueKey('homeSuggestionsAll'))).height, greaterThanOrEqualTo(44));
          await unmount(tester);
        });
      }
    }
  });

  group('Tümünü gör sayfası', () {
    testWidgets('dikey liste; satırda Takip et; dokununca profil', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 5, reasonFor: 'Ortak kulüp')
        ..on('/users/101/follow', {'following': true, 'followState': 'FOLLOWING'})
        ..on('/users/103', {'id': 103, 'displayName': 'Kişi 3', 'followState': 'NONE'});
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Önerilen kişiler'), findsNothing); // sayfa başlığı görünmez (sadeleştirme)
      expect(find.text('Ortak kulüp'), findsOneWidget);
      expect(b.requests.where((r) => r.contains('size=20') && r.contains('page=0')).length, 1);
      await tester.tap(find.byKey(const ValueKey('followButton')).first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('POST /users/'), 1);
      await tester.tap(find.text('Kişi 3'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(UserProfilePage), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('kaydırdıkça sayfalanır; son sayfada durur', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 45);
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      final list = find.byKey(const ValueKey('followSuggestionsList'));
      for (var i = 0; i < 6; i++) {
        await tester.drag(list, const Offset(0, -4000));
        await settle(tester, const Duration(milliseconds: 600));
      }
      expect(b.count('page=1'), 1);
      expect(b.count('page=2'), 1);
      expect(b.count('page=3'), 0);
      expect(find.byKey(const ValueKey('suggestion-row-145')), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('eski sunucu (page yok sayılır): yinelenen satır yok, istek döngüsü yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 40, supportsPage: false);
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      final list = find.byKey(const ValueKey('followSuggestionsList'));
      for (var i = 0; i < 4; i++) {
        await tester.drag(list, const Offset(0, -4000));
        await settle(tester, const Duration(milliseconds: 600));
      }
      expect(find.byKey(const ValueKey('suggestion-row-101')).evaluate().length <= 1, isTrue);
      expect(b.count(_path), lessThanOrEqualTo(2));
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('çek-yenile baştan yükler', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 5);
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      final n = b.count(_path);
      await tester.drag(find.byKey(const ValueKey('followSuggestionsList')), const Offset(0, 400));
      await settle(tester, const Duration(seconds: 1));
      expect(b.count(_path), n + 1);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('boş durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on(_path, <Object>[]);
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Şimdilik önerilecek kişi yok.'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('hata: Yeniden dene ile toparlanır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail(_path);
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Bağlantı hatası'), findsOneWidget);
      b.on(_path, [_person(7)]);
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Kişi 7'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('yüklenirken iskelet', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _paged(total: 3)..delay = const Duration(seconds: 2);
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(b)), size: kPhoneMedium));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Kişi 1'), findsNothing);
      await settle(tester, const Duration(seconds: 3));
      expect(find.text('Kişi 1'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });
  });

  group('Ana Sayfa entegrasyonu', () {
    Widget home(FakeBackend b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}));

    testWidgets('veri varsa Günün menüsünden sonra, haberlerden önce; yoksa hiç görünmez', (tester) async {
      useScreen(tester, const Size(390, 2400));
      mockSecureStorage();
      await HomeLayoutStore.clear();
      final b = _paged(total: 4)
        ..on('/menu/today', {
          'date': '2026-01-01',
          'items': ['Mercimek çorbası'],
          'dishes': [
            {'name': 'Mercimek çorbası', 'kcal': 160}
          ],
          'totalKcal': 160,
          'kcalComplete': true,
        });
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('homeSuggestions')), findsOneWidget);
      double y(Finder f) => tester.getTopLeft(f).dy;
      expect(y(find.text('Günün menüsü')), lessThan(y(find.byKey(const ValueKey('homeSuggestions')))));
      expect(y(find.byKey(const ValueKey('homeSuggestions'))), lessThan(y(find.text('Öne çıkan haberler'))));
      noErr(tester);
      await unmount(tester);

      final none = FakeBackend()..on(_path, <Object>[]);
      await tester.pumpWidget(buildApp(home(none)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('homeSuggestions')), findsNothing);
      noErr(tester);
      await unmount(tester);
      await HomeLayoutStore.clear();
    });

    testWidgets('düzen sayfasında kapatılırsa bölüm ve istek yok', (tester) async {
      useScreen(tester, const Size(390, 2400));
      mockSecureStorage();
      await HomeLayoutStore.save(HomeLayout.defaults.setVisible(HomeSection.suggestions, false), 1);
      final b = _paged(total: 4);
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('homeSuggestions')), findsNothing);
      expect(b.count(_path), 0);
      noErr(tester);
      await unmount(tester);
      await HomeLayoutStore.clear();
    });

    testWidgets('eski kayıtlı düzende bilinmeyen bölüm Günün menüsünün ardına eklenir', (tester) async {
      final v = HomeLayout.fromJson(jsonDecode(jsonEncode({
        'u': 1,
        'order': ['menu', 'quickAccess', 'featuredNews', 'campusMap', 'todayClasses', 'upcomingEvents', 'announcements'],
        'hidden': <String>[],
        'sOn': ['news'],
      })), 1);
      expect(v.order.indexOf(HomeSection.suggestions), v.order.indexOf(HomeSection.menu) + 1);
      expect(v.isVisible(HomeSection.suggestions), isTrue);
    });
  });
}
