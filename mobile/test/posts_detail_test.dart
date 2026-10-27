import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/posts/comment_composer.dart';
import 'package:bu_kampus/features/posts/comment_thread.dart';
import 'package:bu_kampus/features/posts/comment_tile.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/fake_app.dart';

/// Gönderi detayı + yorumlar: sahte sunucu (yönteme duyarlı).
class _Srv {
  _Srv() {
    b.handlers.add(handle);
  }

  final b = FakeBackend();
  Map<String, dynamic> post = samplePost(id: 91, commentCount: 2);
  List<Map<String, dynamic>> roots = [];
  int? total;

  /// `sort|cursor` -> sayfa; yoksa [roots] tek sayfa.
  final Map<String, Map<String, dynamic>> pages = {};

  /// Yorum id -> yanıt sayfası; anahtar `id` ya da `id|cursor`.
  final Map<String, Map<String, dynamic>> replyPages = {};
  bool failList = false;
  FakeResult? createResult;
  int nextId = 500;

  FakeResult? handle(http.Request req, String path) {
    final q = req.url.queryParameters;
    if (req.method == 'GET' && path == '/posts/91') return FakeResult.json(post);
    if (req.method == 'GET' && path == '/posts/91/comments') {
      if (failList) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500);
      final key = '${q['sort'] ?? 'new'}|${q['cursor'] ?? ''}';
      return FakeResult.json(pages[key] ?? {'items': roots, 'nextCursor': null, 'total': total ?? roots.length});
    }
    final rep = RegExp(r'^/comments/(\d+)/replies$').firstMatch(path);
    if (req.method == 'GET' && rep != null) {
      final id = rep.group(1)!;
      final cur = q['cursor'];
      return FakeResult.json(
          replyPages[cur == null ? id : '$id|$cur'] ?? {'items': <Object>[], 'nextCursor': null});
    }
    if (req.method == 'POST' && path == '/posts/91/comments') {
      if (createResult != null) return createResult;
      final body = b.bodies['POST /posts/91/comments'] as Map;
      final parent = body['parentId'] as int?;
      return FakeResult.json(
        sampleComment(
          id: nextId++,
          postId: 91,
          parentId: parent,
          depth: parent == null ? 0 : (parent == 4 ? 3 : 1), // 4 = D3: sunucu kardeş (derinlik 3) döndürür
          text: body['text'] as String,
          mine: true,
          authorId: 1,
          authorName: 'Ayşe Yılmaz',
        ),
        status: 201,
      );
    }
    if (req.method == 'DELETE' && path.startsWith('/comments/')) return const FakeResult.json(null, status: 204);
    return null;
  }
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {String? next, int? total}) =>
    {'items': items, 'nextCursor': next, 'total': total ?? items.length};

Map<String, dynamic> _root(int i, {int replyCount = 0, List<Map<String, dynamic>>? previews, bool mine = false}) =>
    sampleComment(
        id: i, text: 'Kök yorum $i', replyCount: replyCount, previewReplies: previews, mine: mine, authorName: 'Mehmet Kaya');

Map<String, dynamic> _reply(int id, int parent, int depth, String text, {int replyCount = 0}) => sampleComment(
      id: id,
      parentId: parent,
      rootId: 1,
      depth: depth,
      text: text,
      replyCount: replyCount,
      authorName: 'Zeynep Aydın',
      authorId: 14,
      replyToUser: {'id': 13, 'displayName': 'Mehmet Kaya'},
    );

Widget _page0(_Srv s, {int? focus, Post? initial}) => PostDetailPage(
      session: makeSession(s.b),
      postId: 91,
      initial: initial ?? Post.fromJson(s.post),
      focusCommentId: focus,
    );

Finder _composerField() =>
    find.descendant(of: find.byType(CommentComposer), matching: find.byType(TextField));

Finder _tileOf(String text) => find.ancestor(of: find.textContaining(text), matching: find.byType(CommentTile));

Finder _menuOf(String text) =>
    find.descendant(of: _tileOf(text), matching: find.byIcon(LucideIcons.ellipsis));

