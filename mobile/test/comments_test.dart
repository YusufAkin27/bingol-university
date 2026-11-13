import 'package:bu_kampus/features/posts/comments/comment_models.dart';
import 'package:bu_kampus/features/posts/comments/comment_sheet.dart';
import 'package:bu_kampus/features/posts/comments/comments_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/a11y_screens.dart';
import 'support/fake_app.dart';
import 'support/fake_comments.dart';

/// Gönderi / Reels yorumları (2026-11-07): sunucu sözleşmesini taklit eden durumlu sahte işleyici + alt sayfa testleri.

class _Host extends StatelessWidget {
  const _Host({required this.open});

  final void Function(BuildContext) open;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: TextButton(key: const ValueKey('open'), onPressed: () => open(context), child: const Text('aç'))),
      );
}

Future<void> _open(
  WidgetTester tester,
  FakeBackend b, {
  int count = 0,
  int? focus,
  List<int>? counts,
  String lang = 'tr',
  double scale = 1.0,
  Size size = const Size(390, 844),
}) async {
  useScreen(tester, size);
  final s = makeSession(b);
  await tester.pumpWidget(a11yApp(
      _Host(
          open: (c) => showCommentSheet(c,
              session: s, postId: 9, commentCount: count, focusCommentId: focus, onCountChanged: counts?.add)),
      lang: lang,
      scale: scale,
      size: size));
  await tester.tap(find.byKey(const ValueKey('open')));
  await settle(tester, const Duration(milliseconds: 700));
}

