import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/events/calm_cover.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// DD (Kulupler, Anketler, Destek, Etkinlikler, Akademik) mimar cilasi testleri:
/// sakin kapak (kirmizi vitrin yok, palet tonlari), dikey oy dugmesi, derste Bekliyor gurultusu yok.
class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

Map<String, dynamic> _event() => {
      'id': 5,
      'title': 'Bahar Şenliği',
      'description': 'Kampüs şenliği.',
      'startsAt': DateTime.now().add(const Duration(days: 5)).toUtc().toIso8601String(),
      'location': 'Açık Hava Sahnesi',
      'communityId': 7,
      'communityName': 'Müzik Kulübü',
      'goingCount': 3,
      'interestedCount': 1,
      'status': 'ACTIVE',
      'joinPolicy': 'OPEN',
      'canManage': false,
      'coverUrl': null,
    };

FakeBackend _eventBe() => FakeBackend()
  ..on('/events/5', _event())
  ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': false})
  ..on('/events/5/admission', {'eventId': 5, 'mode': 'OPEN', 'questions': <Object>[]});

void main() {
  setUpAll(loadTestFonts);

  testWidgets('CalmCover palet tonundan boyanir, kirmizi vitrin gradyani kullanmaz', (tester) async {
    for (final dark in [false, true]) {
      for (var seed = 0; seed < 6; seed++) {
        late BuTokens tokens;
        await tester.pumpWidget(p00App(
          Builder(builder: (context) {
            tokens = context.bu;
            return SizedBox(width: 300, height: 160, child: CalmCover(seed: seed, icon: Icons.event));
          }),
          lang: 'tr',
          dark: dark,
          scale: 1,
          scaffold: true,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final deco = tester
            .widgetList<DecoratedBox>(find.descendant(of: find.byType(CalmCover), matching: find.byType(DecoratedBox)))
            .first
            .decoration as BoxDecoration;
        final colors = (deco.gradient as LinearGradient).colors;
        expect(colors.first, tokens.tint(seed).bg, reason: 'seed=$seed dark=$dark');
        expect(colors, isNot(contains(tokens.h1)));
      }
    }
  });

  group('kapaksiz detaylar (3 dil x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('etkinlik detayi', (tester) async {
      await p00Matrix(tester, () => EventDetailPage(session: makeSession(_eventBe()), eventId: 5), scaffold: false, settleMs: 900);
    });
    testWidgets('kulup detayi', (tester) async {
      await p00Matrix(tester, () {
        final b = FakeBackend()
          ..on('/communities/7', {
            'id': 7,
            'name': 'Fotoğraf Kulübü',
            'description': 'Kampüste fotoğraf gezileri.',
            'category': 'Sanat',
            'memberCount': 12,
            'visibility': 'PUBLIC',
            'joinPolicy': 'OPEN',
            'myStatus': 'ACTIVE',
            'myRole': 'MEMBER',
          })
          ..on('/communities/7/posts*', {'items': <Object>[], 'nextCursor': null})
          ..on('/communities/7/requests*', {'items': <Object>[], 'nextCursor': null})
          ..on('/communities/7/join-questions', <Object>[])
          ..on('/events*', {'items': <Object>[], 'nextCursor': null});
        return ClubDetailPage(session: makeSession(b), communityId: 7);
      }, scaffold: false, settleMs: 900);
    });
  });

  testWidgets('etkinlik detayi kapaksiz: sakin kapak gorunur', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(p00App(EventDetailPage(session: makeSession(_eventBe()), eventId: 5), lang: 'tr', dark: false, scale: 1, scaffold: false));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(CalmCover), findsOneWidget);
  });

  testWidgets('oneri oy dugmesi dikey: sayi gorunur, dokununca tetiklenir, 48 dp alt sinir', (tester) async {
    var taps = 0;
    await tester.pumpWidget(p00App(
      Center(child: VotePill(count: 128, voted: false, vertical: true, onTap: () => taps++)),
      lang: 'tr',
      dark: false,
      scale: 1.3,
      scaffold: true,
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('128'), findsOneWidget);
    final size = tester.getSize(find.byType(VotePill));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(VotePill));
    expect(taps, 1);
  });

  group('ders programi', () {
    final now = DateTime.utc(2026, 11, 2, 5, 0); // Pazartesi 08:00 Istanbul
    setUp(() {
      academicClock = () => now;
      ReminderService.platform = _Platform();
      ReminderService.store = MemoryReminderStore();
    });
    tearDown(() {
      academicClock = DateTime.now;
      ReminderService.platform = const ChannelReminderPlatform();
      ReminderService.store = const SecureReminderStore();
    });

    testWidgets('gelecek derste Bekliyor etiketi yok, ders adi ve saat var', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final b = FakeBackend();
      fakeAcademic(b).addCourse('Veri Yapıları', 1, '09:00', '10:50', code: 'BIL201');
      await tester.pumpWidget(p00App(TimetablePage(session: makeSession(b)), lang: 'tr', dark: false, scale: 1, scaffold: false));
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Bekliyor'), findsNothing);
      expect(find.text('Veri Yapıları'), findsWidgets);
      expect(find.text('09:00 - 10:50'), findsOneWidget);
    });
  });
}
