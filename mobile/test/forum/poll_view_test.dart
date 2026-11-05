import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/forum/data/forum_api.dart';
import 'package:bu_kampus/features/forum/data/forum_models.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/poll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_compose.dart';

class _Host extends StatefulWidget {
  const _Host({super.key, required this.poll, required this.api, required this.log, this.now});
  final ForumPoll poll;
  final ForumApi api;
  final List<ForumPoll> log;
  final DateTime Function()? now;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late ForumPoll poll = widget.poll;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: PollView(
            poll: poll,
            api: widget.api,
            topicId: 500,
            now: widget.now,
            onChanged: (p) {
              widget.log.add(p);
              setState(() => poll = p);
            },
          ),
        ),
      );
}

class _Env {
  _Env({Duration delay = Duration.zero})
      : b = FakeBackend(delay: delay) {
    f = fakeForum(b, count: 1);
    c = fakeForumCompose(b, f);
    s = makeSession(b);
  }
  final FakeBackend b;
  late final FakeForum f;
  late final FakeForumCompose c;
  late final Session s;
  final List<ForumPoll> log = [];
  ForumPoll poll(Map<String, dynamic> json) => ForumPoll.fromJson(json);
}

Future<_Env> _pump(
  WidgetTester tester, {
  bool allowChange = false,
  bool closed = false,
  String? endsAt,
  int? mine,
  Duration delay = Duration.zero,
  Brightness brightness = Brightness.light,
  Size size = kPhoneMedium,
  DateTime Function()? now,
  String? question,
}) async {
  final e = _Env(delay: delay);
  final json = e.c.addPoll(500, allowChangeVote: allowChange, closed: closed, endsAt: endsAt, myOptionId: mine, question: question);
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(
    _Host(key: UniqueKey(), poll: e.poll(json), api: ForumApi(e.s), log: e.log, now: now),
    brightness: brightness,
    size: size,
  ));
  await settle(tester, const Duration(milliseconds: 300));
  return e;
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  group('applyVote (iyimser hesap)', () {
    test('ilk oy: toplam +1, yüzdeler 1 ondalık', () {
      final p = ForumPoll.fromJson({
        'id': 1,
        'options': [
          {'id': 1, 'text': 'a', 'voteCount': 1},
          {'id': 2, 'text': 'b', 'voteCount': 1},
          {'id': 3, 'text': 'c', 'voteCount': 0},
        ],
        'totalVotes': 2,
      });
      final n = applyVote(p, 3);
      expect(n.totalVotes, 3);
      expect(n.myOptionId, 3);
      expect(n.options.map((o) => o.voteCount), [1, 1, 1]);
      expect(n.options.map((o) => o.percent), [33.3, 33.3, 33.3]);
    });

    test('değiştirme: eski -1, yeni +1, toplam sabit', () {
      final p = ForumPoll.fromJson({
        'id': 1,
        'options': [
          {'id': 1, 'text': 'a', 'voteCount': 3},
          {'id': 2, 'text': 'b', 'voteCount': 1},
        ],
        'totalVotes': 4,
        'myOptionId': 1,
      });
      final n = applyVote(p, 2);
      expect(n.totalVotes, 4);
      expect(n.options.map((o) => o.voteCount), [2, 2]);
      expect(n.options.map((o) => o.percent), [50.0, 50.0]);
    });

    test('geri alma: toplam -1, oy yok; sıfırın altına inmez', () {
      final p = ForumPoll.fromJson({
        'id': 1,
        'options': [
          {'id': 1, 'text': 'a', 'voteCount': 1},
          {'id': 2, 'text': 'b', 'voteCount': 0},
        ],
        'totalVotes': 1,
        'myOptionId': 1,
      });
      final n = applyVote(p, null);
      expect(n.totalVotes, 0);
      expect(n.myOptionId, isNull);
      expect(n.options.map((o) => o.percent), [0.0, 0.0]);
    });
  });

  testWidgets('seçenekler, yüzde (1 ondalık), oy sayısı ve toplam gösterilir', (tester) async {
    await _pump(tester, question: 'Yemek nasıldı?');
    expect(find.text('Yemek nasıldı?'), findsOneWidget);
    expect(find.text('Evet'), findsOneWidget);
    expect(find.text('%60,0'), findsOneWidget);
    expect(find.text('%40,0'), findsOneWidget);
    expect(find.text('10 oy'), findsOneWidget); // toplam
    expect(find.text('6 oy'), findsOneWidget);
    expect(find.text('Oy verdikten sonra değiştirilemez'), findsOneWidget);
  });

  testWidgets('oy ver: iyimser güncelleme, istek gövdesi, sunucu yanıtı onChanged ile döner', (tester) async {
    final e = await _pump(tester, delay: const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('pollOption2')));
    await tester.pump();
    // Yanıt gelmeden toplam 11 ve işaretli.
    expect(find.text('11 oy'), findsOneWidget);
    await settle(tester, const Duration(milliseconds: 800));
    expect((e.b.bodies['PUT /forum/topics/500/poll/vote'] as Map)['optionId'], 2);
    expect(e.log, hasLength(1));
    expect(e.log.single.myOptionId, 2);
    expect(find.text('11 oy'), findsOneWidget);
    expect(find.text('%54,5'), findsOneWidget);
    expect(find.text('%45,5'), findsOneWidget);
  });

  testWidgets('çift dokunma tek istek', (tester) async {
    final e = await _pump(tester, delay: const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('pollOption1')));
    await tester.tap(find.byKey(const ValueKey('pollOption2')), warnIfMissed: false);
    await tester.tap(find.byKey(const ValueKey('pollOption1')), warnIfMissed: false);
    await settle(tester, const Duration(seconds: 1));
    expect(e.c.voteCalls, 1);
  });

  testWidgets('oy değiştirilemiyorsa ikinci oy istek atmaz, kısa bilgi verir', (tester) async {
    final e = await _pump(tester, mine: 1);
    expect(find.byKey(const ValueKey('pollUndo')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pollOption2')));
    await settle(tester, const Duration(milliseconds: 400));
    expect(e.c.voteCalls, 0);
    expect(find.textContaining('zaten kayıtlı'), findsOneWidget);
  });

  testWidgets('oy değiştirilebilir: başka seçeneğe dokun -> kaydırılır, toplam sabit', (tester) async {
    final e = await _pump(tester, allowChange: true, mine: 1);
    expect(find.text('Oyunu değiştirebilirsin'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pollOption2')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(e.c.voteCalls, 1);
    expect(e.c.myVotes[500], 2);
    expect(find.text('10 oy'), findsOneWidget);
    expect(e.log.single.myOptionId, 2);
    // Kendi seçeneğine tekrar dokunmak istek atmaz.
    await tester.tap(find.byKey(const ValueKey('pollOption2')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(e.c.voteCalls, 1);
  });

  testWidgets('geri al: oy kalkar, toplam düşer', (tester) async {
    final e = await _pump(tester, allowChange: true, mine: 1);
    await tester.tap(find.byKey(const ValueKey('pollUndo')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(e.c.myVotes.containsKey(500), isFalse);
    expect(find.text('9 oy'), findsOneWidget);
    expect(find.byKey(const ValueKey('pollUndo')), findsNothing);
    expect(e.log.single.myOptionId, isNull);
  });

  testWidgets('kapalı anket: pasif, "Anket sona erdi", dokunuş istek atmaz', (tester) async {
    final e = await _pump(tester, closed: true);
    expect(find.text('Anket sona erdi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pollOption1')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(e.c.voteCalls, 0);
    expect(find.byKey(const ValueKey('pollUndo')), findsNothing);
  });

  testWidgets('bitiş zamanı geçmiş anket kapalı sayılır; gelecekteyse kalan süre yazılır', (tester) async {
    final now = DateTime.utc(2026, 11, 5, 12);
    final e = await _pump(tester, endsAt: '2026-11-05T11:00:00Z', now: () => now);
    await tester.tap(find.byKey(const ValueKey('pollOption1')));
    await settle(tester, const Duration(milliseconds: 300));
    expect(e.c.voteCalls, 0);
    expect(find.text('Anket sona erdi'), findsOneWidget);
  });

  testWidgets('kalan süre: gün / saat / dakika', (tester) async {
    final now = DateTime.utc(2026, 11, 5, 12);
    await _pump(tester, endsAt: '2026-11-08T13:00:00Z', now: () => now);
    expect(find.text('3 gün kaldı'), findsOneWidget);
    await _pump(tester, endsAt: '2026-11-05T15:30:00Z', now: () => now);
    expect(find.text('3 saat kaldı'), findsOneWidget);
    await _pump(tester, endsAt: '2026-11-05T12:20:00Z', now: () => now);
    expect(find.text('20 dakika kaldı'), findsOneWidget);
  });

  testWidgets('hata: iyimser güncelleme geri alınır, kısa mesaj', (tester) async {
    final e = await _pump(tester);
    e.c.voteError = const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
    await tester.tap(find.byKey(const ValueKey('pollOption2')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('10 oy'), findsOneWidget);
    expect(find.text('%40,0'), findsOneWidget);
    expect(find.textContaining('Oy işlemi yapılamadı'), findsOneWidget);
    expect(e.log, isEmpty);
  });

  testWidgets('FORUM_POLL_CLOSED: geri alınır ve anket kapalı görünür', (tester) async {
    final e = await _pump(tester);
    e.c.voteError = const FakeResult.json({'code': 'FORUM_POLL_CLOSED', 'message': 'x'}, status: 409);
    await tester.tap(find.byKey(const ValueKey('pollOption2')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('10 oy'), findsOneWidget);
    expect(find.text('Anket sona erdi'), findsWidgets);
  });

  testWidgets('ağ yok ve hız sınırı mesajları', (tester) async {
    final e = await _pump(tester);
    e.b.offline = true;
    await tester.tap(find.byKey(const ValueKey('pollOption1')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.textContaining('İnternet bağlantısı yok'), findsOneWidget);
    e.b.offline = false;
    e.c.voteError = const FakeResult.json({'code': 'RATE_LIMITED', 'message': 'x'}, status: 429);
    await tester.tap(find.byKey(const ValueKey('pollOption1')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.textContaining('Çok sık'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('küçük ekran + büyük yazı: taşma yok (${dark ? 'koyu' : 'açık'})', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = old);
      final e = _Env();
      final json = e.c.addPoll(500,
          options: const [(1, 'Çok uzun bir seçenek metni burada yer alıyor ve satıra sığmayabilir', 12345), (2, 'Kısa', 7)],
          allowChangeVote: true,
          myOptionId: 1,
          question: 'Uzun bir anket sorusu da burada olabilir mi acaba?');
      useScreen(tester, kPhoneSmall);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildApp(_Host(poll: e.poll(json), api: ForumApi(e.s), log: e.log),
          brightness: dark ? Brightness.dark : Brightness.light));
      await settle(tester, const Duration(milliseconds: 400));
      expect(errors.where((d) => d.exceptionAsString().contains('overflowed')), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
