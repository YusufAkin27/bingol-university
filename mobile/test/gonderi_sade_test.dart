import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart' show ImageSource;
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_api.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/posts/post_text_rules.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextEditingValue, TextSelection;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

/// Yüklemeyi ağa gitmeden sahteler.
class _FakeUploader extends PostMediaUploader {
  _FakeUploader(super.session);
  int calls = 0;

  @override
  Future<PostMedia> upload(Uint8List bytes) async {
    calls++;
    return PostMedia.fromJson(samplePostMedia(id: 4242));
  }
}

bool _shareEnabled(WidgetTester tester) {
  final ink = find.descendant(of: find.byKey(const ValueKey('composeShare')), matching: find.byType(InkWell));
  return tester.widget<InkWell>(ink).onTap != null;
}

void main() {
  setUpAll(loadTestFonts);

  group('metin kurallari', () {
    test('gizli ust sinir: 2200 karakter / 40 satir, sessizce kirpar', () {
      expect(kPostMaxChars, 2200);
      expect(kPostMaxLines, 40);
      expect(clampPostText('kisa'), 'kisa');
      expect(clampPostText('a' * 2500).length, 2200);
      expect(clampPostText(List.filled(60, 'x').join('\n')).split('\n'), hasLength(40));
      // Cok satirli, 7 kelimeyi asan metin serbest.
      const free = 'bir iki uc dort bes alti yedi sekiz\ndokuz on';
      expect(clampPostText(free), free);
      // Vekil cift (emoji) ortadan kesilmez.
      final cut = clampPostText('${'a' * 2199}\u{1F600}');
      expect(cut.length, 2199);
    });

    test('PostTextLimiter yapistirmada sessizce keser', () {
      const f = PostTextLimiter();
      final out = f.formatEditUpdate(
          TextEditingValue.empty, TextEditingValue(text: 'b' * 3000, selection: const TextSelection.collapsed(offset: 3000)));
      expect(out.text.length, 2200);
      expect(out.selection.baseOffset, 2200);
    });
  });

  group('gonderi olustur', () {
    Future<(FakeBackend, FakePosts, _FakeUploader, List<ImageSource>)> open(WidgetTester tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = fakePosts(b);
      final s = makeSession(b);
      final up = _FakeUploader(s);
      final asked = <ImageSource>[];
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        uploader: up,
        cropPhoto: (c, b, spec) async => CropOutcome.cropped(b),
        pickPhoto: (src) async {
          asked.add(src);
          return Uint8List.fromList(kFakePng);
        },
      )));
      await settle(tester, const Duration(milliseconds: 300));
      return (b, fp, up, asked);
    }

    testWidgets('fotograf zorunlu: foto yokken paylas pasif, yalniz galeri/kamera secenegi var', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('composePicker')), findsOneWidget);
      expect(find.byKey(const ValueKey('composePreview')), findsNothing);
      expect(_shareEnabled(tester), isFalse);
      // Metin yazmak foto olmadan paylasmayi acmaz.
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'merhaba');
      await tester.pump();
      expect(_shareEnabled(tester), isFalse);
      // Hashtag/anma/video/hikaye girisleri yok.
      expect(find.byIcon(Icons.videocam), findsNothing);
      noErr(tester);
    });

    testWidgets('tek fotograf secilince onizleme gelir ve paylas aktif olur', (tester) async {
      final (_, _, _, asked) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      // Stitch v3 02: Fotoğraf seç -> iki satırlık kaynak sayfası
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(asked, [ImageSource.gallery]);
      expect(find.byKey(const ValueKey('composePreview')), findsOneWidget);
      expect(find.byKey(const ValueKey('composePicker')), findsNothing);
      expect(_shareEnabled(tester), isTrue);
      // Fotografi degistir / yeniden kirp dugmeleri var, kaldir yok (referans 10).
      expect(find.byKey(const ValueKey('composeChange')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeRecrop')), findsOneWidget);
      expect(find.byKey(const ValueKey('composeRemove')), findsNothing);
      noErr(tester);
    });

    testWidgets('kelime siniri yok: sayac ve uyari gorunmez, paylas acik kalir; cok satirli metin serbest', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeCamera')));
      await settle(tester, const Duration(milliseconds: 300));
      final field = find.byKey(const ValueKey('composeText'));
      expect(find.byKey(const ValueKey('composeCounter')), findsNothing);
      expect(find.textContaining('kelime'), findsNothing);
      await tester.enterText(field, 'bir iki uc dort bes alti yedi sekiz dokuz on onbir oniki');
      await tester.pump();
      expect(find.byKey(const ValueKey('composeLimitWarn')), findsNothing);
      expect(find.textContaining('/7'), findsNothing);
      expect(_shareEnabled(tester), isTrue);
      await tester.enterText(field, 'bir\niki\nuc');
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'bir\niki\nuc');
      noErr(tester);
    });

    testWidgets('2200 karakterde giris sessizce durur (sayac/uyari yok)', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeCamera')));
      await settle(tester, const Duration(milliseconds: 300));
      final field = find.byKey(const ValueKey('composeText'));
      await tester.enterText(field, 'x' * 2600);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text.length, 2200);
      expect(find.textContaining('2200'), findsNothing);
      expect(_shareEnabled(tester), isTrue);
      noErr(tester);
    });

    testWidgets('paylas: once tek foto yuklenir, sonra mediaIds tek ogeyle gonderi olusur', (tester) async {
      final (b, fp, up, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      // Stitch v3 02: Fotoğraf seç -> iki satırlık kaynak sayfası
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'kisa not');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(up.calls, 1);
      final body = b.bodies['POST /posts'] as Map;
      expect(body['mediaIds'], [4242]);
      expect(body['text'], 'kisa not');
      expect(fp.posts.first['media'], hasLength(1));
      noErr(tester);
    });

    testWidgets('metinsiz de paylasilir (metin istege bagli)', (tester) async {
      final (b, _, _, _) = await open(tester);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      // Stitch v3 02: Fotoğraf seç -> iki satırlık kaynak sayfası
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      final body = b.bodies['POST /posts'] as Map;
      expect(body.containsKey('text'), isFalse);
      expect(body['mediaIds'], [4242]);
      noErr(tester);
    });
  });

  group('akis ve detay', () {
    test('video-only (eski bicim) gonderi artik video olarak gorunur, cok gorselli gonderide yalniz ilk foto', () async {
      final b = FakeBackend();
      b.on('/feed*', {
        'items': [
          samplePost(id: 1, media: [samplePostMedia(id: 10, video: true)]),
          samplePost(id: 2, media: [samplePostMedia(id: 20, video: true), samplePostMedia(id: 21)]),
          samplePost(id: 3, media: [samplePostMedia(id: 30), samplePostMedia(id: 31)]),
        ],
        'nextCursor': null,
      });
      final page = await PostApi(makeSession(b)).feed();
      expect(page.items.map((p) => p.id), [1, 2, 3]);
      expect(page.items[0].isVideo, isTrue);
      expect(page.items[1].photo!.id, 21);
      expect(page.items[2].photo!.id, 30);
    });

    testWidgets('detay: foto + yazar + metin + begeni; yorum ve kaydet yok, yorum ucu cagrilmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final p = samplePost(id: 91, text: 'Kisa bir not', media: [samplePostMedia(id: 910)], likeCount: 4);
      b.on('/posts/91', p);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(PostDetailPage(session: s, postId: 91, initial: Post.fromJson(p))));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('post-photo-91')), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Kisa bir not'), findsOneWidget);
      expect(find.byKey(const ValueKey('like-heart')), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // yorum yazma alani yok
      expect(find.byIcon(BuIcons.bookmarkFilled), findsNothing);
      expect(b.requests.any((r) => r.contains('/comments')), isFalse);
      noErr(tester);
    });

    testWidgets('begeni: kalbe dokununca iyimser artar ve PUT /posts/{id}/like gider', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final p = Post.fromJson(samplePost(id: 1000, text: 'Gonderi 1000', media: [samplePostMedia(id: 1)], likeCount: 4));
      await tester.pumpWidget(buildApp(Scaffold(
        body: ListView(children: [
          PostCard(session: s, post: p, onChanged: (_) {}, onDeleted: (_) {}),
        ]),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      expect((tester.widget(find.byKey(const ValueKey('like-count'))) as Text).data, '4');
      await tester.tap(find.byKey(const ValueKey('like-heart')));
      await tester.pump();
      expect((tester.widget(find.byKey(const ValueKey('like-count'))) as Text).data, '5');
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.startsWith('PUT') && r.contains('/posts/1000/like')), isTrue);
      noErr(tester);
    });

    testWidgets('kullanici gonderileri: yorum/kaydet simgesi yok, yorum ucu cagrilmaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b), userId: 12, name: 'Ayşe Yılmaz')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('upost-')), findsWidgets);
      expect(find.byType(PostCard), findsNothing); // 3 sutun izgara, kart listesi degil
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      expect(b.requests.any((r) => r.contains('/comments') || r.contains('/stories') || r.contains('/hashtags')), isFalse);
      noErr(tester);
    });
  });
}
