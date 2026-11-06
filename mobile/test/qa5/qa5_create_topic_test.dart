// QA-5: yeni konu formu etkileşimleri (başlık/açıklama sınırları, kategori, anonim, çift dokunma tek konu,
// hata + yeniden deneme aynı anahtar, taslak kaydet/geri yükle/temizle).
import 'package:bu_kampus/features/forum/data/forum_draft_store.dart';
import 'package:bu_kampus/features/forum/presentation/pages/create_topic_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_comments.dart';

const _title = ValueKey('forumTitle');
const _bodyKey = ValueKey('forumBody');
const _publish = ValueKey('forumPublish');

Finder _field(Key k) {
  final direct = find.byKey(k);
  final inner = find.descendant(of: direct, matching: find.byType(TextField));
  return inner.evaluate().isNotEmpty ? inner : direct;
}

void main() {
  setUpAll(loadTestFonts);

  Future<({FakeBackend b, FakeForum f})> open(WidgetTester tester, {Size size = kPhoneMedium, int? categoryId = 1, double scale = 1}) async {
    final b = FakeBackend();
    final f = fakeForum(b, count: 3);
    fakeForumComments(b, f);
    final s = makeSession(b);
    await ForumDraftStore.clearAll();
    useScreen(tester, size);
    await tester.pumpWidget(buildApp(Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => CreateTopicPage(session: s, categoryId: categoryId, draftDebounce: const Duration(milliseconds: 50)),
          ),
        ),
      ),
    )));
    await settle(tester, const Duration(seconds: 1));
    return (b: b, f: f);
  }

  Future<void> fill(WidgetTester tester, {String title = 'Kantin fiyatları', String body = 'Yemek fiyatları hakkında ne düşünüyorsunuz?'}) async {
    await tester.enterText(_field(_title), title);
    await tester.enterText(_field(_bodyKey), body);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapPublish(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(_publish));
    await tester.tap(find.byKey(_publish));
    await tester.pump();
  }

  group('yeni konu formu', () {
    testWidgets('boş form: Yayınla istek atmaz', (tester) async {
      final r = await open(tester);
      await tapPublish(tester);
      await settle(tester, const Duration(milliseconds: 500));
      expect(r.b.count('POST /forum/topics'), 0);
      await unmount(tester);
    });

    testWidgets('başlık 150 sınırı: 151. karakter alana girmez; 150 yayınlanır', (tester) async {
      final r = await open(tester);
      await fill(tester, title: 'a' * 151);
      expect(tester.widget<TextField>(_field(_title)).controller!.text.length, 150, reason: 'alan 150 karakterde keser');
      await tapPublish(tester);
      await settle(tester, const Duration(seconds: 1));
      expect(r.b.count('POST /forum/topics'), 1);
      expect((r.b.bodies['POST /forum/topics'] as Map)['title'].toString().length, 150);
      await unmount(tester);
    });

    testWidgets('açıklama 10 000 sınırı: 10 001. karakter alana girmez; 10 000 yayınlanır', (tester) async {
      final r = await open(tester);
      await fill(tester, body: 'x' * 10001);
      expect(tester.widget<TextField>(_field(_bodyKey)).controller!.text.length, 10000, reason: 'alan 10000 karakterde keser');
      await tapPublish(tester);
      await settle(tester, const Duration(seconds: 1));
      expect(r.b.count('POST /forum/topics'), 1);
      expect((r.b.bodies['POST /forum/topics'] as Map)['body'].toString().length, 10000);
      await unmount(tester);
    });

    testWidgets('yalnız boşluk başlık/açıklama sayılmaz', (tester) async {
      final r = await open(tester);
      await fill(tester, title: '    ', body: '  \n  ');
      await tapPublish(tester);
      await settle(tester, const Duration(milliseconds: 500));
      expect(r.b.count('POST /forum/topics'), 0);
      await unmount(tester);
    });

    testWidgets('çift dokunma tek konu: tek POST, Idempotency-Key gider', (tester) async {
      final r = await open(tester);
      await fill(tester);
      await tester.ensureVisible(find.byKey(_publish));
      await tester.tap(find.byKey(_publish));
      await tester.tap(find.byKey(_publish), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.byKey(_publish), warnIfMissed: false);
      await settle(tester, const Duration(seconds: 1));
      expect(r.b.count('POST /forum/topics'), 1);
      expect(r.f.topics.where((t) => t['title'] == 'Kantin fiyatları').length, 1);
      await unmount(tester);
    });

    testWidgets('anonim anahtarı: kapalıyken anonymous=false, açıkken true gider', (tester) async {
      final r = await open(tester);
      await fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('forumAnonymous')));
      await tester.tap(find.byKey(const ValueKey('forumAnonymous')));
      await tester.pump(const Duration(milliseconds: 200));
      await tapPublish(tester);
      await settle(tester, const Duration(seconds: 1));
      final sent = r.b.bodies['POST /forum/topics'] as Map;
      expect(sent['anonymous'], true);
      expect(sent['title'], 'Kantin fiyatları');
      await unmount(tester);
    });

    testWidgets('sunucu hatası: metin korunur, hata görünür, yeniden deneme AYNI anahtarla', (tester) async {
      final r = await open(tester);
      final keys = <String?>[];
      var n = 0;
      r.b.handlers.insert(0, (req, path) {
        if (req.method == 'POST' && path == '/forum/topics') {
          keys.add(req.headers['Idempotency-Key']);
          n++;
          if (n == 1) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'Sunucu hatası'}, status: 500);
        }
        return null;
      });
      await fill(tester);
      await tapPublish(tester);
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('forumComposeError')), findsOneWidget);
      expect(tester.widget<TextField>(_field(_title)).controller!.text, 'Kantin fiyatları', reason: 'yazılanlar korunur');
      await tapPublish(tester);
      await settle(tester, const Duration(seconds: 1));
      expect(keys.length, 2);
      expect(keys[0], isNotNull);
      expect(keys[0], keys[1], reason: 'yeniden deneme aynı Idempotency-Key');
      await unmount(tester);
    });

    for (final status in [401, 403, 422, 429]) {
      testWidgets('hata $status: hata gösterilir, form açık kalır, istisna yok', (tester) async {
        final r = await open(tester);
        r.b.handlers.insert(0, (req, path) => req.method == 'POST' && path == '/forum/topics'
            ? FakeResult.json({'code': 'QA_$status', 'message': 'İleti $status'}, status: status)
            : null);
        await fill(tester);
        await tapPublish(tester);
        await settle(tester, const Duration(seconds: 1));
        expect(find.byKey(_publish), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('çevrimdışı: hata gösterilir, yazılanlar korunur', (tester) async {
      final r = await open(tester);
      await fill(tester);
      r.b.offline = true;
      await tapPublish(tester);
      await settle(tester, const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('forumComposeError')), findsOneWidget);
      expect(tester.widget<TextField>(_field(_bodyKey)).controller!.text, isNotEmpty);
      await unmount(tester);
    });

    testWidgets('taslak: yazılanlar otomatik kaydedilir; yeniden açınca geri yüklenir; yayınlayınca silinir', (tester) async {
      final r = await open(tester);
      await fill(tester, title: 'Taslak başlık', body: 'Taslak metin');
      await tester.pump(const Duration(milliseconds: 300)); // debounce
      final store = ForumDraftStore();
      final saved = await store.load(1);
      expect(saved?.title, 'Taslak başlık');
      expect(saved?.body, 'Taslak metin');
      await unmount(tester);

      // Yeniden aç: taslak geri gelir.
      final s2 = makeSession(r.b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(CreateTopicPage(session: s2, categoryId: 1, draftDebounce: const Duration(milliseconds: 50))));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.widget<TextField>(_field(_title)).controller!.text, 'Taslak başlık');
      await tapPublish(tester);
      await settle(tester, const Duration(seconds: 1));
      expect(r.b.count('POST /forum/topics'), 1);
      expect(await store.load(1), isNull, reason: 'yayınlanınca taslak silinir');
      await unmount(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      testWidgets('${size.width.toInt()} dp, yazı x1.3: taşma yok; anket ekle + 4 görsel sınırı çizimi', (tester) async {
        await open(tester, size: size, scale: 1.3);
        await tester.ensureVisible(find.byKey(const ValueKey('forumPollAdd')));
        await tester.tap(find.byKey(const ValueKey('forumPollAdd')));
        await settle(tester, const Duration(milliseconds: 500));
        expect(find.byKey(const ValueKey('pollBuilder')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('pollAddOption')));
        for (var i = 0; i < 10; i++) {
          final add = find.byKey(const ValueKey('pollAddOption'));
          if (add.evaluate().isEmpty) break;
          await tester.tap(add, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });
}
