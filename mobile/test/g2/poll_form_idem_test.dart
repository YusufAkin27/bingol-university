import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

void main() {
  setUpAll(loadTestFonts);

  /// POST /polls başlıklarını ve sırasını kaydeder; [failFirst] ise ilk istek 503 döner (yanıt kaybı benzetimi).
  Future<(FakeBackend, List<String?>)> setup(WidgetTester tester, {bool failFirst = false}) async {
    useScreen(tester, const Size(390, 844));
    final b = FakeBackend();
    final keys = <String?>[];
    b.handlers.add((req, path) {
      if (req.method == 'POST' && path == '/polls') {
        keys.add(req.headers['Idempotency-Key']);
        if (failFirst && keys.length == 1) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 503);
        return FakeResult.json(samplePoll(id: 9, title: 'Anket'), status: 201);
      }
      return null;
    });
    await tester.pumpWidget(buildApp(Builder(
      builder: (c) => Center(
        child: TextButton(
          key: const ValueKey('open'),
          onPressed: () =>
              Navigator.of(c).push<Object?>(MaterialPageRoute<Object?>(builder: (_) => PollFormPage(session: makeSession(b), communityId: 5))),
          child: const Text('ac'),
        ),
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('open')));
    await settle(tester, const Duration(milliseconds: 600));
    return (b, keys);
  }

  Future<void> fill(WidgetTester tester, {String title = 'Hangi gun?'}) async {
    final f = find.byType(TextField);
    await tester.enterText(f.at(0), title);
    await tester.enterText(f.at(2), 'Pazartesi');
    await tester.enterText(f.at(3), 'Sali');
    await tester.pump();
  }

  Future<void> publish(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Yayınla'));
    await tester.tap(find.text('Yayınla'));
    await settle(tester, const Duration(milliseconds: 800));
  }

  testWidgets('anket olusturma Idempotency-Key gonderir; yanit kaybolursa ayni anahtarla yeniden dener (tek anket)', (tester) async {
    final (_, keys) = await setup(tester, failFirst: true);
    await fill(tester);
    await publish(tester);
    expect(keys, hasLength(1));
    expect(keys.first, isNotNull);
    expect(keys.first!.length, inInclusiveRange(8, 64));
    expect(find.byType(PollFormPage), findsOneWidget, reason: 'hata: form acik, icerik korunur');
    await publish(tester);
    expect(keys, hasLength(2));
    expect(keys[1], keys[0], reason: 'gecici hatada ayni anahtar');
    expect(find.byType(PollFormPage), findsNothing);
  });

  testWidgets('icerik degisince yeni anahtar', (tester) async {
    final (_, keys) = await setup(tester, failFirst: true);
    await fill(tester);
    await publish(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Baska baslik');
    await publish(tester);
    expect(keys, hasLength(2));
    expect(keys[1], isNot(keys[0]));
  });

  testWidgets('cift dokunus: tek istek', (tester) async {
    final (_, keys) = await setup(tester);
    await fill(tester);
    await tester.ensureVisible(find.text('Yayınla'));
    await tester.tap(find.text('Yayınla'));
    await tester.tap(find.text('Yayınla'), warnIfMissed: false);
    await settle(tester, const Duration(milliseconds: 800));
    expect(keys, hasLength(1));
  });

  testWidgets('geri jesti: dolu formda onay sorulur (vazgec formda tutar), bos formda onaysiz kapanir', (tester) async {
    await setup(tester);
    await fill(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byType(PollFormPage), findsOneWidget, reason: 'onay sorulur, kapanmaz');
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('bos formda geri onaysiz kapanir', (tester) async {
    await setup(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    await nav.maybePop();
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byType(PollFormPage), findsNothing);
  });
}
