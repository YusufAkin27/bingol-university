import 'package:bu_kampus/core/platform/video_service.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/reels/reels_comments.dart';
import 'package:bu_kampus/features/reels/reels_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'kesfet_ks_test.dart' show FakeVideoPlatformKs, videoPost;
import 'support/fake_app.dart';

/// KS-MB 2. tur: 5 kapsül filtre (konum koruma), Reels tükendi/Tekrar izle/İlgilenmiyorum/yorum paneli, Paylaş menüsü,
/// kapak karesi seçimi, avatar uzun basma önizlemesi.

class _Frames implements VideoCompressor {
  int n = 0;

  @override
  Future<VideoInfo?> info(String path) async =>
      VideoInfo(path: path, sizeBytes: 90 * 1024 * 1024, durationMs: 20000, width: 1920, height: 1080);

  @override
  Future<VideoInfo?> compress(String path, void Function(double) onProgress) async => VideoInfo(
      path: '/c.mp4', sizeBytes: 12 * 1024 * 1024, durationMs: 20000, width: 720, height: 1280, bytes: Uint8List.fromList(List.filled(2048, 1)));

  @override
  Future<Uint8List?> poster(String path, {int positionMs = 0}) async {
    n++;
    return Uint8List.fromList(kFakePng);
  }

  @override
  Future<void> cancel() async {}
}

class _FakeComments implements CommentsRepository {
  final added = <String>[];
  final liked = <int>[];

  @override
  Future<ReelCommentPage> list(int postId, {String? cursor, String sort = 'top'}) async => ReelCommentPage([
        ReelComment.fromJson({
          'id': 1,
          'author': {'id': 5, 'displayName': 'Deniz Aksoy'},
          'text': 'Harika video',
          'createdAt': '2026-11-04T08:00:00Z',
          'likeCount': 2,
          'replyCount': 1,
        })
      ], null);

  @override
  Future<ReelCommentPage> replies(int commentId, {String? cursor}) async => ReelCommentPage([
        ReelComment.fromJson({'id': 2, 'parentId': 1, 'author': {'id': 6, 'displayName': 'Ece Yılmaz'}, 'text': 'Katılıyorum'})
      ], null);

  @override
  Future<ReelComment> add(int postId, String text, {int? parentId}) async {
    added.add('$parentId:$text');
    return ReelComment.fromJson({'id': 99, 'author': {'id': 1, 'displayName': 'Ayşe Yılmaz'}, 'text': text, 'mine': true});
  }

  @override
  Future<void> delete(int commentId) async {}

  @override
  Future<void> setLiked(int commentId, bool l) async => liked.add(commentId);
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

Widget discover(FakeBackend b) => DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null));