/// 4 seviyeli örnek ağaç: K1 > D1 > D2 > D3.
void _deepTree(_Srv s) {
  s.roots = [
    _root(1, replyCount: 1, previews: [_reply(2, 1, 1, 'D1', replyCount: 1)]),
  ];
  s.replyPages['2'] = _page([_reply(3, 2, 2, 'D2', replyCount: 1)]);
  s.replyPages['3'] = _page([_reply(4, 3, 3, 'D3')]);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_composerField(), text);
  await tester.pump();
}

Future<void> _tapReplyOf(WidgetTester tester, String text) async {
  final f = find.descendant(of: _tileOf(text), matching: find.text('Yanıtla'));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
}

Future<void> _openDeep(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    // Dar ekranda 44 dp dokunma satırları listeyi uzatır: düğme alt çubuğun arkasında kalmasın.
    await tester.ensureVisible(find.text('1 yanıtı göster'));
    await tester.pump();
    await tester.tap(find.text('1 yanıtı göster'));
    await settle(tester);
  }
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('yorumlar yükleniyor iskeleti, sonra liste', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()
      ..roots = [_root(1), _root(2)]
      ..b.delay = const Duration(milliseconds: 300);
    await tester.pumpWidget(buildApp(_page0(s)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CommentsSkeleton), findsOneWidget);
    s.b.delay = Duration.zero;
    await settle(tester, const Duration(seconds: 2));
    expect(find.byType(CommentsSkeleton), findsNothing);
    expect(find.textContaining('Kök yorum 1'), findsOneWidget);
    expect(find.textContaining('Kök yorum 2'), findsOneWidget);
    expect(s.b.requests, contains('GET /posts/91/comments?sort=new&size=20'));
    await unmount(tester);
  });

  testWidgets('boş: İlk yorumu sen yaz', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv();
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    expect(find.text('İlk yorumu sen yaz'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('hata + yeniden dene', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()
      ..roots = [_root(1)]
      ..failList = true;
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    expect(find.text('Yeniden dene'), findsOneWidget);
    expect(find.textContaining('Kök yorum 1'), findsNothing);
    s.failList = false;
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester);
    expect(find.textContaining('Kök yorum 1'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('imleçli sayfalama: ikinci sayfa imleçle istenir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv();
    s.pages['new|'] = _page([_root(1), _root(2)], next: 'c2', total: 3);
    s.pages['new|c2'] = _page([_root(3)], total: 3);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester, const Duration(seconds: 2));
    expect(s.b.requests.where((r) => r.contains('cursor=c2')), isNotEmpty);
    expect(find.textContaining('Kök yorum 3'), findsOneWidget);
    expect(s.b.requests.where((r) => r.contains('cursor=c2')).length, 1);
    await unmount(tester);
  });

  testWidgets('sıralama Yeni | Üst: istek sort ile gider', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv();
    s.pages['new|'] = _page([_root(1)]);
    s.pages['top|'] = _page([_root(9)]);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    expect(find.textContaining('Kök yorum 1'), findsOneWidget);
    await tester.tap(find.text('Üst'));
    await settle(tester);
    expect(s.b.requests, contains('GET /posts/91/comments?sort=top&size=20'));
    expect(find.textContaining('Kök yorum 9'), findsOneWidget);
    expect(find.textContaining('Kök yorum 1'), findsNothing);
    await unmount(tester);
  });

  testWidgets('yorum ekleme: iyimser görünür, sunucu yanıtı gelince kalır, sayı artar', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(1)];
    Post? last;
    await tester.pumpWidget(buildApp(PostDetailPage(
      session: makeSession(s.b),
      postId: 91,
      initial: Post.fromJson(s.post),
      onChanged: (p) => last = p,
    )));
    await settle(tester);
    expect(find.text('Yorumlar (2)'), findsOneWidget);
    await _type(tester, 'Merhaba dünya');
    s.b.delay = const Duration(milliseconds: 300);
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Merhaba dünya'), findsOneWidget);
    expect(find.text('Gönderiliyor…'), findsOneWidget);
    expect(find.text('Yorumlar (3)'), findsOneWidget);
    s.b.delay = Duration.zero;
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('Gönderiliyor…'), findsNothing);
    expect(find.textContaining('Merhaba dünya'), findsOneWidget);
    expect(s.b.bodies['POST /posts/91/comments'], {'text': 'Merhaba dünya'});
    expect(last?.commentCount, 3);
    expect(tester.widget<TextField>(_composerField()).controller!.text, '');
    await unmount(tester);
  });

  testWidgets('yanıt verme: banner + parentId gövdede', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(1)];
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await tester.tap(find.text('Yanıtla'));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.text('Yanıtlıyor: @Mehmet Kaya'), findsOneWidget);
    await _type(tester, 'Katılıyorum');
    await tester.tap(find.byTooltip('Gönder'));
    await settle(tester, const Duration(seconds: 2));
    expect(s.b.bodies['POST /posts/91/comments'], {'text': 'Katılıyorum', 'parentId': 1});
    expect(find.textContaining('Katılıyorum'), findsOneWidget);
    expect(find.textContaining('Yanıtlıyor'), findsNothing);
    await unmount(tester);
  });

  testWidgets('yanıt modu iptal edilir (✕)', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(1)];
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await tester.tap(find.text('Yanıtla'));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.bySemanticsLabel('Yanıtı iptal et'));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.textContaining('Yanıtlıyor'), findsNothing);
  });

  testWidgets('derinlik 3: yanıt kardeş olarak eklenir, aynı girinti', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv();
    _deepTree(s);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await _openDeep(tester);
    expect(find.textContaining('D3'), findsOneWidget);
    await _tapReplyOf(tester, 'D3');
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.text('Yanıtlıyor: @Zeynep Aydın'), findsOneWidget);
    await _type(tester, 'Derin cevap');
    await tester.tap(find.byTooltip('Gönder'));
    await settle(tester, const Duration(seconds: 2));
    expect(s.b.bodies['POST /posts/91/comments'], {'text': 'Derin cevap', 'parentId': 4});
    expect(find.textContaining('Derin cevap'), findsOneWidget);
    final dx3 = tester.getTopLeft(find.textContaining('D3')).dx;
    final dxNew = tester.getTopLeft(find.textContaining('Derin cevap')).dx;
    expect(dxNew, dx3, reason: 'derinlik 3 yanıtı kardeş seviyesinde (aynı girinti)');
    await unmount(tester);
  });

  testWidgets('N yanıtı göster -> replies isteği; Yanıtları gizle', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(1, replyCount: 3)];
    s.replyPages['1'] = _page([_reply(2, 1, 1, 'Yanıt A'), _reply(3, 1, 1, 'Yanıt B')], next: 'r2');
    s.replyPages['1|r2'] = _page([_reply(4, 1, 1, 'Yanıt C')]);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    expect(find.text('3 yanıtı göster'), findsOneWidget);
    await tester.tap(find.text('3 yanıtı göster'));
    await settle(tester);
    expect(s.b.requests, contains('GET /comments/1/replies?size=20'));
    expect(find.textContaining('Yanıt A'), findsOneWidget);
    expect(find.textContaining('Yanıt C'), findsNothing);
    await tester.tap(find.text('Daha fazla yanıt göster'));
    await settle(tester);
    expect(s.b.requests, contains('GET /comments/1/replies?size=20&cursor=r2'));
    expect(find.textContaining('Yanıt C'), findsOneWidget);
    expect(find.text('Daha fazla yanıt göster'), findsNothing);
    await tester.tap(find.text('Yanıtları gizle'));
    await settle(tester);
    expect(find.textContaining('Yanıt A'), findsNothing);
    expect(find.text('3 yanıtı göster'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('önizleme yanıtları görünür; kalanı replies ile gelir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()
      ..roots = [
        _root(1, replyCount: 3, previews: [_reply(2, 1, 1, 'Yanıt A'), _reply(3, 1, 1, 'Yanıt B')]),
      ];
    s.replyPages['1'] = _page([_reply(2, 1, 1, 'Yanıt A'), _reply(3, 1, 1, 'Yanıt B'), _reply(4, 1, 1, 'Yanıt C')]);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    expect(find.textContaining('Yanıt B'), findsOneWidget);
    expect(find.textContaining('Yanıt C'), findsNothing);
    await tester.tap(find.text('Daha fazla yanıt göster'));
    await settle(tester);
    expect(find.textContaining('Yanıt C'), findsOneWidget);
    expect(find.textContaining('Yanıt A'), findsOneWidget, reason: 'tekrarlanmaz');
    await unmount(tester);
  });

  testWidgets('silinmiş yorum soluk satır, yanıtlar görünür kalır', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()
      ..roots = [
        sampleComment(id: 1, deleted: true, replyCount: 1, previewReplies: [_reply(2, 1, 1, 'Hâlâ buradayım')]),
      ];
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    expect(find.text('Bu yorum silindi'), findsOneWidget);
    expect(find.textContaining('Hâlâ buradayım'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('düzenleme: satır içi alan, PATCH, düzenlendi etiketi', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(1, mine: true)];
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await tester.tap(_menuOf('Kök yorum 1'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Şikâyet et'), findsNothing);
    await tester.tap(find.text('Düzenle'));
    await settle(tester, const Duration(milliseconds: 500));
    final editor = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Yorumu düzenle');
    await tester.enterText(editor, 'Düzeltilmiş');
    await tester.tap(find.text('Kaydet'));
    await settle(tester);
    expect(s.b.bodies['PATCH /comments/1'], {'text': 'Düzeltilmiş'});
    expect(find.textContaining('Düzeltilmiş'), findsOneWidget);
    expect(find.textContaining('düzenlendi'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('silme onaylı: vazgeç kalır, sil kaldırır ve sayıyı düşürür', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(1, mine: true)];
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await tester.tap(_menuOf('Kök yorum 1'));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Sil'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Yorum silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(s.b.requests.where((r) => r.startsWith('DELETE')), isEmpty);
    expect(find.textContaining('Kök yorum 1'), findsOneWidget);

    await tester.tap(_menuOf('Kök yorum 1'));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Sil'));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sil')));
    await settle(tester);
    expect(s.b.requests, contains('DELETE /comments/1'));
    expect(find.textContaining('Kök yorum 1'), findsNothing);
    expect(find.text('Yorumlar (1)'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('yanıtı olan yorum silinince "Bu yorum silindi" olur', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()
      ..roots = [
        _root(1, mine: true, replyCount: 1, previews: [_reply(2, 1, 1, 'Cevap var')]),
      ];
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await tester.tap(_menuOf('Kök yorum 1'));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Sil'));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sil')));
    await settle(tester);
    expect(find.text('Bu yorum silindi'), findsOneWidget);
    expect(find.textContaining('Cevap var'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('şikâyet: FEED_COMMENT hedefi gönderilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(77)];
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await tester.tap(_menuOf('Kök yorum 77'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Düzenle'), findsNothing);
    await tester.tap(find.text('Şikâyet et'));
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Gönder').last);
    await settle(tester, const Duration(milliseconds: 600));
    expect(s.b.bodies['POST /reports'], {'targetType': 'FEED_COMMENT', 'targetId': 77, 'reason': 'SPAM'});
    await unmount(tester);
  });

  testWidgets('küfür 422: yorum geri alınır, mesaj çubuk altında, metin korunur', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()
      ..roots = [_root(1)]
      ..createResult =
          const FakeResult.json({'code': 'CONTENT_PROFANITY', 'message': 'Uygunsuz ifade içeriyor.'}, status: 422);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await _type(tester, 'kötü söz');
    await tester.tap(find.byTooltip('Gönder'));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Uygunsuz ifade içeriyor.'), findsOneWidget);
    expect(tester.widget<TextField>(_composerField()).controller!.text, 'kötü söz');
    expect(find.text('Yorumlar (2)'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('429: mesaj gösterilir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()
      ..roots = [_root(1)]
      ..createResult = const FakeResult.json({'code': 'RATE_LIMITED', 'message': 'Çok hızlısın.'}, status: 429);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await _type(tester, 'selam');
    await tester.tap(find.byTooltip('Gönder'));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Çok hızlısın.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('sunucu hatası: Gönderilemedi · Yeniden dene, sonra başarılı', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()
      ..roots = [_root(1)]
      ..createResult = const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    await _type(tester, 'tekrar dene');
    await tester.tap(find.byTooltip('Gönder'));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Gönderilemedi · Yeniden dene'), findsOneWidget);
    expect(find.text('Yorumlar (2)'), findsOneWidget, reason: 'başarısız yorum sayıya girmez');
    s.createResult = null;
    await tester.tap(find.text('Gönderilemedi · Yeniden dene'));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Gönderilemedi · Yeniden dene'), findsNothing);
    expect(find.text('Yorumlar (3)'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('focusCommentId: yoruma kaydırır ve kısa süre vurgular', (tester) async {
    useScreen(tester, kPhoneSmall);
    final s = _Srv()..roots = [for (var i = 1; i <= 20; i++) _root(i)];
    await tester.pumpWidget(buildApp(_page0(s, focus: 18)));
    await settle(tester, const Duration(seconds: 2));
    final f = find.textContaining('Kök yorum 18');
    expect(f, findsOneWidget);
    final r = tester.getRect(f);
    expect(r.top, greaterThan(0));
    expect(r.bottom, lessThan(kPhoneSmall.height));
    final soft = tester.element(find.byType(PostDetailPage)).bu.soft;
    Finder highlighted() => find.byWidgetPredicate(
        (w) => w is AnimatedContainer && (w.decoration as BoxDecoration?)?.color == soft);
    expect(highlighted(), findsOneWidget);
    await settle(tester, const Duration(seconds: 4));
    expect(highlighted(), findsNothing);
    await unmount(tester);
  });

  testWidgets('focusCommentId: gizli yanıtı bulmak için replies açılır', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(1, replyCount: 3), _root(2)];
    s.replyPages['1'] = _page([_reply(11, 1, 1, 'Hedef yanıt'), _reply(12, 1, 1, 'Öteki')]);
    await tester.pumpWidget(buildApp(_page0(s, focus: 11)));
    await settle(tester, const Duration(seconds: 2));
    expect(find.textContaining('Hedef yanıt'), findsOneWidget);
    await unmount(tester);
  });

  for (final dark in [false, true]) {
    for (final size in kPhoneSizes) {
      testWidgets('taşma yok: ${size.width.toInt()} dp ${dark ? 'koyu' : 'açık'}', (tester) async {
        useScreen(tester, size);
        final s = _Srv();
        _deepTree(s);
        s.roots.add(_root(5, replyCount: 2, mine: true));
        await tester.pumpWidget(buildApp(_page0(s), brightness: dark ? Brightness.dark : Brightness.light));
        await settle(tester);
        await _openDeep(tester);
        await _tapReplyOf(tester, 'D3');
        await settle(tester, const Duration(milliseconds: 300));
        await _type(tester, 'Uzun bir yanıt ' * 40);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  }

  testWidgets('dispose sonrası istisna yok (istek sürerken kapanır)', (tester) async {
    useScreen(tester, kPhoneMedium);
    final s = _Srv()..roots = [_root(1, replyCount: 2)];
    s.replyPages['1'] = _page([_reply(2, 1, 1, 'Yanıt')]);
    await tester.pumpWidget(buildApp(_page0(s)));
    await settle(tester);
    s.b.delay = const Duration(milliseconds: 500);
    await tester.tap(find.text('2 yanıtı göster'));
    await tester.pump(const Duration(milliseconds: 50));
    await _type(tester, 'gönderilecek');
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump(const Duration(milliseconds: 50));
    await unmount(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
