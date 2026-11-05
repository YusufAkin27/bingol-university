import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/features/reels/reels_feed.dart';
import 'package:bu_kampus/features/shell/floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'kesfet_ks_test.dart' show FakeVideoPlatformKs, videoPost;
import 'support/fake_app.dart';

/// QA-SO: Reels sıradaki videoyu önceden hazırlar (yalnız aktif oynar), yazar satırında "Takip et",
/// sürükleyici modda alt gezinme saydamlaşır.

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

Future<FakeVideoPlatformKs> plat() async {
  final p = FakeVideoPlatformKs();
  final prev = VideoPlayerPlatform.instance;
  VideoPlayerPlatform.instance = p;
  addTearDown(() => VideoPlayerPlatform.instance = prev);
  return p;
}

Map<String, dynamic> reel(int id, {int author = 12}) {
  final m = videoPost(id: id);
  (m['author'] as Map)['id'] = author;
  return m;
}

FakeBackend backend(List<Map<String, dynamic>> items, {String state = 'NONE', bool isPrivate = false}) {
  final b = FakeBackend();
  b.on('/feed/reels*', {'items': items, 'nextCursor': null});
  b.on('/users/12', {'id': 12, 'displayName': 'Ayşe Yılmaz', 'followState': state, 'isPrivate': isPrivate, 'followerCount': 3});
  b.handlers.add((req, path) {
    if (path != '/users/12/follow') return null;
    if (req.method == 'POST') {
      return FakeResult.json({'following': !isPrivate, 'followerCount': 4, 'followState': isPrivate ? 'REQUESTED' : 'FOLLOWING'});
    }
    return const FakeResult.json({'following': false, 'followerCount': 3, 'followState': 'NONE'});
  });
  return b;
}

void main() {
  setUpAll(loadTestFonts);

  group('Reels önyükleme', () {
    testWidgets('sıradaki video hazırlanır ama oynamaz; yalnız aktif oynar', (tester) async {
      useScreen(tester, const Size(390, 844));
      final pl = await plat();
      final b = backend([reel(7), reel(8), reel(9), reel(10)]);
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true)));
      await settle(tester, const Duration(milliseconds: 700));
      // Aktif (7) + sıradaki (8) kuruldu; 9 ve 10 henüz değil.
      expect(pl.created.length, 2, reason: 'aktif + sıradaki');
      expect(pl.calls.where((c) => c == 'play').length, 1, reason: 'yalnız aktif oynar');
      // Bir sonrakine geç: 8 oynar (hazır olduğundan yeni kurulum gerekmez), 9 hazırlanır.
      await tester.fling(find.byKey(const ValueKey('reelsPager')), const Offset(0, -500), 1500);
      await settle(tester, const Duration(milliseconds: 900));
      expect(pl.created.length, 3, reason: '9 hazırlandı; 8 yeniden kurulmadı');
      expect(pl.calls.where((c) => c == 'play').length, 2);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('pasif (active:false) iken hiç oynatıcı kurulmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final pl = await plat();
      final b = backend([reel(7), reel(8)]);
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: false)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(pl.created, isEmpty);
      await unmount(tester);
    });
  });

  group('Reels Takip et', () {
    testWidgets('yazar takip edilmiyorsa alt satırda Takip et; dokununca POST /users/12/follow', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat();
      final b = backend([reel(7), reel(8)]);
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true)));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.count('GET /users/12'), 1);
      expect(find.byKey(const ValueKey('reel-follow-btn-7')), findsOneWidget);
      expect(find.text('Takip et'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reel-follow-btn-7')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('POST /users/12/follow'), 1);
      expect(find.text('Takip ediliyor'), findsOneWidget);
      // Aynı yazarın sonraki reeli: durum önbellekten (yeni GET /users/12 yok) ve "Takipte" gelir.
      await tester.fling(find.byKey(const ValueKey('reelsPager')), const Offset(0, -500), 1500);
      await settle(tester, const Duration(milliseconds: 900));
      expect(b.count('GET /users/12'), 1);
      expect(find.byKey(const ValueKey('reel-follow-btn-8')), findsOneWidget);
      expect(find.text('Takip ediliyor'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('gizli hesap: İstek gönderildi', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat();
      final b = backend([reel(7)], isPrivate: true);
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true)));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('reel-follow-btn-7')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İstek gönderildi'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kendi reelim: düğme yok ve takip durumu istenmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat();
      final b = backend([reel(7, author: 1)]);
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true)));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('reel-follow-btn-7')), findsNothing);
      expect(b.count('GET /users/1'), 0);
      await unmount(tester);
    });

    testWidgets('zaten takip ediliyor: Takipte (soluk) görünür, istek hatasında düğme çizilmez (sahte durum yok)', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat();
      final b = backend([reel(7)], state: 'FOLLOWING');
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true)));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Takip ediliyor'), findsOneWidget);
      await unmount(tester);

      final bad = FakeBackend();
      bad.on('/feed/reels*', {'items': [reel(7)], 'nextCursor': null});
      bad.fail('/users/12', status: 500, code: 'SERVER_ERROR');
      await tester.pumpWidget(buildApp(ReelsFeed(key: UniqueKey(), session: makeSession(bad), active: true)));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('reel-follow-btn-7')), findsNothing);
      await unmount(tester);
    });

    for (final size in [const Size(320, 640), const Size(390, 844)]) {
      testWidgets('taşma yok ${size.width.toInt()} dp x1.3 + RTL', (tester) async {
        useScreen(tester, size);
        await plat();
        final b = backend([reel(7)]);
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)),
          child: buildApp(Directionality(textDirection: TextDirection.rtl, child: ReelsFeed(session: makeSession(b), active: true))),
        ));
        await settle(tester, const Duration(milliseconds: 700));
        expect(find.byKey(const ValueKey('reel-follow-btn-7')), findsOneWidget);
        noErr(tester);
        await unmount(tester);
      });
    }
  });

  group('Sürükleyici mod (alt gezinme)', () {
    testWidgets('Reels aktifken shellImmersive true, pasifken/kapanınca false', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat();
      final b = backend([reel(7)]);
      shellImmersive.value = false;
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(shellImmersive.value, isTrue);
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: false)));
      await settle(tester, const Duration(milliseconds: 300));
      expect(shellImmersive.value, isFalse);
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true)));
      await settle(tester, const Duration(milliseconds: 300));
      expect(shellImmersive.value, isTrue);
      await unmount(tester);
      expect(shellImmersive.value, isFalse);
    });

    testWidgets('FloatingNav immersive: yüzey saydam, kenarlık/gölge yok; seçili hap onMedia tonu', (tester) async {
      useScreen(tester, const Size(390, 844));
      final badge = ValueNotifier<int>(0);
      addTearDown(badge.dispose);
      Future<ShapeDecoration> pill(bool immersive) async {
        await tester.pumpWidget(buildApp(Scaffold(
            bottomNavigationBar: FloatingNav(index: 1, onChanged: (_) {}, chatBadge: badge, immersive: immersive))));
        await tester.pump(const Duration(milliseconds: 400));
        final c = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('nav-pill')));
        return c.decoration! as ShapeDecoration;
      }

      final normal = await pill(false);
      expect(normal.color!.a, 1);
      expect(normal.shadows ?? const [], isEmpty, reason: 'monochrome: alt cubukta golge yok (sf + ince bd kenarlik)');
      final dark = await pill(true);
      expect(dark.color!.a, 0);
      expect(dark.shadows ?? const [], isEmpty);
      noErr(tester);
    });
  });
}