void main() {
  setUpAll(loadTestFonts);

  group('Kesfet tek akis', () {
    testWidgets('filtre kapsulu yok; yalniz scope=foryou istenir ve gorulenler POST /feed/seen ile bildirilir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      for (final f in ['Senin İçin', 'Popüler', 'Reels', 'En Yeni', 'Takip Ettiklerim']) {
        expect(find.text(f), findsNothing, reason: f);
      }
      expect(b.requests.any((r) => r.startsWith('GET /feed?') && r.contains('scope=foryou')), isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(b.count('POST /feed/seen'), greaterThanOrEqualTo(1));
      expect(b.requests.any((r) => r.contains('scope=popular') || r.contains('scope=latest') || r.contains('scope=following')), isFalse);
      expect(b.count('GET /feed/reels'), 0); // Reels akisi Kesfet'ten acilmaz
      noErr(tester);
    });

    testWidgets('avatara uzun basma: blur onizleme acilir, disina dokununca kapanir; fotografsiz avatar onizlenmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final withAvatar = videoPost(id: 2001);
      (withAvatar['author'] as Map)['avatarUrl'] = '/files/avatars/x.jpg';
      b.on('/feed*', {'items': [withAvatar, videoPost(id: 2002)], 'nextCursor': null});
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.longPress(find.byKey(const ValueKey('discover-author-2002')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('profilePhotoViewerBackdrop')), findsNothing);
      // Fotografsiz avatarda onizleme yok; uzun basma gonderi menusunu acar (kapat).
      await tester.tapAt(const Offset(10, 60));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.longPress(find.byKey(const ValueKey('discover-author-2001')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('profilePhotoViewerBackdrop')), findsOneWidget);
      await tester.tapAt(const Offset(10, 300));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('profilePhotoViewerBackdrop')), findsNothing);
      noErr(tester);
    });
  });

  group('Reels', () {
    Future<FakeVideoPlatformKs> plat(WidgetTester tester) async {
      final p = FakeVideoPlatformKs();
      final prev = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = p;
      addTearDown(() => VideoPlayerPlatform.instance = prev);
      return p;
    }

    testWidgets('icerik tukendi: sonsuz dongu yok; Tekrar izle replay=true ile yeni oturum; Kesfet gonderilerine bak', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat(tester);
      final b = FakeBackend();
      var posts = 0;
      b.on('/feed/reels*', {'items': [], 'nextCursor': null, 'exhausted': true});
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true, onOpenPosts: () => posts++)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('reelsDone')), findsOneWidget);
      expect(find.text('Şimdilik tüm videoları gördün'), findsOneWidget);
      b.on('/feed/reels*', {'items': [videoPost(id: 7)], 'nextCursor': null, 'exhausted': false});
      await tester.tap(find.byKey(const ValueKey('reelsReplay')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.requests.any((r) => r.startsWith('GET /feed/reels?') && r.contains('replay=true')), isTrue);
      expect(find.byKey(const ValueKey('reel-author-7')), findsOneWidget);
      // Son sayfadan sonra (nextCursor null + exhausted false) tukendi sayfasi eklenmez; tukendi ise eklenir.
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('video yok (tukendi degil): bos durum + paylas; pasif (active:false) iken hic oynatici kurulmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final pl = await plat(tester);
      final b = FakeBackend();
      b.on('/feed/reels*', {'items': [], 'nextCursor': null, 'exhausted': false});
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true, onCompose: () {})));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('reelsEmpty')), findsOneWidget);
      expect(find.text('Henüz reel yok'), findsOneWidget);
      b.on('/feed/reels*', {'items': [videoPost()], 'nextCursor': null, 'exhausted': false});
      await tester.pumpWidget(buildApp(ReelsFeed(key: UniqueKey(), session: makeSession(b), active: false)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(pl.created, isEmpty);
      await unmount(tester);
    });

    testWidgets('son reelden sonra tukendi sayfasi; Kesfet gonderilerine bak geri cagirir', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat(tester);
      final b = FakeBackend();
      var posts = 0;
      b.on('/feed/reels*', {'items': [videoPost(id: 7)], 'nextCursor': null, 'exhausted': true});
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true, onOpenPosts: () => posts++)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('reelsDone')), findsNothing);
      await tester.fling(find.byKey(const ValueKey('reelsPager')), const Offset(0, -500), 1500);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('reelsDone')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reelsToPosts')));
      expect(posts, 1);
      await unmount(tester);
    });

    testWidgets('eylem cubugu: yorum/kaydet yalniz sunucu sunuyorsa gorunur; yorum paneli (liste, yanit, yazma)', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat(tester);
      final b = FakeBackend();
      final plain = videoPost(id: 7);
      final rich = videoPost(id: 8)..addAll({'commentCount': 1, 'savedByMe': false});
      b.on('/feed/reels*', {'items': [plain, rich], 'nextCursor': null});
      final repo = _FakeComments();
      await tester.pumpWidget(buildApp(ReelsFeed(session: makeSession(b), active: true, comments: repo)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('reel-comments-7')), findsNothing);
      expect(find.byKey(const ValueKey('reel-save-7')), findsNothing);
      expect(find.byKey(const ValueKey('reel-menu-7')), findsOneWidget);
      await tester.fling(find.byKey(const ValueKey('reelsPager')), const Offset(0, -500), 1500);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('reel-save-8')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reel-save-8')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(b.requests.any((r) => r.startsWith('PUT /posts/8/save')), isTrue);
      await tester.tap(find.byKey(const ValueKey('reel-comments-8')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Harika video'), findsOneWidget);
      expect(find.textContaining('Deniz Aksoy', findRichText: true), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentReplies-1')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Katılıyorum'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('commentInput')), 'Güzel');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('commentSend')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(repo.added, ['null:Güzel']);
      expect(find.text('Güzel'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentLike-1')));
      await settle(tester, const Duration(milliseconds: 200));
      expect(repo.liked, [1]);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('uc nokta: Ilgilenmiyorum -> POST /posts/{id}/not-interested, reel akistan kalkar', (tester) async {
      useScreen(tester, const Size(390, 844));
      await plat(tester);
      final b = FakeBackend();
      b.on('/feed/reels*', {'items': [videoPost(id: 7), videoPost(id: 8)], 'nextCursor': null});
      await tester.pumpWidget(buildApp(Scaffold(body: ReelsFeed(session: makeSession(b), active: true))));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('reel-menu-7')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İlgilenmiyorum'), findsOneWidget);
      await tester.tap(find.text('İlgilenmiyorum'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.startsWith('POST /posts/7/not-interested')), isTrue);
      expect(find.byKey(const ValueKey('reel-author-7')), findsNothing);
      await unmount(tester);
    });
  });

  group('Paylas menusu + kapak', () {
    testWidgets('Paylas menusu: Fotograf paylas | Video / Reels paylas (metin gonderisi yok)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => openComposePost(c, s), child: const Text('ac')))),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Fotoğraf paylaş'), findsOneWidget);
      expect(find.text('Video / Reels paylaş'), findsOneWidget);
      expect(find.textContaining('Metin'), findsNothing);
      noErr(tester);
    });

    testWidgets('video secilince kapak kareleri seridi; kare secimi poster olarak yuklenir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final comp = _Frames();
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        videoService: VideoService(limitBytes: VideoService.postMaxBytes, compressor: comp, pick: (src) async => const PickedVideo('/orig.mp4')),
        videoUploader: VideoUploader(s, client: b.client),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeVideoGallery')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(find.byKey(const ValueKey('composeCoverStrip')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeCover-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeCover-3')), findsOneWidget);
      expect(comp.n, greaterThanOrEqualTo(7)); // hazirlama posteri + 6 aday
      await tester.tap(find.byKey(const ValueKey('composeCover-3')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(b.count('POST /posts/media'), 1);
      noErr(tester);
    });
  });
}
