import 'dart:async';

import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/posts/like_button.dart';
import 'package:bu_kampus/features/posts/likers_sheet.dart';
import 'package:bu_kampus/features/posts/post_actions.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _post(int id,
        {int likes = 3,
        bool liked = false,
        bool mine = false,
        String text = 'Merhaba kampüs',
        int authorId = 7,
        List<Map<String, dynamic>> media = const []}) =>
    {
      'id': id,
      'author': {'id': mine ? 1 : authorId, 'displayName': mine ? 'Ayşe Yılmaz' : 'Mehmet Kaya'},
      'text': text,
      'media': media,
      'likeCount': likes,
      'commentCount': 2,
      'likedByMe': liked,
      'mine': mine,
      'canEdit': mine,
      'canDelete': mine,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {String? next, int? total}) =>
    {'items': items, 'nextCursor': next, if (total != null) 'total': total};

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

/// Beğeni düğmesini durumlu bir sarmalayıcıda gösterir.
class _LikeHarness extends StatefulWidget {
  const _LikeHarness({required this.session, required this.post, this.controller});

  final Session session;
  final Post post;
  final LikeController? controller;

  @override
  State<_LikeHarness> createState() => _LikeHarnessState();
}

class _LikeHarnessState extends State<_LikeHarness> {
  late Post p = widget.post;
  int changes = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: LikeButton(
            session: widget.session,
            post: p,
            controller: widget.controller,
            onChanged: (n) => setState(() {
              p = n;
              changes++;
            }),
          ),
        ),
      );
}

Future<void> _pumpLike(WidgetTester tester, FakeBackend be, Post post,
    {Brightness b = Brightness.light, Size size = kPhoneMedium, LikeController? controller}) async {
  useScreen(tester, size);
  await tester.pumpWidget(
      buildApp(_LikeHarness(session: makeSession(be), post: post, controller: controller), brightness: b, size: size));
  await tester.pump();
}

/// Menü / diyalog denemeleri için tek düğmeli sayfa.
Future<List<String>> _pumpMenu(WidgetTester tester, FakeBackend be, Post post,
    {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  final log = <String>[];
  final s = makeSession(be);
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(
    Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showPostActions(c,
                session: s,
                post: post,
                onEdited: (p) => log.add('edited:${p.text}'),
                onDeleted: () => log.add('deleted')),
            child: const Text('ac'),
          ),
        ),
      ),
    ),
    brightness: b,
    size: size,
  ));
  await tester.tap(find.text('ac'));
  await settle(tester, const Duration(milliseconds: 400));
  return log;
}

