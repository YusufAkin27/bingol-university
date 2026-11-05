import 'package:bu_kampus/features/profile/profile_content_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(20).join('\n')}');
}

Map<String, dynamic> post(int id, {bool video = false}) => {
      'id': id,
      'text': 'merhaba',
      if (!video) 'media': [
        {'id': id, 'kind': 'IMAGE', 'url': '/api/posts/media/$id', 'thumbUrl': '/api/posts/media/$id?thumb=true'}
      ],
      if (video) 'type': 'VIDEO',
      if (video) 'video': {'url': '/api/posts/media/$id', 'posterUrl': '/api/posts/media/$id?poster=true', 'durationMs': 65000},
      if (video) 'viewCount': 1234,
    };

Widget host(FakeBackend b, {bool locked = false, int userId = 7}) => Scaffold(
      body: SingleChildScrollView(
        child: ProfileContentTabs(session: makeSession(b), userId: userId, locked: locked),
      ),
    );

void main() {
  setUpAll(loadTestFonts);

  test('ProfileGridItem: video alanlari ve eski medya listesi', () {
    final v = ProfileGridItem.fromJson(post(3, video: true));
    expect(v.isVideo, isTrue);
    expect(v.durationLabel, '1:05');
    expect(v.views, 1234);
    expect(v.imageUrl, contains('poster=true'));
    final p = ProfileGridItem.fromJson(post(4));
    expect(p.isVideo, isFalse);
    expect(p.imageUrl, contains('thumb=true'));
    expect(const ProfileGridItem(id: 1).durationLabel, isNull);
  });

  testWidgets('Gonderiler 3 sutun grid; Reels sekmesi yuklenir (sure + goruntulenme)', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    b.on('/users/7/posts*', {
      'items': [post(1), post(2), post(3)],
      'nextCursor': null
    });
    b.on('/users/7/reels*', {
      'items': [post(9, video: true)],
      'nextCursor': null
    });
    await tester.pumpWidget(buildApp(host(b)));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Gönderiler'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-post-1')), findsOneWidget);
    final w = tester.getSize(find.byKey(const ValueKey('profile-post-1'))).width;
    expect((w - (390 - 40 - 6) / 3).abs(), lessThan(1));
    // Reels yalniz secilince istenir.
    expect(b.requests.any((r) => r.contains('/reels')), isFalse);
    await tester.tap(find.text('Reels'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('profile-reel-9')), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    noErr(tester);
  });

  testWidgets('bos durum ve reels ucu yoksa (404) bos gosterir, hata degil', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    b.on('/users/7/posts*', {'items': [], 'nextCursor': null});
    b.fail('/users/7/reels*', status: 404, code: 'NOT_FOUND');
    await tester.pumpWidget(buildApp(host(b)));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Henüz gönderi yok.'), findsOneWidget);
    await tester.tap(find.text('Reels'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Henüz reels yok.'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsNothing);
    noErr(tester);
  });

  testWidgets('sayfalama: Daha fazla goster sonraki sayfayi ekler', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    b.on('/users/7/posts?size=18', {
      'items': [post(1), post(2)],
      'nextCursor': 'c2'
    });
    b.on('/users/7/posts?size=18&cursor=c2', {
      'items': [post(2), post(3)],
      'nextCursor': null
    });
    await tester.pumpWidget(buildApp(host(b)));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Daha fazla göster'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('profile-post-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-post-2')), findsOneWidget);
    expect(find.text('Daha fazla göster'), findsNothing);
    noErr(tester);
  });

  testWidgets('gizli hesap: kilit bilgisi, hic istek yok', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    await tester.pumpWidget(buildApp(host(b, locked: true)));
    await settle(tester, const Duration(milliseconds: 400));
    expect(find.text('Bu hesap gizli'), findsOneWidget);
    expect(b.requests, isEmpty);
    noErr(tester);
  });

  testWidgets('kendi profilim: /posts/mine', (tester) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    b.on('/posts/mine*', {
      'items': [post(5)],
      'nextCursor': null
    });
    await tester.pumpWidget(buildApp(host(b, userId: 1)));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('profile-post-5')), findsOneWidget);
    noErr(tester);
  });

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    for (final dark in [false, true]) {
      testWidgets('tasma yok ${size.width.toInt()} dp x1.3 ${dark ? 'koyu' : 'acik'} + RTL', (tester) async {
        useScreen(tester, size);
        final b = FakeBackend();
        b.on('/users/7/posts*', {
          'items': [for (var i = 1; i <= 7; i++) post(i)],
          'nextCursor': null
        });
        b.on('/users/7/reels*', {
          'items': [post(9, video: true), post(10, video: true)],
          'nextCursor': null
        });
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)),
          child: buildApp(Directionality(textDirection: TextDirection.rtl, child: host(b)),
              brightness: dark ? Brightness.dark : Brightness.light),
        ));
        await settle(tester, const Duration(milliseconds: 500));
        await tester.tap(find.textContaining('Reels'));
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.byType(ProfileGridTile), findsWidgets);
        noErr(tester);
      });
    }
  }
}
