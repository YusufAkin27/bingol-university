import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

Future<void> show(WidgetTester tester, Widget w, {Size size = kPhoneMedium, Brightness b = Brightness.light, bool rtl = false}) async {
  useScreen(tester, size);
  final home = rtl ? Directionality(textDirection: TextDirection.rtl, child: w) : w;
  await tester.pumpWidget(buildApp(home, brightness: b, size: size));
  await tester.pumpAndSettle();
}

void main() {
  group('anket tasarimi', () {
    for (final size in kPhoneSizes) {
      for (final br in Brightness.values) {
        testWidgets('liste ${size.width.toInt()} $br', (tester) async {
          final b = FakeBackend();
          final f = fakePolls(b, count: 0);
          f.polls
            ..add(samplePoll(id: 1, title: 'Genel anket ' * 6, communityId: null, communityName: null, anonymous: true))
            ..add(samplePoll(id: 2, title: 'Kulup anketi', myOptionIds: [201]))
            ..add(samplePoll(id: 3, title: 'Menu', type: 'RATING', communityId: null));
          await show(tester, PollListPage(session: makeSession(b)), size: size, b: br);
          expect(find.text('Gizli oy'), findsOneWidget);
          expect(find.text('Oy ver'), findsWidgets);
          noErr(tester);
        });

        testWidgets('sonuc ${size.width.toInt()} $br', (tester) async {
          final b = FakeBackend();
          final f = fakePolls(b, count: 1);
          f.polls[0] = samplePoll(id: 1, anonymous: true, myOptionIds: [101], optionCount: 5, title: 'Uzun baslik ' * 8);
          await show(tester, PollDetailPage(session: makeSession(b), pollId: 1), size: size, b: br);
          expect(find.textContaining('Oyunuz gizlidir', skipOffstage: false), findsOneWidget);
          noErr(tester);
        });

        testWidgets('puanlama sonucu ${size.width.toInt()} $br', (tester) async {
          final b = FakeBackend();
          final f = fakePolls(b, count: 1);
          f.polls[0] = samplePoll(id: 1, type: 'RATING', myRating: 4);
          await show(tester, PollDetailPage(session: makeSession(b), pollId: 1), size: size, b: br);
          noErr(tester);
        });

        testWidgets('form ${size.width.toInt()} $br', (tester) async {
          final b = FakeBackend();
          fakePolls(b, count: 0);
          await show(tester, PollFormPage(session: makeSession(b), communityId: 5), size: size, b: br);
          expect(find.text('Yayınla'), findsOneWidget);
          noErr(tester);
        });
      }
    }

    testWidgets('RTL: liste, oylama, form tasmaz', (tester) async {
      final b = FakeBackend();
      final f = fakePolls(b, count: 0);
      f.polls
        ..add(samplePoll(id: 1, type: 'RANKED', anonymous: true))
        ..add(samplePoll(id: 2, type: 'MULTI'));
      await show(tester, PollListPage(session: makeSession(b)), size: kPhoneSmall, rtl: true);
      noErr(tester);
      await show(tester, PollDetailPage(session: makeSession(b), pollId: 1), size: kPhoneSmall, rtl: true);
      noErr(tester);
      await show(tester, PollFormPage(session: makeSession(b), communityId: 5), size: kPhoneSmall, rtl: true);
      noErr(tester);
    });

    testWidgets('form: varsayilan gorunurluk AFTER_VOTE, bildirim acik', (tester) async {
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await show(tester, PollFormPage(session: makeSession(b), communityId: 5), size: const Size(390, 2400));
      await tester.enterText(find.byType(TextField).first, 'Gun secimi');
      await tester.enterText(find.byType(TextField).at(2), 'Pazartesi');
      await tester.enterText(find.byType(TextField).at(3), 'Sali');
      await tester.pump();
      await tester.tap(find.text('Yayınla'));
      await tester.pumpAndSettle();
      final body = b.bodies['POST /polls'] as Map;
      expect(body['showResults'], 'AFTER_VOTE');
      expect(body['notify'], true);
      noErr(tester);
    });
  });
}
