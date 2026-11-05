import 'package:bu_kampus/features/forum/forum_routes.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/report_sheet.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_extras.dart';
import '../support/forum_d_harness.dart';

/// Sheet/akislari acan sade ana sayfa.
class _Host extends StatelessWidget {
  const _Host({required this.session, required this.onResult, this.type = kForumReportComment, this.id = 55, this.offerBlock = true});

  final dynamic session;
  final void Function(Object?) onResult;
  final String type;
  final int id;
  final bool offerBlock;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          TextButton(
            key: const ValueKey('open-report'),
            onPressed: () async => onResult(await showForumReportSheet(context, session, targetType: type, targetId: id, offerBlock: offerBlock)),
            child: const Text('rapor'),
          ),
          TextButton(
            key: const ValueKey('open-report-route'),
            onPressed: () async => onResult(await openReportSheet(context, session, targetType: type, targetId: id, anonymousAuthor: true)),
            child: const Text('rota'),
          ),
          TextButton(
            key: const ValueKey('open-block'),
            onPressed: () async => onResult(await openBlockAuthor(context, session, targetType: type, targetId: id)),
            child: const Text('engelle'),
          ),
          TextButton(
            key: const ValueKey('open-mute'),
            onPressed: () async => onResult(await openMuteUser(context, session, userId: 12, name: 'Mehmet Kaya')),
            child: const Text('sessiz'),
          ),
        ]),
      );
}