void main() {
  setUpAll(loadTestFonts);

  group('LikeButton', () {
    testWidgets('iyimser güncelleme, sunucu sayısını esas alır', (tester) async {
      final be = FakeBackend()..on('/posts/5/like', {'liked': true, 'likeCount': 4});
      await _pumpLike(tester, be, Post.fromJson(_post(5)));
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump();
      expect(find.text('4'), findsOneWidget); // istek gitmeden
      expect(be.count('PUT /posts/5/like'), 0);
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('PUT /posts/5/like'), 1);
      expect(find.text('4'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('beğenilmişi geri alma: DELETE', (tester) async {
      final be = FakeBackend()..on('/posts/5/like', {'liked': false, 'likeCount': 2});
      await _pumpLike(tester, be, Post.fromJson(_post(5, liked: true)));
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('DELETE /posts/5/like'), 1);
      expect(be.count('PUT /posts/5/like'), 0);
      await unmount(tester);
    });

    testWidgets('hata: geri alınır + snackbar', (tester) async {
      final be = FakeBackend()..fail('/posts/5/like', status: 500, code: 'SERVER_ERROR', message: 'Sunucu hatası');
      await _pumpLike(tester, be, Post.fromJson(_post(5)));
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump();
      expect(find.text('4'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Sunucu hatası'), findsOneWidget);
      final st = tester.state<_LikeHarnessState>(find.byType(_LikeHarness));
      expect(st.p.likedByMe, false);
      await unmount(tester);
    });

    testWidgets('art arda 5 dokunuş -> tek son istek', (tester) async {
      final be = FakeBackend()..on('/posts/5/like', {'liked': true, 'likeCount': 4});
      await _pumpLike(tester, be, Post.fromJson(_post(5)));
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('like-heart')));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('/posts/5/like'), 1);
      expect(be.count('PUT /posts/5/like'), 1); // 5 dokunuş: son durum beğenili
      await unmount(tester);
    });

    testWidgets('çift sayıda dokunuş: sunucuya hiç istek gitmez', (tester) async {
      final be = FakeBackend()..on('/posts/5/like', {'liked': true, 'likeCount': 4});
      await _pumpLike(tester, be, Post.fromJson(_post(5)));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('like-heart')));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('/posts/5/like'), 0);
      expect(find.text('3'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kalp animasyonu: kare kare build, taşma yok', (tester) async {
      final be = FakeBackend()..on('/posts/5/like', {'liked': true, 'likeCount': 4});
      await _pumpLike(tester, be, Post.fromJson(_post(5)));
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 70));
      }
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      _ok(tester);
      await settle(tester, const Duration(milliseconds: 800));
      await unmount(tester);
    });

    testWidgets('LikeController.like yalnız beğenilmemişse beğenir', (tester) async {
      final be = FakeBackend()..on('/posts/5/like', {'liked': true, 'likeCount': 4});
      final c = LikeController();
      await _pumpLike(tester, be, Post.fromJson(_post(5)), controller: c);
      c.like();
      c.like(); // ikincisi etkisiz
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('PUT /posts/5/like'), 1);
      expect(c.liked, true);
      await unmount(tester);
    });

    testWidgets('DoubleTapLike: çift dokunuşta büyük kalp ve geri çağrı', (tester) async {
      var n = 0;
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 200,
                      height: 200,
                      child: DoubleTapLike(onLike: () => n++, child: const ColoredBox(color: Colors.grey))))),
          size: kPhoneMedium));
      await tester.tap(find.byType(ColoredBox).last);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.byType(ColoredBox).last);
      await tester.pump(const Duration(milliseconds: 150));
      expect(n, 1);
      expect(find.byKey(const ValueKey('double-tap-heart')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('double-tap-heart')), findsNothing);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('düzen ${b.name} ${size.width.toInt()}: büyük sayı taşmaz', (tester) async {
          final be = FakeBackend();
          await _pumpLike(tester, be, Post.fromJson(_post(5, likes: 123456, liked: true)), b: b, size: size);
          expect(find.text('123456'), findsOneWidget);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });

  group('LikersSheet', () {
    Future<void> open(WidgetTester tester, FakeBackend be, {int? total}) async {
      final s = makeSession(be);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          Builder(
              builder: (c) => Scaffold(
                  body: TextButton(onPressed: () => showLikersSheet(c, s, 5, total: total), child: const Text('ac')))),
          size: kPhoneMedium));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 600));
    }

    List<Map<String, dynamic>> users(int from, int n) =>
        [for (var i = from; i < from + n; i++) {'id': 100 + i, 'displayName': 'Kişi $i', 'avatarUrl': null}];

    testWidgets('sayfalama: kaydırınca sonraki sayfa', (tester) async {
      final be = FakeBackend()
        ..on('/posts/5/likes?size=30', _page(users(0, 15), next: 'c2', total: 20))
        ..on('/posts/5/likes?size=30&cursor=c2', _page(users(15, 5), total: 20));
      await open(tester, be);
      expect(find.text('Beğenenler (20)'), findsOneWidget);
      expect(find.text('Kişi 0'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -700));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.count('cursor=c2'), 1);
      await tester.drag(find.byType(ListView).last, const Offset(0, -900));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Kişi 19'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('boş durum', (tester) async {
      final be = FakeBackend()..on('/posts/5/likes?size=30', _page([], total: 0));
      await open(tester, be);
      expect(find.text('Henüz beğenen yok'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hata durumu ve yeniden dene', (tester) async {
      final be = FakeBackend()..fail('/posts/5/likes?size=30', status: 500, message: 'Sunucu hatası');
      await open(tester, be);
      expect(find.text('Sunucu hatası'), findsOneWidget);
      be.on('/posts/5/likes?size=30', _page(users(0, 2), total: 2));
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Kişi 1'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kişiye dokununca profil açılır', (tester) async {
      final be = FakeBackend()
        ..on('/posts/5/likes?size=30', _page(users(0, 2), total: 2))
        ..on('/users/100', {'id': 100, 'displayName': 'Kişi 0'});
      await open(tester, be);
      await tester.tap(find.text('Kişi 0'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(UserProfilePage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('showPostActions', () {
    testWidgets('yazar: Düzenle + Sil, şikâyet/engel yok', (tester) async {
      await _pumpMenu(tester, FakeBackend(), Post.fromJson(_post(5, mine: true)));
      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);
      expect(find.text('Şikâyet et'), findsNothing);
      expect(find.text('Bu kullanıcıyı engelle'), findsNothing);
      expect(find.text('Bağlantıyı kopyala'), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('başkası: Profili gör, Şikâyet et, Engelle; Düzenle/Sil yok', (tester) async {
      await _pumpMenu(tester, FakeBackend(), Post.fromJson(_post(5)));
      expect(find.text('Profili gör'), findsOneWidget);
      expect(find.text('Şikâyet et'), findsOneWidget);
      expect(find.text('Bu kullanıcıyı engelle'), findsOneWidget);
      expect(find.text('Düzenle'), findsNothing);
      expect(find.text('Sil'), findsNothing);
      await unmount(tester);
    });

    testWidgets('bariyere dokununca kapanır', (tester) async {
      await _pumpMenu(tester, FakeBackend(), Post.fromJson(_post(5)));
      await tester.tapAt(const Offset(5, 5));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('postMenu.card')), findsNothing);
      await unmount(tester);
    });

    testWidgets('düzenle: PATCH gövdesi ve onEdited', (tester) async {
      final be = FakeBackend()..on('/posts/5', {..._post(5, mine: true, text: 'Yeni metin'), 'editedAt': '2026-10-27T10:00:00Z'});
      final log = await _pumpMenu(tester, be, Post.fromJson(_post(5, mine: true)));
      await tester.tap(find.text('Düzenle'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Gönderiyi düzenle'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('edit-post-text')), 'Yeni metin');
      await tester.tap(find.byKey(const ValueKey('edit-post-save')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(be.bodies['PATCH /posts/5'], {'text': 'Yeni metin'});
      expect(log, ['edited:Yeni metin']);
      expect(find.text('Gönderiyi düzenle'), findsNothing);
      await unmount(tester);
    });

    testWidgets('düzenle: küfür 422 mesajı diyalogda kalır', (tester) async {
      final be = FakeBackend()..fail('/posts/5', status: 422, code: 'CONTENT_PROFANITY', message: 'Metin uygunsuz ifade içeriyor.');
      final log = await _pumpMenu(tester, be, Post.fromJson(_post(5, mine: true)));
      await tester.tap(find.text('Düzenle'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.enterText(find.byKey(const ValueKey('edit-post-text')), 'kötü söz');
      await tester.tap(find.byKey(const ValueKey('edit-post-save')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Metin uygunsuz ifade içeriyor.'), findsOneWidget);
      expect(find.text('Gönderiyi düzenle'), findsOneWidget);
      expect(log, isEmpty);
      await unmount(tester);
    });

    testWidgets('sil: onay sonra DELETE ve onDeleted', (tester) async {
      final be = FakeBackend();
      final log = await _pumpMenu(tester, be, Post.fromJson(_post(5, mine: true)));
      await tester.tap(find.text('Sil'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Gönderi silinsin mi?'), findsOneWidget);
      expect(be.count('DELETE /posts/5'), 0);
      await tester.tap(find.widgetWithText(TextButton, 'Sil'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(be.count('DELETE /posts/5'), 1);
      expect(log, ['deleted']);
      await unmount(tester);
    });

    testWidgets('sil: vazgeç isteği göndermez', (tester) async {
      final be = FakeBackend();
      final log = await _pumpMenu(tester, be, Post.fromJson(_post(5, mine: true)));
      await tester.tap(find.text('Sil'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(be.count('DELETE'), 0);
      expect(log, isEmpty);
      await unmount(tester);
    });

    testWidgets('şikâyet: FEED_POST hedefi', (tester) async {
      final be = FakeBackend();
      await _pumpMenu(tester, be, Post.fromJson(_post(5)));
      await tester.tap(find.text('Şikâyet et'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Gönderiyi şikâyet et'), findsOneWidget);
      await tester.tap(find.text('Gönder'));
      await settle(tester, const Duration(milliseconds: 500));
      final body = be.bodies['POST /reports'] as Map;
      expect(body['targetType'], 'FEED_POST');
      expect(body['targetId'], 5);
      await unmount(tester);
    });

    testWidgets('engelle: onay sonra POST /users/7/block ve onDeleted', (tester) async {
      final be = FakeBackend();
      final log = await _pumpMenu(tester, be, Post.fromJson(_post(5)));
      await tester.tap(find.text('Bu kullanıcıyı engelle'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Kullanıcı engellensin mi?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Engelle'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(be.count('POST /users/7/block'), 1);
      expect(log, ['deleted']);
      await unmount(tester);
    });

    testWidgets('profili gör: kullanıcı profili açılır', (tester) async {
      final be = FakeBackend()..on('/users/7', {'id': 7, 'displayName': 'Mehmet Kaya'});
      await _pumpMenu(tester, be, Post.fromJson(_post(5)));
      await tester.tap(find.text('Profili gör'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(UserProfilePage), findsOneWidget);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('menü düzeni ${b.name} ${size.width.toInt()}', (tester) async {
          await _pumpMenu(tester, FakeBackend(), Post.fromJson(_post(5)), b: b, size: size);
          expect(find.text('Bu kullanıcıyı engelle'), findsOneWidget);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });

  group('UserPostsPage', () {
    Future<void> open(WidgetTester tester, FakeBackend be,
        {int userId = 7, Size size = kPhoneMedium, Brightness b = Brightness.light}) async {
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(
          UserPostsPage(session: makeSession(be), userId: userId, name: 'Mehmet Kaya'),
          size: size,
          brightness: b));
      await settle(tester, const Duration(milliseconds: 600));
    }

    testWidgets('yükleme ve sayfalama', (tester) async {
      final first = [for (var i = 1; i <= 8; i++) _post(i, text: 'Gönderi metni $i')];
      final be = FakeBackend()
        ..on('/users/7/posts?size=10', _page(first, next: 'p2'))
        ..on('/users/7/posts?cursor=p2&size=10', _page([_post(9, text: 'Son gönderi')]));
      await open(tester, be);
      expect(find.text('Mehmet Kaya'), findsWidgets);
      expect(find.text('Gönderi metni 1'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await settle(tester, const Duration(milliseconds: 300));
      }
      expect(be.count('cursor=p2'), 1);
      expect(find.text('Son gönderi'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('boş durum', (tester) async {
      final be = FakeBackend()..on('/users/7/posts?size=10', _page([]));
      await open(tester, be);
      expect(find.text('Henüz gönderi yok'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hata durumu', (tester) async {
      final be = FakeBackend()..fail('/users/7/posts?size=10', status: 500, message: 'Sunucu hatası');
      await open(tester, be);
      expect(find.text('Sunucu hatası'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kendi profil: /posts/mine ve "Gönderilerim"', (tester) async {
      final be = FakeBackend()..on('/posts/mine?size=10', _page([_post(3, mine: true, text: 'Benim gönderim')]));
      await open(tester, be, userId: 1);
      expect(find.text('Gönderilerim'), findsOneWidget);
      expect(find.text('Benim gönderim'), findsOneWidget);
      expect(be.count('/posts/mine'), 1);
      await unmount(tester);
    });

    testWidgets('kartta beğeni ve menü düğmesi bağlı', (tester) async {
      final be = FakeBackend()
        ..on('/users/7/posts?size=10', _page([_post(3)]))
        ..on('/posts/3/like', {'liked': true, 'likeCount': 4});
      await open(tester, be);
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(be.count('PUT /posts/3/like'), 1);
      expect(find.text('4'), findsOneWidget);
      expect(find.byKey(const ValueKey('post-menu-button')), findsOneWidget);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('düzen ${b.name} ${size.width.toInt()}', (tester) async {
          final be = FakeBackend()
            ..on('/users/7/posts?size=10', _page([_post(3, text: 'Uzun ' * 80), _post(4)]));
          await open(tester, be, size: size, b: b);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });

  group('Profilde Gönderiler', () {
    const profile = {'id': 2, 'displayName': 'Mehmet Kaya'};
    Future<void> open(WidgetTester tester, FakeBackend be,
        {Size size = kPhoneMedium, Brightness b = Brightness.light}) async {
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(be), userId: 2), size: size, brightness: b));
      await settle(tester, const Duration(milliseconds: 800));
    }

    final media = [
      {'id': 1, 'kind': 'IMAGE', 'url': '/api/posts/media/1', 'thumbUrl': '/api/posts/media/1?thumb=true'}
    ];

    testWidgets('dolu: ızgara + Tümünü gör', (tester) async {
      final posts = [
        for (var i = 1; i <= 6; i++) _post(i, authorId: 2, text: 'Metin $i', media: i.isEven ? media : const []),
      ];
      final be = FakeBackend()
        ..on('/users/2', profile)
        ..on('/users/2/posts?size=6', _page(posts))
        ..on('/users/2/posts?size=10', _page(posts));
      await open(tester, be);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('profile-posts-all')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Gönderiler'), findsOneWidget);
      expect(find.text('Metin 1'), findsOneWidget); // metin-only karo önizlemesi
      await tester.tap(find.byKey(const ValueKey('profile-posts-all')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(UserPostsPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('boş: bölüm gizli', (tester) async {
      final be = FakeBackend()
        ..on('/users/2', profile)
        ..on('/users/2/posts?size=6', _page([]));
      await open(tester, be);
      expect(find.byKey(const ValueKey('profile-posts-section')), findsNothing);
      await unmount(tester);
    });

    testWidgets('engellenmiş kullanıcı: bölüm gizli', (tester) async {
      final be = FakeBackend()
        ..on('/users/2', profile)
        ..on('/users/me/blocks?limit=50', {'items': [{'id': 2}]})
        ..on('/users/2/posts?size=6', _page([_post(1, authorId: 2)]));
      await open(tester, be);
      expect(find.byKey(const ValueKey('profile-posts-section')), findsNothing);
      await unmount(tester);
    });

    testWidgets('hata: bölüm sessizce gizli, profil çalışır', (tester) async {
      final be = FakeBackend()
        ..on('/users/2', profile)
        ..fail('/users/2/posts?size=6', status: 500);
      await open(tester, be);
      expect(find.text('Mehmet Kaya'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-posts-section')), findsNothing);
      await unmount(tester);
    });

    for (final b in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('düzen ${b.name} ${size.width.toInt()}', (tester) async {
          final be = FakeBackend()
            ..on('/users/2', profile)
            ..on('/users/2/posts?size=6', _page([for (var i = 1; i <= 6; i++) _post(i, authorId: 2, text: 'Uzun ' * 40)]));
          await open(tester, be, size: size, b: b);
          _ok(tester);
          await unmount(tester);
        });
      }
    }
  });

  group('Profil sekmesi', () {
    testWidgets('"Gönderilerim" satırı UserPostsPage açar', (tester) async {
      final be = FakeBackend()
        ..on('/users/me', {'id': 1, 'displayName': 'Ayşe Yılmaz', 'email': 'a@bingol.edu.tr'})
        ..on('/posts/mine?size=10', _page([_post(3, mine: true, text: 'Benim gönderim')]));
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          ProfileTab(session: makeSession(be), themeController: ThemeController()),
          size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Gönderilerim'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(UserPostsPage), findsOneWidget);
      expect(find.text('Benim gönderim'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Bildirim yönlendirmesi', () {
    Map<String, dynamic> notif(int id, String type, Map<String, dynamic> data) =>
        {'id': id, 'type': type, 'title': 'Başlık $id', 'body': 'Metin', 'read': false, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'data': data};

    Future<FakeBackend> openList(WidgetTester tester, List<Map<String, dynamic>> items) async {
      final be = FakeBackend()..on('/notifications', {'items': items, 'nextCursor': null, 'unreadCount': items.length});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(be)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      return be;
    }

    testWidgets('POST türleri: kalp / mesaj / yanıt ikonu', (tester) async {
      await openList(tester, [
        notif(1, 'POST_LIKE', {'targetType': 'POST', 'targetId': 9}),
        notif(2, 'POST_COMMENT', {'targetType': 'POST', 'targetId': 9, 'commentId': 4}),
        notif(3, 'COMMENT_REPLY', {'targetType': 'POST', 'targetId': 9, 'commentId': 5}),
      ]);
      expect(find.byIcon(LucideIcons.heart), findsOneWidget);
      expect(find.byIcon(LucideIcons.messageSquare), findsOneWidget);
      expect(find.byIcon(LucideIcons.reply), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('POST hedefine dokunma gönderi detayına yönlendirir (diğer sayfa açılmaz)', (tester) async {
      final be = await openList(tester, [
        notif(2, 'POST_COMMENT', {'targetType': 'POST', 'targetId': 9, 'commentId': 4}),
      ]);
      await tester.tap(find.text('Başlık 2'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.count('POST /notifications/read'), 1);
      expect(be.count('/conversations'), 0);
      // M1/M3 sayfası bağlıysa PostDetailPage, değilse geçici "Yakında" bilgisi.
      final routed = find.text('Yakında').evaluate().isNotEmpty ||
          find.byWidgetPredicate((w) => w.runtimeType.toString() == 'PostDetailPage').evaluate().isNotEmpty;
      expect(routed, true);
      await unmount(tester);
    });

    testWidgets('PushRouter: targetType POST yük ile yönlendirir', (tester) async {
      final be = FakeBackend();
      final s = makeSession(be);
      PushRouter.session = s;
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: BuTheme.light(),
        home: const Scaffold(body: Text('ana')),
      ));
      unawaited(PushRouter.open({'targetType': 'POST', 'targetId': '9', 'commentId': '4'}));
      await settle(tester, const Duration(milliseconds: 600));
      // Bildirim listesine düşmemeli; gönderi detayı (ya da geçici Yakında) açılmalı.
      expect(find.byType(NotificationsPage), findsNothing);
      expect(find.text('ana').hitTestable(), findsNothing);
      await unmount(tester);
      PushRouter.session = null;
    });
  });
}
