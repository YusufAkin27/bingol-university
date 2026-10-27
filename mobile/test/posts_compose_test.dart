import 'dart:async';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_draft_store.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

/// Gerçek ağ/sıkıştırma yok: her öğe için kapı (Completer) ile yükleme denetlenir.
class _FakeUploader extends PostMediaUploader {
  _FakeUploader(super.session);

  final started = <String>[];
  final gates = <String, Completer<void>>{};
  final failures = <String, PostUploadException>{};
  int active = 0;
  int maxActive = 0;

  void hold(String key) => gates[key] = Completer<void>();
  void release(String key) => gates[key]?.complete();

  @override
  Future<PostMedia> upload(MediaPick item, {void Function(double)? onProgress, PostUploadCancel? cancel}) async {
    started.add(item.key);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      onProgress?.call(.5);
      final g = gates[item.key];
      if (g != null) await g.future;
      final f = failures[item.key];
      if (f != null) throw f;
      onProgress?.call(1);
      return PostMedia(
        id: int.parse(item.key.replaceAll(RegExp(r'\D'), '')),
        kind: item.isVideo ? PostMediaKind.video : PostMediaKind.image,
        url: '/api/posts/media/1',
      );
    } finally {
      active--;
    }
  }
}

const _postJson = {
  'id': 91,
  'author': {'id': 1, 'displayName': 'Ayşe Yılmaz'},
  'text': 'merhaba',
  'media': <Object>[],
  'likeCount': 0,
  'commentCount': 0,
  'mine': true,
};

class _Rig {
  _Rig(this.be) : session = makeSession(be) {
    up = _FakeUploader(session);
  }
  final FakeBackend be;
  final Session session;
  late final _FakeUploader up;
  final results = <Object?>[];
  final lib = FakeMediaLibrary.photos(6, videos: [FakeMediaLibrary.video('v1')]);

  ComposePostPage page({List<MediaPick> media = const [], String? text}) => ComposePostPage(
        session: session,
        initialMedia: media,
        initialText: text,
        library: lib,
        ensureAccess: (c, p, {rationale}) async => true,
        uploader: up,
      );

  Future<void> open(WidgetTester tester, ComposePostPage Function() build,
      {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
    useScreen(tester, size);
    await tester.pumpWidget(buildApp(
      Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => results.add(await Navigator.push<Post>(c, MaterialPageRoute(builder: (_) => build()))),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
      brightness: b,
      size: size,
    ));
    await tester.tap(find.text('aç'));
    await settle(tester, const Duration(milliseconds: 500));
  }
}

_Rig _rig([FakeBackend? be]) => _Rig((be ?? FakeBackend())..on('/posts', _postJson));

final _share = find.byKey(const ValueKey('composeShare'));
final _text = find.byKey(const ValueKey('composeText'));
Finder _item(String k) => find.byKey(ValueKey('composeItem_$k'));

bool _shareEnabled(WidgetTester t) => t.widget<BuButton>(_share).onPressed != null;

Future<void> _tapShare(WidgetTester t) async {
  await t.tap(_share);
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail(e is FlutterError ? e.diagnostics.map((d) => d.toStringDeep()).join(' | ') : '$e');
}

List<MediaPick> _photos(int n) => [for (var i = 1; i <= n; i++) fakePhotoPick('p$i')];

void main() {
  setUpAll(loadTestFonts);
  setUp(() async {
    mockSecureStorage();
  });

  Future<void> clearDraft(WidgetTester tester) => PostDraftStore().clear(1);

  group('metin ve Paylaş düğmesi', () {
    testWidgets('boşken Paylaş devre dışı; yazınca açılır; sayaç 1800\'den sonra; sınır 2000', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      await r.open(tester, () => r.page());
      expect(_shareEnabled(tester), isFalse);
      expect(find.text('Ne düşünüyorsun?'), findsOneWidget);
      await tester.enterText(_text, 'selam');
      await tester.pump();
      expect(_shareEnabled(tester), isTrue);
      expect(find.byKey(const ValueKey('composeCounter')), findsNothing);
      await tester.enterText(_text, 'a' * 1850);
      await tester.pump();
      expect(find.text('1850/2000'), findsOneWidget);
      await tester.enterText(_text, 'a' * 2100);
      await tester.pump();
      expect(find.text('2000/2000'), findsOneWidget);
      await tester.enterText(_text, '   ');
      await tester.pump();
      expect(_shareEnabled(tester), isFalse);
      await unmount(tester);
      _ok(tester);
    });
  });