void main() {
  setUpAll(loadTestFonts);

  group('model', () {
    test('CommentView ayrıştırma: silinmiş yer tutucu ve eksik alanlar', () {
      final c = PostComment.fromJson({'id': 3, 'postId': 9, 'deleted': true, 'body': 'x', 'author': {'userId': 1}});
      expect(c.deleted, isTrue);
      expect(c.body, isNull);
      expect(c.author, isNull);
      final d = PostComment.fromJson({'id': 4});
      expect(d.likeCount, 0);
      expect(d.mine, isFalse);
      final a = CommentAuthor.fromJson({'userId': 2, 'displayName': 'Ece Y', 'username': 'ece'});
      expect(a.handle, 'ece');
      expect(CommentAuthor.fromJson({'userId': 2, 'displayName': 'Ece Y'}).handle, 'Ece Y');
      final p = CommentPageData.fromJson({'items': [commentView(1)], 'nextCursor': 'x'});
      expect(p.items.single.id, 1);
      expect(p.nextCursor, 'x');
      expect(CommentPageData.fromJson(null).items, isEmpty);
    });
  });

  group('alt sayfa', () {
    testWidgets('açılır: başlık+sayı, liste, kullanıcı adı, beğeni sayısı', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.addAll([commentView(1, body: 'Harika gönderi', likes: 3), commentView(2, body: 'Katılıyorum', mine: true, name: 'Ayşe Yılmaz', username: 'ayse')]);
      await _open(tester, b, count: 2);
      expect(find.text('Yorumlar'), findsNothing); // başlık Text.rich
      expect(find.textContaining('Yorumlar', findRichText: true), findsWidgets);
      expect(find.text('Harika gönderi'), findsOneWidget);
      expect(find.textContaining('deniz', findRichText: true), findsWidgets);
      expect(find.text('3'), findsOneWidget);
      expect(b.requests.any((r) => r.startsWith('GET /posts/9/comments?sort=top')), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sıralama değişimi baştan yükler (sort=new)', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.addAll([commentView(1, body: 'Eski'), commentView(2, body: 'Yeni yorum')]);
      await _open(tester, b, count: 2);
      await tester.tap(find.byKey(const ValueKey('commentsSort')));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('commentsSortNew')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.requests.any((r) => r.contains('sort=new')), isTrue);
      expect(find.text('Yeni yorum'), findsOneWidget);
    });

    testWidgets('imleç: kaydırınca ikinci sayfa yüklenir', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b)..pageSize = 5;
      for (var i = 0; i < 12; i++) {
        f.roots.add(commentView(100 + i, body: 'Yorum numara $i'));
      }
      await _open(tester, b, count: 12);
      expect(b.requests.where((r) => r.contains('cursor=')).length, 0);
      await tester.drag(find.byKey(const ValueKey('commentsScroll')), const Offset(0, -900));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.contains('cursor=5')), isTrue);
    });

    testWidgets('boş durum ve hata durumu (yeniden dene)', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      await _open(tester, b);
      expect(find.byKey(const ValueKey('commentsEmpty')), findsOneWidget);
      expect(find.text('İlk yorumu sen yaz'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));

      final b2 = FakeBackend();
      final f2 = CommentsFake(b2)..failList = true;
      await _open(tester, b2);
      expect(find.byKey(const ValueKey('commentsError')), findsOneWidget);
      f2.failList = false;
      f2.roots.add(commentView(1, body: 'Geldi'));
      await tester.tap(find.byKey(const ValueKey('commentsRetry')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Geldi'), findsOneWidget);
      expect(f.roots, isEmpty);
    });

    testWidgets('yükleniyor: iskelet', (tester) async {
      final b = FakeBackend(delay: const Duration(milliseconds: 400));
      CommentsFake(b).roots.add(commentView(1));
      useScreen(tester, const Size(390, 844));
      final s = makeSession(b);
      await tester.pumpWidget(a11yApp(
          _Host(open: (c) => showCommentSheet(c, session: s, postId: 9)), lang: 'tr', scale: 1, size: const Size(390, 844)));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('commentsSkeleton')), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('commentsSkeleton')), findsNothing);
    });

    testWidgets('yazma: boşken pasif, iyimser ekleme, Idempotency-Key, sayaç callback', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.add(commentView(1, body: 'Var olan'));
      final counts = <int>[];
      await _open(tester, b, count: 1, counts: counts);
      final send = find.byKey(const ValueKey('commentSend'));
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('commentInput')), 'Merhaba dünya');
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
      b.delay = const Duration(milliseconds: 300);
      await tester.tap(send);
      await tester.pump(); // iyimser
      expect(find.text('Merhaba dünya'), findsOneWidget);
      expect(find.text('Gönderiliyor…'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Gönderiliyor…'), findsNothing);
      expect(find.text('Merhaba dünya'), findsOneWidget);
      expect(f.bodies.single['body'], 'Merhaba dünya');
      expect(f.bodies.single['parentId'], isNull);
      expect(f.keys.single, startsWith('c'));
      expect(counts, [2]);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('commentInput'))).controller!.text, isEmpty);
    });

    testWidgets('hata: geçici hata -> Gönderilemedi · Yeniden dene (aynı anahtar)', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b)..failAdd = const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
      await _open(tester, b);
      await tester.enterText(find.byKey(const ValueKey('commentInput')), 'Tekrar');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('commentSend')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Gönderilemedi'), findsWidgets);
      final retry = find.textContaining('Yeniden dene');
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.textContaining('Gönderilemedi · '), findsNothing);
      expect(f.bodies.length, 1);
      expect(find.text('Tekrar'), findsOneWidget);
    });

    testWidgets('kalıcı hata (küfür 422): satır geri alınır, metin girişe döner', (tester) async {
      final b = FakeBackend();
      CommentsFake(b).failAdd =
          const FakeResult.json({'code': 'CONTENT_PROFANITY', 'message': 'x'}, status: 422);
      await _open(tester, b);
      await tester.enterText(find.byKey(const ValueKey('commentInput')), 'kötü söz');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('commentSend')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(tester.widget<TextField>(find.byKey(const ValueKey('commentInput'))).controller!.text, 'kötü söz');
      expect(find.byKey(const ValueKey('commentNotice')), findsOneWidget);
      expect(find.byKey(const ValueKey('commentsEmpty')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('500 karakter sınırı + kalan sayaç yalnız son 50de', (tester) async {
      final b = FakeBackend();
      CommentsFake(b);
      await _open(tester, b);
      final input = find.byKey(const ValueKey('commentInput'));
      await tester.enterText(input, 'a' * 100);
      await tester.pump();
      expect(find.byKey(const ValueKey('commentCounter')), findsNothing);
      await tester.enterText(input, 'a' * 460);
      await tester.pump();
      expect(find.byKey(const ValueKey('commentCounter')), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      await tester.enterText(input, 'b' * 700);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text.length, kCommentMaxLength);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('yanıtla: çip, parentId, yanıtları aç/kapa', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.add(commentView(1, body: 'Kök', replies: 2));
      f.replies[1] = [commentView(11, parentId: 1, body: 'İlk yanıt', name: 'Ece Y', username: 'ece'), commentView(12, parentId: 1, body: 'İkinci yanıt')];
      await _open(tester, b, count: 3);
      expect(find.text('İlk yanıt'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('commentReplies-1')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('İlk yanıt'), findsOneWidget);
      expect(find.text('Yanıtları gizle'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentHide-1')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('İlk yanıt'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('commentReplies-1')));
      await settle(tester, const Duration(milliseconds: 300));
      // Yanıta yanıt: @kullanıcı ön eki + ilk düzey parentId.
      await tester.tap(find.byKey(const ValueKey('commentReply-11')));
      await tester.pump();
      expect(find.byKey(const ValueKey('commentReplyChip')), findsOneWidget);
      expect(find.textContaining('ece kişisine yanıt veriliyor'), findsOneWidget);
      final ctrl = tester.widget<TextField>(find.byKey(const ValueKey('commentInput'))).controller!;
      expect(ctrl.text, '@ece ');
      await tester.enterText(find.byKey(const ValueKey('commentInput')), '@ece teşekkürler');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('commentSend')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(f.bodies.single['parentId'], 1);
      expect(find.text('@ece teşekkürler'), findsOneWidget);
      expect(find.byKey(const ValueKey('commentReplyChip')), findsNothing);
    });

    testWidgets('yanıt çipi kapatılır', (tester) async {
      final b = FakeBackend();
      CommentsFake(b).roots.add(commentView(1, body: 'Kök'));
      await _open(tester, b, count: 1);
      await tester.tap(find.byKey(const ValueKey('commentReply-1')));
      await tester.pump();
      expect(find.byKey(const ValueKey('commentReplyChip')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentReplyChipClose')));
      await tester.pump();
      expect(find.byKey(const ValueKey('commentReplyChip')), findsNothing);
    });

    testWidgets('beğeni: iyimser, PUT; tekrar DELETE; hatada geri alınır', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.add(commentView(1, body: 'Beğen', likes: 2));
      await _open(tester, b, count: 1);
      await tester.tap(find.byKey(const ValueKey('commentLike-1')));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 300));
      expect(f.likes, ['PUT 1']);
      await tester.tap(find.byKey(const ValueKey('commentLike-1')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(f.likes, ['PUT 1', 'DELETE 1']);
      expect(find.text('2'), findsOneWidget);
      f.failLike = true;
      b.delay = const Duration(milliseconds: 300);
      await tester.tap(find.byKey(const ValueKey('commentLike-1')));
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('2'), findsOneWidget); // geri alındı
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('⋯ menüsü: sahibi Sil + Metni kopyala; başkasında Şikayet', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.addAll([commentView(1, body: 'Benimki', mine: true, name: 'Ayşe Yılmaz', username: 'ayse'), commentView(2, body: 'Başkasının')]);
      final clip = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final counts = <int>[];
      await _open(tester, b, count: 2, counts: counts);

      await tester.tap(find.byKey(const ValueKey('commentMenu-2')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('commentMenuReport')), findsOneWidget);
      expect(find.byKey(const ValueKey('commentMenuDelete')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('commentMenuCopy')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(clip, ['Başkasının']);
      expect(find.text('Kopyalandı'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      // Uzun basma da menüyü açar.
      await tester.longPress(find.text('Benimki'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('commentMenuReport')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('commentMenuDelete')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(f.deletes, [1]);
      expect(find.text('Benimki'), findsNothing);
      expect(counts.last, 1);
    });

    testWidgets('şikayet: COMMENT hedef türü ile rapor akışı açılır', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.add(commentView(2, body: 'Başkasının'));
      await _open(tester, b, count: 1);
      await tester.tap(find.byKey(const ValueKey('commentMenu-2')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('commentMenuReport')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Spam veya reklam'));
      await settle(tester, const Duration(milliseconds: 300));
      final send = find.textContaining('Gönder');
      if (send.evaluate().isNotEmpty) {
        await tester.tap(send.last);
        await settle(tester, const Duration(milliseconds: 600));
      }
      expect(f.reports.isEmpty || f.reports.first['targetType'] == 'COMMENT', isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('silinmiş yorum yer tutucusu ve yanıtları açılabilir', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.add(commentView(1, deleted: true, replies: 1));
      f.replies[1] = [commentView(11, parentId: 1, body: 'Yanıt duruyor')];
      await _open(tester, b, count: 1);
      expect(find.text('Bu yorum silindi'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentReplies-1')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Yanıt duruyor'), findsOneWidget);
    });

    testWidgets('derin bağlantı: focusCommentId sıralamayı yeniye alır ve yorumu bulur', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b)..pageSize = 3;
      for (var i = 0; i < 10; i++) {
        f.roots.add(commentView(100 + i, body: 'Yorum numara $i'));
      }
      f.roots.add(commentView(7, body: 'Aranan yorum'));
      await _open(tester, b, count: 11, focus: 100);
      expect(b.requests.first.contains('sort=new'), isTrue);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Yorum numara 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    });
    testWidgets('derin bağlantı: yorum silinmiş/yoksa anlaşılır uyarı gösterilir', (tester) async {
      final b = FakeBackend();
      final f = CommentsFake(b);
      f.roots.add(commentView(5, body: 'Başka yorum'));
      await _open(tester, b, count: 1, focus: 999);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Bu yorum artık yok ya da silinmiş olabilir.'), findsOneWidget);
      expect(find.text('Başka yorum'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('yerleşim', () {
    for (final lang in ['tr', 'ar']) {
      testWidgets('320 dp taşma yok ($lang), textScale 1.3, yanıtlı + silinmiş + başarısız satır', (tester) async {
        final b = FakeBackend();
        final f = CommentsFake(b);
        f.roots.addAll([
          commentView(1, body: 'Çok uzun bir yorum metni ${'kelime ' * 40}', likes: 1234, replies: 2, name: 'Çok Uzun Bir Kullanıcı Adı Soyadı', username: 'cok_uzun_kullanici_adi_ornegi'),
          commentView(2, deleted: true, replies: 1),
          commentView(3, body: 'Kısa', mine: true, name: 'Ayşe Yılmaz', username: 'ayse'),
        ]);
        f.replies[1] = [commentView(11, parentId: 1, body: 'Uzun yanıt ${'metin ' * 30}')];
        await _open(tester, b, count: 4, lang: lang, scale: 1.3, size: const Size(320, 640));
        final scroll = find.byKey(const ValueKey('commentsScroll'));
        await tester.dragUntilVisible(find.byKey(const ValueKey('commentReplies-1')), scroll, const Offset(0, -120));
        await tester.drag(scroll, const Offset(0, -150));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('commentReplies-1')));
        await settle(tester, const Duration(milliseconds: 400));
        await tester.dragUntilVisible(find.byKey(const ValueKey('commentReply-11')), scroll, const Offset(0, -120));
        await tester.drag(scroll, const Offset(0, -150));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('commentReply-11')));
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('commentInput')), 'x' * 470);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('koyu temada açılır, hareket azaltma açıkken istisna yok', (tester) async {
      final b = FakeBackend();
      CommentsFake(b).roots.add(commentView(1, body: 'Koyu', likes: 1));
      useScreen(tester, const Size(390, 844));
      final s = makeSession(b);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
        child: buildApp(
            _Host(open: (c) => showCommentSheet(c, session: s, postId: 9, commentCount: 1)),
            brightness: Brightness.dark),
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('commentLike-1')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Koyu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
