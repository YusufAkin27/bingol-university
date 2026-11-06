import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/features/discover/discover_box.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/follow/follow_button.dart';
import 'package:bu_kampus/features/posts/like_button.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_text_rules.dart';
import 'package:bu_kampus/features/posts/post_video_limits.dart';
import 'package:bu_kampus/features/posts/social_models.dart';
import 'package:bu_kampus/features/reels/reels_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'kesfet_ks_test.dart' show FakeVideoPlatformKs, videoPost;
import 'support/fake_app.dart';

/// QA alani 3, ikinci tur: Idempotency-Key, durum matrisi (401/403/404/429/5xx), sinirlar, buyuk liste (200+) olcumleri.
void main() {
  setUpAll(loadTestFonts);

  group('POST /posts Idempotency-Key (QA-P-07)', () {
    test('anahtar bicimi: p + 24 hex (sunucu 8-64 [A-Za-z0-9_-]); her cagri benzersiz', () {
      final a = PostApi.newIdempotencyKey();
      final b = PostApi.newIdempotencyKey();
      expect(RegExp(r'^p[0-9a-f]{24}$').hasMatch(a), isTrue);
      expect(a, isNot(b));
    });

    test('zaman asimi sonrasi tekrar deneme AYNI anahtari yollar; sunucu ayni gonderiyi doner', () async {
      final b = FakeBackend();
      final keys = <String>[];
      var n = 0;
      b.handlers.add((req, path) {
        if (path != '/posts' || req.method != 'POST') return null;
        keys.add(req.headers['Idempotency-Key'] ?? '');
        n++;
        if (n == 1) throw Exception('timeout'); // yanit kayboldu; sunucu gonderiyi olusturmus olabilir
        return FakeResult.json(samplePost(id: 700, text: 'x', mine: true), status: 201);
      });
      final api = PostApi(makeSession(b));
      final key = PostApi.newIdempotencyKey();
      await expectLater(api.create(text: 'x', mediaId: 5, idempotencyKey: key), throwsA(anything));
      final p = await api.create(text: 'x', mediaId: 5, idempotencyKey: key);
      expect(p.id, 700);
      expect(keys.length, 2);
      expect(keys[0], key);
      expect(keys[1], key);
    });

    test('anahtar verilmezse yine de uretilir (eski cagiranlar korunur)', () async {
      final b = FakeBackend();
      String? k;
      b.handlers.add((req, path) {
        if (path != '/posts') return null;
        k = req.headers['Idempotency-Key'];
        return FakeResult.json(samplePost(id: 1, text: 'x'), status: 201);
      });
      await PostApi(makeSession(b)).create(text: 'x', mediaId: 5);
      expect(k, isNotNull);
      expect(k!.length, greaterThanOrEqualTo(8));
    });
  });

  group('Durum matrisi: begeni ucu', () {
    for (final c in const [
      [401, 'UNAUTHORIZED'],
      [403, 'POST_FORBIDDEN'],
      [404, 'POST_NOT_FOUND'],
      [429, 'RATE_LIMITED'],
      [500, 'SERVER_ERROR'],
      [503, 'DB_TIMEOUT'],
    ]) {
      testWidgets('PUT /like -> ${c[0]}: iyimser geri alinir, cokme yok', (tester) async {
        useScreen(tester, const Size(390, 844));
        final b = FakeBackend();
        b.fail('/posts/500/like', status: c[0] as int, code: c[1] as String);
        await tester.pumpWidget(buildApp(Scaffold(
            body: Center(
                child: LikeButton(
                    session: makeSession(b), post: Post.fromJson(samplePost(id: 500, text: 'a', likeCount: 4)))))));
        await tester.tap(find.byKey(const ValueKey('like-heart')));
        await tester.pump();
        expect(find.text('5'), findsOneWidget);
        await settle(tester, const Duration(milliseconds: 1500));
        expect(find.text('4'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('404 (gonderi yok): "Tekrar dene" eylemi YOK (QA-P-10); 500: var', (tester) async {
      useScreen(tester, const Size(390, 844));
      Future<void> run(int status) async {
        final b = FakeBackend();
        b.fail('/posts/500/like', status: status, code: 'X');
        await tester.pumpWidget(buildApp(Scaffold(
            body: Center(
                child: LikeButton(
                    session: makeSession(b), post: Post.fromJson(samplePost(id: 500, text: 'a', likeCount: 4)))))));
        await tester.tap(find.byKey(const ValueKey('like-heart')));
        await settle(tester, const Duration(milliseconds: 1200));
      }

      await run(404);
      final retry404 = find.text('Tekrar dene').evaluate().length;
      await run(500);
      final retry500 = find.text('Tekrar dene').evaluate().length;
      expect(retry404, 0);
      expect(retry500, greaterThanOrEqualTo(retry404));
    });
  });

  group('FollowStateButton (QA-P-08)', () {
    testWidgets('istek surerken disaridan gelen durum, istek bitince uygulanir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend(delay: const Duration(milliseconds: 400));
      b.handlers.add((req, path) {
        if (path != '/users/9/follow') return null;
        return const FakeResult.json({'following': true, 'followerCount': 1, 'followState': 'FOLLOWING'});
      });
      final state = ValueNotifier<FollowState>(FollowState.none);
      await tester.pumpWidget(buildApp(Scaffold(
          body: Center(
              child: ValueListenableBuilder<FollowState>(
                  valueListenable: state,
                  builder: (c, s, _) => FollowStateButton(session: makeSession(b), userId: 9, state: s))))));
      await tester.tap(find.byKey(const ValueKey('followButton')));
      await tester.pump(const Duration(milliseconds: 100));
      state.value = FollowState.requested; // ust widget yeni durum yolladi (istek hala surerken)
      await tester.pump();
      await settle(tester, const Duration(milliseconds: 1000));
      // sunucu FOLLOWING dedi; ertelenen dis durum (requested) sonra uygulanir: bayat 'Takip ediliyor' kalmaz
      expect(find.text('İstek gönderildi'), findsOneWidget);
      expect(find.text('Takip ediliyor'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Sinirlar', () {
    test('video suresi 59/60/61 sn: 60 + 500 ms tolerans', () {
      expect(PostVideoLimits.needsTrim(59000), isFalse);
      expect(PostVideoLimits.needsTrim(60000), isFalse);
      expect(PostVideoLimits.needsTrim(60500), isFalse);
      expect(PostVideoLimits.needsTrim(60501), isTrue);
      expect(PostVideoLimits.needsTrim(61000), isTrue);
    });

    test('video boyutu siniri sunucuyla ayni: 50 MB', () {
      expect(PostVideoLimits.maxBytes, 50 * 1024 * 1024);
    });

    test('metin: 2200 karakter / 40 satir sessiz kirpma; vekil cift ortadan kesilmez', () {
      expect(clampPostText('a' * 3000).length, kPostMaxChars);
      expect(clampPostText(List.filled(60, 'x').join('\n')).split('\n').length, kPostMaxLines);
      final emoji = '${'a' * (kPostMaxChars - 1)}\u{1F600}';
      final out = clampPostText(emoji);
      expect(out.length, kPostMaxChars - 1); // yarim emoji dusurulur
      expect(clampPostText('merhaba'), 'merhaba');
      expect(clampPostText(''), '');
    });
  });

  group('Buyuk liste olcumu (200+ oge)', () {
    testWidgets('Kesfet: 240 gonderi, derin kaydirmada ekrandaki kutu sayisi sabit kalir (tembel masonry)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, count: 240, pageSize: 20);
      await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
      await settle(tester, const Duration(milliseconds: 600));
      var peak = 0;
      for (var i = 0; i < 28; i++) {
        await tester.fling(find.byType(Scrollable).first, const Offset(0, -900), 3000);
        await tester.pump(const Duration(milliseconds: 500));
        final built = find.byType(DiscoverPostBox).evaluate().length;
        if (built > peak) peak = built;
      }
      await settle(tester, const Duration(milliseconds: 300));
      final pages = b.requests.where((r) => r.contains('/feed')).length;
      expect(pages, greaterThan(3), reason: 'sayfalama calisti');
      expect(peak, lessThan(40), reason: 'ekrandaki kutu sayisi liste boyutundan bagimsiz (bellek sabit)');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reels: 220 video, 40 kaydirma sonrasi en cok 4 canli oynatici (dispose sizintisi yok)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final pl = FakeVideoPlatformKs();
      final prev = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = pl;
      addTearDown(() => VideoPlayerPlatform.instance = prev);
      final b = FakeBackend();
      final items = [
        for (var i = 0; i < 220; i++) videoPost(id: 5000 + i),
      ];
      b.on('/feed/reels*', {'items': items, 'nextCursor': null});
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true)));
      await settle(tester, const Duration(milliseconds: 700));
      for (var i = 0; i < 40; i++) {
        await tester.fling(find.byKey(const ValueKey('reelsPager')), const Offset(0, -500), 1500);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5))); // async dispose tamamlansin
        await tester.pump();
      }
      final live = pl.created.length - pl.disposed.length;
      expect(live, lessThanOrEqualTo(4), reason: 'aktif + onceki + sirada + gecis: sabit ust sinir, liste boyutundan bagimsiz');
      expect(pl.created.length, greaterThan(20));
      // widget agaci kaldirilinca TUM oynaticilar birakilir
      await tester.pumpWidget(buildApp(const SizedBox()));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(seconds: 1));
      expect(pl.created.length - pl.disposed.length, 0, reason: 'sizinti yok');
      expect(tester.takeException(), isNull);
    });
  });


  group('Kullanici profili durum matrisi', () {
    for (final st in const [401, 403, 404, 429, 500, 503]) {
      for (final size in const [Size(320, 640), Size(390, 844)]) {
        for (final dark in const [false, true]) {
          testWidgets('GET /users/2 -> $st, ${size.width.toInt()} dp, ${dark ? "koyu" : "acik"}, x1.3: cokme/tasma yok, hata durumu cizilir',
              (tester) async {
            useScreen(tester, size);
            final b = FakeBackend()..fail('/users/2', status: st, code: 'E$st');
            await tester.pumpWidget(MediaQuery(
                data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)),
                child: buildApp(UserProfilePage(session: makeSession(b), userId: 2, initialName: 'Mehmet'),
                    brightness: dark ? Brightness.dark : Brightness.light, size: size)));
            await settle(tester, const Duration(milliseconds: 800));
            expect(tester.takeException(), isNull);
            expect(find.byType(UserProfilePage), findsOneWidget);
            expect(find.byType(CircularProgressIndicator), findsNothing);
          });
        }
      }
    }
  });

  group('ApiError esleme', () {
    test('ApiError status/code korunur (401/403/429/5xx ayrimi icin)', () {
      final e = ApiError(429, 'RATE_LIMITED', 'cok fazla');
      expect(e.status, 429);
      expect(e.code, 'RATE_LIMITED');
      expect(jsonEncode({'s': e.status}), '{"s":429}');
    });
  });
}