  group('medya', () {
    testWidgets('galeriden ekle, kaldır, yeniden sırala', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      await r.open(tester, () => r.page());
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      await settle(tester, const Duration(milliseconds: 500));
      _ok(tester);
      await tester.tap(find.byKey(const ValueKey('galleryTile_p1')));
      await tester.pump();
      _ok(tester);
      await tester.tap(find.byKey(const ValueKey('galleryTile_p2')));
      await tester.pump();
      _ok(tester);
      await tester.tap(find.byKey(const ValueKey('pickerSend')));
      await settle(tester, const Duration(milliseconds: 500));
      _ok(tester);
      expect(_item('p1'), findsOneWidget);
      expect(_item('p2'), findsOneWidget);
      expect(find.text('2/10'), findsOneWidget);
      expect(_shareEnabled(tester), isTrue);

      // Sürükleyerek sırala: p1 -> p2'nin sağına.
      final x1 = tester.getCenter(_item('p1')).dx;
      expect(x1, lessThan(tester.getCenter(_item('p2')).dx));
      final g = await tester.startGesture(tester.getCenter(_item('p1')));
      await tester.pump(const Duration(milliseconds: 700));
      await g.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await g.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await settle(tester, const Duration(milliseconds: 600));
      expect(tester.getCenter(_item('p1')).dx, greaterThan(tester.getCenter(_item('p2')).dx));

      await tester.tap(find.byKey(const ValueKey('composeRemove_p2')));
      await tester.pump();
      expect(_item('p2'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('composeRemove_p1')));
      await tester.pump();
      expect(find.byKey(const ValueKey('composeStrip')), findsNothing);
      expect(_shareEnabled(tester), isFalse);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('video rozeti süreyi gösterir; en çok 10 öğe', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      await r.open(tester, () => r.page(media: [fakeVideoPick('v1', ms: 75000), ..._photos(12)]));
      expect(find.text('1:15'), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);
      await unmount(tester);
      _ok(tester);
    });
  });

