import 'package:bu_kampus/features/forum/data/forum_api.dart';
import 'package:bu_kampus/features/forum/data/forum_models.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/comment_controller.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/comment_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_forum.dart';
import 'support/fake_forum_comments.dart';

/// Yorum ağacı: saf Dart düzleştirme/girinti mantığı ve denetleyici (arayüzsüz).
ForumComment c(int id, {int? parent, int depth = 0, int replies = 0, List<ForumComment> preview = const [], bool deleted = false}) =>
    ForumComment(
      id: id,
      topicId: 1,
      parentCommentId: parent,
      depth: depth,
      body: deleted ? null : 'm$id',
      replyCount: replies,
      replyPreview: preview,
      deleted: deleted,
      author: deleted ? null : const ForumAuthor(userId: 2, displayName: 'K'),
    );

List<String> kinds(List<CommentRow> rows) => [for (final r in rows) '${r.kind.name}:${r.node.id}@${r.level}'];

void main() {
  group('flattenComments', () {
    test('yanitsiz yorumlar: yalniz yorum satirlari, seviye 0', () {
      final rows = flattenComments([CommentNode(c(1)), CommentNode(c(2))]);
      expect(kinds(rows), ['comment:1@0', 'comment:2@0']);
    });

    test('onizleme yanitlari acik gelir; kalan icin alt bilgi satiri', () {
      final n = CommentNode(c(1, replies: 5, preview: [c(2, parent: 1, depth: 1), c(3, parent: 1, depth: 1)]));
      final rows = flattenComments([n]);
      expect(kinds(rows), ['comment:1@0', 'comment:2@1', 'comment:3@1', 'footer:1@1']);
      expect(n.hiddenReplyCount, 3);
      expect(n.hasMoreReplies, isTrue);
    });

    test('kapali yorum: yalniz alt bilgi ("N yaniti goster")', () {
      final n = CommentNode(c(1, replies: 4));
      expect(n.expanded, isFalse);
      expect(kinds(flattenComments([n])), ['comment:1@0', 'footer:1@1']);
    });

    test('girinti siniri: seviye 2 yorumun yanitlari satir ici cizilmez, zincir satiri gelir', () {
      final deep = c(3, parent: 2, depth: 2, replies: 2, preview: [c(4, parent: 3, depth: 3)]);
      final mid = c(2, parent: 1, depth: 1, replies: 1, preview: [deep]);
      final root = CommentNode(c(1, replies: 1, preview: [mid]));
      final rows = flattenComments([root]);
      expect(kinds(rows), ['comment:1@0', 'comment:2@1', 'comment:3@2', 'chain:3@2', 'footer:2@2', 'footer:1@1']);
      expect(rows.any((r) => r.node.id == 4), isFalse);
    });

    test('ayri zincir: baseDepth ile kok seviye 0 olur ve derinlik yeniden sayilir', () {
      final deep = c(3, parent: 2, depth: 2, replies: 1, preview: [c(4, parent: 3, depth: 3, replies: 1, preview: [c(5, parent: 4, depth: 4)])]);
      final rows = flattenComments([CommentNode(deep)], baseDepth: 2);
      expect(kinds(rows), ['comment:3@0', 'comment:4@1', 'comment:5@2', 'footer:4@2', 'footer:3@1']);
    });

    test('gizleme animasyonu: collapsing iken cocuklar exiting, alt bilgi gizli', () {
      final n = CommentNode(c(1, replies: 1, preview: [c(2, parent: 1, depth: 1)]));
      n.collapsing = true;
      final rows = flattenComments([n]);
      expect(kinds(rows), ['comment:1@0', 'comment:2@1']);
      expect(rows[1].exiting, isTrue);
      expect(rows[0].exiting, isFalse);
    });

    test('yuklenirken ve hatada satir turleri', () {
      final n = CommentNode(c(1, replies: 3))..expanded = true;
      n.loadingReplies = true;
      expect(kinds(flattenComments([n])), ['comment:1@0', 'loading:1@1', 'footer:1@1']);
      n.loadingReplies = false;
      n.repliesError = Exception('x');
      expect(kinds(flattenComments([n])), ['comment:1@0', 'error:1@1', 'footer:1@1']);
    });

    test('silinmis yer tutucu: yaniti olduğu surece gorunur', () {
      final n = CommentNode(c(1, deleted: true, replies: 1, preview: [c(2, parent: 1, depth: 1)]));
      final rows = flattenComments([n]);
      expect(rows.first.node.deleted, isTrue);
      expect(rows.first.node.body, isNull);
      expect(kinds(rows), ['comment:1@0', 'comment:2@1', 'footer:1@1']);
    });

    test('buyuk zincir: 5000 dugum duzlestirme milisaniyelerde biter', () {
      final first = CommentNode(c(1, replies: 1));
      final kids = [for (var i = 2; i < 5000; i++) CommentNode(c(i, parent: 1, depth: 1))];
      first.children.addAll(kids);
      first.expanded = true;
      first.replyCount = kids.length;
      final sw = Stopwatch()..start();
      final rows = flattenComments([first]);
      sw.stop();
      expect(rows.length, 1 + kids.length + 1);
      expect(sw.elapsedMilliseconds, lessThan(200));
    });
  });

  group('CommentNode', () {
    test('authorGone: yazarsiz ve silinmemis = hesap kaldirilmis; silinmis degil', () {
      expect(CommentNode(const ForumComment(id: 1, topicId: 1, body: 'x')).authorGone, isTrue);
      expect(CommentNode(c(1, deleted: true)).authorGone, isFalse);
      expect(CommentNode(c(1)).authorGone, isFalse);
      expect(CommentNode(const ForumComment(id: 1, topicId: 1, body: 'x', author: ForumAuthor(displayName: 'Anonim #3', anonymous: true))).authorGone, isFalse);
    });

    test('find: derin dugumu bulur', () {
      final root = CommentNode(c(1, replies: 1, preview: [c(2, parent: 1, depth: 1, replies: 1, preview: [c(3, parent: 2, depth: 2)])]));
      expect(root.find(3)?.id, 3);
      expect(root.find(99), isNull);
    });
  });

  group('CommentsController', () {
    late FakeForumComments fk;
    CommentsController make(FakeBackend b, {List<int>? deltas}) {
      final f = fakeForum(b, count: 3);
      fk = fakeForumComments(b, f);
      final s = makeSession(b);
      return CommentsController(api: ForumApi(s), topicId: 500, collapseDuration: Duration.zero, onCountDelta: deltas?.add);
    }

    test('load: ust duzey liste + imlec; setSort listeyi yeniler', () async {
      final b = FakeBackend();
      final cc = make(b);
      await cc.load();
      expect(cc.roots.map((r) => r.id), containsAll([1, 6, 7, 8]));
      expect(cc.hasMore, isFalse);
      await cc.setSort(ForumCommentSort.oldest);
      expect(cc.roots.first.id, 1);
      expect(cc.sort, ForumCommentSort.oldest);
      cc.dispose();
    });

    test('create: ust duzey basa girer, yanit parent altina; sayac +1', () async {
      final b = FakeBackend();
      final deltas = <int>[];
      final cc = make(b, deltas: deltas);
      await cc.load();
      final top = await cc.create(body: 'Yeni', anonymous: false, key: 'k1');
      expect(cc.roots.first.id, top.id);
      final reply = await cc.create(body: 'Yanit', parent: cc.find(6), anonymous: false, key: 'k2');
      expect(cc.find(6)!.children.single.id, reply.id);
      expect(cc.find(6)!.replyCount, 1);
      expect(deltas, [1, 1]);
      cc.dispose();
    });

    test('create: ayni Idempotency-Key ile tekrar ayni yorumu dondurur (cift gonderim yok)', () async {
      final b = FakeBackend();
      final cc = make(b);
      await cc.load();
      final a = await cc.create(body: 'Tek', anonymous: false, key: 'ayni');
      final n = cc.roots.length;
      final a2 = await cc.create(body: 'Tek', anonymous: false, key: 'ayni');
      expect(a2.id, a.id);
      expect(cc.roots.length, n, reason: 'listede yinelenmez');
      cc.dispose();
    });

    test('remove: yanitsiz kalkar (sayac -1); yanitli yer tutucu olur; son yanit silinince yer tutucu da kalkar', () async {
      final b = FakeBackend();
      final deltas = <int>[];
      final cc = make(b, deltas: deltas);
      await cc.load();
      // c6: yanitsiz
      await cc.remove(cc.find(6)!);
      expect(cc.find(6), isNull);
      // c1 -> c2 -> c3 (benim): c3 yanitli (c4) -> yer tutucu
      await cc.showReplies(cc.find(1)!);
      await cc.showReplies(cc.find(2)!);
      final c3 = cc.find(3)!;
      await cc.remove(c3);
      expect(c3.deleted, isTrue);
      expect(c3.body, isNull);
      expect(deltas, [-1, -1]);
      cc.dispose();
    });

    test('toggleLike: art arda dokunuslar tek ucusta birlesir; son durum sunucuyla ayni', () async {
      final b = FakeBackend(delay: const Duration(milliseconds: 20));
      final cc = make(b);
      await cc.load();
      final n = cc.find(1)!;
      final f1 = cc.toggleLike(n); // begen
      final f2 = cc.toggleLike(n); // geri al
      final f3 = cc.toggleLike(n); // begen
      expect(n.likedByMe, isTrue);
      await Future.wait([f1, f2, f3]);
      expect(n.likedByMe, isTrue);
      expect(n.likeCount, 4);
      cc.dispose();
    });

    test('toggleLike: hata olunca onaylanmis duruma doner ve hata firlatir', () async {
      final b = FakeBackend();
      final cc = make(b);
      await cc.load();
      fk.failLike = true;
      final n = cc.find(1)!;
      await expectLater(cc.toggleLike(n), throwsA(anything));
      expect(n.likedByMe, isFalse);
      expect(n.likeCount, 3);
      cc.dispose();
    });

    test('loadReplies: sayfali; onizleme durumu korunur; hata satir ici tutulur', () async {
      final b = FakeBackend();
      final cc = make(b);
      await cc.load();
      final n = cc.find(1)!;
      expect(n.repliesLoaded, isFalse);
      await cc.loadReplies(n);
      expect(n.repliesLoaded, isTrue);
      expect(n.children.map((e) => e.id), [2, 5]);
      expect(n.hasMoreReplies, isFalse);
      cc.dispose();
    });

    test('focus: derin yorum icin needsThread; seviye 1 icin found; bilinmeyen icin notFound', () async {
      final b = FakeBackend();
      final cc = make(b);
      await cc.load();
      final r5 = await cc.focus(5);
      expect(r5.kind, CommentFocus.found);
      expect(cc.highlightId, 5);
      final r4 = await cc.focus(4);
      expect(r4.kind, CommentFocus.needsThread);
      expect(r4.threadRoot!.id, 3);
      final rx = await cc.focus(12345);
      expect(rx.kind, CommentFocus.notFound);
      cc.dispose();
    });

    test('hideReplies: animasyonsuz (sure 0) aninda kapanir', () async {
      final b = FakeBackend();
      final cc = make(b);
      await cc.load();
      final n = cc.find(1)!;
      expect(n.expanded, isTrue);
      cc.hideReplies(n);
      expect(n.expanded, isFalse);
      expect(n.collapsing, isFalse);
      cc.dispose();
    });
  });
}
