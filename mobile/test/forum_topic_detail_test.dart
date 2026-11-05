import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/forum/forum_routes.dart';
import 'package:bu_kampus/features/forum/presentation/pages/comment_thread_page.dart';
import 'package:bu_kampus/features/forum/presentation/pages/topic_detail_page.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/topic_detail_share.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_forum.dart';
import 'support/fake_forum_comments.dart';

/// Konu detayı + yorum sistemi (MB-B). Sahte uçlar: FakeForum (konular) + FakeForumComments (yorumlar).
void main() {
  setUpAll(loadTestFonts);

  Future<({FakeBackend b, FakeForum f, FakeForumComments c, Session s})> open(
    WidgetTester tester, {
    int topicId = 500,
    int? commentId,
    Brightness brightness = Brightness.light,
    Size size = kPhoneMedium,
    bool seed = true,
    void Function(FakeForum f, FakeForumComments c)? prepare,
    TopicPollBuilder? pollBuilder,
    double textScale = 1,
  }) async {
    final b = FakeBackend();
    final f = fakeForum(b, count: 3);
    final c = fakeForumComments(b, f, seed: seed);
    prepare?.call(f, c);
    final s = makeSession(b);
    useScreen(tester, size);
    final page = TopicDetailPage(session: s, topicId: topicId, commentId: commentId, pollBuilder: pollBuilder);
    final Widget home = textScale == 1
        ? page
        : Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: page,
            ),
          );
    await tester.pumpWidget(buildApp(home, brightness: brightness));
    await settle(tester, const Duration(seconds: 1));
    return (b: b, f: f, c: c, s: s);
  }

  // Kaydırılabilir ana liste.
  Finder list() => find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;

  Future<void> reveal(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 250, scrollable: list(), maxScrolls: 80);
    await t.pump(const Duration(milliseconds: 100));
  }

  Finder card(int id) => find.byKey(ValueKey('commentCard-$id'));
  Finder inCard(int id, Key k) => find.descendant(of: card(id), matching: find.byKey(k));
  Finder field() => find.byKey(const ValueKey('commentField'));
  Finder send() => find.byKey(const ValueKey('commentSend'));

  Future<void> write(WidgetTester t, String text) async {
    await t.enterText(field(), text);
    await t.pump();
  }

  Future<void> tapSend(WidgetTester t, {Duration wait = const Duration(seconds: 1)}) async {
    await t.tap(send());
    await settle(t, wait);
  }

  Future<void> openMenu(WidgetTester t, int id) async {
    final f = find.byKey(ValueKey('commentMore-$id'));
    await reveal(t, f);
    await t.tap(f);
    await settle(t, const Duration(milliseconds: 500));
  }

  Future<void> pick(WidgetTester t, String action) async {
    await t.tap(find.byKey(ValueKey('commentAction-$action')));
    await settle(t, const Duration(milliseconds: 600));
  }

  Future<void> confirm(WidgetTester t, String label) async {
    await t.tap(find.widgetWithText(BuButton, label));
    await settle(t, const Duration(seconds: 1));
  }

  group('yukleme ve gorunum', () {
    testWidgets('konu ve ust duzey yorumlar yuklenir; yazar etiketi, anonim ad, silinmis yer tutucu', (tester) async {
      final r = await open(tester, prepare: (f, c) => c.byId(1)!['topicAuthor'] = true);
      expect(find.byKey(const ValueKey('topicTitle')), findsOneWidget);
      expect(find.text('Birinci yorum metni'), findsOneWidget);
      expect(find.text('Zeynep yanıtı'), findsOneWidget, reason: 'replyPreview');
      expect(find.byKey(const ValueKey('commentAuthorBadge')), findsOneWidget);
      expect(r.c.commentQueries.first, contains('sort=BEST'));
      await reveal(tester, find.text('Anonim görüş'));
      expect(find.text('Anonim #3'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('commentDeletedPlaceholder')));
      expect(find.text('Bu yorum silindi'), findsOneWidget);
      expect(find.text('Silinmişin yanıtı'), findsOneWidget, reason: 'silinmis yorumun yaniti gorunur');
      await unmount(tester);
    });

    testWidgets('yorum yok: bos durum; yazma cubugu yine acik', (tester) async {
      await open(tester, seed: false);
      expect(find.byKey(const ValueKey('commentsEmpty')), findsOneWidget);
      expect(find.text('Henüz yorum yok'), findsOneWidget);
      expect(field(), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yorum listesi sunucu hatasi: hata + yeniden dene', (tester) async {
      final r = await open(tester, prepare: (f, c) => c.failList = true);
      expect(find.byKey(const ValueKey('commentsError')), findsOneWidget);
      r.c.failList = false;
      await tester.tap(find.widgetWithText(BuButton, 'Yeniden dene'));
      await settle(tester);
      expect(find.text('Birinci yorum metni'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('internet yok: konu hata durumu, geri gelince yeniden dene calisir', (tester) async {
      final b = FakeBackend()..offline = true;
      final f = fakeForum(b, count: 3);
      fakeForumComments(b, f);
      final s = makeSession(b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(TopicDetailPage(session: s, topicId: 500)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('topicError')), findsOneWidget);
      b.offline = false;
      await tester.tap(find.widgetWithText(BuButton, 'Yeniden dene'));
      await settle(tester);
      expect(find.byKey(const ValueKey('topicTitle')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('silinmis konu (404): kisa mesaj; kaldirilmis konu (REMOVED): kaldirildi mesaji', (tester) async {
      await open(tester, topicId: 9999);
      expect(find.byKey(const ValueKey('topicGone')), findsOneWidget);
      expect(find.text('Bu konu artık yok'), findsOneWidget);
      expect(field(), findsNothing);
      await unmount(tester);

      await open(tester, prepare: (f, c) => f.byId(500)!['status'] = 'REMOVED');
      // FakeForum REMOVED konuyu 404 yapar; sunucu 200 + REMOVED dönerse de ayni ekran.
      expect(find.byKey(const ValueKey('topicGone')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yavas baglanti: yorumlar gecikince ipucu cikar', (tester) async {
      final r = await open(tester);
      r.b.delay = const Duration(seconds: 9);
      await tester.tap(find.byKey(const ValueKey('commentSort-newest')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      expect(find.byKey(const ValueKey('commentsSlow')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(find.byKey(const ValueKey('commentsSlow')), findsNothing);
      await unmount(tester);
    });

    testWidgets('anket: konuda anket varsa PollView gorunur; oy verilir ve sonuc konuya yansir', (tester) async {
      final poll = {
        'id': 1,
        'question': 'Hangisi?',
        'options': [
          {'id': 11, 'text': 'Secenek A', 'voteCount': 0, 'percent': 0},
          {'id': 12, 'text': 'Secenek B', 'voteCount': 0, 'percent': 0},
        ],
        'totalVotes': 0,
        'myOptionId': null,
        'closed': false,
        'allowChangeVote': false,
        'canVote': true,
      };
      final r = await open(tester, prepare: (f, c) => f.byId(500)!['poll'] = poll);
      r.b.handlers.add((req, path) {
        if (req.method == 'PUT' && path == '/forum/topics/500/poll/vote') {
          return FakeResult.json({
            ...poll,
            'options': [
              {'id': 11, 'text': 'Secenek A', 'voteCount': 1, 'percent': 100.0},
              {'id': 12, 'text': 'Secenek B', 'voteCount': 0, 'percent': 0},
            ],
            'totalVotes': 1,
            'myOptionId': 11,
          });
        }
        return null;
      });
      expect(find.byKey(const ValueKey('topicPoll')), findsOneWidget);
      expect(find.byKey(const ValueKey('pollView')), findsOneWidget);
      expect(find.text('Secenek A'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pollOption11')));
      await settle(tester, const Duration(seconds: 1));
      expect(r.b.bodies['PUT /forum/topics/500/poll/vote'], {'optionId': 11});
      await unmount(tester);
    });

    testWidgets('anket yuvasi: ozel pollBuilder verilirse o cizilir', (tester) async {
      await open(
        tester,
        prepare: (f, c) => f.byId(500)!['poll'] = {
          'id': 1,
          'question': 'Soru',
          'options': [
            {'id': 1, 'text': 'A', 'voteCount': 0, 'percent': 0},
            {'id': 2, 'text': 'B', 'voteCount': 0, 'percent': 0},
          ],
          'totalVotes': 0,
          'canVote': true,
        },
        pollBuilder: (context, api, topic, onChanged) => Text('ANKET ${topic.poll!.options.length}'),
      );
      expect(find.text('ANKET 2'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('galeri: coklu gorsel sayaci; dokununca tam ekran acilmaz', (tester) async {
      await open(tester, prepare: (f, c) {
        f.byId(500)!['images'] = [
          for (var i = 1; i <= 3; i++) {'id': i, 'url': '/api/forum/media/$i', 'thumbUrl': '/api/forum/media/$i', 'width': 800, 'height': 600},
        ];
      });
      expect(find.byKey(const ValueKey('topicGallery')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('topicGallery')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('topicGallery')), findsOneWidget, reason: 'yeni sayfa acilmadi');
      expect(find.byType(TopicDetailPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('siralama ve sayfalama', () {
    testWidgets('siralama cipleri: En yeni / En eski / En iyi istekleri', (tester) async {
      final r = await open(tester);
      await tester.tap(find.byKey(const ValueKey('commentSort-newest')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('commentSort-oldest')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('commentSort-best')));
      await settle(tester);
      expect(r.c.commentQueries.length, 4);
      expect(r.c.commentQueries[1], contains('sort=NEWEST'));
      expect(r.c.commentQueries[2], contains('sort=OLDEST'));
      expect(r.c.commentQueries[3], contains('sort=BEST'));
      await unmount(tester);
    });

    testWidgets('sayfalama: sona inince ikinci sayfa imlecle istenir ve tum yorumlar gelir', (tester) async {
      final r = await open(tester, prepare: (f, c) {
        for (var i = 0; i < 20; i++) {
          c.add(500, 'Toplu yorum $i', userId: 30 + i, name: 'Kisi $i');
        }
      });
      expect(r.c.commentQueries.length, 1);
      expect(r.c.commentQueries.first, contains('size=15'));
      await reveal(tester, find.text('Toplu yorum 0'));
      await tester.pump(const Duration(seconds: 1));
      expect(r.c.commentQueries.length, greaterThanOrEqualTo(2));
      expect(r.c.commentQueries[1], contains('cursor=p2'));
      await unmount(tester);
    });
  });

  group('yorum yazma', () {
    testWidgets('yorum yaz: govde temizlenir, Idempotency-Key gider, yorum listeye girer, alan bosalir', (tester) async {
      final r = await open(tester);
      await write(tester, '  Yeni yorumum  ');
      await tapSend(tester);
      expect(r.b.bodies['POST /forum/topics/500/comments'], {'body': 'Yeni yorumum', 'anonymous': false});
      expect(r.c.postKeys.single, isNotNull);
      expect(find.text('Yeni yorumum'), findsOneWidget);
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
      await unmount(tester);
    });

    testWidgets('yanit ver: Yanitla -> bant + dogru parent; iptal bandi kaldirir', (tester) async {
      final r = await open(tester);
      await tester.tap(find.byKey(const ValueKey('commentReply-1')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('commentTargetBanner')), findsOneWidget);
      expect(find.text('Mehmet Kaya kişisine yanıt veriyorsun'), findsOneWidget);
      // iptal
      await tester.tap(find.byKey(const ValueKey('commentCancelTarget')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('commentTargetBanner')), findsNothing);
      // tekrar yanıtla ve gönder
      await tester.tap(find.byKey(const ValueKey('commentReply-1')));
      await settle(tester, const Duration(milliseconds: 400));
      await write(tester, 'Katiliyorum');
      await tapSend(tester);
      expect(r.b.bodies['POST /forum/topics/500/comments'], {'body': 'Katiliyorum', 'parentCommentId': 1, 'anonymous': false});
      expect(find.text('Katiliyorum'), findsOneWidget);
      expect(find.byKey(const ValueKey('commentTargetBanner')), findsNothing, reason: 'gonderince hedef birakilir');
      await unmount(tester);
    });

    testWidgets('yanitin yaniti: ic ice yanit dogru parent ile gider ve girintili gorunur', (tester) async {
      final r = await open(tester);
      // c5 (seviye 1) -> yanit seviye 2.
      await tester.tap(find.byKey(const ValueKey('commentReply-5')));
      await settle(tester, const Duration(milliseconds: 400));
      await write(tester, 'Yanitin yaniti');
      await tapSend(tester);
      expect(r.b.bodies['POST /forum/topics/500/comments'], {'body': 'Yanitin yaniti', 'parentCommentId': 5, 'anonymous': false});
      expect(find.text('Yanitin yaniti'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('anonim secimi AYRI anahtar: varsayilan kapali, konu anonim olsa da acilmaz; gonderince kapanir', (tester) async {
      final r = await open(tester, prepare: (f, c) => f.byId(500)!['author'] = sampleForumAnonAuthor(4));
      await tester.tap(field());
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.widget<Switch>(find.byKey(const ValueKey('commentAnonSwitch'))).value, isFalse);
      await write(tester, 'Acik yorum');
      await tapSend(tester);
      expect(r.b.bodies['POST /forum/topics/500/comments'], {'body': 'Acik yorum', 'anonymous': false});
      // simdi anonim
      await tester.tap(field());
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('commentAnonToggle')));
      await tester.pump();
      expect(tester.widget<Switch>(find.byKey(const ValueKey('commentAnonSwitch'))).value, isTrue);
      await write(tester, 'Gizli yorum');
      await tapSend(tester);
      expect(r.b.bodies['POST /forum/topics/500/comments'], {'body': 'Gizli yorum', 'anonymous': true});
      await tester.tap(field());
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.widget<Switch>(find.byKey(const ValueKey('commentAnonSwitch'))).value, isFalse, reason: 'gonderim sonrasi kapanir');
      await unmount(tester);
    });

    testWidgets('gonderme hatasi: metin KAYBOLMAZ, ayni Idempotency-Key ile yeniden denenir', (tester) async {
      final r = await open(tester, prepare: (f, c) => c.failPost = true);
      await write(tester, 'Yarim kalan yorum');
      await tapSend(tester);
      expect(tester.widget<TextField>(field()).controller!.text, 'Yarim kalan yorum');
      expect(find.text('Sunucu hatası'), findsOneWidget);
      r.c.failPost = false;
      await tester.pump(const Duration(seconds: 4));
      await tapSend(tester);
      expect(r.c.postKeys.length, 2);
      expect(r.c.postKeys[0], r.c.postKeys[1], reason: 'ayni niyet = ayni anahtar');
      expect(find.text('Yarim kalan yorum'), findsOneWidget);
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
      await unmount(tester);
    });

    testWidgets('metin degisince yeni Idempotency-Key uretilir', (tester) async {
      final r = await open(tester, prepare: (f, c) => c.failPost = true);
      await write(tester, 'Birinci');
      await tapSend(tester);
      await write(tester, 'Ikinci');
      await tapSend(tester);
      expect(r.c.postKeys.length, 2);
      expect(r.c.postKeys[0], isNot(r.c.postKeys[1]));
      await unmount(tester);
    });

    testWidgets('cift dokunma korumasi: gonderirken ikinci dokunus yok sayilir', (tester) async {
      final r = await open(tester);
      r.b.delay = const Duration(milliseconds: 600);
      await write(tester, 'Tek yorum');
      await tester.tap(send());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('commentSending')), findsOneWidget, reason: 'gonderirken dönen çember');
      await tester.tap(send(), warnIfMissed: false);
      await tester.tap(send(), warnIfMissed: false);
      await settle(tester, const Duration(seconds: 2));
      expect(r.c.postCount, 1);
      expect(find.text('Tek yorum'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bos / yalniz bosluk metin gonderilemez', (tester) async {
      final r = await open(tester);
      await write(tester, '    ');
      await tester.tap(send(), warnIfMissed: false);
      await settle(tester, const Duration(milliseconds: 300));
      expect(r.c.postCount, 0);
      await unmount(tester);
    });

    testWidgets('4000 karakter ust siniri sessizce uygulanir; sayac gorunur', (tester) async {
      await open(tester);
      await tester.enterText(field(), 'a' * 4300);
      await tester.pump();
      expect(tester.widget<TextField>(field()).controller!.text.length, 4000);
      expect(find.byKey(const ValueKey('commentCounter')), findsOneWidget);
      expect(find.text('4000 / 4000'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kilitli konu: bant, pasif alan, Yanitla yok; sunucu 409 donerse mesaj + metin kalir', (tester) async {
      await open(tester, prepare: (f, c) => f.byId(500)!['locked'] = true);
      expect(find.byKey(const ValueKey('topicLockedBand')), findsOneWidget);
      expect(find.byKey(const ValueKey('commentLockedHint')), findsOneWidget);
      expect(field(), findsNothing);
      expect(find.byKey(const ValueKey('commentReply-1')), findsNothing);
      await unmount(tester);

      final r = await open(tester, prepare: (f, c) => c.lockedOnPost = true);
      await write(tester, 'Gec kaldim');
      await tapSend(tester);
      expect(find.text('Bu konu kilitli.'), findsOneWidget, reason: 'sunucu mesaji');
      expect(tester.widget<TextField>(field()).controller!.text, 'Gec kaldim');
      expect(r.c.postCount, 1);
      await unmount(tester);
    });
  });

  group('yanitlar ve zincir', () {
    testWidgets('yanitlari goster: replies ucu cagrilir; sayfalama; Yanitlari gizle', (tester) async {
      final r = await open(tester, prepare: (f, c) {
        for (var i = 0; i < 20; i++) {
          c.add(500, 'Cok yanit $i', parent: 6, userId: 40 + i, name: 'Yanitci $i');
        }
      });
      // BEST siralamada c6 en ustte: onizleme (2) acik, kalan 18 icin "daha" dugmesi.
      final first = find.byKey(const ValueKey('commentMoreReplies-6'));
      await reveal(tester, first);
      expect(find.text('18 yanıt daha'), findsOneWidget);
      await tester.tap(first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.c.replyQueries.single, contains('size=15'));
      expect(r.c.replyQueries.single, isNot(contains('cursor')));
      await reveal(tester, find.text('Cok yanit 14'));
      expect(find.text('Cok yanit 14'), findsOneWidget);
      // sonraki sayfa
      final more = find.byKey(const ValueKey('commentMoreReplies-6'));
      await reveal(tester, more);
      expect(more, findsOneWidget);
      await tester.tap(more);
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.c.replyQueries.length, 2);
      expect(r.c.replyQueries[1], contains('cursor=p2'));
      // gizle
      final hide = find.byKey(const ValueKey('commentHideReplies-6'));
      await reveal(tester, hide);
      await tester.tap(hide);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Cok yanit 14'), findsNothing);
      expect(find.byKey(const ValueKey('commentShowReplies-6')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('onizleme yanitlari acik gelir; Yanitlari gizle ile kapanir, N yaniti goster ile doner', (tester) async {
      await open(tester);
      expect(find.text('Zeynep yanıtı'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentHideReplies-1')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Zeynep yanıtı'), findsNothing);
      expect(find.text('2 yanıtı göster'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentShowReplies-1')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Zeynep yanıtı'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('derin zincir: girinti siniri asilinca Yanit zincirini ac -> ayri ekran, yanit yaz', (tester) async {
      final r = await open(tester);
      await tester.tap(find.byKey(const ValueKey('commentShowReplies-2')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Benim yanıtım'), findsOneWidget, reason: 'seviye 2');
      expect(find.text('Derin yanıt metni'), findsNothing, reason: 'seviye 3 satir ici cizilmez');
      final chain = find.byKey(const ValueKey('commentChain-3'));
      await reveal(tester, chain);
      expect(find.text('Yanıt zincirini aç (1)'), findsOneWidget);
      await tester.tap(chain);
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(CommentThreadPage), findsOneWidget);
      expect(find.text('Derin yanıt metni'), findsOneWidget);
      // zincirde yazilan yorum kok yorumun cocugudur
      await write(tester, 'Zincire eklendi');
      await tapSend(tester);
      expect(r.b.bodies['POST /forum/topics/500/comments'], {'body': 'Zincire eklendi', 'parentCommentId': 3, 'anonymous': false});
      expect(find.text('Zincire eklendi'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yanit listesi hatasi: satir ici hata + yeniden dene', (tester) async {
      final r = await open(tester, prepare: (f, c) => c.failReplies = true);
      await tester.tap(find.byKey(const ValueKey('commentShowReplies-2')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Yanıtlar yüklenemedi.'), findsOneWidget);
      r.c.failReplies = false;
      await tester.tap(find.byKey(const ValueKey('commentRepliesRetry-2')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Benim yanıtım'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('duzenle / sil / begen', () {
    testWidgets('duzenle yalniz sahip menusunde; metin editore gelir, Kaydet -> yerinde guncellenir + Duzenlendi', (tester) async {
      final r = await open(tester);
      // baskasinin yorumu: Duzenle/Sil yok
      await openMenu(tester, 1);
      expect(find.byKey(const ValueKey('commentAction-edit')), findsNothing);
      expect(find.byKey(const ValueKey('commentAction-delete')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('commentAction-reply')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('commentCancelTarget')));
      await settle(tester, const Duration(milliseconds: 400));
      // kendi yorumum
      await openMenu(tester, 6);
      expect(find.byKey(const ValueKey('commentAction-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('commentAction-delete')), findsOneWidget);
      await pick(tester, 'edit');
      expect(find.text('Yorumunu düzenliyorsun'), findsOneWidget);
      expect(tester.widget<TextField>(field()).controller!.text, 'Benim yorumum');
      await write(tester, 'Duzeltilmis yorum');
      await tapSend(tester);
      expect(r.b.bodies['PATCH /forum/comments/6'], {'body': 'Duzeltilmis yorum'});
      await reveal(tester, find.text('Duzeltilmis yorum'));
      expect(inCard(6, const ValueKey('commentEdited')), findsOneWidget);
      expect(find.text('Yorumunu düzenliyorsun'), findsNothing);
      await unmount(tester);
    });

    testWidgets('duzenlemeyi iptal: editor temizlenir, yeni yorum taslagi olmaz', (tester) async {
      await open(tester);
      await openMenu(tester, 6);
      await pick(tester, 'edit');
      await tester.tap(find.byKey(const ValueKey('commentCancelTarget')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
      await unmount(tester);
    });

    testWidgets('sil: onay penceresi; yanitsiz yorum listeden kalkar; sayac duser', (tester) async {
      final r = await open(tester);
      await openMenu(tester, 6);
      await pick(tester, 'delete');
      expect(find.text('Yorum silinsin mi?'), findsOneWidget);
      // vazgec
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.b.requests.where((q) => q.startsWith('DELETE /forum/comments')), isEmpty);
      await openMenu(tester, 6);
      await pick(tester, 'delete');
      await confirm(tester, 'Sil');
      expect(r.b.requests, contains('DELETE /forum/comments/6'));
      expect(find.text('Benim yorumum'), findsNothing);
      expect(find.text('Yorum silindi'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sil: yaniti olan yorum "Bu yorum silindi" yer tutucusu olur, yanitlari kalir', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('commentShowReplies-2')));
      await settle(tester, const Duration(milliseconds: 600));
      await openMenu(tester, 3);
      await pick(tester, 'delete');
      await confirm(tester, 'Sil');
      expect(inCard(3, const ValueKey('commentDeletedPlaceholder')), findsOneWidget);
      expect(find.text('Benim yanıtım'), findsNothing);
      expect(find.byKey(const ValueKey('commentChain-3')), findsOneWidget, reason: 'yanitlari ulasilabilir');
      await unmount(tester);
    });

    testWidgets('eszamanli silme (404): kisa mesaj + liste yenilenir', (tester) async {
      final r = await open(tester, prepare: (f, c) => c.goneOnWrite = true);
      await openMenu(tester, 6);
      await pick(tester, 'delete');
      await confirm(tester, 'Sil');
      expect(find.text('Bu yorum artık yok. Liste yenilendi.'), findsOneWidget);
      expect(r.c.commentQueries.length, 2, reason: 'yenilendi');
      await unmount(tester);
    });

    testWidgets('eszamanli duzenleme (409): cakisma mesaji', (tester) async {
      await open(tester, prepare: (f, c) => c.conflictOnWrite = true);
      await openMenu(tester, 6);
      await pick(tester, 'edit');
      await write(tester, 'Baska metin');
      await tapSend(tester);
      expect(find.text('Yorum başka bir yerde değişti. Liste yenilendi.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('begen: aninda geri bildirim (iyimser), PUT/DELETE; geri al', (tester) async {
      final r = await open(tester);
      r.b.delay = const Duration(milliseconds: 400);
      final like = inCard(1, const ValueKey('commentLike'));
      expect(find.descendant(of: like, matching: find.text('3')), findsOneWidget);
      await tester.tap(like);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.descendant(of: like, matching: find.text('4')), findsOneWidget, reason: 'sunucu yanitindan once');
      await settle(tester, const Duration(seconds: 2));
      expect(r.c.likeCalls, ['PUT 1']);
      expect(find.descendant(of: like, matching: find.text('4')), findsOneWidget);
      await tester.tap(like);
      await settle(tester, const Duration(seconds: 2));
      expect(r.c.likeCalls, ['PUT 1', 'DELETE 1']);
      expect(find.descendant(of: like, matching: find.text('3')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('cift beğeni yok: art arda hizli dokunus tek uçuş + son durum', (tester) async {
      final r = await open(tester);
      r.b.delay = const Duration(milliseconds: 400);
      final like = inCard(1, const ValueKey('commentLike'));
      await tester.tap(like);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(like);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(like);
      await settle(tester, const Duration(seconds: 4));
      // 3 dokunus = beğenildi; ayni anda en fazla bir istek ucuyor, sonuç tutarlı
      expect(r.c.liked.contains(1), isTrue);
      expect(find.descendant(of: like, matching: find.text('4')), findsOneWidget);
      expect(r.c.likeCalls.first, 'PUT 1');
      await unmount(tester);
    });

    testWidgets('begeni hatasi: onceki duruma geri alinir + hata mesaji', (tester) async {
      await open(tester, prepare: (f, c) => c.failLike = true);
      final like = inCard(1, const ValueKey('commentLike'));
      await tester.tap(like);
      await settle(tester, const Duration(seconds: 1));
      expect(find.descendant(of: like, matching: find.text('3')), findsOneWidget);
      expect(find.text('Hata'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('uzun basma menusu', () {
    testWidgets('baskasinin yorumu: Yanitla, Begen, Kopyala, Paylas, Kaydet, Sikayet, Engelle', (tester) async {
      await open(tester);
      await tester.longPress(find.text('Birinci yorum metni'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('commentActionsSheet')), findsOneWidget);
      for (final a in ['reply', 'like', 'save', 'copy', 'share', 'report', 'block']) {
        expect(find.byKey(ValueKey('commentAction-$a')), findsOneWidget, reason: a);
      }
      expect(find.byKey(const ValueKey('commentAction-edit')), findsNothing);
      expect(find.byKey(const ValueKey('commentAction-delete')), findsNothing);
      await unmount(tester);
    });

    testWidgets('kendi yorumu: Yanitla, Duzenle, Sil, Kopyala, Paylas; Sikayet/Engelle yok', (tester) async {
      await open(tester);
      await openMenu(tester, 6);
      for (final a in ['reply', 'edit', 'delete', 'copy', 'share']) {
        expect(find.byKey(ValueKey('commentAction-$a')), findsOneWidget, reason: a);
      }
      expect(find.byKey(const ValueKey('commentAction-report')), findsNothing);
      expect(find.byKey(const ValueKey('commentAction-block')), findsNothing);
      await unmount(tester);
    });

    testWidgets('kopyala + baglanti paylas + kaydet', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      String? shared;
      debugForumShare = (t) async => shared = t;
      addTearDown(() => debugForumShare = null);
      final r = await open(tester);
      await openMenu(tester, 1);
      await pick(tester, 'copy');
      expect(copied, 'Birinci yorum metni');
      expect(find.text('Metin kopyalandı'), findsOneWidget);
      await openMenu(tester, 1);
      await pick(tester, 'share');
      expect(shared, 'https://bukampus.com.tr/s/fc/1');
      await openMenu(tester, 1);
      await pick(tester, 'save');
      expect(r.c.saved, contains(1));
      await unmount(tester);
    });

    testWidgets('kullaniciyi engelle: onay + block-author + sonuc mesaji; anonim yazar icin de', (tester) async {
      final r = await open(tester);
      await openMenu(tester, 1);
      await pick(tester, 'block');
      expect(find.text('Bu kullanıcı engellensin mi?'), findsOneWidget);
      await confirm(tester, 'Engelle');
      expect(r.c.blockedComments, [1]);
      expect(find.text('Kullanıcı engellendi'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('commentMore-7')));
      await tester.pump(const Duration(seconds: 4));
      await openMenu(tester, 7);
      await pick(tester, 'block');
      await confirm(tester, 'Engelle');
      expect(r.c.blockedComments, [1, 7]);
      await unmount(tester);
    });

    testWidgets('uzun yorum: kesilir, Devamini oku / Daha az goster', (tester) async {
      await open(tester, prepare: (f, c) => c.byId(1)!['body'] = 'Cok uzun satir ' * 120);
      expect(find.byKey(const ValueKey('commentReadMore')), findsOneWidget);
      expect(find.text('Devamını oku'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('commentReadMore')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Daha az göster'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hesabi kaldirilmis yazar: Silinmis hesap yer tutucusu', (tester) async {
      await open(tester, prepare: (f, c) => c.byId(6)!['accountGone'] = true);
      await reveal(tester, find.text('Benim yorumum'));
      expect(find.text('Silinmiş hesap'), findsWidgets);
      await unmount(tester);
    });
  });

  group('baglantidan / bildirimden acma', () {
    testWidgets('ust duzey olmayan yorum (seviye 1): ata zinciri acilir ve yorum vurgulanir', (tester) async {
      final r = await open(tester, commentId: 5);
      expect(find.text('İkinci yanıt'), findsOneWidget);
      expect(r.b.requests.any((q) => q.startsWith('GET /forum/comments/5')), isTrue);
      final deco = tester.widget<AnimatedContainer>(card(5)).decoration as BoxDecoration?;
      expect(deco?.color, isNot(Colors.transparent));
      await unmount(tester);
    });

    testWidgets('baska sayfadaki yorum: listeye eklenip vurgulanir', (tester) async {
      await open(tester, commentId: 30, prepare: (f, c) {
        for (var i = 0; i < 20; i++) {
          c.add(500, 'Sayfa yorumu $i', userId: 30 + i, name: 'Kisi $i', id: 100 + i);
        }
        c.add(500, 'Hedef eski yorum', id: 30, userId: 50, name: 'Hedef Kisi');
        c.byId(30)!['likeCount'] = 0;
      });
      expect(find.text('Hedef eski yorum'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('girinti sinirindan derin yorum (seviye 3): yanit zinciri ekrani acilir', (tester) async {
      await open(tester, commentId: 4);
      expect(find.byType(CommentThreadPage), findsOneWidget);
      expect(find.text('Derin yanıt metni'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('silinmis yorumun yanitina baglanti: ust yer tutucu acilir', (tester) async {
      await open(tester, commentId: 9);
      expect(find.text('Silinmişin yanıtı'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bulunamayan yorum: kisa mesaj, sayfa calismaya devam eder', (tester) async {
      await open(tester, commentId: 777);
      expect(find.text('Bağlantıdaki yorum bulunamadı'), findsOneWidget);
      expect(find.text('Birinci yorum metni'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('konu etkilesimleri ve menusu', () {
    testWidgets('begen / kaydet / takip et: iyimser + sunucu', (tester) async {
      final r = await open(tester);
      await tester.tap(find.byKey(const ValueKey('topicLike')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.f.liked, contains(500));
      await tester.tap(find.byKey(const ValueKey('topicSave')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.f.saved, contains(500));
      await tester.tap(find.byKey(const ValueKey('topicFollow')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.f.followed, contains(500));
      // geri al
      await tester.tap(find.byKey(const ValueKey('topicLike')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.f.liked, isNot(contains(500)));
      await unmount(tester);
    });

    testWidgets('konu begenisi hatasi geri alinir', (tester) async {
      final r = await open(tester, prepare: (f, c) => f.failWrites = true);
      final before = r.f.byId(500)!['likeCount'] as int;
      await tester.tap(find.byKey(const ValueKey('topicLike')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(r.f.liked, isEmpty);
      expect(before, r.f.byId(500)!['likeCount']);
      await unmount(tester);
    });

    testWidgets('paylas: konu baglantisi', (tester) async {
      String? shared;
      debugForumShare = (t) async => shared = t;
      addTearDown(() => debugForumShare = null);
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('topicShare')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(shared, 'https://bukampus.com.tr/s/f/500');
      await unmount(tester);
    });

    testWidgets('baskasinin konusu menusu: Paylas, Sikayet, Yazari engelle; sahip secenekleri yok', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('topicMore')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('topicMenu-share')), findsOneWidget);
      expect(find.byKey(const ValueKey('topicMenu-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('topicMenu-block')), findsOneWidget);
      expect(find.byKey(const ValueKey('topicMenu-edit')), findsNothing);
      expect(find.byKey(const ValueKey('topicMenu-delete')), findsNothing);
      expect(find.byKey(const ValueKey('topicMenu-pin')), findsNothing);
      await unmount(tester);
    });

    testWidgets('konu sahibi: Duzenle, Sil, Bildirimleri kapat/ac; sil onayli ve sayfa kapanir', (tester) async {
      final b = FakeBackend();
      final f = fakeForum(b, count: 3);
      f.topics.insert(0, sampleForumTopic(id: 700, mine: true, title: 'Benim konum'));
      fakeForumComments(b, f, seed: false);
      final s = makeSession(b);
      useScreen(tester, kPhoneMedium);
      TopicSummary? popped = const TopicSummary(id: -1);
      await tester.pumpWidget(buildApp(Builder(
        builder: (context) => TextButton(
          onPressed: () async => popped = await openTopicDetail(context, s, 700),
          child: const Text('ac'),
        ),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('topicMore')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('topicMenu-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('topicMenu-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('topicMenu-report')), findsNothing);
      // bildirimleri kapat
      await tester.tap(find.byKey(const ValueKey('topicMenu-notifications')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.bodies['PUT /forum/topics/700/notifications'], {'enabled': false});
      // sil
      await tester.tap(find.byKey(const ValueKey('topicMore')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('topicMenu-delete')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Konu silinsin mi?'), findsOneWidget);
      await confirm(tester, 'Sil');
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests, contains('DELETE /forum/topics/700'));
      expect(find.byType(TopicDetailPage), findsNothing, reason: 'sayfa kapandi');
      expect(popped, isNull, reason: 'silinen konu: null doner');
      await unmount(tester);
    });

    testWidgets('moderator: Sabitle / Kilitle menude; moderate cagrisi + konu guncellenir', (tester) async {
      final r = await open(tester, prepare: (f, c) {
        f.byId(500)!['canModerate'] = true;
        f.byId(500)!['pinned'] = false;
      });
      await tester.tap(find.byKey(const ValueKey('topicMore')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('topicMenu-pin')), findsOneWidget);
      expect(find.byKey(const ValueKey('topicMenu-lock')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('topicMenu-lock')));
      await settle(tester, const Duration(seconds: 1));
      expect(r.c.moderations, ['LOCK']);
      expect(find.byKey(const ValueKey('topicLockedBand')), findsOneWidget);
      expect(find.byKey(const ValueKey('commentLockedHint')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yazari engelle: onay + block-author + sayfa kapanir', (tester) async {
      final b = FakeBackend();
      final f = fakeForum(b, count: 3);
      final c = fakeForumComments(b, f);
      final s = makeSession(b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(Builder(
        builder: (context) => TextButton(onPressed: () => openTopicDetail(context, s, 500), child: const Text('ac')),
      )));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('topicMore')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('topicMenu-block')));
      await settle(tester, const Duration(milliseconds: 600));
      await confirm(tester, 'Engelle');
      await settle(tester, const Duration(seconds: 1));
      expect(c.blockedTopics, [500]);
      expect(find.byType(TopicDetailPage), findsNothing);
      await unmount(tester);
    });
  });

  group('tema ve erisilebilirlik', () {
    testWidgets('koyu mod: tum durumlar hatasiz cizilir', (tester) async {
      await open(tester, brightness: Brightness.dark);
      expect(find.text('Birinci yorum metni'), findsOneWidget);
      await openMenu(tester, 1);
      expect(find.byKey(const ValueKey('commentActionsSheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('buyuk yazi olcegi (2.0) ve dar ekran (320): tasma yok', (tester) async {
      await open(tester, size: kPhoneSmall, textScale: 2.0);
      await reveal(tester, find.text('Birinci yorum metni'));
      expect(find.text('Birinci yorum metni'), findsOneWidget);
      await tester.tap(field());
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('commentReply-1')), warnIfMissed: false);
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('dokunma hedefleri >= 44 dp (begen, yanitla, daha fazla, gonder)', (tester) async {
      await open(tester);
      for (final k in [
        inCard(1, const ValueKey('commentLike')),
        find.byKey(const ValueKey('commentReply-1')),
        find.byKey(const ValueKey('commentMore-1')),
        send(),
      ]) {
        final size = tester.getSize(k.first);
        expect(size.height, greaterThanOrEqualTo(44), reason: '$k');
        expect(size.width, greaterThanOrEqualTo(44), reason: '$k');
      }
      await unmount(tester);
    });

    testWidgets('hareketi azalt: yanit gizle aninda kapanir (animasyon beklemeden)', (tester) async {
      final b = FakeBackend();
      final f = fakeForum(b, count: 3);
      fakeForumComments(b, f);
      final s = makeSession(b);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: TopicDetailPage(session: s, topicId: 500),
        ),
      )));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('commentHideReplies-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Zeynep yanıtı'), findsNothing);
      await unmount(tester);
    });
  });
}