  group('paylaşma', () {
    testWidgets('en çok 3 paralel yükler, sırayı korur, ilerleme gösterir ve Post döner', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      for (var i = 1; i <= 5; i++) {
        r.up.hold('p$i');
      }
      await r.open(tester, () => r.page(media: _photos(5), text: 'merhaba'));
      await _tapShare(tester);
      expect(r.up.started, ['p1', 'p2', 'p3']);
      expect(r.up.maxActive, 3);
      expect(find.byKey(const ValueKey('composeProgress_p1')), findsOneWidget);
      expect(_shareEnabled(tester), isFalse); // yükleme sürerken devre dışı
      expect(r.be.count('POST /posts'), 0);

      r.up.release('p3');
      await tester.pump(const Duration(milliseconds: 50));
      expect(r.up.started, ['p1', 'p2', 'p3', 'p4']);
      for (final k in ['p1', 'p2', 'p4', 'p5']) {
        r.up.release(k);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.up.maxActive, 3);
      expect((r.be.bodies['POST /posts'] as Map)['mediaIds'], [1, 2, 3, 4, 5]);
      expect((r.be.bodies['POST /posts'] as Map)['text'], 'merhaba');
      expect(r.results.single, isA<Post>());
      expect((r.results.single as Post).id, 91);
      expect(find.text('Paylaşıldı'), findsOneWidget);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('tek öğe hatasında gönderi oluşmaz; yeniden dene ile tamamlanır', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      r.up.failures['p2'] = PostUploadException('Bağlantı yok, tekrar dene.');
      await r.open(tester, () => r.page(media: _photos(3)));
      await _tapShare(tester);
      await settle(tester, const Duration(milliseconds: 400));
      expect(r.be.count('POST /posts'), 0);
      expect(find.byKey(const ValueKey('composeNotice')), findsOneWidget);
      expect(find.textContaining('1 medya yüklenemedi'), findsOneWidget);
      expect(find.byKey(const ValueKey('composeRetry_p2')), findsOneWidget);
      expect(_shareEnabled(tester), isTrue);

      r.up.failures.clear();
      await tester.tap(find.byKey(const ValueKey('composeRetryFailed')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('composeNotice')), findsNothing);
      // yalnız başarısız öğe yeniden yüklendi
      expect(r.up.started.where((k) => k == 'p1').length, 1);
      expect(r.up.started.where((k) => k == 'p2').length, 2);
      await _tapShare(tester);
      await settle(tester, const Duration(milliseconds: 600));
      expect((r.be.bodies['POST /posts'] as Map)['mediaIds'], [1, 2, 3]);
      expect(r.results.single, isA<Post>());
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('başarısız öğe çıkarılırsa kalanlarla paylaşılır', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      r.up.failures['p2'] = PostUploadException('Medya geçersiz.', retryable: false);
      await r.open(tester, () => r.page(media: _photos(3)));
      await _tapShare(tester);
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('composeRemoveFailed')));
      await tester.pump();
      expect(_item('p2'), findsNothing);
      await _tapShare(tester);
      await settle(tester, const Duration(milliseconds: 600));
      expect((r.be.bodies['POST /posts'] as Map)['mediaIds'], [1, 3]);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('CONTENT_PROFANITY 422: alan altında mesaj, sayfa açık kalır', (tester) async {
      await clearDraft(tester);
      final be = FakeBackend()..fail('/posts', status: 422, code: 'CONTENT_PROFANITY', message: 'x');
      final r = _Rig(be);
      await r.open(tester, () => r.page(text: 'kötü söz'));
      await _tapShare(tester);
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.widget<Text>(find.byKey(const ValueKey('composeTextError'))).data, 'Bu alanda uygunsuz ifade kullanılamaz. Lütfen metni düzenleyin.');
      expect(r.results, isEmpty);
      expect(_shareEnabled(tester), isTrue);
      // metin düzenlenince hata kalkar
      await tester.enterText(_text, 'temiz');
      await tester.pump();
      expect(find.byKey(const ValueKey('composeTextError')), findsNothing);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('429: yavaşla mesajı', (tester) async {
      await clearDraft(tester);
      final be = FakeBackend()..fail('/posts', status: 429, code: 'RATE_LIMITED');
      final r = _Rig(be);
      await r.open(tester, () => r.page(text: 'a'));
      await _tapShare(tester);
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Çok hızlı paylaşım yapıyorsun, biraz bekle.'), findsOneWidget);
      expect(r.results, isEmpty);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('ağ hatası: sayfa ve taslak korunur', (tester) async {
      await clearDraft(tester);
      final be = FakeBackend()..network('/posts');
      final r = _Rig(be);
      await r.open(tester, () => r.page(text: 'önemli metin'));
      await _tapShare(tester);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Taslağın korundu'), findsOneWidget);
      expect(r.results, isEmpty);
      final d = await PostDraftStore().load(1);
      expect(d?.text, 'önemli metin');
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('yükleme sürerken sayfa kapanırsa istisna olmaz', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      r.up.hold('p1');
      await r.open(tester, () => r.page(media: _photos(1)));
      await _tapShare(tester);
      await unmount(tester);
      r.up.release('p1');
      await tester.pump(const Duration(milliseconds: 200));
      _ok(tester);
    });
  });

  group('taslak ve kapatma', () {
    testWidgets('yazılan taslak kaydedilir, yeniden açılınca geri yüklenir', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      await r.open(tester, () => r.page());
      await tester.enterText(_text, 'yarım kalan');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await unmount(tester);

      final r2 = _rig();
      await r2.open(tester, () => r2.page());
      expect(find.byKey(const ValueKey('composeDraftBanner')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeDraftRestore')));
      await tester.pump();
      expect(find.text('yarım kalan'), findsOneWidget);
      expect(find.byKey(const ValueKey('composeDraftBanner')), findsNothing);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('medya taslağı geri yüklenir; 24 saatten eski taslak yok sayılır', (tester) async {
      await clearDraft(tester);
      final store = PostDraftStore();
      final m = await store.materialize(fakePhotoPick('p7'));
      expect(m, isNotNull);
      await store.save(1, PostDraft(text: 'x', items: [m!], savedAt: DateTime.now()));
      final r = _rig();
      await r.open(tester, () => r.page());
      await tester.tap(find.byKey(const ValueKey('composeDraftRestore')));
      await tester.pump();
      expect(_item('p7'), findsOneWidget);
      await unmount(tester);

      await store.save(1, PostDraft(text: 'eski', items: const [], savedAt: DateTime.now().subtract(const Duration(hours: 25))));
      final r2 = _rig();
      await r2.open(tester, () => r2.page());
      expect(find.byKey(const ValueKey('composeDraftBanner')), findsNothing);
      await unmount(tester);
      _ok(tester);
    });

    testWidgets('kapatma: boşken doğrudan; değişiklik varsa onay (Devam / Taslağı sil)', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      await r.open(tester, () => r.page());
      await tester.tap(find.byKey(const ValueKey('composeClose')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Yeni gönderi'), findsNothing); // kapandı
      expect(r.results.single, isNull);

      await tester.tap(find.text('aç'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.enterText(_text, 'silinecek');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('composeClose')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Taslağı sil'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeKeep')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Yeni gönderi'), findsOneWidget);

      // Android geri tuşu da aynı onayı açar.
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Taslağı sil'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeDiscard')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Yeni gönderi'), findsNothing);
      expect(await PostDraftStore().load(1), isNull);
      _ok(tester);
    });
  });

  group('gerçek yükleyici (FakeBackend)', () {
    testWidgets('görsel POST /posts/media -> PostMedia; ilerleme 1\'e ulaşır', (tester) async {
      final be = FakeBackend()
        ..on('/posts/media', {'id': 5, 'kind': 'IMAGE', 'url': '/api/posts/media/5', 'width': 10, 'height': 20});
      final up = PostMediaUploader(makeSession(be), client: be.client);
      final prog = <double>[];
      final m = await up.upload(fakePhotoPick('a'), onProgress: prog.add);
      expect(m.id, 5);
      expect(m.isVideo, isFalse);
      expect(be.requests, contains('POST /posts/media'));
      expect(prog.last, 1);
    });

    testWidgets('hata kodları Türkçe kısa mesaja eşlenir', (tester) async {
      final cases = <(int, String, String)>[
        (413, 'VIDEO_TOO_LARGE', 'Video çok büyük (en fazla 40 MB).'),
        (400, 'VIDEO_TOO_LONG', 'Video en fazla 60 saniye olabilir.'),
        (400, 'VIDEO_INVALID', 'Video biçimi desteklenmiyor.'),
        (422, 'MEDIA_BLOCKED', 'Bu içerik paylaşılamaz.'),
        (400, 'POST_MEDIA_INVALID', 'Medya geçersiz, yeniden yükle.'),
        (429, 'RATE_LIMITED', 'Çok hızlı paylaşım yapıyorsun, biraz bekle.'),
      ];
      for (final (status, code, msg) in cases) {
        final be = FakeBackend()..fail('/posts/media', status: status, code: code, message: 'sunucu');
        final up = PostMediaUploader(makeSession(be), client: be.client);
        await expectLater(
          up.upload(fakePhotoPick('a')),
          throwsA(isA<PostUploadException>().having((e) => e.message, 'message', msg)),
          reason: code,
        );
      }
      final be = FakeBackend()..network('/posts/media');
      final up = PostMediaUploader(makeSession(be), client: be.client);
      await expectLater(
        up.upload(fakePhotoPick('a')),
        throwsA(isA<PostUploadException>().having((e) => e.message, 'message', 'Bağlantı yok, tekrar dene.')),
      );
      expect(postErrorText(ApiError(0, 'NETWORK', '')), 'Bağlantı yok, tekrar dene.');
    });
  });

  group('yerleşim', () {
    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        testWidgets('${size.width.toInt()} dp ${b.name}: taşma yok (10 medya, bildirim, hata, taslak şeridi)', (tester) async {
          await clearDraft(tester);
          final r = _rig();
          r.up.failures['p3'] = PostUploadException('Bağlantı yok, tekrar dene.');
          await r.open(tester, () => r.page(media: [fakeVideoPick('v1', ms: 59000), ..._photos(9)], text: 'a' * 1900),
              b: b, size: size);
          expect(find.text('1900/2000'), findsOneWidget);
          await _tapShare(tester);
          await settle(tester, const Duration(milliseconds: 500));
          expect(find.byKey(const ValueKey('composeNotice')), findsOneWidget);
          _ok(tester);
          // klavye benzeri alt boşluk: araç çubuğu görünür kalır
          expect(find.byKey(const ValueKey('composeGallery')), findsOneWidget);
          await unmount(tester);
          _ok(tester);
        });
      }
    }

    testWidgets('klavye açıkken (alt boşluk) araç çubuğu üstte kalır, taşma yok', (tester) async {
      await clearDraft(tester);
      final r = _rig();
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(MaterialApp(
        theme: BuTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640), viewInsets: EdgeInsets.only(bottom: 300)),
          child: r.page(media: _photos(4), text: 'merhaba'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      _ok(tester);
      expect(tester.getBottomLeft(find.byKey(const ValueKey('composeGallery'))).dy, lessThanOrEqualTo(640));
      await unmount(tester);
    });
  });
}