void main() {
  late FakeBackend b;
  late FakeForum f;
  late FakeForumExtras x;
  Object? result;
  var results = 0;

  setUp(() {
    b = FakeBackend();
    f = fakeForum(b, count: 3);
    x = fakeForumExtras(f);
    result = null;
    results = 0;
  });

  Future<void> open(WidgetTester tester, {String type = kForumReportComment, int id = 55, bool offerBlock = true, Brightness brightness = Brightness.light, double scale = 1, Size size = kPhoneMedium}) async {
    useScreen(tester, size);
    await tester.pumpWidget(forumDApp(
      _Host(
        session: makeSession(b),
        type: type,
        id: id,
        offerBlock: offerBlock,
        onResult: (r) {
          result = r;
          results++;
        },
      ),
      brightness: brightness,
      textScale: scale,
    ));
    await settle(tester, const Duration(milliseconds: 200));
  }

  Future<void> openSheet(WidgetTester tester, [String key = 'open-report']) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await settle(tester, const Duration(milliseconds: 500));
  }

  bool sendEnabled(WidgetTester tester) => tester.widget<BuButton>(find.byKey(const ValueKey('forum-report-send'))).onPressed != null;

  group('sikayet alt sayfasi', () {
    testWidgets('neden secilmeden Gonder pasif; 5 neden listelenir', (tester) async {
      await open(tester);
      await openSheet(tester);
      for (final c in ['SPAM', 'HARASSMENT', 'PERSONAL_INFO', 'INAPPROPRIATE', 'OTHER']) {
        expect(find.byKey(ValueKey('forum-report-reason-$c')), findsOneWidget, reason: c);
      }
      expect(find.text('Kişisel bilgi paylaşımı'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('forum-report-reason-SPAM')));
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
    });

    testWidgets('gonderince POST /reports (hedef turu + neden + not), tesekkur bildirimi, sonuc true', (tester) async {
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('forum-report-reason-PERSONAL_INFO')));
      await tester.enterText(find.byKey(const ValueKey('forum-report-note')), 'Telefon numarası var');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forum-report-send')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(x.reports.single, {'targetType': 'FORUM_COMMENT', 'targetId': 55, 'reason': 'PERSONAL_INFO', 'note': 'Telefon numarası var'});
      expect(result, isTrue);
      expect(find.byKey(const ValueKey('forum-report-send')), findsNothing, reason: 'sayfa kapanmalı');
      expect(find.textContaining('Teşekkürler'), findsOneWidget);
      expect(x.blocks, isEmpty);
    });

    testWidgets('not bossa gonderilmez; konu hedefi FORUM_TOPIC; anonim yazar icin kimlik alani yok', (tester) async {
      await open(tester, type: kForumReportTopic, id: 500);
      await openSheet(tester, 'open-report-route'); // openReportSheet (anonymousAuthor: true)
      await tester.tap(find.byKey(const ValueKey('forum-report-reason-HARASSMENT')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forum-report-send')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(x.reports.single, {'targetType': 'FORUM_TOPIC', 'targetId': 500, 'reason': 'HARASSMENT'});
      expect(result, isTrue);
    });

    testWidgets('yinelenen sikayet (409): kisa bilgi mesaji, sayfa kapanir, sonuc false', (tester) async {
      x.reported.add('FORUM_COMMENT:55');
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('forum-report-reason-SPAM')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forum-report-send')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(result, isFalse);
      expect(results, 1);
      expect(find.text('Bu içeriği zaten bildirmiştin.'), findsOneWidget);
      expect(find.byKey(const ValueKey('forum-report-send')), findsNothing);
    });

    testWidgets('sunucu hatasi: sayfa acik kalir, hata metni gorunur; yeniden denenince gider', (tester) async {
      x.failReport = true;
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('forum-report-reason-OTHER')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forum-report-send')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('forum-report-error')), findsOneWidget);
      expect(results, 0);
      x.failReport = false;
      await tester.tap(find.byKey(const ValueKey('forum-report-send')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(x.reports.length, 1);
      expect(result, isTrue);
    });

    testWidgets('"Bu yazari da engelle" acikken sikayetten sonra block-author cagrilir (yorum)', (tester) async {
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('forum-report-reason-SPAM')));
      await tester.tap(find.byKey(const ValueKey('forum-report-block-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forum-report-send')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(x.reports.length, 1);
      expect(x.blocks, ['comment:55']);
      expect(find.textContaining('Yazar engellendi'), findsOneWidget);
    });

    testWidgets('konu sikayetinde engel konu ucundan gider; offerBlock=false anahtari gizler', (tester) async {
      await open(tester, type: kForumReportTopic, id: 500);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('forum-report-reason-SPAM')));
      await tester.tap(find.byKey(const ValueKey('forum-report-block-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forum-report-send')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(x.blocks, ['topic:500']);

      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, offerBlock: false);
      await openSheet(tester);
      expect(find.byKey(const ValueKey('forum-report-block-toggle')), findsNothing);
    });

    testWidgets('engel basarisiz olsa da sikayet gitmis sayilir', (tester) async {
      x.failBlock = true;
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('forum-report-reason-SPAM')));
      await tester.tap(find.byKey(const ValueKey('forum-report-block-toggle')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('forum-report-send')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(x.reports.length, 1);
      expect(result, isTrue);
      expect(x.blocks, isEmpty);
    });

    testWidgets('kapatilirsa istek yok, sonuc false', (tester) async {
      await open(tester);
      await openSheet(tester);
      await tester.tapAt(const Offset(10, 60)); // bariyer
      await settle(tester, const Duration(milliseconds: 500));
      expect(x.reports, isEmpty);
      expect(result, isFalse);
    });

    testWidgets('koyu tema + buyuk yazi + dar ekran: tasma yok', (tester) async {
      await open(tester, brightness: Brightness.dark, scale: 2.0, size: kPhoneSmall);
      await openSheet(tester);
      expectNoException(tester);
      expect(find.byKey(const ValueKey('forum-report-send')), findsOneWidget);
    });
  });

  group('yazari engelle / sessize al', () {
    testWidgets('onay sonrasi block-author (anonim dahil); toast; sonuc true', (tester) async {
      await open(tester, type: kForumReportTopic, id: 500);
      await openSheet(tester, 'open-block');
      expect(find.text('Yazar engellensin mi?'), findsOneWidget);
      // Onay metni kimlik/ad icermez.
      expect(find.textContaining('anonim olsa da'), findsOneWidget);
      await tester.tap(find.text('Engelle'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(x.blocks, ['topic:500']);
      expect(result, isTrue);
      expect(find.text('Yazar engellendi.'), findsOneWidget);
    });

    testWidgets('vazgecilirse istek yok', (tester) async {
      await open(tester);
      await openSheet(tester, 'open-block');
      await tester.tap(find.text('Vazgeç'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(x.blocks, isEmpty);
      expect(result, isFalse);
    });

    testWidgets('engel hatasi: sonuc false + hata bildirimi', (tester) async {
      x.failBlock = true;
      await open(tester);
      await openSheet(tester, 'open-block');
      await tester.tap(find.text('Engelle'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(result, isFalse);
      expect(find.byIcon(BuIcons.circleAlert), findsOneWidget);
    });

    testWidgets('sessize al: ad onay metninde, PUT /forum/mutes/{id}', (tester) async {
      await open(tester);
      await openSheet(tester, 'open-mute');
      expect(find.textContaining('Mehmet Kaya'), findsOneWidget);
      await tester.tap(find.text('Sessize al').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests, contains('PUT /forum/mutes/12'));
      expect(result, isTrue);
      expect(x.mutes.single['userId'], 12);
    });
  });
}
