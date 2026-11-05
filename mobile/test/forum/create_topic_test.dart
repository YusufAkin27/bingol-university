import 'dart:async';
import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/forum/data/forum_draft_store.dart';
import 'package:bu_kampus/features/forum/forum_routes.dart';
import 'package:bu_kampus/features/forum/presentation/pages/create_topic_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_compose.dart';

final _png = Uint8List.fromList(kFakePng);

ForumImage _img(int id) => ForumImage(id: id, url: 'http://localhost/api/forum/media/$id', thumbUrl: 'http://localhost/api/forum/media/$id?thumb', width: 10, height: 10);

class _Env {
  _Env(this.b, this.f, this.c, this.s);
  final FakeBackend b;
  final FakeForum f;
  final FakeForumCompose c;
  final Session s;
  TopicSummary? result;
  bool opened = false;
}

_Env _env({Duration delay = Duration.zero}) {
  final b = FakeBackend(delay: delay);
  final f = fakeForum(b, count: 3);
  final c = fakeForumCompose(b, f);
  return _Env(b, f, c, makeSession(b));
}

/// Giriş sayfası: "open" düğmesi [CreateTopicPage]i (enjekte edilmiş bağımlılıklarla) açar.
Future<void> _open(
  WidgetTester tester,
  _Env e, {
  ForumPhotoPicker? pick,
  ForumImageUploader? upload,
  int? categoryId,
  Brightness brightness = Brightness.light,
  Size size = kPhoneMedium,
  double textScale = 1,
}) async {
  useScreen(tester, size);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(buildApp(
    Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open'),
            onPressed: () async {
              e.opened = true;
              e.result = await Navigator.of(ctx).push<TopicSummary>(MaterialPageRoute(
                settings: const RouteSettings(name: 'forum_create'),
                builder: (_) => CreateTopicPage(
                  session: e.s,
                  categoryId: categoryId,
                  pickPhoto: pick,
                  uploader: upload,
                  draftDebounce: const Duration(milliseconds: 50),
                ),
              ));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
    brightness: brightness,
    size: size,
  ));
  await tester.tap(find.byKey(const ValueKey('open')));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> _fill(WidgetTester tester, {String title = 'Yurt yemekleri', String body = 'Bu hafta yemekler nasıl?', int? category = 2}) async {
  // Önce kategori (liste tembeldir: uzun metin girilince üstteki satır ağaçtan düşebilir).
  if (category != null) {
    await tester.tap(find.byKey(const ValueKey('forumCategoryField')));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byKey(ValueKey('forumCategory$category')));
    await settle(tester, const Duration(milliseconds: 500));
  }
  await tester.enterText(find.byKey(const ValueKey('forumTitle')), title);
  await tester.enterText(find.byKey(const ValueKey('forumBody')), body);
  await settle(tester, const Duration(milliseconds: 200));
}

bool _publishEnabled(WidgetTester tester) {
  final ink = find.descendant(of: find.byKey(const ValueKey('forumPublish')), matching: find.byType(InkWell));
  return tester.widget<InkWell>(ink).onTap != null;
}

Future<void> _publish(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('forumPublish')));
  await settle(tester, const Duration(milliseconds: 800));
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  setUp(() async {
    mockSecureStorage();
    await ForumDraftStore().clear(1);
  });

  group('doğrulama', () {
    testWidgets('boş form: Yayınla pasif; boşluk-only başlık/açıklama kabul edilmez', (tester) async {
      final e = _env();
      await _open(tester, e);
      expect(_publishEnabled(tester), isFalse);
      await _fill(tester, title: '    ', body: '\n  \n');
      expect(_publishEnabled(tester), isFalse);
      expect(find.byKey(const ValueKey('forumComposeHint')), findsOneWidget);
      expect(find.text('Bir başlık yaz.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('forumTitle')), 'Merhaba');
      await settle(tester, const Duration(milliseconds: 200));
      expect(find.text('Bir açıklama yaz.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('forumBody')), 'Gövde');
      await settle(tester, const Duration(milliseconds: 200));
      expect(_publishEnabled(tester), isTrue);
    });

    testWidgets('kategori seçilmeden yayınlanmaz', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester, category: null);
      expect(_publishEnabled(tester), isFalse);
      expect(find.text('Bir kategori seç.'), findsOneWidget);
    });

    testWidgets('başlık 150, açıklama 10000 karakterde kesilir (sayaç yok)', (tester) async {
      final e = _env();
      await _open(tester, e);
      await tester.enterText(find.byKey(const ValueKey('forumTitle')), 'a' * 200);
      await settle(tester, const Duration(milliseconds: 200));
      expect(tester.widget<TextField>(find.byKey(const ValueKey('forumTitle'))).controller!.text.length, 150);
      await tester.enterText(find.byKey(const ValueKey('forumBody')), 'b' * 10050);
      await settle(tester, const Duration(milliseconds: 200));
      expect(tester.widget<TextField>(find.byKey(const ValueKey('forumBody'))).controller!.text.length, 10000);
      expect(find.text('150/150'), findsNothing);
    });

    testWidgets('önceden seçili kategori (çipten gelen)', (tester) async {
      final e = _env();
      await _open(tester, e, categoryId: 3);
      expect(find.text('Dersler'), findsOneWidget);
    });
  });

  group('yayınlama', () {
    testWidgets('başarı: istek gövdesi doğru, çağırana özet döner, detay açılır, taslak silinir', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester);
      await tester.tap(find.byKey(const ValueKey('forumAnonymous')));
      await tester.pump();
      await _publish(tester);
      final body = e.b.bodies['POST /forum/topics'] as Map;
      expect(body['title'], 'Yurt yemekleri');
      expect(body['body'], 'Bu hafta yemekler nasıl?');
      expect(body['categoryId'], 2);
      expect(body['anonymous'], isTrue);
      expect(body['imageIds'], isEmpty);
      expect(body.containsKey('poll'), isFalse);
      expect(e.result, isNotNull);
      expect(e.result!.title, 'Yurt yemekleri');
      // Oluşturma ekranı kalktı, detay (yer tutucu) açıldı.
      expect(find.byKey(const ValueKey('forumTitle')), findsNothing);
      expect(find.bySemanticsLabel('forum_topic'), findsOneWidget);
      expect(await ForumDraftStore().load(1), isNull);
    });

    testWidgets('çift dokunma tek istek üretir ve anahtar gönderilir', (tester) async {
      final e = _env(delay: const Duration(milliseconds: 300));
      await _open(tester, e);
      await _fill(tester);
      final btn = find.byKey(const ValueKey('forumPublish'));
      await tester.tap(btn);
      await tester.tap(btn, warnIfMissed: false);
      await tester.tap(btn, warnIfMissed: false);
      await settle(tester, const Duration(seconds: 2));
      expect(e.c.createCalls, 1);
      expect(e.c.createKeys.single, isNotNull);
      expect(e.f.topics.where((t) => t['title'] == 'Yurt yemekleri').length, 1);
    });

    for (final c in [
      (const FakeResult.json({'code': 'CONTENT_PROFANITY', 'message': 'x'}, status: 422), 'uygunsuz ifade'),
      (const FakeResult.json({'code': 'RATE_LIMITED', 'message': 'x'}, status: 429), 'Çok sık'),
      (const FakeResult.json({'code': 'FORUM_DUPLICATE_CONTENT', 'message': 'x'}, status: 429), 'Aynı içeriği'),
      (const FakeResult.json({'code': 'FORUM_CATEGORY_ARCHIVED', 'message': 'x'}, status: 409), 'kategori artık'),
      (const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500), 'yayınlanamadı'),
    ]) {
      testWidgets('hata ${c.$1.status} ${(c.$1.json as Map)['code']}: kısa mesaj, yazılanlar korunur', (tester) async {
        final e = _env();
        await _open(tester, e);
        await _fill(tester);
        e.c.createError = c.$1;
        await _publish(tester);
        expect(find.byKey(const ValueKey('forumComposeError')), findsOneWidget);
        expect(find.textContaining(c.$2), findsOneWidget);
        final title = tester.widget<TextField>(find.byKey(const ValueKey('forumTitle')));
        final body = tester.widget<TextField>(find.byKey(const ValueKey('forumBody')));
        expect(title.controller!.text, 'Yurt yemekleri');
        expect(body.controller!.text, 'Bu hafta yemekler nasıl?');
        expect(e.result, isNull);
        expect(find.byKey(const ValueKey('forumTitle')), findsOneWidget); // hâlâ formda
      });
    }

    testWidgets('ağ yok: kısa mesaj, metin korunur, ağ gelince tekrar gönderilebilir', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester);
      e.b.offline = true;
      await _publish(tester);
      expect(find.textContaining('İnternet bağlantısı yok'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('forumTitle'))).controller!.text, 'Yurt yemekleri');
      e.b.offline = false;
      await _publish(tester);
      expect(e.result, isNotNull);
      expect(e.f.topics.where((t) => t['title'] == 'Yurt yemekleri').length, 1);
    });

    testWidgets('sunucu hatasından sonra yeniden deneme AYNI Idempotency-Key ile gider', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester);
      e.c.createError = const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
      await _publish(tester);
      e.c.createError = null;
      await _publish(tester);
      expect(e.c.createCalls, 2);
      expect(e.c.createKeys[0], e.c.createKeys[1]);
      expect(e.result, isNotNull);
      expect(e.f.topics.where((t) => t['title'] == 'Yurt yemekleri').length, 1);
    });

    testWidgets('içerik değişince yeni anahtar üretilir', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester);
      e.c.createError = const FakeResult.json({'code': 'CONTENT_PROFANITY', 'message': 'x'}, status: 422);
      await _publish(tester);
      await tester.enterText(find.byKey(const ValueKey('forumBody')), 'Başka bir gövde');
      await settle(tester, const Duration(milliseconds: 200));
      e.c.createError = null;
      await _publish(tester);
      expect(e.c.createKeys.toSet().length, 2);
    });
  });

  group('görseller', () {
    testWidgets('yükleme bitmeden yayınlanmaz; bitince görsel kimliği gönderilir', (tester) async {
      final e = _env();
      final done = Completer<ForumImage>();
      await _open(tester, e, pick: (_) async => _png, upload: (_) => done.future);
      await _fill(tester);
      expect(_publishEnabled(tester), isTrue);
      await tester.tap(find.byKey(const ValueKey('forumImageAdd')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('forumPickGallery')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('forumImage0')), findsOneWidget);
      expect(_publishEnabled(tester), isFalse);
      expect(find.text('Görseller yüklenince yayınlayabilirsin.'), findsOneWidget);
      done.complete(_img(77));
      await settle(tester, const Duration(milliseconds: 300));
      expect(_publishEnabled(tester), isTrue);
      await _publish(tester);
      expect((e.b.bodies['POST /forum/topics'] as Map)['imageIds'], [77]);
    });

    testWidgets('yükleme hatası: yeniden dene, sonra başarı; kaldırınca yayınlanabilir', (tester) async {
      final e = _env();
      var calls = 0;
      await _open(tester, e, pick: (_) async => _png, upload: (_) async {
        calls++;
        if (calls == 1) throw ImageException('TOO_LARGE');
        return _img(5);
      });
      await _fill(tester);
      await tester.tap(find.byKey(const ValueKey('forumImageAdd')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('forumPickGallery')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('forumImageRetry')), findsOneWidget);
      expect(_publishEnabled(tester), isFalse);
      expect(find.text('Görsel çok büyük.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forumImageRetry')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('forumImageRetry')), findsNothing);
      expect(_publishEnabled(tester), isTrue);
      expect(calls, 2);
      // Kaldır
      await tester.tap(find.byKey(const ValueKey('forumImageRemove')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('forumImage0')), findsNothing);
      expect(_publishEnabled(tester), isTrue);
    });

    testWidgets('en çok 4 görsel: dördüncüden sonra ekle karesi kalkar', (tester) async {
      final e = _env();
      var id = 0;
      await _open(tester, e, pick: (_) async => _png, upload: (_) async => _img(++id));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('forumImageAdd')));
        await settle(tester, const Duration(milliseconds: 500));
        await tester.tap(find.byKey(const ValueKey('forumPickGallery')));
        await settle(tester, const Duration(milliseconds: 500));
      }
      expect(find.byKey(const ValueKey('forumImageAdd')), findsNothing);
      expect(find.text('4/4 görsel'), findsOneWidget);
    });

    testWidgets('seçim iptal: görsel eklenmez', (tester) async {
      final e = _env();
      await _open(tester, e, pick: (_) async => null, upload: (_) async => _img(1));
      await tester.tap(find.byKey(const ValueKey('forumImageAdd')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('forumPickGallery')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('forumImage0')), findsNothing);
    });
  });

  group('anket', () {
    testWidgets('anket ekle: 2 boş seçenek; 6 sınırı; silme 2 altına inmez', (tester) async {
      final e = _env();
      await _open(tester, e);
      await tester.ensureVisible(find.byKey(const ValueKey('forumPollAdd')));
      await tester.tap(find.byKey(const ValueKey('forumPollAdd')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('pollBuilder')), findsOneWidget);
      expect(find.byKey(const ValueKey('pollOpt0')), findsOneWidget);
      expect(find.byKey(const ValueKey('pollOpt1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pollOptRemove0')), findsNothing);
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(find.byKey(const ValueKey('pollAddOption')));
        await tester.tap(find.byKey(const ValueKey('pollAddOption')));
        await settle(tester, const Duration(milliseconds: 300));
      }
      expect(find.byKey(const ValueKey('pollOpt5')), findsOneWidget);
      expect(find.text('En çok 6 seçenek eklenebilir.'), findsOneWidget);
      final add = tester.widget<TextButton>(find.byKey(const ValueKey('pollAddOption')));
      expect(add.onPressed, isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('pollOptRemove5')));
      await tester.tap(find.byKey(const ValueKey('pollOptRemove5')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('pollOpt5')), findsNothing);
    });

    testWidgets('geçersiz anket yayını engeller; geçerli anket gövdede gider (bitiş + oy değiştirme)', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('forumPollAdd')));
      await tester.tap(find.byKey(const ValueKey('forumPollAdd')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(_publishEnabled(tester), isFalse);
      expect(find.text('Ankette en az 2 dolu seçenek olmalı.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('pollOpt0')), 'Evet');
      await tester.enterText(find.byKey(const ValueKey('pollOpt1')), 'Hayır');
      await settle(tester, const Duration(milliseconds: 200));
      expect(_publishEnabled(tester), isTrue);
      await tester.ensureVisible(find.byKey(const ValueKey('pollEnds3')));
      await tester.tap(find.byKey(const ValueKey('pollEnds3')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pollEndsLabel')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('pollAllowChange')));
      await tester.tap(find.byKey(const ValueKey('pollAllowChange')));
      await tester.pump();
      await _publish(tester);
      final poll = (e.b.bodies['POST /forum/topics'] as Map)['poll'] as Map;
      expect(poll['options'], ['Evet', 'Hayır']);
      expect(poll['allowChangeVote'], isTrue);
      final ends = DateTime.parse(poll['endsAt'] as String);
      final d = ends.difference(DateTime.now().toUtc());
      expect(d.inHours, inInclusiveRange(70, 72));
    });

    testWidgets('anketi kaldır', (tester) async {
      final e = _env();
      await _open(tester, e);
      await tester.ensureVisible(find.byKey(const ValueKey('forumPollAdd')));
      await tester.tap(find.byKey(const ValueKey('forumPollAdd')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('pollRemove')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('pollBuilder')), findsNothing);
      expect(find.byKey(const ValueKey('forumPollAdd')), findsOneWidget);
    });
  });

  group('anonim', () {
    testWidgets('anahtar varsayılan kapalı, açıklama ve uyarı görünür', (tester) async {
      final e = _env();
      await _open(tester, e);
      await tester.ensureVisible(find.byKey(const ValueKey('forumAnonymous')));
      expect(find.text('Adın diğer öğrencilere gösterilmez.'), findsOneWidget);
      expect(find.text('Moderatörler kötüye kullanımı görebilir.'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await _fill(tester);
      await _publish(tester);
      expect((e.b.bodies['POST /forum/topics'] as Map)['anonymous'], isFalse);
    });
  });

  group('taslak', () {
    testWidgets('yazarken otomatik kaydedilir; yeniden açılınca geri yüklenir', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester, title: 'Taslak başlık', body: 'Taslak gövde');
      await tester.pump(const Duration(milliseconds: 200));
      final saved = await tester.runAsync(() => ForumDraftStore().load(1));
      expect(saved, isNotNull);
      expect(saved!.title, 'Taslak başlık');
      expect(saved.categoryId, 2);
      // Geri: sorulur; "Taslağı kaydet" -> kapanır, taslak durur.
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('draftSave')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('draftSave')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('forumTitle')), findsNothing);
      // Yeniden aç
      await tester.tap(find.byKey(const ValueKey('open')));
      await settle(tester, const Duration(milliseconds: 800));
      final title = tester.widget<TextField>(find.byKey(const ValueKey('forumTitle')));
      expect(title.controller!.text, 'Taslak başlık');
      expect(find.text('Taslak geri yüklendi'), findsOneWidget);
    });

    testWidgets('çıkışta Sil: taslak silinir', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester, title: 'Silinecek', body: 'x');
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('draftDiscard')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('forumTitle')), findsNothing);
      final d = await tester.runAsync(() => ForumDraftStore().load(1));
      expect(d, isNull);
    });

    testWidgets('çıkışta Devam et: formda kalır', (tester) async {
      final e = _env();
      await _open(tester, e);
      await _fill(tester, title: 'Kalsın', body: 'x');
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('draftKeep')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('forumTitle')), findsOneWidget);
    });

    testWidgets('değişiklik yoksa çıkışta soru sorulmaz', (tester) async {
      final e = _env();
      await _open(tester, e);
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('draftSave')), findsNothing);
      expect(find.byKey(const ValueKey('forumTitle')), findsNothing);
    });

    testWidgets('görsel taslakta yalnız yüklenmiş kimlikle tutulur', (tester) async {
      final e = _env();
      final never = Completer<ForumImage>();
      var n = 0;
      await _open(tester, e, pick: (_) async => _png, upload: (_) {
        n++;
        return n == 1 ? Future.value(_img(41)) : never.future;
      });
      await _fill(tester, title: 'T', body: 'B');
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('forumImageAdd')));
        await settle(tester, const Duration(milliseconds: 500));
        await tester.tap(find.byKey(const ValueKey('forumPickGallery')));
        await settle(tester, const Duration(milliseconds: 500));
      }
      await tester.pump(const Duration(milliseconds: 200));
      final d = await tester.runAsync(() => ForumDraftStore().load(1));
      expect(d!.images.map((i) => i.id), [41]);
    });
  });

  group('görünüm', () {
    for (final dark in [false, true]) {
      testWidgets('küçük ekran + büyük yazı ölçeği taşmaz (${dark ? 'koyu' : 'açık'})', (tester) async {
        final e = _env();
        await _open(tester, e,
            brightness: dark ? Brightness.dark : Brightness.light, size: kPhoneSmall, textScale: 2, pick: (_) async => _png, upload: (_) async => _img(1));
        await _fill(tester);
        await tester.enterText(find.byKey(const ValueKey('forumTitle')), 'Çok uzun bir başlık ' * 6);
        await tester.enterText(find.byKey(const ValueKey('forumBody')), 'Uzun gövde ' * 40);
        await settle(tester, const Duration(milliseconds: 200));
        final list = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.byKey(const ValueKey('forumImageAdd')), 200, scrollable: list);
        await tester.ensureVisible(find.byKey(const ValueKey('forumImageAdd')));
        await settle(tester, const Duration(milliseconds: 200));
        await tester.tap(find.byKey(const ValueKey('forumImageAdd')));
        await settle(tester, const Duration(milliseconds: 500));
        await tester.tap(find.byKey(const ValueKey('forumPickGallery')));
        await settle(tester, const Duration(milliseconds: 500));
        await tester.scrollUntilVisible(find.byKey(const ValueKey('forumPollAdd')), 200, scrollable: list);
        await tester.ensureVisible(find.byKey(const ValueKey('forumPollAdd')));
        await settle(tester, const Duration(milliseconds: 200));
        await tester.tap(find.byKey(const ValueKey('forumPollAdd')));
        await settle(tester, const Duration(milliseconds: 500));
        await tester.scrollUntilVisible(find.byKey(const ValueKey('forumAnonymous')), 200, scrollable: list);
        await tester.ensureVisible(find.byKey(const ValueKey('forumAnonymous')));
        await settle(tester, const Duration(milliseconds: 200));
        await settle(tester, const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
